import SwiftUI
import MoonClubCore

// The Market World chart games. Every game is a few short rounds inside one `GameShell`: a prompt, a chart
// you touch, a gentle "why", then stars. Answers come from MoonClubCore.ChartMath (unit-tested). Nothing
// on these screens scrolls inside a card: the chart takes the space that's left, and copy is one line.

struct RoundResult: Equatable { let right: Bool; let why: String }

/// Rounds, feedback, stars and the finish card for every game.
struct GameShell<Round: View>: View {
  let node: WorldNode
  let rounds: Int
  let intro: String
  var onFinish: (Int) -> Void
  @ViewBuilder let round: (_ index: Int, _ answer: @escaping (RoundResult) -> Void, _ answered: RoundResult?) -> Round

  @Environment(\.dismiss) private var dismiss
  @Environment(\.accessibilityReduceMotion) private var rm
  @State private var index = 0
  @State private var right = 0
  @State private var result: RoundResult?
  @State private var finished = false
  @State private var burst = 0

  var body: some View {
    VStack(spacing: 14) {
      header
      ZStack {
        if finished { finish.transition(.scale(scale: 0.92).combined(with: .opacity)) }
        else {
          round(index, { r in guard result == nil else { return }; withAnimation(Motion.safe(Motion.card, rm)) { result = r }; if r.right { right += 1 } }, result)
            .id(index)
            .transition(rm ? .opacity : .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      footer
    }
    .padding(.horizontal, 20).padding(.bottom, 12)
    .readable(760)
    .background(AuroraField(surface: .school))
    .overlay(Celebrate(trigger: burst))
    .navigationTitle(node.title)
    .navigationBarTitleDisplayMode(.inline)
    .sensoryFeedback(trigger: result) { _, n in n.map { $0.right ? .success : .warning } }
  }

  private var header: some View {
    VStack(spacing: 8) {
      HStack(spacing: 6) {
        ForEach(0..<rounds, id: \.self) { i in
          Capsule().fill(i < index || (i == index && (result != nil || finished)) ? Palette.accent : Palette.line).frame(height: 6)
        }
      }
      if !finished { Text(intro).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink2).frame(maxWidth: .infinity, alignment: .leading).lineLimit(2).minimumScaleFactor(0.85) }
    }
    .padding(.top, 8)
    .animation(Motion.safe(Motion.card, rm), value: index)
  }

  @ViewBuilder private var footer: some View {
    if finished {
      Button("Back to the map") { dismiss() }.buttonStyle(PrimaryButtonStyle())
    } else if let r = result {
      VStack(spacing: 10) {
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: r.right ? "checkmark.circle.fill" : "arrow.uturn.left.circle.fill").font(.title2).foregroundStyle(r.right ? Palette.good : Hue.orange.color)
          Text((r.right ? "Yes! " : "Good try. ") + r.why).font(.callout.weight(.medium)).fixedSize(horizontal: false, vertical: true)
          Spacer(minLength: 0)
        }
        .padding(12).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        Button(index + 1 < rounds ? "Next" : "See my stars") { next() }.buttonStyle(PrimaryButtonStyle())
      }
      .transition(.move(edge: .bottom).combined(with: .opacity))
    }
  }

  private var stars: Int { World.starsFor(right: right, of: rounds) }

  private var finish: some View {
    VStack(spacing: 16) {
      Luna(size: 110, wave: true, mood: stars == 3 ? .cheering : .happy)
      StarRow(stars: stars, size: 40, animated: true)
      Text(stars == 3 ? "Perfect!" : stars == 2 ? "Great job!" : "You did it!").font(.kHero)
      Text("\(right) of \(rounds) right. \(stars == 3 ? "You conquered it!" : "Play again any time for more stars.")").font(.kRead).multilineTextAlignment(.center).foregroundStyle(Palette.ink2)
    }
    .padding(28)
    .frame(maxWidth: .infinity)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
  }

  private func next() {
    if index + 1 < rounds {
      withAnimation(Motion.safe(Motion.card, rm)) { index += 1; result = nil }
    } else {
      onFinish(stars)
      withAnimation(Motion.safe(Motion.celebrate, rm)) { finished = true }
      burst += 1
    }
  }
}

struct StarRow: View {
  let stars: Int
  var size: CGFloat = 14
  var animated = false
  @Environment(\.accessibilityReduceMotion) private var rm
  @State private var shown = 0
  var body: some View {
    HStack(spacing: size * 0.18) {
      ForEach(0..<3, id: \.self) { i in
        Image(systemName: i < (animated ? shown : stars) ? "star.fill" : "star")
          .font(.system(size: size, weight: .bold))
          .foregroundStyle(i < (animated ? shown : stars) ? Hue.gold.color : Palette.line)
          .scaleEffect(animated && i < shown && !rm ? 1 : animated && !rm ? 0.6 : 1)
      }
    }
    .accessibilityElement().accessibilityLabel("\(stars) of 3 stars")
    .task {
      guard animated else { return }
      for i in 0..<stars {
        try? await Task.sleep(for: .milliseconds(rm ? 0 : 260))
        withAnimation(Motion.safe(Motion.celebrate, rm)) { shown = i + 1 }
      }
    }
    .sensoryFeedback(.impact(weight: .medium), trigger: shown)
  }
}

/// A card that holds the chart: fills the space it's given, never scrolls.
struct ChartCard<C: View>: View {
  var caption: String? = nil
  @ViewBuilder var content: C
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      if let caption { Text(caption).font(.kEyebrow).tracking(1.2).foregroundStyle(Palette.accent).textCase(.uppercase) }
      content.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .padding(16)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(Palette.line.opacity(0.6), lineWidth: 0.5))
  }
}

/// Answer buttons in one row when they fit, else stacked.
struct Choices: View {
  let options: [String]
  var correct: Int
  var answered: RoundResult?
  var picked: Int?
  var pick: (Int) -> Void
  var body: some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: 10) { buttons }
      VStack(spacing: 8) { buttons }
    }
  }
  @ViewBuilder private var buttons: some View {
    ForEach(options.indices, id: \.self) { i in
      Button { pick(i) } label: {
        Text(options[i]).font(.kHeadline).multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.8)
          .frame(maxWidth: .infinity, minHeight: 50).padding(.horizontal, 12)
          .background(fill(i), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
          .foregroundStyle(answered != nil && (i == correct || i == picked) ? Color.white : Palette.ink)
      }
      .buttonStyle(PressStyle())
      .disabled(answered != nil)
    }
  }
  private func fill(_ i: Int) -> AnyShapeStyle {
    guard answered != nil else { return AnyShapeStyle(.thinMaterial) }
    if i == correct { return AnyShapeStyle(Palette.good) }
    if i == picked { return AnyShapeStyle(Hue.coral.color) }
    return AnyShapeStyle(.thinMaterial)
  }
}

/// Instant press feedback (the touch shows on the first frame, settles with Motion.tap).
struct PressStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.scaleEffect(configuration.isPressed ? 0.96 : 1).animation(Motion.tap, value: configuration.isPressed)
  }
}

// MARK: - Rounds data

/// Picks real chart windows for a game, the same each day (seeded by date and node), from the bundled
/// or freshly loaded candles.
struct Rounds {
  let series: [CandleSeries]
  var seed: Int
  init(series: [CandleSeries], seed: Int) { self.series = series.filter { $0.candles.count >= 60 }; self.seed = seed }
  func window(_ i: Int, length: Int, trend: Trend? = nil) -> (String, [Candle]) {
    var g = Seeded(seed &+ i &* 7919)
    for _ in 0..<40 {
      guard let s = series.randomElement(using: &g) else { break }
      let starts: [Int] = trend.map { ChartMath.windows(s, length: length, trend: $0, step: 3) } ?? Array(stride(from: 0, through: s.candles.count - length, by: 3))
      if let st = starts.randomElement(using: &g) { return (s.s, s.window(st, length)) }
    }
    return ("Practice", Practice.chart(.bounce, seed: seed &+ i, n: length))
  }
  func day(_ i: Int, story: DayStory) -> (String, Candle) {
    var g = Seeded(seed &+ i &* 104729)
    let pool = series.flatMap { s in s.candles.map { (s.s, $0) } }.filter { ChartMath.story($0.1) == story }
    if let p = pool.randomElement(using: &g) { return p }
    return ("Practice", Candle(d: "", o: 100, h: 104, l: 98, c: story == .bigUp ? 103 : 97))
  }
}

@MainActor func companyName(_ s: String, _ app: AppModel) -> String { app.companies[s]?.nick ?? (s == "Practice" ? "Practice chart" : s) }

// MARK: - Candle Canyon

/// Build the candle: drag Start, End, High and Low to match the day's story.
struct BuildCandleGame: View {
  let node: WorldNode; let onFinish: (Int) -> Void
  static let days: [(o: Double, h: Double, l: Double, c: Double)] = [(5, 9, 4, 8), (9, 10, 3, 4), (6, 11, 5, 7), (8, 9, 2, 3)]
  var body: some View {
    GameShell(node: node, rounds: 3, intro: "Drag the four handles to build this day's candle.", onFinish: onFinish) { i, answer, answered in
      BuildCandleRound(day: Self.days[i % Self.days.count], answer: answer, answered: answered)
    }
  }
}

struct BuildCandleRound: View {
  let day: (o: Double, h: Double, l: Double, c: Double)
  let answer: (RoundResult) -> Void
  let answered: RoundResult?
  /// start, end, high, low: a calm starting candle, every handle in a different spot.
  @State private var v: [Double] = [5, 7, 10, 2]
  @State private var dragging: Int?
  let names = ["Start", "End", "High", "Low"]
  static let bodyWidth: CGFloat = 64, lane: CGFloat = 34, axis: CGFloat = 40
  // Lanes: Start on the body's left edge, End on its right edge, High and Low on the wick (centered).
  // Labels on the outside (Start left, End right, High above, Low below), so nothing overlaps. A faint
  // ghost candle shows the shape being built; `set` keeps it a real candle (High on top, Low at the bottom).
  var body: some View {
    VStack(spacing: 12) {
      Text("It started at **\(coins(day.o))**, went as high as **\(coins(day.h))**, as low as **\(coins(day.l))**, and ended at **\(coins(day.c))**.")
        .font(.kRead).fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
      ChartCard {
        GeometryReader { geo in
          let h = geo.size.height, w = geo.size.width
          let y: (Double) -> CGFloat = { p in h - 22 - CGFloat(p / 12) * (h - 44) }
          let cx = Self.axis + (w - Self.axis) * 0.5
          let xs: [CGFloat] = [cx - Self.bodyWidth / 2 - Self.lane, cx + Self.bodyWidth / 2 + Self.lane, cx, cx]
          ZStack(alignment: .topLeading) {
            ghost(cx: cx, y: y, size: geo.size)
            ForEach(0..<4, id: \.self) { k in
              label(k).position(labelPoint(k, x: xs[k], y: y(v[k])))
              handle(k).position(x: xs[k], y: y(v[k]))
                .gesture(DragGesture(minimumDistance: 0).onChanged { g in
                  dragging = k
                  set(k, (Double((h - 22 - g.location.y) / (h - 44)) * 12).rounded())
                }.onEnded { _ in dragging = nil })
                .disabled(answered != nil)
            }
          }
        }
      }
      Button("Check my candle") {
        let ok = v[0] == day.o && v[1] == day.c && v[2] == day.h && v[3] == day.l
        answer(RoundResult(right: ok, why: ok ? "Start and end make the body. High and low make the wicks." : "Start \(coins(day.o)), end \(coins(day.c)): that's the body. High \(coins(day.h)) and low \(coins(day.l)) are the wick tips."))
      }
      .buttonStyle(PrimaryButtonStyle()).disabled(answered != nil)
      .sensoryFeedback(.selection, trigger: v)
    }
  }
  /// Keeps it a real candle: High ≥ the body ≥ Low, and High above Low.
  private func set(_ k: Int, _ raw: Double) {
    var n = v
    n[k] = max(0, min(12, raw))
    switch k {
    case 2: n[2] = max(n[2], n[0], n[1], 1)
    case 3: n[3] = min(n[3], n[0], n[1], 11)
    default: n[2] = max(n[2], n[k]); n[3] = min(n[3], n[k])
    }
    if n[2] <= n[3] { if k == 3 { n[3] = n[2] - 1 } else { n[2] = n[3] + 1 } }
    if n != v { v = n }
  }

  /// The price grid and the candle being built: faint with a dashed outline, solid once checked.
  private func ghost(cx: CGFloat, y: @escaping (Double) -> CGFloat, size: CGSize) -> some View {
    Canvas { g, sz in
      for k in stride(from: 0, through: 12, by: 2) {
        let yy = y(Double(k))
        g.stroke(Path { $0.move(to: .init(x: Self.axis, y: yy)); $0.addLine(to: .init(x: sz.width, y: yy)) }, with: .color(Palette.line.opacity(0.7)), style: .init(lineWidth: 0.5, dash: [3, 4]))
        g.draw(g.resolve(Text("$\(k)").font(.caption2.monospacedDigit()).foregroundColor(.secondary)), at: CGPoint(x: 18, y: yy))
      }
      let col = v[1] >= v[0] ? CandleChart.up : CandleChart.down
      let strong = answered != nil
      g.stroke(Path { $0.move(to: .init(x: cx, y: y(v[2]))); $0.addLine(to: .init(x: cx, y: y(v[3]))) }, with: .color(col.opacity(strong ? 1 : 0.45)), style: .init(lineWidth: 5, lineCap: .round))
      let top = y(max(v[0], v[1])), bot = y(min(v[0], v[1]))
      let candleBody = Path(roundedRect: CGRect(x: cx - Self.bodyWidth / 2, y: top, width: Self.bodyWidth, height: max(bot - top, 4)), cornerRadius: 10)
      g.fill(candleBody, with: .color(col.opacity(strong ? 1 : 0.22)))
      g.stroke(candleBody, with: .color(col.opacity(strong ? 1 : 0.7)), style: .init(lineWidth: 2, dash: strong ? [] : [6, 4]))
      for (k, dx) in [(0, -1.0), (1, 1.0)] {   // dotted ties from the Start / End handles to the body's edges
        let yy = y(v[k]), x0 = cx + CGFloat(dx) * Self.bodyWidth / 2, x1 = cx + CGFloat(dx) * (Self.bodyWidth / 2 + Self.lane)
        g.stroke(Path { $0.move(to: .init(x: x0, y: yy)); $0.addLine(to: .init(x: x1, y: yy)) }, with: .color(Palette.accent.opacity(0.5)), style: .init(lineWidth: 1.5, dash: [2, 3]))
      }
    }
    .frame(width: size.width, height: size.height)
    .accessibilityHidden(true)
  }

  private func labelPoint(_ k: Int, x: CGFloat, y: CGFloat) -> CGPoint {
    switch k {
    case 0: return CGPoint(x: x - 44, y: y)     // Start: left of its handle
    case 1: return CGPoint(x: x + 44, y: y)     // End: right of its handle
    case 2: return CGPoint(x: x, y: y - 32)     // High: above
    default: return CGPoint(x: x, y: y + 32)    // Low: below
    }
  }
  private func label(_ k: Int) -> some View {
    VStack(spacing: 0) {
      Text(names[k]).font(.caption2.weight(.heavy)).foregroundStyle(Palette.ink2)
      Text(coins(v[k])).font(.caption.monospacedDigit().weight(.semibold)).foregroundStyle(Palette.ink)
    }
    .fixedSize()
    .allowsHitTesting(false)
  }
  private func handle(_ k: Int) -> some View {
    Circle().fill(k < 2 ? Palette.accent : Hue.grape.color).frame(width: 30, height: 30)
      .overlay(Image(systemName: "arrow.up.and.down").font(.caption.weight(.bold)).foregroundStyle(.white))
      .shadow(color: .black.opacity(0.15), radius: 3, y: 2)
      .scaleEffect(dragging == k ? 1.2 : 1).animation(Motion.tap, value: dragging)
      .frame(width: 44, height: 44).contentShape(Rectangle())
      .accessibilityElement().accessibilityLabel("\(names[k]): \(coins(v[k]))")
      .accessibilityAdjustableAction { d in set(k, v[k] + (d == .increment ? 1 : -1)) }
  }
}

/// Read the day: what happened in this (real) candle?
struct ReadDayGame: View {
  let node: WorldNode; let rounds: Rounds; let onFinish: (Int) -> Void
  @Environment(AppModel.self) private var app
  static let order: [DayStory] = [.bigUp, .bigDown, .tugOfWar, .smallUp]
  var body: some View {
    GameShell(node: node, rounds: 4, intro: "Look at one real day. What did the price do?", onFinish: onFinish) { i, answer, answered in
      let story = Self.order[i % Self.order.count]
      let (sym, c) = rounds.day(i, story: story)
      let opts = Self.options(story, i)
      ReadDayRound(company: companyName(sym, app), candle: c, options: opts, correct: opts.firstIndex(of: story.line) ?? 0, answer: answer, answered: answered)
    }
  }
  static func options(_ s: DayStory, _ i: Int) -> [String] {
    let others = DayStory.allCases.filter { $0 != s && !($0 == .smallUp && s == .bigUp) && !($0 == .smallDown && s == .bigDown) && !($0 == .bigUp && s == .smallUp) }
    var o = [s.line] + others.prefix(2).map(\.line)
    o.rotate(by: i % 3)
    return o
  }
}

struct ReadDayRound: View {
  let company: String, candle: Candle, options: [String], correct: Int
  let answer: (RoundResult) -> Void; let answered: RoundResult?
  @State private var picked: Int?
  var body: some View {
    VStack(spacing: 12) {
      ChartCard(caption: "\(company) · one day") {
        let pad = max(candle.range * 0.25, candle.h * 0.004)
        BigCandle(o: candle.o, h: candle.h, l: candle.l, c: candle.c, domain: (candle.l - pad)...(candle.h + pad))
      }
      Choices(options: options, correct: correct, answered: answered, picked: picked) { i in
        picked = i
        answer(RoundResult(right: i == correct, why: candle.bodyShare < 0.25 ? "Tiny body, long wicks: it swung both ways." : candle.up ? "Green: it ended higher than it started." : "Red: it ended lower than it started."))
      }
    }
  }
}

extension Array { mutating func rotate(by k: Int) { guard !isEmpty else { return }; let s = k % count; self = Array(self[s...] + self[..<s]) } }

/// Candle match: which candle tells this story?
struct CandleMatchGame: View {
  let node: WorldNode; let onFinish: (Int) -> Void
  static let shapes: [(DayStory, Candle)] = [
    (.bigUp, Candle(d: "", o: 100, h: 109, l: 99, c: 108)),
    (.bigDown, Candle(d: "", o: 108, h: 109, l: 99, c: 100)),
    (.tugOfWar, Candle(d: "", o: 104, h: 110, l: 97, c: 104.5)),
    (.smallUp, Candle(d: "", o: 103, h: 105.5, l: 102.5, c: 105)),
  ]
  static func pool(_ target: (DayStory, Candle), _ i: Int) -> [(DayStory, Candle)] {
    var p = shapes.filter { $0.0 != target.0 }.prefix(2).map { $0 } + [target]
    p.rotate(by: i % 3)
    return p
  }
  var body: some View {
    GameShell(node: node, rounds: 4, intro: "Tap the candle that tells the story.", onFinish: onFinish) { i, answer, answered in
      let target = Self.shapes[i % 4]
      let pool = Self.pool(target, i)
      CandleMatchRound(story: target.0, candles: pool.map(\.1), correct: pool.firstIndex { $0.0 == target.0 } ?? 0, answer: answer, answered: answered)
    }
  }
}

struct CandleMatchRound: View {
  let story: DayStory, candles: [Candle], correct: Int
  let answer: (RoundResult) -> Void; let answered: RoundResult?
  @State private var picked: Int?
  var body: some View {
    VStack(spacing: 14) {
      Text("“\(story.line).”").font(.kTitle).multilineTextAlignment(.center).frame(maxWidth: .infinity)
      HStack(spacing: 12) {
        ForEach(candles.indices, id: \.self) { i in
          Button { picked = i; answer(RoundResult(right: i == correct, why: Self.why(story))) } label: {
            BigCandle(o: candles[i].o, h: candles[i].h, l: candles[i].l, c: candles[i].c, domain: 95...112, labels: false)
              .padding(10).frame(maxWidth: .infinity, maxHeight: .infinity)
              .background(answered != nil && i == correct ? AnyShapeStyle(Palette.good.opacity(0.18)) : answered != nil && i == picked ? AnyShapeStyle(Hue.coral.color.opacity(0.18)) : AnyShapeStyle(.regularMaterial), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
              .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(answered != nil && i == correct ? Palette.good : Palette.line, lineWidth: answered != nil && i == correct ? 3 : 0.5))
          }
          .buttonStyle(PressStyle()).disabled(answered != nil)
          .accessibilityLabel("Candle \(i + 1)")
        }
      }
    }
  }
  static func why(_ s: DayStory) -> String {
    switch s {
    case .bigUp, .smallUp: return "A green body means it ended higher. Taller body, bigger move."
    case .bigDown, .smallDown: return "A red body means it ended lower."
    case .tugOfWar: return "Long wicks and a tiny body: a tug-of-war day."
    }
  }
}

// MARK: - Trend Trails

struct SpotTrendGame: View {
  let node: WorldNode; let rounds: Rounds; let onFinish: (Int) -> Void
  @Environment(AppModel.self) private var app
  static let order: [Trend] = [.up, .down, .sideways, .up, .down]
  var body: some View {
    GameShell(node: node, rounds: 5, intro: "Swipe the way the price is going: up, down or sideways.", onFinish: onFinish) { i, answer, answered in
      let t = Self.order[i]
      let (sym, cs) = rounds.window(i, length: 30, trend: t)
      SpotTrendRound(company: companyName(sym, app), candles: cs, trend: t, answer: answer, answered: answered)
    }
  }
}

struct SpotTrendRound: View {
  let company: String, candles: [Candle], trend: Trend
  let answer: (RoundResult) -> Void; let answered: RoundResult?
  @State private var picked: Trend?
  @State private var drag: CGSize = .zero
  var body: some View {
    let f = ChartMath.fit(candles.map(\.c))
    VStack(spacing: 12) {
      ChartCard(caption: "\(company) · 30 days") {
        CandleChart(candles: candles, answerTrend: answered != nil ? (f.a, f.a + f.b * Double(candles.count - 1)) : nil)
          .offset(x: drag.width * 0.08, y: drag.height * 0.08)
          .gesture(DragGesture(minimumDistance: 24).onChanged { drag = $0.translation }.onEnded { g in
            drag = .zero
            let t = g.translation
            pick(abs(t.height) < 40 && abs(t.width) > 40 ? .sideways : t.height < 0 ? .up : .down)
          })
          .animation(Motion.tap, value: drag)
      }
      HStack(spacing: 10) {
        ForEach([Trend.up, .sideways, .down], id: \.self) { t in
          Button { pick(t) } label: {
            Label(t == .up ? "Up" : t == .down ? "Down" : "Sideways", systemImage: t == .up ? "arrow.up.right" : t == .down ? "arrow.down.right" : "arrow.right")
              .font(.kHeadline).labelStyle(.titleAndIcon).lineLimit(1).minimumScaleFactor(0.7)
              .frame(maxWidth: .infinity, minHeight: 52)
              .background(color(t), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
              .foregroundStyle(answered != nil && (t == trend || t == picked) ? Color.white : Palette.ink)
          }
          .buttonStyle(PressStyle()).disabled(answered != nil)
        }
      }
    }
  }
  private func color(_ t: Trend) -> AnyShapeStyle {
    guard answered != nil else { return AnyShapeStyle(.thinMaterial) }
    return t == trend ? AnyShapeStyle(Palette.good) : t == picked ? AnyShapeStyle(Hue.coral.color) : AnyShapeStyle(.thinMaterial)
  }
  private func pick(_ t: Trend) {
    guard answered == nil else { return }
    picked = t
    answer(RoundResult(right: t == trend, why: trend == .sideways ? "It wiggled but ended near where it started." : "The gold line shows the big picture: \(trend.word.lowercased())."))
  }
}

struct DrawTrendGame: View {
  let node: WorldNode; let rounds: Rounds; let onFinish: (Int) -> Void
  @Environment(AppModel.self) private var app
  var body: some View {
    GameShell(node: node, rounds: 3, intro: "Draw one line with your finger that follows the price.", onFinish: onFinish) { i, answer, answered in
      let (sym, cs) = rounds.window(i + 10, length: 30, trend: i == 1 ? .down : .up)
      DrawTrendRound(company: companyName(sym, app), candles: cs, answer: answer, answered: answered)
    }
  }
}

struct DrawTrendRound: View {
  let company: String, candles: [Candle]
  let answer: (RoundResult) -> Void; let answered: RoundResult?
  @State private var line: (Double, Double)?
  var body: some View {
    let closes = candles.map(\.c), f = ChartMath.fit(closes)
    let chart = CandleChart(candles: candles, line: true)
    VStack(spacing: 12) {
      ChartCard(caption: "\(company) · 30 days") {
        GeometryReader { geo in
          CandleChart(candles: candles, line: true, trend: line, answerTrend: answered != nil ? (f.a, f.a + f.b * Double(candles.count - 1)) : nil)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 4).onChanged { g in
              guard answered == nil else { return }
              let a = CandleChart.price(atY: g.startLocation.y, height: geo.size.height, range: chart.range)
              let b = CandleChart.price(atY: g.location.y, height: geo.size.height, range: chart.range)
              let dx = max(g.location.x - g.startLocation.x, 1), w = geo.size.width
              // Extend the drawn segment across the whole chart, so a short swipe still makes a full line.
              let slope = (b - a) / Double(dx)
              let start = a - slope * Double(g.startLocation.x), end = start + slope * Double(w)
              line = (start, end)
            })
        }
      }
      Button("Check my line") {
        guard let l = line else { return }
        let s = ChartMath.trendlineStars(start: l.0, end: l.1, closes: closes)
        answer(RoundResult(right: s >= 2, why: s >= 2 ? "Your line follows the gold best-fit line." : "Follow the middle of the wiggles, from left to right. The gold line shows it."))
      }
      .buttonStyle(PrimaryButtonStyle()).disabled(line == nil || answered != nil)
    }
  }
}

// MARK: - Pattern Peaks

struct FindFloorGame: View {
  let node: WorldNode; let onFinish: (Int) -> Void
  var body: some View {
    GameShell(node: node, rounds: 4, intro: "Drag the line to the floor (or ceiling) the price keeps bouncing off.", onFinish: onFinish) { i, answer, answered in
      let ceiling = i % 2 == 1
      FindLevelRound(candles: Practice.chart(ceiling ? .breakout : .bounce, seed: 40 + i, n: 32).prefix(ceiling ? 22 : 26).map { $0 }, ceiling: ceiling, answer: answer, answered: answered)
    }
  }
}

struct FindLevelRound: View {
  let candles: [Candle], ceiling: Bool
  let answer: (RoundResult) -> Void; let answered: RoundResult?
  @State private var level: Double?
  var body: some View {
    let chart = CandleChart(candles: candles)
    let target = ceiling ? ChartMath.ceiling(candles) : ChartMath.floor(candles)
    VStack(spacing: 12) {
      Text(ceiling ? "Find the **ceiling**: the high spot it keeps stopping at." : "Find the **floor**: the low spot it keeps bouncing up from.").font(.kRead).frame(maxWidth: .infinity, alignment: .leading)
      ChartCard(caption: "Practice chart") {
        GeometryReader { geo in
          CandleChart(candles: candles, level: level ?? chart.range.lowerBound + (chart.range.upperBound - chart.range.lowerBound) / 2, levelLabel: ceiling ? "Ceiling" : "Floor", answerLevel: answered != nil ? target : nil)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { g in
              guard answered == nil else { return }
              level = CandleChart.price(atY: g.location.y, height: geo.size.height, range: chart.range)
            })
        }
      }
      Button(ceiling ? "That's the ceiling" : "That's the floor") {
        let lv = level ?? (chart.range.lowerBound + chart.range.upperBound) / 2
        let s = ChartMath.levelStars(guess: lv, target: target, chartRange: chart.range.upperBound - chart.range.lowerBound)
        answer(RoundResult(right: s >= 2, why: s >= 2 ? "Right where the price kept turning. Remember: floors can break!" : "The gold line is where it kept turning. A floor is a clue, not a promise."))
      }
      .buttonStyle(PrimaryButtonStyle()).disabled(answered != nil)
    }
  }
}

struct PatternDetectiveGame: View {
  let node: WorldNode; let onFinish: (Int) -> Void
  static let order: [ChartPattern] = [.bounce, .breakout, .doubleTop, .doubleBottom]
  static func options(_ p: ChartPattern, _ i: Int) -> [ChartPattern] {
    var o = [p] + ChartPattern.allCases.filter { $0 != p }.prefix(2)
    o.rotate(by: i % 3)
    return o
  }
  var body: some View {
    GameShell(node: node, rounds: 4, intro: "What shape is this chart making? It's a clue, not a promise.", onFinish: onFinish) { i, answer, answered in
      let p = Self.order[i]
      let opts = Self.options(p, i)
      PatternRound(pattern: p, candles: Practice.chart(p, seed: 70 + i), options: opts, answer: answer, answered: answered)
    }
  }
}

struct PatternRound: View {
  let pattern: ChartPattern, candles: [Candle], options: [ChartPattern]
  let answer: (RoundResult) -> Void; let answered: RoundResult?
  @State private var picked: Int?
  var body: some View {
    VStack(spacing: 12) {
      ChartCard(caption: "Practice chart") { CandleChart(candles: candles) }
      Choices(options: options.map(\.name), correct: options.firstIndex(of: pattern) ?? 0, answered: answered, picked: picked) { i in
        picked = i
        answer(RoundResult(right: options[i] == pattern, why: pattern.clue))
      }
    }
  }
}

// MARK: - Signal Sea

struct BusyDayGame: View {
  let node: WorldNode; let rounds: Rounds; let onFinish: (Int) -> Void
  @Environment(AppModel.self) private var app
  var body: some View {
    GameShell(node: node, rounds: 3, intro: "The bars at the bottom are volume. Tap the busiest day.", onFinish: onFinish) { i, answer, answered in
      let (sym, cs) = rounds.window(i + 30, length: 20)
      BusyDayRound(company: companyName(sym, app), candles: cs, answer: answer, answered: answered)
    }
  }
}

struct BusyDayRound: View {
  let company: String, candles: [Candle]
  let answer: (RoundResult) -> Void; let answered: RoundResult?
  @State private var tapped: Int?
  var body: some View {
    let busiest = ChartMath.busiest(candles)
    VStack(spacing: 12) {
      ChartCard(caption: "\(company) · 20 days") {
        GeometryReader { geo in
          CandleChart(candles: candles, volume: true, highlight: answered != nil ? busiest : tapped)
            .contentShape(Rectangle())
            .onTapGesture { p in
              guard answered == nil else { return }
              let i = min(candles.count - 1, max(0, Int(p.x / geo.size.width * CGFloat(candles.count))))
              tapped = i
              let close = abs(i - busiest) <= 0 || candles[i].v >= candles[busiest].v * 0.92
              answer(RoundResult(right: close, why: "The tallest volume bar is the busiest day. \(candles[busiest].changePct >= 0 ? "The price went up" : "The price went down") that day, and lots of people traded."))
            }
        }
      }
      Text("Busy days often come with big news, like a report card.").font(.footnote).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

struct SmoothLineGame: View {
  let node: WorldNode; let onFinish: (Int) -> Void
  var body: some View {
    GameShell(node: node, rounds: 3, intro: "One colored line is the moving average. Which one?", onFinish: onFinish) { i, answer, answered in
      SmoothRound(seed: 90 + i, order: i % 3, answer: answer, answered: answered)
    }
  }
}

struct SmoothRound: View {
  let seed: Int, order: Int
  let answer: (RoundResult) -> Void; let answered: RoundResult?
  @State private var picked: Int?
  static let names = ["Blue line", "Pink line", "Gold line"]
  static let colors = [Hue.sky.color, Hue.berry.color, Hue.gold.color]
  var body: some View {
    let ys = Practice.noisy(seed: seed)
    let candles = ys.enumerated().map { Candle(d: "\($0.offset)", o: $0.element, h: $0.element, l: $0.element, c: $0.element) }
    let real = ChartMath.sma(ys, window: 7)
    let jumpy = ys.enumerated().map { i, y -> Double? in i < 6 ? nil : y + (i % 2 == 0 ? 3 : -3) }               // zig-zags even more
    let flat = ys.enumerated().map { i, _ -> Double? in i < 6 ? nil : ((ys.first ?? 0) + (ys.last ?? 0)) / 2 + Double(i - 20) * 0.05 } // ignores the price
    var lines = [real, jumpy, flat]; lines.rotate(by: order)
    let correct = lines.firstIndex { $0 == real } ?? 0
    return VStack(spacing: 12) {
      ChartCard(caption: "Practice chart") { CandleChart(candles: candles, line: true, smooth: lines, smoothColors: Self.colors) }
      Choices(options: Self.names, correct: correct, answered: answered, picked: picked) { i in
        picked = i
        answer(RoundResult(right: i == correct, why: "The \(Self.names[correct].lowercased()) follows the middle of the last few days, without the zig-zags."))
      }
    }
  }
}
