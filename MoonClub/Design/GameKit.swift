import SwiftUI
import AudioToolbox
import MoonClubCore

// Game On (0.10): one HUD + juice system for every lesson, chart game, boss and quest, so they all feel
// like the same game. Hearts, a combo flame, coins that fly to the HUD, a live star meter, Luna reacting,
// chunky 3D answer buttons, a speed ring (games only, off in relaxed mode), a results screen where the
// stars slam in, and immersive full-screen play (no tab bar). Never punitive: running out of hearts just
// means Luna's rocket needs fuel, and you try again with your stars kept.

// MARK: - Settings (grown-ups corner) and sound

enum PlayPrefs {
  /// Relaxed play hides the speed ring (no clock at all).
  static let relaxedKey = "play.relaxed"
  static let soundsKey = "play.sounds"
}

/// System sounds only (no licensed assets). System sounds follow the ring/silent switch.
enum GameSound {
  case right, wrong, coin, win, chest
  @MainActor static func play(_ s: GameSound) {
    guard UserDefaults.standard.object(forKey: PlayPrefs.soundsKey) as? Bool ?? true else { return }
    let id: SystemSoundID
    switch s { case .right: id = 1057; case .wrong: id = 1104; case .coin: id = 1103; case .win: id = 1025; case .chest: id = 1021 }
    AudioServicesPlaySystemSound(id)
  }
}

// MARK: - The run

/// One run of a lesson, game, boss or quest: hearts, combo, coins, accuracy and Luna's mood.
@MainActor @Observable final class RunModel {
  static let maxHearts = 3
  var hearts = RunModel.maxHearts
  var combo = 0
  var bestCombo = 0
  var coins = 0
  var right = 0
  var answered = 0
  var mood: Luna.Mood = .happy
  /// Ticks that drive one-shot effects.
  var coinTick = 0
  var crackTick = 0
  var winTick = 0
  /// Boss health 0…1 (bosses only).
  var bossHP: Double = 1
  /// Global point the coins fly to (the HUD's coin counter).
  var coinTarget: CGPoint = .zero
  /// When the current round started (for the speed ring).
  var roundStart = Date()
  var started = false

  var multiplier: Int { combo >= 5 ? 3 : combo >= 3 ? 2 : 1 }
  var outOfFuel: Bool { hearts <= 0 }
  var accuracy: Int { answered == 0 ? 100 : Int((Double(right) / Double(answered) * 100).rounded()) }
  /// The run has progress worth asking about before leaving.
  var midRun: Bool { answered > 0 }

  /// Scores one answer. Returns the coins it earned (0 when wrong).
  @discardableResult func record(_ ok: Bool, fast: Bool = false, bossHit: Double = 0) -> Int {
    started = true
    answered += 1
    if ok {
      right += 1; combo += 1; bestCombo = max(bestCombo, combo)
      let gained = 10 * multiplier + (fast ? 5 : 0)
      coins += gained; coinTick += 1
      mood = combo >= 3 ? .cheering : .happy
      if bossHit > 0 { bossHP = max(0, bossHP - bossHit) }
      GameSound.play(.right)
      return gained
    } else {
      combo = 0; hearts = max(0, hearts - 1); crackTick += 1
      mood = .oops
      GameSound.play(.wrong)
      return 0
    }
  }
  func nextRound() { roundStart = Date(); if mood == .oops { mood = .thinking } }
  func reset() {
    hearts = Self.maxHearts; combo = 0; bestCombo = 0; coins = 0; right = 0; answered = 0
    mood = .happy; bossHP = 1; roundStart = Date(); started = false
  }
}

/// A boss shown in the HUD: a portrait and a health bar that drains as you answer right.
struct BossInfo {
  let name: String
  let art: String
}

// MARK: - HUD

struct GameHUD: View {
  @Bindable var run: RunModel
  let title: String
  /// Rounds/steps done, and how many in all.
  let done: Int
  let total: Int
  var boss: BossInfo? = nil
  /// Seconds for the speed ring (nil = no ring: lessons, quests, relaxed mode).
  var speed: Double? = nil
  var dark = false
  let onClose: () -> Void

  @Environment(\.accessibilityReduceMotion) private var rm
  @State private var confirm = false

  var body: some View {
    VStack(spacing: 8) {
      HStack(spacing: 12) {
        Button { if run.midRun { confirm = true } else { onClose() } } label: {
          Image(systemName: "xmark").font(.system(size: 16, weight: .heavy)).frame(width: 36, height: 36)
            .background(dark ? AnyShapeStyle(.white.opacity(0.14)) : AnyShapeStyle(.thinMaterial), in: Circle())
            .foregroundStyle(dark ? .white : Palette.ink)
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel("Close")
        .confirmationDialog("Leave? Your stars stay.", isPresented: $confirm, titleVisibility: .visible) {
          Button("Leave") { onClose() }
          Button("Keep playing", role: .cancel) {}
        }
        SegmentBar(done: done, total: total, dark: dark)
        Hearts(hearts: run.hearts, crack: run.crackTick)
      }
      HStack(spacing: 10) {
        Luna(size: 30, mood: run.mood)
          .modifier(Shake(amount: rm ? 0 : 5, tick: run.crackTick))
          .scaleEffect(run.mood == .cheering && !rm ? 1.12 : 1)
          .animation(Motion.safe(Motion.celebrate, rm), value: run.mood)
        ComboFlame(combo: run.combo, multiplier: run.multiplier, dark: dark)
        Spacer(minLength: 4)
        if let speed { SpeedRing(start: run.roundStart, seconds: speed) }
        StarMeter(stars: World.starsFor(right: run.right, of: max(total, 1)), live: run.answered > 0, dark: dark)
        CoinCounter(coins: run.coins, tick: run.coinTick, dark: dark)
          .background(GeometryReader { g in Color.clear.onAppear { run.coinTarget = CGPoint(x: g.frame(in: .global).midX, y: g.frame(in: .global).midY) }
            .onChange(of: g.frame(in: .global)) { _, f in run.coinTarget = CGPoint(x: f.midX, y: f.midY) } })
      }
      if let boss { BossBar(boss: boss, hp: run.bossHP) }
    }
    .padding(.top, 6)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("\(title). \(run.hearts) hearts, \(run.coins) coins.")
  }
}

struct SegmentBar: View {
  let done: Int, total: Int
  var dark = false
  @Environment(\.accessibilityReduceMotion) private var rm
  var body: some View {
    GeometryReader { g in
      ZStack(alignment: .leading) {
        Capsule().fill(dark ? Color.white.opacity(0.16) : Palette.line)
        Capsule().fill(LinearGradient(colors: [Hue.mint.color, Hue.teal.color], startPoint: .leading, endPoint: .trailing))
          .frame(width: max(14, g.size.width * CGFloat(min(done, total)) / CGFloat(max(total, 1))))
          .overlay(alignment: .top) { Capsule().fill(.white.opacity(0.35)).frame(height: 4).padding(.horizontal, 6).padding(.top, 3) }
          .opacity(done == 0 ? 0.35 : 1)
      }
    }
    .frame(height: 16)
    .animation(Motion.safe(Motion.card, rm), value: done)
    .accessibilityLabel("\(done) of \(total) done")
  }
}

struct Hearts: View {
  let hearts: Int
  let crack: Int
  @Environment(\.accessibilityReduceMotion) private var rm
  var body: some View {
    HStack(spacing: 2) {
      ForEach(0..<RunModel.maxHearts, id: \.self) { i in
        Image(systemName: i < hearts ? "heart.fill" : "heart.slash.fill")
          .font(.system(size: 18, weight: .bold))
          .foregroundStyle(i < hearts ? Hue.coral.color : Palette.line)
          .scaleEffect(i == hearts && !rm ? 0.85 : 1)
          .contentTransition(.symbolEffect(.replace))
      }
    }
    .modifier(Shake(amount: rm ? 0 : 7, tick: crack))
    .animation(Motion.safe(Motion.tap, rm), value: hearts)
    .accessibilityLabel("\(hearts) hearts")
  }
}

struct ComboFlame: View {
  let combo: Int, multiplier: Int
  var dark = false
  @Environment(\.accessibilityReduceMotion) private var rm
  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: "flame.fill").font(.system(size: 16, weight: .bold))
        .foregroundStyle(combo > 0 ? AnyShapeStyle(LinearGradient(colors: [Hue.lemon.color, Hue.orange.color, Hue.coral.color], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(Palette.line))
        .symbolEffect(.bounce, value: combo)
      // The meter fills toward the next multiplier (x2 at 3 in a row, x3 at 5).
      let goal = combo >= 5 ? 5 : combo >= 3 ? 5 : 3
      let base = combo >= 5 ? 5 : combo >= 3 ? 3 : 0
      VStack(alignment: .leading, spacing: 2) {
        Text(multiplier > 1 ? "x\(multiplier) combo" : combo > 0 ? "\(combo) in a row" : "Combo").font(.caption2.weight(.heavy)).lineLimit(1).fixedSize().foregroundStyle(dark ? .white : Palette.ink)
        Capsule().fill(dark ? Color.white.opacity(0.16) : Palette.line).frame(width: 54, height: 5)
          .overlay(alignment: .leading) {
            Capsule().fill(Hue.orange.color).frame(width: combo >= 5 ? 54 : 54 * CGFloat(combo - base) / CGFloat(max(1, goal - base)), height: 5)
          }
      }
    }
    .padding(.horizontal, 10).padding(.vertical, 5)
    .background(dark ? AnyShapeStyle(.white.opacity(0.1)) : AnyShapeStyle(.thinMaterial), in: Capsule())
    .scaleEffect(multiplier > 1 && !rm ? 1.04 : 1)
    .animation(Motion.safe(Motion.celebrate, rm), value: combo)
    .accessibilityLabel(combo > 0 ? "\(combo) in a row" : "No combo yet")
  }
}

struct StarMeter: View {
  let stars: Int; let live: Bool
  var dark = false
  @Environment(\.accessibilityReduceMotion) private var rm
  var body: some View {
    HStack(spacing: 1) {
      ForEach(0..<3, id: \.self) { i in
        Image(systemName: live && i < stars ? "star.fill" : "star").font(.system(size: 12, weight: .heavy))
          .foregroundStyle(live && i < stars ? Hue.gold.color : (dark ? Color.white.opacity(0.35) : Palette.line))
          .scaleEffect(live && i < stars && !rm ? 1.1 : 1)
      }
    }
    .animation(Motion.safe(Motion.celebrate, rm), value: stars)
    .accessibilityLabel("\(live ? stars : 0) stars so far")
  }
}

struct CoinCounter: View {
  let coins: Int, tick: Int
  var dark = false
  @Environment(\.accessibilityReduceMotion) private var rm
  var body: some View {
    HStack(spacing: 4) {
      CoinMark(size: 18)
      Text("\(coins)").font(.system(.subheadline, design: .rounded).weight(.heavy)).monospacedDigit()
        .contentTransition(.numericText(value: Double(coins)))
        .foregroundStyle(dark ? .white : Palette.ink)
    }
    .padding(.horizontal, 9).padding(.vertical, 5)
    .background(dark ? AnyShapeStyle(.white.opacity(0.1)) : AnyShapeStyle(.thinMaterial), in: Capsule())
    .modifier(Pop(tick: tick))
    .animation(Motion.safe(Motion.tap, rm), value: coins)
    .accessibilityLabel("\(coins) pretend coins")
  }
}

/// A drawn coin (gold disc with a rim and a moon), so no emoji is drawn as a picture.
struct CoinMark: View {
  var size: CGFloat = 18
  var body: some View {
    ZStack {
      Circle().fill(LinearGradient(colors: [Color(hex: 0xFFE27A), Hue.gold.color], startPoint: .top, endPoint: .bottom))
      Circle().strokeBorder(Color(hex: 0xB37A10).opacity(0.6), lineWidth: max(1, size * 0.08))
      Image(systemName: "moon.fill").font(.system(size: size * 0.48, weight: .bold)).foregroundStyle(Color(hex: 0xB37A10).opacity(0.8))
    }
    .frame(width: size, height: size)
    .accessibilityHidden(true)
  }
}

/// Speed ring: a round's clock drains around it; answering before it's empty earns +5 bonus coins.
/// It never ends a round or costs a heart.
struct SpeedRing: View {
  let start: Date; let seconds: Double
  var body: some View {
    TimelineView(.periodic(from: start, by: 0.1)) { ctx in
      let left = max(0, 1 - ctx.date.timeIntervalSince(start) / seconds)
      ZStack {
        Circle().stroke(Palette.line, lineWidth: 4)
        Circle().trim(from: 0, to: left).stroke(left > 0.3 ? Hue.mint.color : Hue.orange.color, style: .init(lineWidth: 4, lineCap: .round)).rotationEffect(.degrees(-90))
        Image(systemName: "bolt.fill").font(.system(size: 10, weight: .heavy)).foregroundStyle(left > 0 ? Hue.gold.color : Palette.line)
      }
      .frame(width: 26, height: 26)
    }
    .accessibilityLabel("Speed bonus timer")
  }
  static func fast(_ start: Date, _ seconds: Double?) -> Bool { seconds.map { Date().timeIntervalSince(start) < $0 } ?? false }
}

struct BossBar: View {
  let boss: BossInfo; let hp: Double
  @Environment(\.accessibilityReduceMotion) private var rm
  var body: some View {
    HStack(spacing: 10) {
      ZStack {
        Circle().fill(RadialGradient(colors: [Hue.berry.color, Palette.midnight], center: .center, startRadius: 2, endRadius: 26))
        Glyph(boss.art, size: 34, style: .plain).colorMultiply(.white).brightness(0.3)
      }
      .frame(width: 44, height: 44)
      .overlay(Circle().strokeBorder(Hue.lemon.color.opacity(0.8), lineWidth: 2))
      .modifier(Shake(amount: rm ? 0 : 6, tick: Int(hp * 100)))
      VStack(alignment: .leading, spacing: 4) {
        HStack {
          Text("BOSS · \(boss.name.uppercased())").font(.caption2.weight(.heavy)).tracking(1).foregroundStyle(.white)
          Spacer()
          Text("\(Int((hp * 100).rounded()))%").font(.caption2.weight(.heavy)).monospacedDigit().foregroundStyle(.white.opacity(0.8))
        }
        GeometryReader { g in
          ZStack(alignment: .leading) {
            Capsule().fill(.white.opacity(0.15))
            Capsule().fill(LinearGradient(colors: [Hue.coral.color, Hue.berry.color], startPoint: .leading, endPoint: .trailing))
              .frame(width: max(0, g.size.width * hp))
          }
        }
        .frame(height: 12)
      }
    }
    .padding(10)
    .background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    .animation(Motion.safe(Motion.card, rm), value: hp)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Boss \(boss.name), \(Int(hp * 100)) percent left")
  }
}

// MARK: - Juice

/// A horizontal shake each time `tick` changes.
struct Shake: GeometryEffect {
  var amount: CGFloat
  var tick: Int
  var animatableData: CGFloat
  init(amount: CGFloat, tick: Int) { self.amount = amount; self.tick = tick; animatableData = CGFloat(tick) }
  func effectValue(size: CGSize) -> ProjectionTransform {
    ProjectionTransform(CGAffineTransform(translationX: amount * sin(animatableData * .pi * 6), y: 0))
  }
}

/// A quick scale pop when `tick` changes.
struct Pop: ViewModifier {
  let tick: Int
  @Environment(\.accessibilityReduceMotion) private var rm
  @State private var up = false
  func body(content: Content) -> some View {
    content.scaleEffect(up ? 1.18 : 1)
      .onChange(of: tick) { _, _ in
        guard !rm else { return }
        withAnimation(Motion.tap) { up = true }
        Task { try? await Task.sleep(for: .milliseconds(160)); withAnimation(Motion.tap) { up = false } }
      }
  }
}

/// Coins that fly from the middle of the screen to the HUD's coin counter. One Canvas, no views per coin.
struct CoinBurst: View {
  let tick: Int
  let target: CGPoint
  @Environment(\.accessibilityReduceMotion) private var rm
  @State private var start: Date?
  var body: some View {
    GeometryReader { geo in
      let origin = geo.frame(in: .global).origin
      TimelineView(.animation(paused: start == nil)) { ctx in
        Canvas { g, size in
          guard let start else { return }
          let t = ctx.date.timeIntervalSince(start)
          let to = CGPoint(x: target.x - origin.x, y: target.y - origin.y)
          let from = CGPoint(x: size.width / 2, y: size.height * 0.55)
          for i in 0..<9 {
            let d = Double(i) * 0.045
            let k = min(1, max(0, (t - d) / 0.6))
            guard k > 0, k < 1 else { continue }
            let e = 1 - pow(1 - k, 3)
            let spread = CGFloat(i - 4) * 18
            let ctrl = CGPoint(x: from.x + spread * 2.2, y: from.y - 160)
            let x = (1 - e) * (1 - e) * (from.x + spread) + 2 * (1 - e) * e * ctrl.x + e * e * to.x
            let y = (1 - e) * (1 - e) * from.y + 2 * (1 - e) * e * ctrl.y + e * e * to.y
            let r: CGFloat = 9 * (1 - 0.35 * e)
            g.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .linearGradient(Gradient(colors: [Color(hex: 0xFFE27A), Hue.gold.color]), startPoint: CGPoint(x: x, y: y - r), endPoint: CGPoint(x: x, y: y + r)))
            g.stroke(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(Color(hex: 0xB37A10).opacity(0.6)), lineWidth: 1.5)
          }
        }
      }
    }
    .ignoresSafeArea()
    .allowsHitTesting(false)
    .accessibilityHidden(true)
    .onChange(of: tick) { _, _ in
      guard !rm else { return }
      start = Date()
      Task { try? await Task.sleep(for: .seconds(1.1)); start = nil }
    }
  }
}

// MARK: - Chunky answer buttons

enum AnswerState { case idle, right, wrong, dim }

/// A big 3D answer button: a colored edge under a face that presses down. Right glows green with a
/// check that pops; wrong wobbles. `index` picks its color, so the choices read as a colorful set.
struct AnswerButton: View {
  let text: String
  var icon: String? = nil
  var index = 0
  var state: AnswerState = .idle
  var compact = false
  let action: () -> Void
  static let hues: [Hue] = [.sky, .grape, .orange, .teal]
  var body: some View {
    Button(action: action) {
      if compact {
        // A row of short answers: the icon sits above the word so the word gets the whole width, and the
        // right/wrong mark is a corner badge (never squeezes the word).
        VStack(spacing: 2) {
          if let icon { Image(systemName: icon).font(.system(size: 16, weight: .heavy)) }
          Text(text).font(.system(.headline, design: .rounded).weight(.bold)).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .topTrailing) {
          if state == .right || state == .wrong {
            Image(systemName: state == .right ? "checkmark.circle.fill" : "xmark.circle.fill").font(.subheadline.weight(.bold))
              .offset(x: 6, y: -4).transition(.scale(scale: 0.2).combined(with: .opacity))
          }
        }
      } else {
      HStack(spacing: 10) {
        if let icon { Image(systemName: icon).font(.system(size: 17, weight: .heavy)) }
        else if !compact { Text(["A", "B", "C", "D"][index % 4]).font(.system(.subheadline, design: .rounded).weight(.heavy)).frame(width: 28, height: 28)
            .background(state == .idle ? hue.color : .white.opacity(0.25), in: RoundedRectangle(cornerRadius: 8, style: .continuous)).foregroundStyle(.white) }
        Text(text).font(.system(.headline, design: .rounded).weight(.bold)).multilineTextAlignment(compact ? .center : .leading).lineLimit(compact ? 1 : 3).minimumScaleFactor(compact ? 0.6 : 0.8)
          .frame(maxWidth: .infinity, alignment: compact ? .center : .leading)
        if state == .right { Image(systemName: "checkmark.circle.fill").font(.title3.weight(.bold)).transition(.scale(scale: 0.2).combined(with: .opacity)) }
        if state == .wrong { Image(systemName: "xmark.circle.fill").font(.title3.weight(.bold)).transition(.scale(scale: 0.2).combined(with: .opacity)) }
      }
      }
    }
    .buttonStyle(ChunkyStyle(face: face, edge: edge, ink: ink, glow: state == .right ? Hue.mint.color : nil))
    .modifier(Shake(amount: 8, tick: state == .wrong ? 1 : 0))
    .animation(Motion.celebrate, value: state)
    .accessibilityAddTraits(state == .right || state == .wrong ? .isSelected : [])
  }
  private var hue: Hue { Self.hues[index % Self.hues.count] }
  private var face: Color { switch state { case .idle: return Palette.card; case .right: return Palette.good; case .wrong: return Palette.bad; case .dim: return Palette.card.opacity(0.6) } }
  private var edge: Color { switch state { case .idle: return hue.color.opacity(0.55); case .right: return Color(hex: 0x135A37); case .wrong: return Color(hex: 0x7E2E1D); case .dim: return Palette.line } }
  private var ink: Color { state == .right || state == .wrong ? .white : (state == .dim ? Palette.ink2 : Palette.ink) }
}

/// The 3D press: the face sits 5 pt above its edge and sinks on touch (first frame), springs back.
struct ChunkyStyle: ButtonStyle {
  var face: Color = Palette.card
  var edge: Color = Palette.line
  var ink: Color = Palette.ink
  var glow: Color? = nil
  var depth: CGFloat = 4
  var radius: CGFloat = 18
  func makeBody(configuration: Configuration) -> some View {
    let down = configuration.isPressed ? depth - 1 : 0
    configuration.label
      .foregroundStyle(ink)
      .padding(.horizontal, 14).padding(.vertical, 9)
      .frame(maxWidth: .infinity, minHeight: 50)
      .background(face, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
      .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(edge.opacity(0.5), lineWidth: 1.5))
      .offset(y: down)
      .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(edge).offset(y: depth))
      .padding(.bottom, depth)
      .shadow(color: (glow ?? .clear).opacity(0.7), radius: glow == nil ? 0 : 14)
      .animation(Motion.tap, value: configuration.isPressed)
      .contentShape(Rectangle())
  }
}

/// The big primary action ("Next", "Check"), chunky like the answers.
struct ChunkyPrimary: ButtonStyle {
  var tint: Color = Palette.accent
  func makeBody(configuration: Configuration) -> some View {
    ChunkyStyle(face: tint, edge: tint.blend(with: .black, by: 0.35), ink: .white, radius: 22)
      .makeBody(configuration: configuration)
      .font(.system(.headline, design: .rounded).weight(.heavy))
  }
}

// MARK: - Results, out of fuel

/// End of a run: stars slam in one by one, then a stat row and the two ways on.
struct RunResults: View {
  let stars: Int
  let run: RunModel
  var boss = false
  var subtitle: String? = nil
  let again: () -> Void
  let map: () -> Void
  @Environment(\.accessibilityReduceMotion) private var rm
  @State private var slammed = 0
  @State private var flag = false
  var body: some View {
    VStack(spacing: 16) {
      Spacer(minLength: 0)
      ZStack(alignment: .bottom) {
        Luna(size: 92, wave: true, mood: stars >= 2 ? .cheering : .happy)
        if boss {
          Image(systemName: "flag.fill").font(.system(size: 44, weight: .heavy)).foregroundStyle(Hue.coral.color)
            .offset(x: 62, y: flag ? 0 : -260).opacity(flag ? 1 : 0)
            .rotationEffect(.degrees(flag ? 0 : -25), anchor: .bottom)
        }
      }
      Text(boss ? "Land conquered!" : stars == 3 ? "Perfect!" : stars == 2 ? "Great job!" : "You did it!")
        .font(.system(.largeTitle, design: .rounded).weight(.black)).multilineTextAlignment(.center)
      HStack(spacing: 14) {
        ForEach(0..<3, id: \.self) { i in
          Image(systemName: i < slammed ? "star.fill" : "star")
            .font(.system(size: 50, weight: .black))
            .foregroundStyle(i < slammed ? AnyShapeStyle(LinearGradient(colors: [Hue.lemon.color, Hue.gold.color], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(Palette.line))
            .shadow(color: i < slammed ? Hue.gold.color.opacity(0.6) : .clear, radius: 10)
            .scaleEffect(i < slammed || rm ? 1 : 0.6)
            .rotationEffect(.degrees(i < slammed || rm ? 0 : -30))
            .offset(y: i == 1 ? -10 : 0)
        }
      }
      .accessibilityElement().accessibilityLabel("\(stars) of 3 stars")
      .sensoryFeedback(.impact(weight: .heavy), trigger: slammed)
      if let subtitle { Text(subtitle).font(.kRead).multilineTextAlignment(.center).foregroundStyle(Palette.ink2).fixedSize(horizontal: false, vertical: true) }
      HStack(spacing: 10) {
        stat("\(run.accuracy)%", "right", "target", .mint)
        stat("\(run.bestCombo)", "best combo", "flame.fill", .orange)
        stat("\(run.coins)", "coins", "moon.fill", .gold)
      }
      Spacer(minLength: 0)
      VStack(spacing: 8) {
        Button(action: map) { Text(boss ? "Plant my flag" : "Back to the map") }.buttonStyle(ChunkyPrimary())
        Button(action: again) { Label("Play again", systemImage: "arrow.counterclockwise") }.buttonStyle(ChunkyStyle(face: Palette.card, edge: Palette.line, ink: Palette.ink))
      }
    }
    .task {
      GameSound.play(.win)
      if boss { try? await Task.sleep(for: .milliseconds(rm ? 0 : 250)); withAnimation(Motion.safe(Motion.celebrate, rm)) { flag = true } }
      for i in 0..<stars {
        try? await Task.sleep(for: .milliseconds(rm ? 0 : 330))
        withAnimation(rm ? Motion.fade : .spring(response: 0.32, dampingFraction: 0.5)) { slammed = i + 1 }
      }
    }
  }
  private func stat(_ v: String, _ label: String, _ icon: String, _ hue: Hue) -> some View {
    VStack(spacing: 2) {
      Image(systemName: icon).font(.system(size: 15, weight: .bold)).foregroundStyle(hue.color)
      Text(v).font(.system(.title2, design: .rounded).weight(.black)).monospacedDigit()
      Text(label).font(.caption.weight(.semibold)).foregroundStyle(Palette.ink2)
    }
    .frame(maxWidth: .infinity).padding(.vertical, 10)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    .accessibilityElement(children: .combine)
  }
}

/// Out of hearts: never a "game over", just a refuel.
struct OutOfFuel: View {
  let retry: () -> Void
  let leave: () -> Void
  var body: some View {
    VStack(spacing: 16) {
      Spacer(minLength: 0)
      ZStack {
        Circle().fill(Hue.orange.light.opacity(0.5)).frame(width: 150, height: 150)
        RocketMark(skin: Skins.all[0], size: 90, flame: false).rotationEffect(.degrees(-20))
      }
      Text("Luna's rocket needs fuel!").font(.system(.title, design: .rounded).weight(.black)).multilineTextAlignment(.center)
      Text("Everyone runs out sometimes. Try again and fill it back up. Your stars stay safe.").font(.kRead).multilineTextAlignment(.center).foregroundStyle(Palette.ink2).fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: 0)
      Button(action: retry) { Label("Refuel and try again", systemImage: "fuelpump.fill") }.buttonStyle(ChunkyPrimary(tint: Hue.orange.color.blend(with: .black, by: 0.12)))
      Button("Back to the map", action: leave).buttonStyle(ChunkyStyle())
    }
  }
}

// MARK: - The rocket (map + results), in the kid's skin

struct RocketMark: View {
  let skin: RocketSkin
  var size: CGFloat = 44
  var flame = true
  @Environment(\.accessibilityReduceMotion) private var rm
  @State private var flicker = false
  var body: some View {
    Canvas { g, sz in
      let w = sz.width, h = sz.height
      let body = Color(hex: skin.body), fin = Color(hex: skin.fin)
      if flame {
        var f = Path(); f.move(to: .init(x: w * 0.4, y: h * 0.78)); f.addQuadCurve(to: .init(x: w * 0.6, y: h * 0.78), control: .init(x: w * 0.5, y: h * (flicker ? 1.02 : 0.96))); f.closeSubpath()
        g.fill(f, with: .color(Color(hex: skin.flame)))
      }
      var l = Path(); l.move(to: .init(x: w * 0.36, y: h * 0.5)); l.addLine(to: .init(x: w * 0.18, y: h * 0.78)); l.addLine(to: .init(x: w * 0.38, y: h * 0.72)); l.closeSubpath()
      var r = Path(); r.move(to: .init(x: w * 0.64, y: h * 0.5)); r.addLine(to: .init(x: w * 0.82, y: h * 0.78)); r.addLine(to: .init(x: w * 0.62, y: h * 0.72)); r.closeSubpath()
      g.fill(l, with: .color(fin)); g.fill(r, with: .color(fin))
      var b = Path(); b.move(to: .init(x: w * 0.5, y: h * 0.04)); b.addQuadCurve(to: .init(x: w * 0.64, y: h * 0.76), control: .init(x: w * 0.78, y: h * 0.36)); b.addLine(to: .init(x: w * 0.36, y: h * 0.76)); b.addQuadCurve(to: .init(x: w * 0.5, y: h * 0.04), control: .init(x: w * 0.22, y: h * 0.36))
      g.fill(b, with: .color(body))
      g.stroke(b, with: .color(fin.opacity(0.45)), lineWidth: max(1, w * 0.02))
      g.fill(Path(ellipseIn: CGRect(x: w * 0.42, y: h * 0.28, width: w * 0.16, height: w * 0.16)), with: .color(Color(hex: 0x3F82EE)))
      g.stroke(Path(ellipseIn: CGRect(x: w * 0.42, y: h * 0.28, width: w * 0.16, height: w * 0.16)), with: .color(.white), lineWidth: max(1, w * 0.025))
    }
    .frame(width: size, height: size)
    .accessibilityHidden(true)
    .task { guard flame, !rm else { return }; withAnimation(.easeInOut(duration: 0.18).repeatForever()) { flicker = true } }
  }
}

// MARK: - Immersive play chrome

extension View {
  /// Full-screen play: no tab bar, no navigation bar (the HUD has the close button).
  func playChrome() -> some View {
    self.toolbar(.hidden, for: .tabBar)
      .toolbar(.hidden, for: .navigationBar)
      .navigationBarBackButtonHidden(true)
      .statusBarHidden(false)
  }
}

/// The dark, dramatic stage for boss fights: midnight with slow embers. Static under Reduce Motion.
struct BossBackdrop: View {
  @Environment(\.accessibilityReduceMotion) private var rm
  var body: some View {
    TimelineView(.animation(paused: rm)) { ctx in
      Canvas { g, size in
        let t = rm ? 0 : ctx.date.timeIntervalSinceReferenceDate
        g.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(Gradient(colors: [Color(hex: 0x0E0B24), Color(hex: 0x2A1145), Color(hex: 0x3B1230)]), startPoint: .zero, endPoint: CGPoint(x: size.width * 0.4, y: size.height)))
        g.fill(Path(ellipseIn: CGRect(x: -size.width * 0.3, y: size.height * 0.55, width: size.width * 1.6, height: size.height * 0.7)), with: .radialGradient(Gradient(colors: [Hue.coral.color.opacity(0.35), .clear]), center: CGPoint(x: size.width / 2, y: size.height), startRadius: 10, endRadius: size.height * 0.6))
        for i in 0..<28 {
          let fi = Double(i)
          let x = (fi * 137.5).truncatingRemainder(dividingBy: Double(size.width))
          let speed = 18 + (fi * 7).truncatingRemainder(dividingBy: 22)
          let y = Double(size.height) - (t * speed + fi * 61).truncatingRemainder(dividingBy: Double(size.height) + 40)
          let r = 1.2 + (fi * 3).truncatingRemainder(dividingBy: 2.4)
          g.fill(Path(ellipseIn: CGRect(x: x + sin(t + fi) * 8, y: y, width: r, height: r)), with: .color((i % 3 == 0 ? Hue.lemon.color : Hue.coral.color).opacity(0.55)))
        }
      }
    }
    .ignoresSafeArea()
    .accessibilityHidden(true)
  }
}

/// The boss itself, big, between the HUD and the question: it flinches and flashes when a right answer
/// lands, gloats a little on a miss, and wobbles on its last hit points. It takes the room the question
/// leaves, so a boss quiz never floats over an empty card. (The HP bar stays in the HUD, right above.)
struct BossArena: View {
  let boss: BossInfo
  @Bindable var run: RunModel
  @Environment(\.accessibilityReduceMotion) private var rm
  @State private var breathe = false
  @State private var flash = false
  @State private var last: Bool?
  var body: some View {
    GeometryReader { g in
      let d = max(56, min(g.size.height - 40, g.size.width * 0.55, 210))
      VStack(spacing: 10) {
        ZStack {
          Circle().fill(RadialGradient(colors: [Hue.berry.color.opacity(0.55), Hue.grape.color.opacity(0.18), .clear], center: .center, startRadius: 4, endRadius: d * 0.8))
            .frame(width: d * 1.6, height: d * 1.6)
            .scaleEffect(breathe && !rm ? 1.06 : 0.96)
          Circle().fill(RadialGradient(colors: [Hue.berry.color, Color(hex: 0x2A1145)], center: .center, startRadius: 2, endRadius: d * 0.55))
            .frame(width: d, height: d)
            .overlay(Circle().strokeBorder(Hue.lemon.color.opacity(0.85), lineWidth: 3))
            .shadow(color: Hue.berry.color.opacity(0.6), radius: 24)
          Glyph(boss.art, size: d * 0.5, style: .plain)
            .colorMultiply(Hue.lemon.color).brightness(0.25)
          if flash { Circle().fill(.white.opacity(0.7)).frame(width: d, height: d).transition(.opacity) }
        }
        .frame(height: d)
        .modifier(Shake(amount: rm ? 0 : 12, tick: run.coinTick))
        .rotationEffect(.degrees(run.bossHP < 0.3 && !rm && breathe ? 3 : 0))
        Text(line).font(.system(.headline, design: .rounded).weight(.heavy)).foregroundStyle(.white)
          .lineLimit(1).minimumScaleFactor(0.8)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .frame(minHeight: 100)
    .onChange(of: run.coinTick) { _, _ in
      last = true
      guard !rm else { return }
      withAnimation(.easeOut(duration: 0.08)) { flash = true }
      withAnimation(.easeIn(duration: 0.3).delay(0.1)) { flash = false }
    }
    .onChange(of: run.crackTick) { _, _ in last = false }
    .task { guard !rm else { return }; withAnimation(.easeInOut(duration: 1.6).repeatForever()) { breathe = true } }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("\(boss.name). \(line)")
  }
  private var line: String {
    if run.bossHP <= 0 { return "\(boss.name) is beaten!" }
    switch last {
    case .some(true): return run.bossHP < 0.3 ? "One more hit!" : "Ouch! Keep going!"
    case .some(false): return "Ha! Try the next one!"
    case .none: return "\(boss.name) blocks the way!"
    }
  }
}
