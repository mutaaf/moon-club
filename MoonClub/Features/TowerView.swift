import SwiftUI
import MoonClubCore

// Moon Tower: climb from the launch pad through the clouds and orbit to the Moon Gate, then out into Deep
// Space, which never ends. One pad per level, a boss gate every 10th. The sky darkens and fills with stars
// as you climb. Rules (games, rounds, hearts, twists, unlocking) are pure in MoonClubCore `Tower.swift`.

enum TowerSky {
  /// Sky colors from the bottom of each zone to its top: day sky → dusk → night → space.
  static let stops: [UInt32] = [0xCDEBFF, 0x9DCBF6, 0x7C9EE6, 0x5966C9, 0x3A3A96, 0x1D1C55, 0x0A0A22]
  static func color(_ u: Double) -> Color {
    let x = max(0, min(1, u)) * Double(stops.count - 1)
    let i = min(stops.count - 2, Int(x)), t = x - Double(i)
    func ch(_ v: UInt32, _ s: UInt32) -> Double { Double((v >> s) & 0xFF) / 255 }
    let a = stops[i], b = stops[i + 1]
    return Color(red: ch(a, 16) + (ch(b, 16) - ch(a, 16)) * t, green: ch(a, 8) + (ch(b, 8) - ch(a, 8)) * t, blue: ch(a, 0) + (ch(b, 0) - ch(a, 0)) * t)
  }
  /// 0 at level 1, 1 at the top of the Moon Gate (and beyond).
  static func height(_ level: Double) -> Double { min(1, level / Double(Tower.mainLevels + 20)) }
  static func dark(_ level: Int) -> Bool { level > 50 }
}

struct TowerView: View {
  @Environment(AppModel.self) private var app
  @Environment(\.dismiss) private var dismiss
  @Environment(\.accessibilityReduceMotion) private var rm
  @State private var selected: TowerLevel?
  @State private var playing: TowerLevel?
  @State private var cleared: Int = 0
  @State private var burst = 0

  static let step: CGFloat = 96

  var body: some View {
    let cur = Tower.current(app.state)
    let floors = Tower.shown(app.state) / Tower.floorSize
    GeometryReader { geo in
      ScrollViewReader { proxy in
        ScrollView(.vertical, showsIndicators: false) {
          VStack(spacing: 0) {
            ForEach((1...floors).reversed(), id: \.self) { f in
              TowerFloor(floor: f, width: geo.size.width, current: cur, tap: { selected = $0 })
                .id("floor-\(f)")
            }
            TowerGround().frame(height: 160)
          }
        }
        .defaultScrollAnchor(.bottom)
        .background(TowerSky.color(0.02))
        .task {
          try? await Task.sleep(for: .milliseconds(80))
          proxy.scrollTo(Tower.id(cur), anchor: UnitPoint(x: 0.5, y: 0.6))
        }
        .onChange(of: cur) { old, new in
          guard new > old else { return }
          cleared = old
          Task {
            try? await Task.sleep(for: .milliseconds(rm ? 0 : 600))
            withAnimation(Motion.safe(Motion.page, rm)) { proxy.scrollTo(Tower.id(new), anchor: UnitPoint(x: 0.5, y: 0.6)) }
          }
        }
      }
    }
    .ignoresSafeArea(edges: .bottom)
    .background(TowerSky.color(TowerSky.height(Double(cur))).ignoresSafeArea())
    .safeAreaInset(edge: .top) { header(cur) }
    .toolbar(.hidden, for: .navigationBar)
    .toolbar(.hidden, for: .tabBar)
    .sheet(item: $selected) { l in
      TowerLevelCard(level: l, play: { selected = nil; playing = l })
        .presentationDetents([.height(470), .large])
        .presentationCornerRadius(32)
        .presentationBackground(.regularMaterial)
    }
    .navigationDestination(item: $playing) { TowerPlayer(level: $0) }
    .overlay(Celebrate(trigger: burst))
    .onAppear {
      #if DEBUG
      let a = ProcessInfo.processInfo.arguments
      if let i = a.firstIndex(of: "-towerPlay"), i + 1 < a.count, let n = Int(a[i + 1]), playing == nil { playing = Tower.level(n) }
      if let i = a.firstIndex(of: "-towerCard"), i + 1 < a.count, let n = Int(a[i + 1]), selected == nil { selected = Tower.level(n) }
      #endif
    }
  }

  private func header(_ cur: Int) -> some View {
    let total = Tower.totalStars(app.state)
    let z = Tower.zone(Tower.tier(cur))
    let dark = TowerSky.dark(cur)
    return HStack(spacing: 10) {
      Button { dismiss() } label: {
        Image(systemName: "chevron.left").font(.headline.weight(.heavy)).frame(width: 40, height: 40)
          .moonGlass(Circle(), interactive: true, weight: .thin, dark: dark)
      }
      .buttonStyle(PressStyle()).accessibilityLabel("Back to the map")
      VStack(alignment: .leading, spacing: 1) {
        Text("Moon Tower").font(.system(.title3, design: .rounded).weight(.heavy))
        Label(cur > Tower.mainLevels ? "Level \(cur) · \(z.name)" : "Level \(cur) of \(Tower.mainLevels) · \(z.name)", systemImage: z.symbol)
          .font(.caption.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.75).opacity(0.85)
      }
      Spacer(minLength: 6)
      Label("\(total)", systemImage: "star.fill").font(.subheadline.weight(.heavy)).monospacedDigit()
        .foregroundStyle(Hue.gold.color).padding(.horizontal, 10).padding(.vertical, 6)
        .moonGlass(Capsule(), weight: .thin, dark: dark)
        .accessibilityLabel("\(total) tower stars")
    }
    .foregroundStyle(dark ? Color.white : Palette.ink)
    .padding(.horizontal, 16).padding(.top, 6).padding(.bottom, 8)
    .background(TowerSky.color(TowerSky.height(Double(cur)) + 0.08).opacity(0.94).ignoresSafeArea(edges: .top).shadow(color: .black.opacity(0.12), radius: 6, y: 3))
    .overlay(alignment: .bottom) {
      GeometryReader { g in
        Capsule().fill(Hue.gold.color).frame(width: g.size.width * min(1, Double(cur - 1) / Double(Tower.mainLevels)), height: 3)
      }
      .frame(height: 3).padding(.horizontal, 16)
    }
  }
}

/// The grass, the launch pad and Luna's hangar under level 1.
struct TowerGround: View {
  var body: some View {
    ZStack(alignment: .top) {
      LinearGradient(colors: [TowerSky.color(0), Color(hex: 0x9ED89A)], startPoint: .top, endPoint: .bottom)
      VStack(spacing: 6) {
        Image(systemName: "flag.checkered").font(.title).foregroundStyle(Palette.ink.opacity(0.7))
        Text("Start here. Climb to the Moon!").font(.callout.weight(.heavy)).foregroundStyle(Palette.ink)
      }
      .padding(.top, 30)
    }
  }
}

/// One floor: ten pads zig-zagging up a beam, the boss gate on top, the sky behind it getting darker.
struct TowerFloor: View, Equatable {
  let floor: Int
  let width: CGFloat
  let current: Int
  let tap: (TowerLevel) -> Void
  @Environment(AppModel.self) private var app
  static func == (a: TowerFloor, b: TowerFloor) -> Bool { a.floor == b.floor && a.width == b.width && a.current == b.current }

  var height: CGFloat { CGFloat(Tower.floorSize) * TowerView.step + 40 }

  func point(_ n: Int) -> CGPoint {
    let k = (n - 1) % Tower.floorSize           // 0 at the bottom of the floor
    let x = width / 2 + min(width * 0.28, 150) * CGFloat(sin(Double(n) * 0.95))
    let y = height - 60 - CGFloat(k) * TowerView.step
    return CGPoint(x: n % Tower.floorSize == 0 ? width / 2 : x, y: y)
  }

  var body: some View {
    let first = (floor - 1) * Tower.floorSize + 1
    let levels = Array(first...(first + Tower.floorSize - 1))
    let lo = TowerSky.height(Double(first - 1)), hi = TowerSky.height(Double(first + Tower.floorSize - 1))
    let zoneStart = Tower.tier(first) != Tower.tier(max(1, first - 1)) || first == 1
    ZStack(alignment: .topLeading) {
      LinearGradient(colors: [TowerSky.color(hi), TowerSky.color(lo)], startPoint: .top, endPoint: .bottom)
      Starfield(seed: floor, density: max(0, (lo - 0.25) * 1.6)).allowsHitTesting(false)
      if lo < 0.3 { CloudBand(seed: floor).allowsHitTesting(false) }
      Canvas { g, _ in
        var p = Path()
        for (i, n) in levels.enumerated() { let q = point(n); if i == 0 { p.move(to: CGPoint(x: q.x, y: height)); p.addLine(to: q) } else { p.addLine(to: q) } }
        p.addLine(to: CGPoint(x: width / 2, y: 0))
        g.stroke(p, with: .color(.white.opacity(0.55)), style: .init(lineWidth: 4, lineCap: .round, dash: [2, 10]))
      }
      .allowsHitTesting(false)
      ForEach(levels, id: \.self) { n in
        let l = Tower.level(n)
        TowerPad(level: l, stars: Tower.stars(n, app.state), open: Tower.open(n, app.state), current: n == current) { tap(l) }
          .equatable()
          .id(Tower.id(n))
          .position(point(n))
        if n == current {
          RocketMark(skin: Skins.current(app.state), size: 36)
            .position(x: point(n).x + (point(n).x > width / 2 ? -64 : 64), y: point(n).y - 4)
            .allowsHitTesting(false)
        }
      }
      if zoneStart {
        let z = Tower.zone(Tower.tier(first))
        ZoneBanner(zone: z, dark: TowerSky.dark(first)).position(x: width / 2, y: height - 14)
      }
    }
    .frame(width: width, height: height)
    .clipped()
  }
}

struct ZoneBanner: View {
  let zone: TowerZone
  let dark: Bool
  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: zone.symbol).font(.headline)
      VStack(alignment: .leading, spacing: 0) {
        Text(zone.name).font(.subheadline.weight(.heavy))
        Text(zone.blurb).font(.caption2.weight(.semibold)).opacity(0.85)
      }
    }
    .foregroundStyle(dark ? Color.white : Palette.ink)
    .padding(.horizontal, 14).padding(.vertical, 6)
    .moonGlass(Capsule(), weight: .thin, dark: dark)
    .accessibilityElement(children: .combine)
  }
}

/// Little stars, more of them the higher you go (a still Canvas: nothing animates on the climb).
struct Starfield: View {
  let seed: Int
  let density: Double
  var body: some View {
    Canvas { g, sz in
      guard density > 0 else { return }
      var r = Seeded(seed &* 977)
      for _ in 0..<Int(density * 60) {
        let x = Double.random(in: 0...sz.width, using: &r), y = Double.random(in: 0...sz.height, using: &r)
        let s = Double.random(in: 1...2.6, using: &r)
        g.fill(Path(ellipseIn: CGRect(x: x, y: y, width: s, height: s)), with: .color(.white.opacity(Double.random(in: 0.35...0.9, using: &r))))
      }
    }
  }
}

struct CloudBand: View {
  let seed: Int
  var body: some View {
    GeometryReader { g in
      var r = Seeded(seed &* 131)
      let spots = (0..<4).map { _ in (Double.random(in: 0...1, using: &r), Double.random(in: 0...1, using: &r), Double.random(in: 40...80, using: &r)) }
      ForEach(spots.indices, id: \.self) { i in
        Image(systemName: "cloud.fill").font(.system(size: spots[i].2)).foregroundStyle(.white.opacity(0.7))
          .position(x: g.size.width * spots[i].0, y: g.size.height * spots[i].1)
      }
    }
  }
}

struct TowerPad: View, Equatable {
  let level: TowerLevel
  let stars: Int
  let open: Bool
  let current: Bool
  let tap: () -> Void
  @Environment(\.accessibilityReduceMotion) private var rm
  @State private var pulse = false
  static func == (a: TowerPad, b: TowerPad) -> Bool { a.level == b.level && a.stars == b.stars && a.open == b.open && a.current == b.current }

  var body: some View {
    let d: CGFloat = level.isBoss ? 82 : 62
    let hue: Hue = level.isBoss ? .coral : [.sky, .mint, .grape, .orange, .berry, .teal][level.tier % 6]
    Button(action: tap) {
      VStack(spacing: 3) {
        ZStack {
          if current {
            Circle().stroke(Hue.lemon.color, lineWidth: 4).frame(width: d + 16, height: d + 16)
              .scaleEffect(pulse && !rm ? 1.12 : 1).opacity(pulse && !rm ? 0.4 : 1)
          }
          Circle().fill(open ? AnyShapeStyle(LinearGradient(colors: [hue.color.opacity(0.95), hue.color], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(Color.white.opacity(0.55)))
            .frame(width: d, height: d)
            .overlay(Circle().strokeBorder(.white.opacity(0.9), lineWidth: 3))
            .shadow(color: .black.opacity(0.18), radius: 4, y: 3)
          if open {
            VStack(spacing: 0) {
              if level.isBoss { Image(systemName: "crown.fill").font(.caption.weight(.black)) }
              Text("\(level.number)").font(.system(size: level.isBoss ? 26 : 22, weight: .black, design: .rounded)).monospacedDigit()
                .minimumScaleFactor(0.6).lineLimit(1)
            }
            .foregroundStyle(.white)
          } else {
            Image(systemName: "lock.fill").font(.headline).foregroundStyle(Palette.ink2)
          }
          if open && !level.isBoss {
            Image(systemName: level.lead.symbol).font(.system(size: 11, weight: .heavy)).foregroundStyle(hue.color)
              .frame(width: 24, height: 24).background(.white, in: Circle())
              .offset(x: d / 2 - 6, y: d / 2 - 8)
          }
          if level.twist != nil && open {
            Image(systemName: "bolt.fill").font(.system(size: 11, weight: .heavy)).foregroundStyle(Hue.gold.color)
              .frame(width: 22, height: 22).background(Palette.midnight, in: Circle())
              .offset(x: -d / 2 + 6, y: -d / 2 + 8)
          }
        }
        .frame(width: d + 18, height: d + 18)
        if open { StarRow(stars: stars, size: 11).padding(.horizontal, 6).padding(.vertical, 2).background(.white.opacity(0.85), in: Capsule()) }
      }
    }
    .buttonStyle(PressStyle())
    .accessibilityLabel(open ? "Level \(level.number), \(level.isBoss ? "boss" : level.lead.title), \(stars) stars" : "Level \(level.number), locked")
    .onAppear { if current && !rm { withAnimation(.easeInOut(duration: 0.9).repeatCount(8, autoreverses: true)) { pulse = true } } }
  }
}

/// The level preview: the game, the dials, your stars and Play. Fits the sheet without scrolling.
struct TowerLevelCard: View {
  let level: TowerLevel
  let play: () -> Void
  @Environment(AppModel.self) private var app
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    let open = Tower.open(level.number, app.state)
    let stars = Tower.stars(level.number, app.state)
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 2) {
          Eyebrow(text: "\(level.zone.name) · Floor \(level.floor)")
          Text(level.isBoss ? "Floor \(level.floor) boss" : "Level \(level.number)").font(.kTitle)
        }
        Spacer()
        StarRow(stars: stars, size: 22)
      }
      if level.isBoss {
        VStack(alignment: .leading, spacing: 8) {
          Text("Every round is a different game you've met. Beat them all!").font(.callout.weight(.semibold))
          HStack(spacing: 6) {
            ForEach(Array(Set(level.games)).sorted { $0.debut < $1.debut }, id: \.self) { g in
              Image(systemName: g.symbol).font(.caption.weight(.heavy)).frame(width: 30, height: 30).moonGlass(Circle(), weight: .thin)
                .accessibilityLabel(g.title)
            }
          }
        }
      } else {
        HStack(spacing: 12) {
          Glyph(symbol: level.lead.symbol, hue: .grape, size: 52)
          VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
              Text(level.lead.title).font(.headline)
              if level.debut != nil {
                Text("NEW GAME").font(.caption2.weight(.black)).foregroundStyle(.white).padding(.horizontal, 6).padding(.vertical, 2).background(Hue.coral.color, in: Capsule())
              }
            }
            Text(level.lead.how).font(.callout).fixedSize(horizontal: false, vertical: true)
            Text(level.lead.classic).font(.caption.weight(.semibold)).foregroundStyle(Palette.ink2)
          }
        }
      }
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], alignment: .leading, spacing: 8) {
        chip("\(level.rounds) rounds", "flag.checkered")
        chip(level.hearts == 1 ? "1 heart" : "\(level.hearts) hearts", "heart.fill")
        chip("\(level.choices) answers", "square.grid.2x2")
        if level.tier >= 3 { chip("Perfect = 3 stars", "star.fill") }
      }
      if let t = level.twist {
        HStack(spacing: 10) {
          Image(systemName: t.symbol).font(.title3).foregroundStyle(Hue.gold.color)
          VStack(alignment: .leading, spacing: 0) {
            Text("Twist: \(t.title)").font(.subheadline.weight(.heavy))
            Text(t.line).font(.caption)
          }
        }
        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.midnight.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
      }
      Spacer(minLength: 0)
      if open {
        Button(stars > 0 ? "Play again" : level.isBoss ? "Take on the boss" : "Play level \(level.number)") { play() }.buttonStyle(ChunkyPrimary())
      } else {
        Label("Win level \(level.number - 1) to open this one", systemImage: "lock.fill").font(.callout.weight(.bold)).foregroundStyle(Palette.ink2)
          .frame(maxWidth: .infinity)
      }
    }
    .padding(22)
  }

  private func chip(_ t: String, _ s: String) -> some View {
    Label(t, systemImage: s).font(.footnote.weight(.bold)).lineLimit(1).minimumScaleFactor(0.8)
      .padding(.horizontal, 10).padding(.vertical, 6).frame(maxWidth: .infinity, alignment: .leading)
      .background(Palette.card.opacity(0.8), in: Capsule())
  }
}

/// Plays one Moon Tower level through the shared GameShell (HUD, hearts, combo, results).
struct TowerPlayer: View {
  let level: TowerLevel
  @Environment(AppModel.self) private var app
  var body: some View {
    let node = WorldNode(id: level.id, title: level.isBoss ? "Floor \(level.floor) boss" : "Level \(level.number)", art: "👑", kind: .game(.readDay))
    let rounds = Rounds(series: Array(app.candles.values).sorted { $0.s < $1.s }, seed: level.seed)
    let finish: (Int) -> Void = { s in
      let first = Tower.stars(level.number, app.state) == 0 && s > 0
      app.mutate { $0.earn(level.id, stars: s); $0.play(level.isBoss ? "boss" : "game", level.id, today: app.today) }
      if level.isBoss && first { PartyCenter.shared.fire(.bossBeaten, title: "Floor \(level.floor) cleared!") }
    }
    GameShell(node: node, rounds: level.rounds, intro: level.lead.how,
              boss: level.isBoss ? BossInfo(name: "Floor \(level.floor) guard", art: "👑") : nil,
              timed: !level.games.allSatisfy { $0 == .candlePop },
              hearts: level.hearts,
              starRule: { Tower.starsFor(right: $0, of: $1, tier: level.tier) },
              roundTag: level.mixed ? { i in "\(level.game(i).title): \(level.game(i).how)" } : nil,
              bossWin: "Floor \(level.floor) cleared!",
              onFinish: finish) { i, answer, answered in
      TowerRound(level: level, index: i, rounds: rounds, answer: answer, answered: answered)
    }
  }
}
