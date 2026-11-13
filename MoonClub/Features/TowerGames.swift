import SwiftUI
import MoonClubCore

// Moon Tower's rounds. The chart games reuse Market World's round views with the level's dials (longer
// charts, more answers, closer look-alikes); three arcade games are new and borrow from games everyone
// knows: Candle Pop (whack-a-mole), Memory flip (the card game) and Line them up (sorting a hand of cards).
// Nothing here scrolls, and no clock ever costs a heart: Candle Pop's wave just ends.

/// Practice candles for each day story, drawn inside 96…111 so they share `CandleMatchRound`'s scale.
enum TowerShapes {
  static func candle(_ s: DayStory, jitter seed: Int? = nil) -> Candle {
    var g = Seeded(seed ?? 0)
    func j(_ r: ClosedRange<Double>) -> Double { seed == nil ? (r.lowerBound + r.upperBound) / 2 : Double.random(in: r, using: &g) }
    switch s {
    case .bigUp:
      let o = 99 + j(0...2), c = o + j(6...8.5)
      return Candle(d: "", o: o, h: c + j(0.2...1.5), l: o - j(0.2...1.5), c: c)
    case .bigDown:
      let o = 107 + j(0...2), c = o - j(6...8.5)
      return Candle(d: "", o: o, h: o + j(0.2...1.5), l: c - j(0.2...1.5), c: c)
    case .smallUp:
      let o = 102 + j(0...3), c = o + j(1.4...2.4)
      return Candle(d: "", o: o, h: c + j(0.2...0.9), l: o - j(0.2...0.9), c: c)
    case .smallDown:
      let o = 105 + j(0...3), c = o - j(1.4...2.4)
      return Candle(d: "", o: o, h: o + j(0.2...0.9), l: c - j(0.2...0.9), c: c)
    case .tugOfWar:
      let o = 103.5 + j(0...1)
      return Candle(d: "", o: o, h: o + j(5...6.5), l: o - j(5...6.5), c: o - 0.3)
    }
  }
  static let domain: ClosedRange<Double> = 95...112
  /// Short names for cards.
  static func word(_ s: DayStory) -> String {
    switch s {
    case .bigUp: return "Big up day"
    case .smallUp: return "Small up day"
    case .bigDown: return "Big down day"
    case .smallDown: return "Small down day"
    case .tugOfWar: return "Tug of war"
    }
  }
}

/// One round of a Moon Tower level: picks the game for this round and dials it to the level.
struct TowerRound: View {
  let level: TowerLevel
  let index: Int
  let rounds: Rounds
  let answer: (RoundResult) -> Void
  let answered: RoundResult?
  @Environment(AppModel.self) private var app

  var body: some View {
    let s = level.seed &+ index &* 7919
    var g = Seeded(s)
    switch level.game(index) {
    case .candleMatch:
      let stories = DayStory.allCases.shuffled(using: &g)
      let target = stories[0]
      let pool = Array(stories.prefix(level.choices)).shuffled(using: &g)
      let candles = pool.enumerated().map { k, st in TowerShapes.candle(st, jitter: level.tier >= 2 ? s &+ k : nil) }
      CandleMatchRound(story: target, candles: candles, correct: pool.firstIndex(of: target) ?? 0, answer: answer, answered: answered)
    case .readDay:
      let story = DayStory.allCases.randomElement(using: &g) ?? .bigUp
      let (sym, c) = rounds.day(index, story: story)
      let opts = Self.dayOptions(story, count: level.choices, near: level.tier >= 3, rotate: s)
      ReadDayRound(company: companyName(sym, app), candle: c, options: opts, correct: opts.firstIndex(of: story.line) ?? 0, answer: answer, answered: answered)
    case .spotTrend:
      let t = Trend.allCases.randomElement(using: &g) ?? .up
      let (sym, cs) = rounds.window(index, length: level.chartDays, trend: t)
      SpotTrendRound(company: companyName(sym, app), candles: cs, trend: t, answer: answer, answered: answered)
    case .pattern:
      let p = ChartPattern.allCases.randomElement(using: &g) ?? .bounce
      let opts = ([p] + ChartPattern.allCases.filter { $0 != p }.shuffled(using: &g).prefix(level.choices - 1)).shuffled(using: &g)
      PatternRound(pattern: p, candles: Practice.chart(p, seed: s % 100_000, n: 30 + level.tier * 4), options: opts, answer: answer, answered: answered)
    case .findFloor:
      let ceiling = Bool.random(using: &g)
      let n = 32 + level.tier * 3
      FindLevelRound(candles: Array(Practice.chart(ceiling ? .breakout : .bounce, seed: s % 100_000, n: n).prefix(Int(Double(n) * (ceiling ? 0.68 : 0.8)))), ceiling: ceiling, answer: answer, answered: answered)
    case .busyDay:
      let (sym, cs) = rounds.window(index &+ 30, length: min(40, 16 + level.tier * 4))
      BusyDayRound(company: companyName(sym, app), candles: cs, answer: answer, answered: answered)
    case .smooth:
      SmoothRound(seed: s % 100_000, order: abs(s) % 3, answer: answer, answered: answered)
    case .candlePop:
      CandlePopRound(tier: level.tier, seed: s, wantUp: level.tier < 3 || index % 2 == 0, answer: answer, answered: answered)
    case .memory:
      MemoryRound(pairs: [3, 3, 4, 4, 5, 6][min(5, level.tier)], misses: max(2, [5, 5, 5, 4, 4, 4][min(5, level.tier)]), seed: s, answer: answer, answered: answered)
    case .ladder:
      LadderRound(count: [3, 3, 4, 4, 5, 5][min(5, level.tier)], gap: [3, 2.2, 1.6, 1.2, 0.9, 0.7][min(5, level.tier)], seed: s, answer: answer, answered: answered)
    }
  }

  /// The right story plus look-alikes: far ones low in the tower, near ones (big up vs small up) high up.
  static func dayOptions(_ s: DayStory, count: Int, near: Bool, rotate: Int) -> [String] {
    func isNear(_ o: DayStory) -> Bool {
      switch (s, o) {
      case (.bigUp, .smallUp), (.smallUp, .bigUp), (.bigDown, .smallDown), (.smallDown, .bigDown): return true
      default: return false
      }
    }
    var others = DayStory.allCases.filter { $0 != s }
    others.sort { a, b in near ? (isNear(a) && !isNear(b)) : (!isNear(a) && isNear(b)) }
    var o = [s.line] + others.prefix(count - 1).map(\.line)
    o.rotate(by: abs(rotate) % o.count)
    return o
  }
}

// MARK: - Candle Pop (like whack-a-mole)

/// Candles pop out of moon craters. Tap the right kind before they sink. A wrong tap takes a point back
/// (never a heart). The wave ends when you reach the goal or the time runs out.
struct CandlePopRound: View {
  let tier: Int
  let seed: Int
  /// Tap up days (or, from the Orbit Ring, every other round: down days).
  let wantUp: Bool
  let answer: (RoundResult) -> Void
  let answered: RoundResult?

  struct Pop: Identifiable, Equatable { let id: Int; let story: DayStory; let candle: Candle; let born: Date; let life: Double }
  @AppStorage(PlayPrefs.relaxedKey) private var relaxed = false
  @Environment(\.accessibilityReduceMotion) private var rm
  @State private var holes: [Pop?] = Array(repeating: nil, count: 9)
  @State private var score = 0
  @State private var started = Date()
  @State private var hitTick = 0
  @State private var whiffTick = 0
  @State private var flash: [Int: Bool] = [:]

  var target: Int { 5 + tier }
  var wave: Double { relaxed ? 28 : 20 }
  var spawnEvery: Double { max(0.45, 1.0 - 0.1 * Double(tier)) * (relaxed ? 1.4 : 1) }
  var life: Double { max(0.95, 2.0 - 0.2 * Double(tier)) * (relaxed ? 1.5 : 1) }
  func good(_ s: DayStory) -> Bool { wantUp ? (s == .bigUp || s == .smallUp) : (s == .bigDown || s == .smallDown) }

  var body: some View {
    VStack(spacing: 10) {
      HStack(spacing: 10) {
        Image(systemName: wantUp ? "arrow.up.circle.fill" : "arrow.down.circle.fill").font(.title2)
          .foregroundStyle(wantUp ? CandleChart.up : CandleChart.down)
        Text(wantUp ? "Tap the **up** days: hollow and green." : "Tap the **down** days: filled and red.")
          .font(.callout).lineLimit(2).minimumScaleFactor(0.8)
        Spacer(minLength: 4)
        Text("\(score)/\(target)").font(.title3.weight(.black).monospacedDigit())
          .contentTransition(.numericText(value: Double(score)))
          .padding(.horizontal, 10).padding(.vertical, 4).moonGlass(Capsule(), weight: .thin)
          .modifier(Shake(amount: rm ? 0 : 6, tick: whiffTick))
      }
      TimelineView(.periodic(from: started, by: 0.2)) { ctx in
        let left = max(0, 1 - ctx.date.timeIntervalSince(started) / wave)
        GeometryReader { g in
          Capsule().fill(Palette.line.opacity(0.5))
            .overlay(alignment: .leading) { Capsule().fill(left > 0.25 ? Hue.mint.color : Hue.orange.color).frame(width: g.size.width * (answered == nil ? left : 0)) }
        }
        .frame(height: 8)
      }
      .accessibilityHidden(true)
      ChartCard {
        GeometryReader { geo in
          let w = geo.size.width / 3, h = geo.size.height / 3
          ZStack(alignment: .topLeading) {
            ForEach(0..<9, id: \.self) { i in
              crater(i, w: w, h: h).frame(width: w, height: h).offset(x: CGFloat(i % 3) * w, y: CGFloat(i / 3) * h)
            }
          }
        }
      }
    }
    .sensoryFeedback(.impact(weight: .light), trigger: hitTick)
    .sensoryFeedback(.warning, trigger: whiffTick)
    .task { await loop() }
  }

  @ViewBuilder private func crater(_ i: Int, w: CGFloat, h: CGFloat) -> some View {
    let side = min(w, h)
    ZStack(alignment: .bottom) {
      Ellipse().fill(Palette.midnight.opacity(0.18)).frame(width: side * 0.86, height: side * 0.26)
        .overlay(Ellipse().strokeBorder(Palette.line, lineWidth: 1))
        .padding(.bottom, 4)
      if let p = holes[i] {
        Button { tap(i) } label: {
          BigCandle(o: p.candle.o, h: p.candle.h, l: p.candle.l, c: p.candle.c, domain: (p.candle.l - 0.5)...(p.candle.l + 12), labels: false)
            .frame(width: side * 0.62, height: side * 0.98)
            .offset(y: -side * 0.08)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .disabled(answered != nil)
        .transition(rm ? .opacity : .move(edge: .bottom).combined(with: .opacity))
        .id(p.id)
        .accessibilityLabel(TowerShapes.word(p.story))
      }
      if let ok = flash[i] {
        Image(systemName: ok ? "sparkles" : "xmark").font(.title.weight(.black))
          .foregroundStyle(ok ? Hue.gold.color : Hue.coral.color)
          .frame(maxHeight: .infinity)
          .transition(.scale.combined(with: .opacity))
      }
    }
    .clipped()
  }

  private func tap(_ i: Int) {
    guard answered == nil, let p = holes[i] else { return }
    let ok = good(p.story)
    withAnimation(Motion.safe(Motion.tap, rm)) {
      holes[i] = nil
      flash[i] = ok
      if ok { score += 1; hitTick += 1 } else { score = max(0, score - 1); whiffTick += 1 }
    }
    if ok { GameSound.play(.coin) }
    Task { try? await Task.sleep(for: .milliseconds(350)); withAnimation { flash[i] = nil } }
  }

  private func loop() async {
    started = Date()
    var g = Seeded(seed)
    var next = 0
    var last = Date.distantPast
    while !Task.isCancelled && answered == nil {
      try? await Task.sleep(for: .milliseconds(100))
      let now = Date()
      for i in holes.indices { if let p = holes[i], now.timeIntervalSince(p.born) > p.life { withAnimation(Motion.safe(Motion.tap, rm)) { holes[i] = nil } } }
      if score >= target { finish(true); return }
      if now.timeIntervalSince(started) >= wave { finish(false); return }
      guard now.timeIntervalSince(last) >= spawnEvery else { continue }
      let empty = holes.indices.filter { holes[$0] == nil }
      guard let h = empty.randomElement(using: &g) else { continue }
      let goodOnes: [DayStory] = wantUp ? [.bigUp, .smallUp] : [.bigDown, .smallDown]
      var badOnes: [DayStory] = wantUp ? [.bigDown, .smallDown] : [.bigUp, .smallUp]
      if tier >= 2 && wantUp { badOnes.append(.tugOfWar) }
      let st = (Double.random(in: 0...1, using: &g) < 0.55 ? goodOnes : badOnes).randomElement(using: &g) ?? .bigUp
      withAnimation(Motion.safe(Motion.card, rm)) {
        holes[h] = Pop(id: next, story: st, candle: TowerShapes.candle(st, jitter: seed &+ next), born: now, life: life)
      }
      next += 1; last = now
    }
  }

  private func finish(_ ok: Bool) {
    answer(RoundResult(right: ok, why: ok ? (wantUp ? "Hollow green bodies ended higher than they started." : "Filled red bodies ended lower than they started.")
                                          : "You got \(score) of \(target). Look for the body: \(wantUp ? "hollow green is up" : "filled red is down")."))
  }
}

// MARK: - Memory flip (like the card game Memory)

/// Cards lie face down. Flip two: a picture and its name stay up. A few misses are free; run out and the
/// round ends (it's a miss, never a lost heart beyond the round's one).
struct MemoryRound: View {
  let pairs: Int
  let misses: Int
  let seed: Int
  let answer: (RoundResult) -> Void
  let answered: RoundResult?

  enum Face: Hashable { case story(DayStory), trend(Trend) }
  struct Card: Identifiable, Hashable { let id: Int; let face: Face; let picture: Bool }
  @Environment(\.accessibilityReduceMotion) private var rm
  @State private var up: [Int] = []
  @State private var matched: Set<Int> = []
  @State private var used = 0
  @State private var busy = false

  var cards: [Card] {
    var g = Seeded(seed)
    let faces = (DayStory.allCases.map(Face.story) + Trend.allCases.map(Face.trend)).shuffled(using: &g).prefix(pairs)
    var out: [Card] = []
    for (k, f) in faces.enumerated() { out.append(Card(id: k * 2, face: f, picture: true)); out.append(Card(id: k * 2 + 1, face: f, picture: false)) }
    return out.shuffled(using: &g)
  }

  var body: some View {
    let cs = cards
    let cols = cs.count <= 6 ? 3 : 4
    let rows = (cs.count + cols - 1) / cols
    VStack(spacing: 10) {
      HStack {
        Label("\(matched.count / 2) of \(pairs) pairs", systemImage: "square.on.square").font(.callout.weight(.bold))
        Spacer()
        HStack(spacing: 3) {
          ForEach(0..<misses, id: \.self) { i in
            Image(systemName: i < misses - used ? "moon.fill" : "moon").foregroundStyle(i < misses - used ? Hue.gold.color : Palette.line)
          }
        }
        .accessibilityElement().accessibilityLabel("\(misses - used) misses left")
      }
      VStack(spacing: 8) {
        ForEach(0..<rows, id: \.self) { r in
          HStack(spacing: 8) {
            ForEach(0..<cols, id: \.self) { c in
              let k = r * cols + c
              if k < cs.count { card(cs[k]) } else { Color.clear }
            }
          }
        }
      }
      .frame(maxHeight: .infinity)
    }
  }

  @ViewBuilder private func card(_ c: Card) -> some View {
    let shown = up.contains(c.id) || matched.contains(c.id) || answered != nil
    Button { flip(c) } label: {
      ZStack {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .fill(shown ? AnyShapeStyle(matched.contains(c.id) ? Palette.good.opacity(0.16) : Palette.card) : AnyShapeStyle(LinearGradient(colors: [Hue.grape.color, Palette.midnight], startPoint: .top, endPoint: .bottom)))
          .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(matched.contains(c.id) ? Palette.good : Palette.line, lineWidth: matched.contains(c.id) ? 2.5 : 1))
        if shown { face(c).padding(6).rotation3DEffect(.degrees(rm ? 0 : 0), axis: (x: 0, y: 1, z: 0)) }
        else { Image(systemName: "moon.stars.fill").font(.title2).foregroundStyle(Hue.lemon.text.opacity(0.9)) }
      }
      .rotation3DEffect(.degrees(shown || rm ? 0 : 180), axis: (x: 0, y: 1, z: 0))
      .animation(Motion.safe(Motion.card, rm), value: shown)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .buttonStyle(PressStyle())
    .disabled(answered != nil || shown || busy)
    .accessibilityLabel(shown ? label(c) : "Face-down card")
  }

  @ViewBuilder private func face(_ c: Card) -> some View {
    if c.picture {
      switch c.face {
      case let .story(s):
        let k = TowerShapes.candle(s)
        BigCandle(o: k.o, h: k.h, l: k.l, c: k.c, domain: TowerShapes.domain, labels: false)
      case let .trend(t):
        TrendSketch(trend: t)
      }
    } else {
      Text(label(c)).font(.footnote.weight(.heavy)).multilineTextAlignment(.center).minimumScaleFactor(0.6).lineLimit(2)
        .foregroundStyle(Palette.ink)
    }
  }

  private func label(_ c: Card) -> String {
    switch c.face { case let .story(s): return TowerShapes.word(s); case let .trend(t): return t.word }
  }

  private func flip(_ c: Card) {
    guard answered == nil, !busy else { return }
    up.append(c.id)
    guard up.count == 2, let a = cards.first(where: { $0.id == up[0] }), let b = cards.first(where: { $0.id == up[1] }) else { return }
    if a.face == b.face && a.picture != b.picture {
      matched.formUnion(up); up = []
      GameSound.play(.coin)
      if matched.count == cards.count {
        answer(RoundResult(right: true, why: "Every picture found its name. Great memory!"))
      }
    } else {
      used += 1; busy = true
      let out = used >= misses
      Task {
        try? await Task.sleep(for: .milliseconds(out ? 500 : 850))
        up = []; busy = false
        if out { answer(RoundResult(right: false, why: "Out of free misses. Hollow green is up, filled red is down, a tiny body is a tug of war.")) }
      }
    }
  }
}

/// A tiny line that goes up, down or sideways (Memory flip's trend cards).
struct TrendSketch: View {
  let trend: Trend
  var body: some View {
    Canvas { g, sz in
      let ys: [Double] = {
        switch trend {
        case .up: return [0.8, 0.65, 0.7, 0.5, 0.55, 0.35, 0.2]
        case .down: return [0.2, 0.35, 0.3, 0.5, 0.45, 0.65, 0.8]
        case .sideways: return [0.5, 0.4, 0.55, 0.45, 0.55, 0.42, 0.5]
        }
      }()
      var p = Path()
      for (i, y) in ys.enumerated() {
        let pt = CGPoint(x: sz.width * CGFloat(i) / CGFloat(ys.count - 1), y: sz.height * CGFloat(y))
        if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
      }
      let col: Color = trend == .up ? CandleChart.up : trend == .down ? CandleChart.down : Hue.sky.color
      g.stroke(p, with: .color(col), style: .init(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
    }
    .accessibilityHidden(true)
  }
}

// MARK: - Line them up (like sorting a hand of cards)

/// A few days, each starting at the same price. Tap them in order: the biggest up day first, the biggest
/// down day last. Higher in the tower, the days are closer together.
struct LadderRound: View {
  let count: Int
  let gap: Double
  let seed: Int
  let answer: (RoundResult) -> Void
  let answered: RoundResult?
  @State private var order: [Int] = []

  /// Percent moves, shown left to right in a shuffled order.
  var moves: [Double] {
    var g = Seeded(seed)
    let top = gap * Double(count - 1) * Double.random(in: 0.35...0.65, using: &g)
    let vs = (0..<count).map { k in top - Double(k) * gap * Double.random(in: 0.85...1.25, using: &g) }
    return vs.map { $0 == 0 ? 0.3 : $0 }.shuffled(using: &g)
  }
  func candle(_ m: Double, _ k: Int) -> Candle {
    var g = Seeded(seed &+ k &* 31)
    let o = 100.0, c = o * (1 + m / 100)
    return Candle(d: "", o: o, h: max(o, c) + Double.random(in: 0.2...0.8, using: &g), l: min(o, c) - Double.random(in: 0.2...0.8, using: &g), c: c)
  }

  var body: some View {
    let ms = moves
    let cs = ms.indices.map { candle(ms[$0], $0) }
    let lo = (cs.map(\.l).min() ?? 95) - 0.6, hi = (cs.map(\.h).max() ?? 105) + 0.6
    let right = ms.indices.sorted { ms[$0] > ms[$1] }
    VStack(spacing: 12) {
      ChartCard(caption: "Every day starts at the same price") {
        HStack(spacing: 6) {
          ForEach(ms.indices, id: \.self) { k in
            Button { tap(k, right: right) } label: {
              VStack(spacing: 4) {
                BigCandle(o: cs[k].o, h: cs[k].h, l: cs[k].l, c: cs[k].c, domain: lo...hi, labels: false)
                  .frame(maxWidth: .infinity, maxHeight: .infinity)
                badge(k, right: right)
              }
              .padding(4)
              .background(order.contains(k) ? Palette.accent.opacity(0.1) : Color.clear, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
              .contentShape(Rectangle())
            }
            .buttonStyle(PressStyle())
            .disabled(answered != nil || order.contains(k))
            .accessibilityLabel(answered == nil ? "Day \(k + 1)" : String(format: "%+.1f%%", ms[k]))
          }
        }
      }
      HStack(spacing: 10) {
        Label("Biggest up first", systemImage: "arrow.up").font(.footnote.weight(.bold)).foregroundStyle(Palette.ink2)
        Spacer()
        Button("Start over") { order = [] }.buttonStyle(SoftButtonStyle()).disabled(order.isEmpty || answered != nil)
      }
    }
  }

  @ViewBuilder private func badge(_ k: Int, right: [Int]) -> some View {
    if answered != nil {
      let rank = (right.firstIndex(of: k) ?? 0) + 1
      Text(String(format: "%d · %+.1f%%", rank, moves[k])).font(.caption2.weight(.heavy).monospacedDigit()).lineLimit(1).minimumScaleFactor(0.6)
        .foregroundStyle(order.firstIndex(of: k).map { $0 + 1 == rank } ?? false ? Palette.good : Hue.coral.color)
    } else if let i = order.firstIndex(of: k) {
      Text("\(i + 1)").font(.headline.weight(.black)).foregroundStyle(.white).frame(width: 26, height: 26).background(Palette.accent, in: Circle())
    } else {
      Circle().strokeBorder(Palette.line, lineWidth: 2).frame(width: 26, height: 26)
    }
  }

  private func tap(_ k: Int, right: [Int]) {
    guard answered == nil, !order.contains(k) else { return }
    order.append(k)
    guard order.count == count else { return }
    let ok = order == right
    answer(RoundResult(right: ok, why: ok ? "Tall hollow green went up the most. Tall filled red went down the most." : "Look at each body: the taller the green, the bigger the up day. Red is down."))
  }
}
