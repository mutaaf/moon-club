import SwiftUI
import MoonClubCore

// Moon Arcade: three climbs behind one door on the World map: Candle Academy (300 levels), Line Lab
// (220 levels) and Moon Tower (100 levels, then Deep Space). Rules are pure in MoonClubCore
// `Academy.swift`; the drills are `CandleDrills.swift` and `LineDrills.swift`.

struct ArcadeHub: View {
  @Environment(AppModel.self) private var app
  @Environment(\.dismiss) private var dismiss
  @State private var open: AcademyTrack?
  @State private var tower = false

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        HStack(spacing: 10) {
          Button { dismiss() } label: {
            Image(systemName: "chevron.left").font(.headline.weight(.heavy)).frame(width: 40, height: 40).moonGlass(Circle(), interactive: true, weight: .thin)
          }
          .buttonStyle(PressStyle()).accessibilityLabel("Back to the map")
          VStack(alignment: .leading, spacing: 0) {
            Text("Moon Arcade").font(.kHero)
            Text("Pick a climb. Every level is a few quick rounds.").font(.callout).foregroundStyle(Palette.ink2)
          }
        }
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 14)], spacing: 14) {
          ForEach(AcademyTrack.allCases, id: \.self) { t in
            door(title: t.title, blurb: t.blurb, symbol: t.symbol, hues: t == .candles ? [.coral, .orange] : [.teal, .sky],
                 level: Academy.current(t, app.state), of: t.mainLevels, stars: Academy.totalStars(t, app.state)) { open = t }
          }
          door(title: "Moon Tower", blurb: "Mixed games, 100 levels, then Deep Space.", symbol: "stairs", hues: [.grape, .berry],
               level: Tower.current(app.state), of: Tower.mainLevels, stars: Tower.totalStars(app.state)) { tower = true }
        }
        Text("Pretend money only. Charts give clues, not promises.").font(.footnote).foregroundStyle(Palette.ink2)
      }
      .padding(20)
      .readable(1040)
    }
    .background(AuroraField(surface: .school).ignoresSafeArea())
    .toolbar(.hidden, for: .navigationBar)
    .toolbar(.hidden, for: .tabBar)
    .navigationDestination(item: $open) { AcademyPath(track: $0) }
    .navigationDestination(isPresented: $tower) { TowerView() }
    .onAppear {
      #if DEBUG
      let a = ProcessInfo.processInfo.arguments
      if let i = a.firstIndex(of: "-academy"), i + 1 < a.count, open == nil { open = AcademyTrack(rawValue: a[i + 1]) }
      #endif
    }
  }

  private func door(title: String, blurb: String, symbol: String, hues: [Hue], level: Int, of total: Int, stars: Int, go: @escaping () -> Void) -> some View {
    Button(action: go) {
      VStack(alignment: .leading, spacing: 10) {
        HStack(alignment: .top) {
          Image(systemName: symbol).font(.system(size: 30, weight: .heavy)).foregroundStyle(.white)
            .frame(width: 60, height: 60).background(.white.opacity(0.22), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
          Spacer()
          Label("\(stars)", systemImage: "star.fill").font(.subheadline.weight(.heavy)).monospacedDigit()
            .foregroundStyle(Hue.gold.text).padding(.horizontal, 10).padding(.vertical, 5).background(.white, in: Capsule())
        }
        Text(title).font(.system(.title2, design: .rounded).weight(.heavy)).foregroundStyle(.white)
        Text(blurb).font(.callout.weight(.medium)).foregroundStyle(.white.opacity(0.92)).fixedSize(horizontal: false, vertical: true)
        VStack(alignment: .leading, spacing: 4) {
          Text(level > total ? "Level \(level) · past the top!" : "Level \(level) of \(total)").font(.caption.weight(.heavy)).foregroundStyle(.white)
          GeometryReader { g in
            ZStack(alignment: .leading) {
              Capsule().fill(.white.opacity(0.3))
              Capsule().fill(.white).frame(width: g.size.width * min(1, Double(level - 1) / Double(total)))
            }
          }
          .frame(height: 6)
        }
      }
      .padding(18)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(LinearGradient(colors: hues.map(\.color), startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
      .shadow(color: hues[0].color.opacity(0.35), radius: 10, y: 6)
    }
    .buttonStyle(PressStyle())
    .accessibilityLabel("\(title): level \(level) of \(total), \(stars) stars")
  }
}

/// A track's path: chapters of 20 level pads, opening on the climber's chapter.
struct AcademyPath: View {
  let track: AcademyTrack
  @Environment(AppModel.self) private var app
  @Environment(\.dismiss) private var dismiss
  @Environment(\.accessibilityReduceMotion) private var rm
  @State private var selected: AcademyLevel?
  @State private var playing: AcademyLevel?

  var body: some View {
    let cur = Academy.current(track, app.state)
    let chapters = Academy.shown(track, app.state) / Academy.chapterSize
    ScrollViewReader { proxy in
      ScrollView {
        VStack(alignment: .leading, spacing: 22) {
          ForEach(0..<chapters, id: \.self) { c in
            ChapterBlock(track: track, chapter: c, current: cur, state: app.state) { selected = $0 }
              .id("chapter-\(c)")
          }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .readable(1040)
      }
      .task {
        try? await Task.sleep(for: .milliseconds(80))
        proxy.scrollTo("chapter-\((cur - 1) / Academy.chapterSize)", anchor: .top)
      }
    }
    .background(AuroraField(surface: track == .candles ? .piggy : .guess).ignoresSafeArea())
    .safeAreaInset(edge: .top) { header(cur) }
    .toolbar(.hidden, for: .navigationBar)
    .toolbar(.hidden, for: .tabBar)
    .sheet(item: $selected) { l in
      AcademyLevelCard(level: l, play: { selected = nil; playing = l })
        .presentationDetents([.height(520), .large])
        .presentationCornerRadius(32)
        .presentationBackground(.regularMaterial)
    }
    .navigationDestination(item: $playing) { AcademyPlayer(level: $0) }
    .onAppear {
      #if DEBUG
      let a = ProcessInfo.processInfo.arguments
      if let i = a.firstIndex(of: "-academyPlay"), i + 1 < a.count, let n = Int(a[i + 1]), playing == nil { playing = Academy.level(track, n) }
      if let i = a.firstIndex(of: "-academyCard"), i + 1 < a.count, let n = Int(a[i + 1]), selected == nil { selected = Academy.level(track, n) }
      #endif
    }
  }

  private func header(_ cur: Int) -> some View {
    let total = Academy.totalStars(track, app.state)
    let ch = Academy.chapterName(track, (cur - 1) / Academy.chapterSize)
    return HStack(spacing: 10) {
      Button { dismiss() } label: {
        Image(systemName: "chevron.left").font(.headline.weight(.heavy)).frame(width: 40, height: 40).moonGlass(Circle(), interactive: true, weight: .thin)
      }
      .buttonStyle(PressStyle()).accessibilityLabel("Back")
      VStack(alignment: .leading, spacing: 1) {
        Text(track.title).font(.system(.title3, design: .rounded).weight(.heavy))
        Text(cur > track.mainLevels ? "Level \(cur) · \(ch)" : "Level \(cur) of \(track.mainLevels) · \(ch)").font(.caption.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.75).foregroundStyle(Palette.ink2)
      }
      Spacer(minLength: 6)
      Label("\(total)", systemImage: "star.fill").font(.subheadline.weight(.heavy)).monospacedDigit()
        .foregroundStyle(Hue.gold.text).padding(.horizontal, 10).padding(.vertical, 6).moonGlass(Capsule(), weight: .thin)
        .accessibilityLabel("\(total) stars")
    }
    .padding(.horizontal, 16).padding(.top, 6).padding(.bottom, 8)
    .background(Palette.paper.opacity(0.94).ignoresSafeArea(edges: .top).shadow(color: .black.opacity(0.1), radius: 6, y: 3))
  }
}

struct ChapterBlock: View, Equatable {
  let track: AcademyTrack
  let chapter: Int
  let current: Int
  let state: KidsState
  let tap: (AcademyLevel) -> Void
  static func == (a: ChapterBlock, b: ChapterBlock) -> Bool {
    a.track == b.track && a.chapter == b.chapter && a.current == b.current && a.stars == b.stars
  }
  var first: Int { chapter * Academy.chapterSize + 1 }
  var stars: [Int] { (first..<(first + Academy.chapterSize)).map { Academy.stars(track, $0, state) } }

  var body: some View {
    let info = track.chapters.indices.contains(chapter) ? track.chapters[chapter] : nil
    let got = stars.reduce(0, +)
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 12) {
        Image(systemName: info?.symbol ?? "infinity").font(.title2.weight(.heavy)).foregroundStyle(.white)
          .frame(width: 50, height: 50).background(LinearGradient(colors: hues.map(\.color), startPoint: .top, endPoint: .bottom), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        VStack(alignment: .leading, spacing: 1) {
          Text(info == nil ? "Endless mix" : "Chapter \(chapter + 1)").font(.kEyebrow).foregroundStyle(Palette.accentInk).textCase(.uppercase)
          Text(info?.name ?? "Every drill, all mixed").font(.kHeadline)
          Text(info?.line ?? "It never ends. How far can you go?").font(.caption).foregroundStyle(Palette.ink2)
        }
        Spacer(minLength: 4)
        Label("\(got)/60", systemImage: "star.fill").font(.caption.weight(.heavy)).monospacedDigit().foregroundStyle(Hue.gold.text)
      }
      if let info, !info.patterns.isEmpty {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 8) {
            ForEach(info.patterns, id: \.self) { p in PatternChip(pattern: p) }
          }
        }
      }
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 62), spacing: 8)], spacing: 10) {
        ForEach(first..<(first + Academy.chapterSize), id: \.self) { n in
          let l = Academy.level(track, n)
          AcademyPad(level: l, stars: Academy.stars(track, n, state), open: Academy.open(track, n, state), current: n == current) { tap(l) }
            .equatable()
            .id(l.id)
        }
      }
    }
    .padding(16)
    .background(Palette.card.opacity(0.9), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
  }
  private var hues: [Hue] { track == .candles ? [[.coral, .orange], [.orange, .gold], [.berry, .coral]][chapter % 3] : [[.teal, .sky], [.sky, .grape], [.mint, .teal]][chapter % 3] }
}

/// A pattern's picture and name (chapter strips and level cards).
struct PatternChip: View {
  let pattern: CandlePattern
  var big = false
  var body: some View {
    let ch = CandleLab.make(pattern, seed: 7, lead: 6)
    let shown = Array(ch.candles[max(0, ch.start - 2)...ch.end])
    HStack(spacing: 8) {
      MiniCandles(candles: shown).frame(width: big ? 64 : 44, height: big ? 56 : 38)
      VStack(alignment: .leading, spacing: 1) {
        Text(pattern.name).font((big ? Font.subheadline : .caption).weight(.heavy)).lineLimit(1)
        if big { Text(pattern.says).font(.caption).foregroundStyle(Palette.ink2).fixedSize(horizontal: false, vertical: true) }
      }
    }
    .padding(.horizontal, 10).padding(.vertical, 6)
    .background(Palette.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    .accessibilityElement(children: .combine)
  }
}

struct AcademyPad: View, Equatable {
  let level: AcademyLevel
  let stars: Int
  let open: Bool
  let current: Bool
  let tap: () -> Void
  @Environment(\.accessibilityReduceMotion) private var rm
  @State private var pulse = false
  static func == (a: AcademyPad, b: AcademyPad) -> Bool { a.level.id == b.level.id && a.stars == b.stars && a.open == b.open && a.current == b.current }

  var body: some View {
    let boss = level.isBoss
    let hue: Hue = level.kind == .boss ? .coral : level.kind == .miniBoss ? .grape : level.kind == .review ? .teal : level.track == .candles ? .orange : .sky
    Button(action: tap) {
      VStack(spacing: 2) {
        ZStack {
          if current {
            Circle().stroke(Hue.lemon.color, lineWidth: 4).frame(width: 62, height: 62)
              .scaleEffect(pulse && !rm ? 1.1 : 1).opacity(pulse && !rm ? 0.4 : 1)
          }
          Circle().fill(open ? AnyShapeStyle(hue.color) : AnyShapeStyle(Palette.line))
            .frame(width: 50, height: 50)
            .overlay(Circle().strokeBorder(.white.opacity(0.9), lineWidth: 2.5))
          if open {
            VStack(spacing: -2) {
              if boss { Image(systemName: level.kind == .boss ? "crown.fill" : "bolt.fill").font(.system(size: 10, weight: .black)) }
              else if level.kind == .review { Image(systemName: "arrow.counterclockwise").font(.system(size: 9, weight: .black)) }
              Text("\(level.number)").font(.system(size: 17, weight: .black, design: .rounded)).monospacedDigit().minimumScaleFactor(0.6).lineLimit(1)
            }
            .foregroundStyle(.white)
          } else {
            Image(systemName: "lock.fill").font(.subheadline).foregroundStyle(Palette.ink2)
          }
        }
        .frame(width: 64, height: 64)
        StarRow(stars: open ? stars : 0, size: 9)
      }
    }
    .buttonStyle(PressStyle())
    .accessibilityLabel(open ? "Level \(level.number), \(label), \(stars) stars" : "Level \(level.number), locked")
    .onAppear { if current && !rm { withAnimation(.easeInOut(duration: 0.9).repeatCount(8, autoreverses: true)) { pulse = true } } }
  }
  private var label: String {
    switch level.kind {
    case .boss: return "chapter boss"
    case .miniBoss: return "mini boss"
    case .review: return "review"
    default: return level.lead.title
    }
  }
}

struct AcademyLevelCard: View {
  let level: AcademyLevel
  let play: () -> Void
  @Environment(AppModel.self) private var app

  var body: some View {
    let open = Academy.open(level.track, level.number, app.state)
    let stars = Academy.stars(level.track, level.number, app.state)
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 2) {
          Eyebrow(text: "\(level.track.title) · \(Academy.chapterName(level.track, level.chapter))")
          Text(title).font(.kTitle)
        }
        Spacer()
        StarRow(stars: stars, size: 22)
      }
      Text(blurb).font(.callout.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
      if !level.teaches.isEmpty {
        VStack(alignment: .leading, spacing: 6) {
          ForEach(level.teaches.prefix(2), id: \.self) { p in PatternChip(pattern: p, big: true) }
        }
      }
      HStack(spacing: 6) {
        ForEach(level.drills, id: \.self) { d in
          Image(systemName: d.symbol).font(.caption.weight(.heavy)).frame(width: 32, height: 32).moonGlass(Circle(), weight: .thin)
            .accessibilityLabel(d.title)
        }
        if !level.mixed {
          VStack(alignment: .leading, spacing: 0) {
            Text(level.lead.title).font(.subheadline.weight(.heavy))
            if let c = level.lead.classic { Text(c).font(.caption).foregroundStyle(Palette.ink2) }
          }
        }
      }
      HStack(spacing: 8) {
        chip("\(level.rounds.count) rounds", "flag.checkered")
        chip(level.hearts == 1 ? "1 heart" : "\(level.hearts) hearts", "heart.fill")
        if level.scaffold > 0 { chip("Tips on", "lightbulb.fill") }
      }
      Spacer(minLength: 0)
      if open {
        PassPlayButton(title: stars > 0 ? "Play again" : level.isBoss ? "Take on the boss" : "Play level \(level.number)",
                       climb: level.track == .candles ? .candles : .lines, number: level.number, id: level.id, won: stars > 0, play: play)
      } else {
        Label("Win level \(level.number - 1) to open this one", systemImage: "lock.fill").font(.callout.weight(.bold)).foregroundStyle(Palette.ink2).frame(maxWidth: .infinity)
      }
    }
    .padding(22)
  }

  private var title: String {
    switch level.kind {
    case .boss: return level.chapterInfo == nil ? "Level \(level.number) boss" : "Chapter boss"
    case .miniBoss: return "Mini boss"
    case .review: return "Review · Level \(level.number)"
    default: return "Level \(level.number)"
    }
  }
  private var blurb: String {
    switch level.kind {
    case .learn: return level.scaffold == 2 ? "Watch and learn: Luna shows you the trick." : level.scaffold == 1 ? "Your turn, with a tip if you want one." : "Now on your own!"
    case .review: return "Old friends come back, so you don't forget them."
    case .miniBoss: return "Every drill from this chapter, mixed up."
    case .boss: return "Everything you've met so far. Beat it to clear the chapter!"
    case .endless: return "A mix of everything. It keeps going!"
    case .practice: return level.lead.how
    }
  }
  private func chip(_ t: String, _ s: String) -> some View {
    Label(t, systemImage: s).font(.footnote.weight(.bold)).lineLimit(1).minimumScaleFactor(0.8)
      .padding(.horizontal, 10).padding(.vertical, 6).background(Palette.card.opacity(0.8), in: Capsule())
  }
}

/// Plays one Academy level through the shared GameShell (HUD, hearts, combo, results).
struct AcademyPlayer: View {
  let level: AcademyLevel
  @Environment(AppModel.self) private var app
  var body: some View {
    let name = level.kind == .boss ? "\(Academy.chapterName(level.track, level.chapter)) boss" : "Level \(level.number)"
    let node = WorldNode(id: level.id, title: name, art: "👑", kind: .game(.readDay))
    let finish: (Int) -> Void = { s in
      let first = Academy.stars(level.track, level.number, app.state) == 0 && s > 0
      app.mutate { $0.earn(level.id, stars: s); $0.play(level.isBoss ? "boss" : "game", level.id, today: app.today) }
      if level.kind == .boss && first { PartyCenter.shared.fire(.bossBeaten, title: "\(Academy.chapterName(level.track, level.chapter)) cleared!") }
    }
    GameShell(node: node, rounds: level.rounds.count, intro: level.lead.how,
              boss: level.isBoss ? BossInfo(name: level.kind == .boss ? "Chapter boss" : "Mini boss", art: "👑") : nil,
              hearts: level.hearts,
              starRule: { Academy.starsFor(right: $0, of: $1) },
              roundTag: level.mixed ? { i in let d = level.rounds[i % level.rounds.count].drill; return "\(d.title): \(d.how)" } : nil,
              bossWin: "\(Academy.chapterName(level.track, level.chapter)) cleared!",
              onFinish: finish) { i, answer, answered in
      let r = level.rounds[i % level.rounds.count]
      if level.track == .candles {
        CandleDrill(level: level, round: r, answer: answer, answered: answered)
      } else {
        LineDrill(level: level, round: r, answer: answer, answered: answered)
      }
    }
  }
}
