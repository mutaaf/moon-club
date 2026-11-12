import SwiftUI
import MoonClubCore

// Candle Academy's ten drills. Every chart is a practice chart generated from the round's seed by
// MoonClubCore `CandleLab` (the same on every device), and every answer is checked by the pattern's
// own rule. A wrong answer explains itself and moves on: never punitive.

struct CandleDrill: View {
  let level: AcademyLevel
  let round: AcademyRound
  let answer: (RoundResult) -> Void
  let answered: RoundResult?

  var body: some View {
    let p = round.pattern
    switch round.drill {
    case .tug: TugDrill(level: level, round: round, answer: answer, answered: answered)
    case .parts: PartsDrill(level: level, round: round, answer: answer, answered: answered)
    case .story: StoryDrill(level: level, round: round, answer: answer, answered: answered)
    case .build where CandleLab.buildable.contains(p) || level.chapter == 0, .fix where CandleLab.buildable.contains(p):
      BuildDrill(level: level, round: round, fix: round.drill == .fix, answer: answer, answered: answered)
    case .spot: SpotDrill(level: level, round: round, answer: answer, answered: answered)
    case .odd: OddDrill(level: level, round: round, answer: answer, answered: answered)
    case .next: NextDrill(level: level, round: round, answer: answer, answered: answered)
    case .catchIt: CatchDrill(level: level, round: round, answer: answer, answered: answered)
    default: NameDrill(level: level, round: round, answer: answer, answered: answered)
    }
  }
}

extension AcademyLevel {
  /// Lead-in days before a pattern: short low in the academy, longer up high.
  var leadDays: Int { [6, 7, 8, 9, 10, 12][tier] }
}

private func prompt(_ s: LocalizedStringKey) -> some View {
  Text(s).font(.kRead).frame(maxWidth: .infinity, alignment: .leading).fixedSize(horizontal: false, vertical: true).lineLimit(3)
}

// MARK: Name it

struct NameDrill: View {
  let level: AcademyLevel, round: AcademyRound
  let answer: (RoundResult) -> Void; let answered: RoundResult?
  @State private var picked: Int?
  var body: some View {
    let p = round.pattern
    let ch = CandleLab.make(p, seed: round.seed, lead: level.leadDays)
    let opts = Self.options(p, level: level, seed: round.seed)
    let correct = opts.firstIndex(of: p) ?? 0
    DrillStage(caption: "Practice chart") {
      prompt("What's the pattern in the **glowing** days?")
      LabTip(text: "Look for \(p.lookFor).", scaffold: level.scaffold, answered: answered != nil)
    } chart: {
      LabChart(candles: ch.candles, glow: [(ch.range, Palette.accent)])
    } controls: {
      Choices(options: opts.map(\.name), correct: correct, answered: answered, picked: picked) { i in
        picked = i
        answer(RoundResult(right: i == correct, why: i == correct ? "\(p.name): \(p.says)" : "It's a \(p.name). Look for \(p.lookFor)."))
      }
    }
  }

  /// The right name, its look-alike and twin first (the near ones), then others met so far.
  static func options(_ p: CandlePattern, level: AcademyLevel, seed: Int) -> [CandlePattern] {
    var g = Seeded(seed &+ 3)
    var out = [p]
    for q in [p.lookalike, p.twin] where !out.contains(q) { out.append(q) }
    let met = Academy.candleChapters.prefix(min(level.chapter, Academy.candleChapters.count - 1) + 1).flatMap(\.patterns)
    for q in (met + CandlePattern.allCases).shuffled(using: &g) where !out.contains(q) && out.count < level.choices { out.append(q) }
    // Low in the academy, keep the far answers: drop the near twin when there are only 3 choices.
    return Array(out.prefix(level.choices)).shuffled(using: &g)
  }
}

// MARK: Who won?

struct TugDrill: View {
  let level: AcademyLevel, round: AcademyRound
  let answer: (RoundResult) -> Void; let answered: RoundResult?
  @State private var picked: Int?
  var body: some View {
    let p = round.pattern
    let ch = CandleLab.make(p, seed: round.seed, lead: level.leadDays)
    let last = ch.end
    let k = ch.candles[last]
    let won: Int = abs(k.c - k.o) < 0.15 * k.range ? 2 : (k.up ? 0 : 1)
    let opts = ["Buyers", "Sellers", "A tie"]
    DrillStage(caption: "Tug-of-war") {
      prompt("Who won the tug-of-war on the **glowing** day?")
      LabTip(text: "Ended higher than it started? Buyers won. Lower? Sellers. About the same? A tie.", scaffold: level.scaffold, answered: answered != nil)
    } chart: {
      LabChart(candles: ch.candles, glow: [(last...last, Hue.gold.color)])
    } controls: {
      Choices(options: opts, correct: won, answered: answered, picked: picked) { i in
        picked = i
        let why = won == 2 ? "It ended right about where it started: a tie." : won == 0 ? "It ended higher than it started, so buyers pulled harder." : "It ended lower than it started, so sellers pulled harder."
        answer(RoundResult(right: i == won, why: why))
      }
    }
  }
}

// MARK: Candle parts

struct PartsDrill: View {
  let level: AcademyLevel, round: AcademyRound
  let answer: (RoundResult) -> Void; let answered: RoundResult?
  enum Part: CaseIterable { case body, upper, lower, high, low, open, close
    var ask: LocalizedStringKey {
      switch self {
      case .body: return "Tap the candle's **body**."
      case .upper: return "Tap the **top wick**."
      case .lower: return "Tap the **bottom wick**."
      case .high: return "Tap the **highest** price of the day."
      case .low: return "Tap the **lowest** price of the day."
      case .open: return "Tap where the day **started**."
      case .close: return "Tap where the day **ended**."
      }
    }
    var why: String {
      switch self {
      case .body: return "The body is the thick part, from where the day started to where it ended."
      case .upper: return "The top wick shows how high buyers pulled before letting go."
      case .lower: return "The bottom wick shows how low sellers pulled before letting go."
      case .high: return "The tip of the top wick is the day's high."
      case .low: return "The tip of the bottom wick is the day's low."
      case .open: return "An up candle starts at the bottom of its body; a down candle starts at the top."
      case .close: return "An up candle ends at the top of its body; a down candle ends at the bottom."
      }
    }
  }
  @State private var tap: CGPoint?
  var body: some View {
    var g = Seeded(round.seed)
    let up = Bool.random(using: &g)
    let lo = Int.random(in: 1...3, using: &g), hi = Int.random(in: 9...11, using: &g)
    let a = Int.random(in: lo + 2...5, using: &g), b = Int.random(in: 7...hi - 2, using: &g)
    let k = up ? GridCandle(o: a, h: hi, l: lo, c: b) : GridCandle(o: b, h: hi, l: lo, c: a)
    let pool: [Part] = level.tier < 1 ? [.body, .upper, .lower] : Part.allCases
    let part = pool.randomElement(using: &g) ?? .body
    DrillStage(caption: up ? "An up day" : "A down day") {
      prompt(part.ask)
      LabTip(text: part.why, scaffold: level.scaffold, answered: answered != nil)
    } chart: {
      GeometryReader { geo in
        let h = geo.size.height, w = geo.size.width
        let y: (Int) -> CGFloat = { p in h - 16 - CGFloat(p) / 12 * (h - 32) }
        let cx = w / 2
        ZStack {
          Canvas { gc, _ in
            CandleInk.draw(gc, x: cx, high: y(k.h), low: y(k.l), top: y(max(k.o, k.c)), bottom: y(min(k.o, k.c)), width: min(80, w * 0.3), up: up, big: true)
            if answered != nil {
              let target = Self.zone(part, k, y)
              gc.stroke(Path(roundedRect: CGRect(x: cx - 60, y: target.lowerBound - 6, width: 120, height: max(12, target.upperBound - target.lowerBound + 12)), cornerRadius: 10),
                        with: .color(Hue.gold.color), style: .init(lineWidth: 3, dash: [6, 4]))
            }
            if let tap { gc.fill(Path(ellipseIn: CGRect(x: tap.x - 9, y: tap.y - 9, width: 18, height: 18)), with: .color(Palette.accent.opacity(0.7))) }
          }
          Color.clear.contentShape(Rectangle())
            .onTapGesture(coordinateSpace: .local) { p in
              guard answered == nil else { return }
              tap = p
              let ok = Self.hit(part, k, y, p, cx: cx)
              answer(RoundResult(right: ok, why: part.why))
            }
        }
      }
    } controls: { EmptyView() }
  }

  /// The y-range (points, top to bottom) of a part.
  static func zone(_ part: Part, _ k: GridCandle, _ y: (Int) -> CGFloat) -> ClosedRange<CGFloat> {
    let top = y(max(k.o, k.c)), bot = y(min(k.o, k.c)), hi = y(k.h), lo = y(k.l)
    switch part {
    case .body: return top...bot
    case .upper: return hi...top
    case .lower: return bot...lo
    case .high: return hi...hi
    case .low: return lo...lo
    case .open: return y(k.o)...y(k.o)
    case .close: return y(k.c)...y(k.c)
    }
  }
  static func hit(_ part: Part, _ k: GridCandle, _ y: (Int) -> CGFloat, _ p: CGPoint, cx: CGFloat) -> Bool {
    guard abs(p.x - cx) < 90 else { return false }
    switch part {
    case .body, .upper, .lower:
      let z = zone(part, k, y)
      return p.y >= z.lowerBound - 6 && p.y <= z.upperBound + 6
    default:
      // The nearest of the four prices wins.
      let pts: [(Part, CGFloat)] = [(.high, y(k.h)), (.low, y(k.l)), (.open, y(k.o)), (.close, y(k.c))]
      let near = pts.min { abs($0.1 - p.y) < abs($1.1 - p.y) }
      return near?.0 == part && abs((near?.1 ?? 0) - p.y) < 44
    }
  }
}

// MARK: Story to candle

struct StoryDrill: View {
  let level: AcademyLevel, round: AcademyRound
  let answer: (RoundResult) -> Void; let answered: RoundResult?
  @State private var picked: Int?
  var body: some View {
    let s = CandleLab.story(seed: round.seed, choices: level.choices)
    let t = s.target
    let correct = s.options.firstIndex(of: t) ?? 0
    let lowFirst = round.seed % 2 == 0
    let text: LocalizedStringKey = level.tier >= 3 && lowFirst
      ? "It started at **$\(t.o)**, dipped to **$\(t.l)**, climbed to **$\(t.h)** and ended at **$\(t.c)**."
      : "It started at **$\(t.o)**, went as high as **$\(t.h)**, as low as **$\(t.l)** and ended at **$\(t.c)**."
    VStack(spacing: 12) {
      prompt(text)
      LabTip(text: "Start and end make the body. High and low are the wick tips.", scaffold: level.scaffold, answered: answered != nil)
      HStack(spacing: 10) {
        ForEach(s.options.indices, id: \.self) { i in
          PictureChoice(index: i, state: answerState(i, correct: correct, picked: picked, answered: answered != nil)) {
            guard answered == nil else { return }
            picked = i
            answer(RoundResult(right: i == correct, why: "Start $\(t.o), end $\(t.c): that's the body. High $\(t.h) and low $\(t.l) are the wick tips."))
          } content: {
            MiniCandles(candles: [s.options[i].candle], range: -0.5...12.5, grid: true)
          }
          .accessibilityLabel("Candle \(i + 1): started \(s.options[i].o), high \(s.options[i].h), low \(s.options[i].l), ended \(s.options[i].c)")
        }
      }
      .frame(maxHeight: .infinity)
    }
  }
}

// MARK: Build it / Fix the candle

struct BuildDrill: View {
  let level: AcademyLevel, round: AcademyRound
  let fix: Bool
  let answer: (RoundResult) -> Void; let answered: RoundResult?
  @State private var v: GridCandle?
  @State private var selected = 2
  var body: some View {
    let p = round.pattern
    let story: GridCandle? = CandleLab.buildable.contains(p) ? nil : CandleLab.story(seed: round.seed, choices: 2).target
    let miss = fix ? CandleLab.nearMiss(p, seed: round.seed) : nil
    let start = miss?.0 ?? GridCandle(o: 5, h: 8, l: 3, c: 6)
    let cur = v ?? start
    VStack(spacing: 10) {
      if let t = story {
        prompt("Build it: started **$\(t.o)**, high **$\(t.h)**, low **$\(t.l)**, ended **$\(t.c)**.")
      } else if fix {
        prompt("This should be a **\(p.name)**, but one handle is wrong. Fix it!")
      } else {
        prompt("Build a **\(p.name)**.")
      }
      LabTip(text: story == nil ? "Look for \(p.lookFor)." : "Start and end make the body. High and low are the wick tips.", scaffold: level.scaffold, answered: answered != nil)
      ChartCard {
        CandleBuilder(value: Binding(get: { cur }, set: { v = $0 }), selected: $selected, locked: answered != nil, pulse: level.scaffold >= 1 ? miss?.1 : nil)
      }
      HingeTip(text: "Open or close me to move the picked handle")
      Button(fix ? "Check my fix" : "Check my candle") {
        let ok = story.map { $0 == cur } ?? CandleLab.shapeOK(p, cur)
        let why: String
        if let t = story { why = ok ? "Start and end make the body. High and low make the wicks." : "Start $\(t.o), end $\(t.c) make the body; high $\(t.h), low $\(t.l) are the tips." }
        else { why = ok ? "That's a \(p.name): \(p.lookFor)." : "A \(p.name) has \(p.lookFor)." }
        answer(RoundResult(right: ok, why: why))
      }
      .buttonStyle(ChunkyPrimary()).disabled(answered != nil)
    }
    .hingeKnob(answered == nil) { f in
      var n = cur
      let val = Int((f * 12).rounded())
      switch selected { case 0: n.o = val; case 1: n.c = val; case 2: n.h = val; default: n.l = val }
      v = CandleBuilder.fixUp(n, moved: selected)
    }
  }
}

/// Four handles on a $0…$12 grid: Start (left), End (right), High and Low (on the wick). Keeps it a real
/// candle while you drag.
struct CandleBuilder: View {
  @Binding var value: GridCandle
  @Binding var selected: Int
  var locked = false
  /// A handle that pulses (Fix the candle's broken one, on tip levels).
  var pulse: Int? = nil
  static let names = ["Start", "End", "High", "Low"]
  @State private var dragging: Int?
  @Environment(\.accessibilityReduceMotion) private var rm

  var body: some View {
    GeometryReader { geo in
      let h = geo.size.height, w = geo.size.width
      let y: (Int) -> CGFloat = { p in h - 18 - CGFloat(p) / 12 * (h - 36) }
      let cx = 40 + (w - 40) / 2, bw = min(64, w * 0.22)
      let lanes: [CGFloat] = [cx - bw / 2 - 34, cx + bw / 2 + 34, cx, cx]
      let vals = [value.o, value.c, value.h, value.l]
      ZStack(alignment: .topLeading) {
        Canvas { g, sz in
          for k in stride(from: 0, through: 12, by: 2) {
            let yy = y(k)
            g.stroke(Path { $0.move(to: .init(x: 40, y: yy)); $0.addLine(to: .init(x: sz.width, y: yy)) }, with: .color(Palette.line.opacity(0.7)), style: .init(lineWidth: 0.5, dash: [3, 4]))
            g.draw(g.resolve(Text("$\(k)").font(.caption2.monospacedDigit()).foregroundColor(.secondary)), at: CGPoint(x: 18, y: yy))
          }
          let up = value.c >= value.o
          CandleInk.draw(g, x: cx, high: y(value.h), low: y(value.l), top: y(max(value.o, value.c)), bottom: y(min(value.o, value.c)), width: bw, up: up, big: true)
          for (k, dx) in [(0, -1.0), (1, 1.0)] {
            let yy = y(vals[k]), x0 = cx + CGFloat(dx) * bw / 2, x1 = lanes[k]
            g.stroke(Path { $0.move(to: .init(x: x0, y: yy)); $0.addLine(to: .init(x: x1, y: yy)) }, with: .color(Palette.accent.opacity(0.5)), style: .init(lineWidth: 1.5, dash: [2, 3]))
          }
        }
        ForEach(0..<4, id: \.self) { k in
          let pt = CGPoint(x: lanes[k] + (k == 2 ? 0 : 0), y: y(vals[k]))
          LabHandle(color: k < 2 ? Palette.accent : Hue.grape.color, selected: selected == k || dragging == k, label: "\(Self.names[k]) $\(vals[k])")
            .scaleEffect(pulse == k && !locked && !rm ? 1.12 : 1)
            .animation(pulse == k && !rm ? .easeInOut(duration: 0.6).repeatCount(6, autoreverses: true) : nil, value: pulse)
            .position(k >= 2 ? CGPoint(x: pt.x + (k == 2 ? 0 : 0), y: pt.y) : pt)
            .offset(x: k == 2 ? 0 : 0)
            .gesture(DragGesture(minimumDistance: 0).onChanged { g in
              guard !locked else { return }
              dragging = k; selected = k
              let raw = Int(((h - 18 - g.location.y) / (h - 36) * 12).rounded())
              var n = value
              switch k { case 0: n.o = raw; case 1: n.c = raw; case 2: n.h = raw; default: n.l = raw }
              let f = Self.fixUp(n, moved: k)
              if f != value { value = f }
            }.onEnded { _ in dragging = nil })
            .accessibilityElement().accessibilityLabel("\(Self.names[k]): $\(vals[k])")
            .accessibilityAdjustableAction { d in
              var n = value
              let delta = d == .increment ? 1 : -1
              switch k { case 0: n.o += delta; case 1: n.c += delta; case 2: n.h += delta; default: n.l += delta }
              value = Self.fixUp(n, moved: k)
            }
        }
        // High and Low share the wick: Low's handle sits a little lower-left so both stay grabbable.
      }
      .sensoryFeedback(.selection, trigger: value)
    }
    .frame(minHeight: 200)
  }

  /// Keeps it a real candle: High on top, Low at the bottom, everything on $0…$12.
  static func fixUp(_ v: GridCandle, moved k: Int) -> GridCandle {
    var n = v
    n.o = max(0, min(12, n.o)); n.c = max(0, min(12, n.c)); n.h = max(0, min(12, n.h)); n.l = max(0, min(12, n.l))
    switch k {
    case 2: n.h = max(n.h, n.o, n.c)
    case 3: n.l = min(n.l, n.o, n.c)
    default: n.h = max(n.h, n.o, n.c); n.l = min(n.l, n.o, n.c)
    }
    if n.h <= n.l { if k == 3 { n.l = max(0, n.h - 1) } else { n.h = min(12, n.l + 1) } }
    return n
  }
}

// MARK: Spot it

struct SpotDrill: View {
  let level: AcademyLevel, round: AcademyRound
  let answer: (RoundResult) -> Void; let answered: RoundResult?
  @State private var tapped: Int?
  var body: some View {
    let p = round.pattern
    let ch = CandleLab.hide(p, seed: round.seed, days: max(16, level.days - 4))
    DrillStage(caption: "\(ch.candles.count) days") {
      prompt("Find the **\(p.name)** and tap it.")
      LabTip(text: "Look for \(p.lookFor).", scaffold: level.scaffold, answered: answered != nil)
    } chart: {
      LabCanvas(candles: ch.candles, chart: LabChart(candles: ch.candles, glow: answered != nil ? [(ch.range, Hue.gold.color)] : (level.scaffold >= 2 ? [(max(0, ch.start - 2)...min(ch.candles.count - 1, ch.end + 2), Palette.accent.opacity(0.5))] : []),
                                                      dots: tapped.map { [($0, answered?.right == true ? Palette.good : Palette.bad)] } ?? [])) { m in
        Color.clear.contentShape(Rectangle())
          .onTapGesture(coordinateSpace: .named(LabSpace.name)) { pt in
            guard answered == nil else { return }
            let i = m.index(atX: pt.x)
            tapped = i
            let ok = ch.range.contains(i)
            answer(RoundResult(right: ok, why: ok ? "Found it! \(p.says)" : "The gold days are the \(p.name): \(p.lookFor)."))
          }
      }
    } controls: { EmptyView() }
  }
}

// MARK: Odd one out

struct OddDrill: View {
  let level: AcademyLevel, round: AcademyRound
  let answer: (RoundResult) -> Void; let answered: RoundResult?
  @State private var picked: Int?
  var body: some View {
    let p = round.pattern, q = p.lookalike
    let odd = abs(round.seed) % 4
    let charts: [PatternChart] = (0..<4).map { i in CandleLab.make(i == odd ? q : p, seed: round.seed &+ i &* 101, lead: 6) }
    VStack(spacing: 10) {
      prompt("Three are **\(p.name)**. Tap the one that isn't.")
      LabTip(text: "A \(p.name) has \(p.lookFor).", scaffold: level.scaffold, answered: answered != nil)
      Grid(horizontalSpacing: 10, verticalSpacing: 10) {
        ForEach(0..<2, id: \.self) { r in
          GridRow {
            ForEach(0..<2, id: \.self) { c in
              let i = r * 2 + c
              let ch = charts[i]
              let window = Array(ch.candles[max(0, ch.start - 5)...ch.end])
              let off = max(0, ch.start - 5)
              PictureChoice(index: i, state: answerState(i, correct: odd, picked: picked, answered: answered != nil)) {
                guard answered == nil else { return }
                picked = i
                answer(RoundResult(right: i == odd, why: "That one is a \(q.name): \(q.lookFor)."))
              } content: {
                LabChart(candles: window, glow: [((ch.start - off)...(ch.end - off), Palette.accent)])
              }
              .accessibilityLabel("Chart \(i + 1)")
            }
          }
        }
      }
      .frame(maxHeight: .infinity)
    }
  }
}

// MARK: What might happen next?

struct NextDrill: View {
  let level: AcademyLevel, round: AcademyRound
  let answer: (RoundResult) -> Void; let answered: RoundResult?
  @State private var picked: Int?
  var body: some View {
    let p = round.pattern
    let ch = CandleLab.make(p, seed: round.seed, lead: level.leadDays, after: 4)
    let opts = ["Might go up", "Might go down", "Hard to tell"]
    let correct = p.hint == .up ? 0 : p.hint == .down ? 1 : 2
    let went: String = {
      guard let f = ch.followed else { return "" }
      return f ? " This time it did." : " This time it didn't. Charts give clues, not promises."
    }()
    DrillStage(caption: answered == nil ? "What's behind the curtain?" : "What happened") {
      prompt("The glowing days are a **\(p.name)**. What clue does it give?")
      LabTip(text: p.says, scaffold: level.scaffold, answered: answered != nil)
    } chart: {
      LabChart(candles: ch.candles, glow: [(ch.range, Palette.accent)], curtain: answered == nil ? ch.end : nil)
    } controls: {
      Choices(options: opts, correct: correct, answered: answered, picked: picked) { i in
        picked = i
        let clue = p.hint == .unsure ? "Nobody won, so it's hard to tell." : "\(p.says) It \(p.hint == .up ? "might go up" : "might go down")."
        answer(RoundResult(right: i == correct, why: clue + went))
      }
    }
  }
}

// MARK: Catch it (like Snap)

struct CatchDrill: View {
  let level: AcademyLevel, round: AcademyRound
  let answer: (RoundResult) -> Void; let answered: RoundResult?
  @AppStorage(PlayPrefs.relaxedKey) private var relaxed = false
  @Environment(\.accessibilityReduceMotion) private var rm
  @State private var shown = 5
  @State private var started = false
  var body: some View {
    let p = round.pattern
    let ch = CandleLab.hide(p, seed: round.seed, days: min(26, max(18, level.days - 6)))
    let n = ch.candles.count
    DrillStage(caption: "Day \(min(shown, n)) of \(n)") {
      prompt("Days appear one by one. Tap **That's it!** when a **\(p.name)** finishes.")
      LabTip(text: "Look for \(p.lookFor).", scaffold: level.scaffold, answered: answered != nil)
    } chart: {
      LabChart(candles: ch.candles, range: PlotMap.range(ch.candles), reveal: answered == nil ? shown : n, glow: answered != nil ? [(ch.range, Hue.gold.color)] : [])
    } controls: {
      Button {
        guard answered == nil else { return }
        let last = shown - 1
        let ok = last >= ch.end && last <= ch.end + 3
        answer(RoundResult(right: ok, why: ok ? "Snap! \(p.says)" : last < ch.end ? "Not yet! The gold days are where it finished." : "The gold days were the \(p.name)."))
      } label: { Label("That's it!", systemImage: "hand.raised.fill") }
      .buttonStyle(ChunkyPrimary()).disabled(answered != nil)
    }
    .task(id: round.seed) {
      guard !started else { return }
      started = true
      let step = [1.1, 1.0, 0.9, 0.8, 0.7, 0.6][level.tier] * (relaxed ? 1.6 : 1)
      while shown < n {
        try? await Task.sleep(for: .seconds(step))
        if Task.isCancelled || answered != nil { return }
        withAnimation(rm ? nil : Motion.tap) { shown += 1 }
      }
      try? await Task.sleep(for: .seconds(step))
      if answered == nil, shown - 1 > ch.end + 3 || shown >= n {
        answer(RoundResult(right: false, why: "It went by! The gold days were the \(p.name)."))
      }
    }
  }
}
