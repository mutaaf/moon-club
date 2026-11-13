import SwiftUI
import MoonClubCore

// iPhone Duo stages (0.14): Luna's puppet show (tent mode), Luna's pocket (the outer display while the
// phone is closed), and a generic "also on the TV" accessory. Every piece here appears only where a hinge
// exists (capability, never model). Pure rules: MoonClubCore `DuoPlay.swift` (Stance, PocketGlance…).

// MARK: - Also on the TV

/// Shows `tv` on a connected TV or display as a non-interactive accessory (AirPlay or cable, iOS 27+),
/// while the phone stays the controller. The system decides when it's available.
struct OnTV<TV: View>: ViewModifier {
  @Binding var available: Bool
  @ViewBuilder var tv: () -> TV
  func body(content: Content) -> some View {
    if #available(iOS 27.0, *) {
      content.sceneAccessory {
        ExternalNonInteractiveAccessory { tv() }
          .onAvailabilityChange { available = $0 }
      }
    } else { content }
  }
}

// MARK: - Puppet show (tent mode)

/// Luna's puppet show: stand an iPhone Duo up like a tent and one page becomes a little theater facing the
/// family, where Luna tells today's market story; the other page is the kid's controls (next line, make
/// Luna wave or cheer, read it aloud). The SDK has no posture API, so the tent is emulated from a steady,
/// narrow hinge angle (`Stance`). Without a fold, the stage and the controls simply stack.
struct PuppetShow: View {
  @Environment(AppModel.self) private var app
  @Environment(DuoModel.self) private var duo: DuoModel?
  @Environment(\.dismiss) private var dismiss
  @Environment(\.accessibilityReduceMotion) private var rm
  @State private var line = 0
  @State private var mood: Luna.Mood = .happy
  @State private var bow = 0
  @State private var onTV = false

  var lines: [String] { PuppetScript.lines(app) }

  var body: some View {
    let ls = lines
    Storybook(spacing: 16, minPage: 260, fill: true) {
      VStack(spacing: 10) { stage(ls, compact: true).frame(maxHeight: .infinity); controls(ls, compact: true) }
    } first: {
      stage(ls)
    } second: {
      controls(ls)
    }
    .padding(16)
    .background(LinearGradient(colors: [Color(hex: 0x1A1440), Color(hex: 0x2E1B4F)], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
    .overlay(Celebrate(trigger: bow, tier: .medium).ignoresSafeArea())
    .modifier(OnTV(available: $onTV) { PuppetTV(line: ls[safe: line] ?? "", mood: mood).environment(app) })
    .playChrome()
  }

  private func stage(_ ls: [String], compact: Bool = false) -> some View {
    ZStack {
      // The theater: velvet curtains and a spotlight, all drawn.
      RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Color(hex: 0x120E2E))
      HStack(spacing: 0) { Curtain(); Spacer(minLength: 0); Curtain().scaleEffect(x: -1) }
      RadialGradient(colors: [Hue.lemon.color.opacity(0.35), .clear], center: .init(x: 0.5, y: 0.45), startRadius: 10, endRadius: 220)
      VStack(spacing: compact ? 8 : 16) {
        Text("LUNA'S PUPPET SHOW").font(.kEyebrow).tracking(1.4).foregroundStyle(Hue.lemon.text)
        Luna(size: compact ? 84 : 150, wave: true, mood: mood)
          .modifier(LunaBounce(tick: line))
        Text(ls[safe: line] ?? "").font(.system(.title3, design: .rounded).weight(.bold)).foregroundStyle(.white)
          .multilineTextAlignment(.center).lineLimit(4).minimumScaleFactor(0.7)
          .padding(compact ? 10 : 16).frame(maxWidth: 420)
          .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
          .id(line).transition(.opacity)
      }
      .padding(compact ? 12 : 24)
    }
    .accessibilityElement(children: .combine)
  }

  private func controls(_ ls: [String], compact: Bool = false) -> some View {
    VStack(alignment: .leading, spacing: compact ? 8 : 14) {
      HStack {
        DuoCallout(text: onTV ? "The show is on the TV too!" : "Puppet show: you run it", symbol: "theatermasks.fill", dark: true)
        Spacer()
        Button { dismiss() } label: { Image(systemName: "xmark").font(.headline.weight(.heavy)).frame(width: 44, height: 44).moonGlass(Circle(), interactive: true, weight: .thin, dark: true) }
          .accessibilityLabel("Close")
      }
      Text("Line \(line + 1) of \(ls.count)").font(.kHeadline).foregroundStyle(.white.opacity(0.8))
      HStack(spacing: 10) {
        Button { go(-1, ls) } label: { Label("Back", systemImage: "chevron.left") }.buttonStyle(SoftButtonStyle()).disabled(line == 0)
        Button { go(1, ls) } label: { Label(line + 1 < ls.count ? "Next line" : "Take a bow", systemImage: line + 1 < ls.count ? "chevron.right" : "hands.clap.fill") }
          .buttonStyle(ChunkyPrimary())
      }
      Text("Make Luna…").font(.caption.weight(.heavy)).foregroundStyle(.white.opacity(0.7))
      HStack(spacing: 10) {
        moodButton("Smile", "face.smiling", .happy)
        moodButton("Cheer", "party.popper.fill", .cheering)
        moodButton("Think", "brain.head.profile", .thinking)
      }
      ReadAloud(source: .appCopy(ls[safe: line] ?? ""), label: "Luna, say it!")
        .foregroundStyle(.white)
      Spacer(minLength: 0)
    }
    .padding(compact ? 12 : 18)
    .frame(maxWidth: .infinity, maxHeight: compact ? nil : .infinity, alignment: .topLeading)
    .moonGlass(radius: 28, dark: true)
  }

  private func moodButton(_ title: String, _ symbol: String, _ m: Luna.Mood) -> some View {
    Button { withAnimation(Motion.safe(Motion.tap, rm)) { mood = m } } label: {
      VStack(spacing: 4) { Image(systemName: symbol).font(.title3.weight(.bold)); Text(title).font(.caption.weight(.bold)) }
        .frame(maxWidth: .infinity, minHeight: 60)
        .foregroundStyle(mood == m ? Palette.midnight : .white)
        .background(mood == m ? Hue.lemon.color : .white.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    .buttonStyle(PressStyle())
    .accessibilityAddTraits(mood == m ? .isSelected : [])
  }

  private func go(_ step: Int, _ ls: [String]) {
    if step > 0, line + 1 >= ls.count {
      bow += 1; mood = .cheering; Chime.rising()
      if duo?.hasHinge == true { app.mutate { $0.useDuo(.puppet) } }
      return
    }
    withAnimation(Motion.safe(Motion.card, rm)) { line = max(0, min(ls.count - 1, line + step)) }
  }
}

/// A velvet curtain, drawn (no images).
private struct Curtain: View {
  var body: some View {
    GeometryReader { g in
      let w = g.size.width, h = g.size.height
      Path { p in
        p.move(to: .zero); p.addLine(to: CGPoint(x: w, y: 0))
        p.addQuadCurve(to: CGPoint(x: w * 0.25, y: h), control: CGPoint(x: w * 0.2, y: h * 0.45))
        p.addLine(to: CGPoint(x: 0, y: h)); p.closeSubpath()
      }
      .fill(LinearGradient(colors: [Color(hex: 0xB0263F), Color(hex: 0x6E1230), Color(hex: 0xB0263F), Color(hex: 0x6E1230)], startPoint: .leading, endPoint: .trailing))
    }
    .frame(width: 70)
    .accessibilityHidden(true)
  }
}

/// The show's lines, from today's market story (grade ≤ 5, app copy only: safe to read aloud).
enum PuppetScript {
  @MainActor static func lines(_ app: AppModel) -> [String] {
    var out = ["Hello, everyone! I'm Luna. Welcome to today's market story!"]
    if let m = app.mood { let w = weatherFor(m); out.append("The market weather today: \(w.title). \(w.line)") }
    var seen = Set<String>()
    for e in app.upcoming where !seen.contains(e.s) && seen.count < 2 {
      seen.insert(e.s)
      out.append("\(app.company(e.s).nick) shares its report card \(kidWhen(e.d, e.h, today: app.today)). Will it beat or miss?")
    }
    out.append("Remember: prices go up and down. Learning to read them is the fun part!")
    out.append("That's the show! Thank you for watching!")
    return out
  }
}

/// The puppet show on a TV: the stage only, big.
struct PuppetTV: View {
  let line: String
  let mood: Luna.Mood
  var body: some View {
    ZStack {
      LinearGradient(colors: [Color(hex: 0x1A1440), Color(hex: 0x2E1B4F)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
      VStack(spacing: 28) {
        Luna(size: 220, wave: true, mood: mood)
        Text(line).font(.system(size: 44, weight: .bold, design: .rounded)).foregroundStyle(.white).multilineTextAlignment(.center).padding(.horizontal, 60)
      }
    }
  }
}

// MARK: - Luna's pocket (outer display)

/// A tiny glanceable screen for the closed phone: today's missions, the Moon Garden, and Luna, asleep
/// until the phone is picked up (device motion, no permission needed) or tapped. Appears when an iPhone
/// Duo closes outside of play; opening the phone (or "Open Moon Club") goes straight back to the app.
struct LunaPocket: View {
  let close: () -> Void
  @Environment(AppModel.self) private var app
  @Environment(\.accessibilityReduceMotion) private var rm
  @State private var awake = false
  @State private var motion = MotionTilt.shared

  var body: some View {
    let g = PocketGlance.make(app.state, app.content, candles: app.candles, today: app.today)
    VStack(spacing: 18) {
      Spacer(minLength: 0)
      Luna(size: 120, wave: awake, mood: awake ? .happy : .sleepy)
        .overlay(alignment: .topTrailing) {
          if !awake { Image(systemName: "moon.zzz.fill").font(.title2.weight(.bold)).foregroundStyle(Hue.grape.light).offset(x: 14, y: -8) }
        }
        .animation(Motion.safe(Motion.celebrate, rm), value: awake)
      Text(awake ? g.line : "Shh… Luna is napping. Pick me up!").font(.kTitle).foregroundStyle(.white)
        .multilineTextAlignment(.center).lineLimit(3).minimumScaleFactor(0.7)
      HStack(spacing: 14) {
        glance(title: "Missions", value: "\(g.missionsDone)/\(g.missionsTotal)", symbol: "checkmark.seal.fill", hue: .gold,
               progress: g.missionsTotal == 0 ? 0 : Double(g.missionsDone) / Double(g.missionsTotal))
        glance(title: "Moon Garden", value: "\(g.gardenValue)", symbol: g.gardenPlanted == 0 ? "leaf" : (g.gardenUp ? "arrow.up.right" : "arrow.down.right"),
               hue: .mint, progress: nil)
      }
      Button("Open Moon Club", action: close).buttonStyle(ChunkyPrimary())
      Spacer(minLength: 0)
    }
    .padding(22)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(LinearGradient(colors: [Color(hex: 0x0F0E22), Color(hex: 0x231B52)], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
    .contentShape(Rectangle())
    .onTapGesture { awake = true }
    .onAppear { motion.retain() }
    .onDisappear { motion.release() }
    .onChange(of: motion.jolt) { _, _ in awake = true }
    .sensoryFeedback(.impact(weight: .light), trigger: awake)
    .task {
      #if DEBUG
      if ProcessInfo.processInfo.arguments.contains("-pocketWake") { try? await Task.sleep(for: .seconds(2)); awake = true }
      #endif
    }
    .accessibilityElement(children: .contain)
    .accessibilityAction(named: "Wake Luna") { awake = true }
  }

  private func glance(title: String, value: String, symbol: String, hue: Hue, progress: Double?) -> some View {
    VStack(spacing: 6) {
      ZStack {
        if let progress {
          Circle().stroke(.white.opacity(0.15), lineWidth: 7)
          Circle().trim(from: 0, to: progress).stroke(hue.color, style: .init(lineWidth: 7, lineCap: .round)).rotationEffect(.degrees(-90))
        }
        Image(systemName: symbol).font(.title2.weight(.heavy)).foregroundStyle(hue.text)
      }
      .frame(width: 58, height: 58)
      Text(value).font(.system(size: 26, weight: .heavy, design: .rounded)).monospacedDigit().foregroundStyle(.white)
      Text(title).font(.caption.weight(.bold)).foregroundStyle(.white.opacity(0.75))
    }
    .frame(maxWidth: .infinity).padding(.vertical, 12)
    .moonGlass(radius: 22, dark: true)
    .accessibilityElement(children: .combine)
  }
}
