import SwiftUI
import MoonClubCore

// Line Lab's drills. Drawing drills put handles on the chart through the same `PlotMap` the chart is
// drawn with, and grade in days and prices (MoonClubCore `LineLab`), so a line passes the same on an
// iPhone SE, an iPad or the open iPhone Duo. On the Duo, the hinge is a knob for the picked handle.

struct LineDrill: View {
  let level: AcademyLevel
  let round: AcademyRound
  let answer: (RoundResult) -> Void
  let answered: RoundResult?

  var body: some View {
    switch round.drill {
    case .trendWay: TrendWayDrill(level: level, round: round, answer: answer, answered: answered)
    case .trendLine: TrendLineDrill(level: level, round: round, answer: answer, answered: answered)
    case .level: LevelDrill(level: level, round: round, answer: answer, answered: answered)
    case .lane: LaneDrill(level: level, round: round, answer: answer, answered: answered)
    case .breakout: BreakoutDrill(level: level, round: round, answer: answer, answered: answered)
    case .stick: StickDrill(level: level, round: round, answer: answer, answered: answered)
    case .maDot: AverageDotDrill(level: level, round: round, answer: answer, answered: answered)
    case .maSide: AverageSideDrill(level: level, round: round, answer: answer, answered: answered)
    case .maPick: AveragePickDrill(level: level, round: round, answer: answer, answered: answered)
    case .cross: CrossDrill(level: level, round: round, answer: answer, answered: answered)
    case .crowd: CrowdDrill(level: level, round: round, answer: answer, answered: answered)
    case .thin: ThinDrill(level: level, round: round, answer: answer, answered: answered)
    case .fill: FillDrill(level: level, round: round, answer: answer, answered: answered)
    default: TrendWayDrill(level: level, round: round, answer: answer, answered: answered)
    }
  }
}

private func ask(_ s: LocalizedStringKey) -> some View {
  Text(s).font(.kRead).frame(maxWidth: .infinity, alignment: .leading).fixedSize(horizontal: false, vertical: true).lineLimit(3)
}

/// Which way this round's line goes (Up Lines teach up, Down Lines down, later chapters mix).
private func wantsUp(_ level: AcademyLevel, _ round: AcademyRound) -> Bool {
  switch level.chapter { case 1: return true; case 2: return false; default: return round.seed % 2 == 0 }
}

// MARK: Which way?

struct TrendWayDrill: View {
  let level: AcademyLevel, round: AcademyRound
  let answer: (RoundResult) -> Void; let answered: RoundResult?
  @State private var picked: Int?
  var body: some View {
    let kind = abs(round.seed) % 3
    let cs: [Candle] = kind == 2 ? LineLab.levelChart(floor: round.seed % 4 == 0, seed: round.seed, days: level.days).candles
      : LineLab.trendChart(up: kind == 0, seed: round.seed, days: level.days).candles
    let t = ChartMath.trend(cs.map(\.c))
    let opts = Trend.allCases
    let correct = opts.firstIndex(of: t) ?? 0
    DrillStage(caption: "\(cs.count) days") {
      ask("Is the price going **up**, **down** or **sideways**?")
      LabTip(text: "Look at where it starts and where it ends, not the wiggles.", scaffold: level.scaffold, answered: answered != nil)
    } chart: {
      LabChart(candles: cs, strokes: answered != nil ? [LabStroke(line: Self.fitLine(cs), color: Hue.gold.color, dashed: true)] : [])
    } controls: {
      Choices(options: opts.map(\.word), correct: correct, answered: answered, picked: picked) { i in
        picked = i
        answer(RoundResult(right: i == correct, why: "\(t.word): the gold line follows the middle of the wiggles."))
      }
    }
  }
  static func fitLine(_ cs: [Candle]) -> ChartLine {
    let f = ChartMath.fit(cs.map(\.c))
    return ChartLine(x1: 0, y1: f.a, x2: Double(cs.count - 1), y2: f.a + f.b * Double(cs.count - 1))
  }
}

// MARK: Draw the trend (two handles)

struct TrendLineDrill: View {
  let level: AcademyLevel, round: AcademyRound
  let answer: (RoundResult) -> Void; let answered: RoundResult?
  @State private var pts: [(day: Double, price: Double)]?
  @State private var selected = 1
  @State private var grab: CGSize = .zero
  @State private var snapped = 0
  @State private var grade: LineGrade?
  var body: some View {
    let up = wantsUp(level, round)
    let (cs, ideal) = LineLab.trendChart(up: up, seed: round.seed, days: level.days, noise: Double(level.tier) / 5)
    let range = PlotMap.range(cs)
    let mid = (range.lowerBound + range.upperBound) / 2
    let cur = pts ?? [(Double(cs.count) * 0.15, mid), (Double(cs.count) * 0.85, mid)]
    let line = ChartLine(x1: cur[0].day, y1: cur[0].price, x2: cur[1].day, y2: cur[1].price)
    DrillStage(caption: up ? "A climb" : "A slide") {
      ask(up ? "Drag the dots to draw the trend line **under the lows**." : "Drag the dots to draw the trend line **over the highs**.")
      LabTip(text: up ? "Put each dot on a low wick tip. The line shouldn't cut through any candle." : "Put each dot on a high wick tip. The line shouldn't cut through any candle.", scaffold: level.scaffold, answered: answered != nil)
    } chart: {
      let chart = LabChart(candles: cs, range: range,
                           glow: answered != nil ? ideal.touches.map { ($0...$0, Hue.gold.color) } : [],
                           strokes: (answered != nil || level.scaffold >= 2 ? [LabStroke(line: ideal.line, color: Hue.gold.color.opacity(answered != nil ? 1 : 0.35), dashed: true, from: Double(ideal.anchors.0))] : [])
                             + [LabStroke(line: line, color: Palette.accent, from: min(cur[0].day, cur[1].day), to: max(cur[0].day, cur[1].day), extend: true)])
      LabCanvas(candles: cs, range: range, chart: chart) { m in
        ForEach(0..<2, id: \.self) { k in
          LabHandle(color: Palette.accent, selected: selected == k, label: coins(cur[k].price))
            .position(m.point(day: cur[k].day, price: cur[k].price))
            .gesture(drag(k, m, cs: cs, up: up, cur: cur))
            .disabled(answered != nil)
            .accessibilityElement().accessibilityLabel("Line dot \(k + 1): day \(Int(cur[k].day) + 1), \(coins(cur[k].price))")
            .accessibilityAdjustableAction { d in nudge(k, d == .increment ? 1 : -1, cur: cur, range: range) }
        }
      }
      .sensoryFeedback(.impact(weight: .light), trigger: snapped)
    } controls: {
      HingeTip(text: "Open or close me to tilt the line")
      Button("Check my line") {
        let g = LineLab.grade(trend: line, ideal: ideal, candles: cs, tol: level.tolerance)
        grade = g
        answer(RoundResult(right: g.right, why: g.line))
      }
      .buttonStyle(ChunkyPrimary()).disabled(answered != nil || pts == nil)
    }
    .hingeKnob(answered == nil) { f in
      var p = cur
      p[selected].price = range.lowerBound + f * (range.upperBound - range.lowerBound)
      pts = p
    }
  }

  private func drag(_ k: Int, _ m: PlotMap, cs: [Candle], up: Bool, cur: [(day: Double, price: Double)]) -> some Gesture {
    DragGesture(minimumDistance: 0, coordinateSpace: .named(LabSpace.name))
      .onChanged { g in
        selected = k
        if g.translation == .zero { grab = CGSize(width: m.x(cur[k].day) - g.startLocation.x, height: m.y(cur[k].price) - g.startLocation.y) }
        let p = CGPoint(x: g.location.x + grab.width, y: g.location.y + grab.height)
        var next = cur
        if let tip = LabSnap.tip(near: p, candles: cs, map: m, lows: up, radius: CGFloat(level.snap)) {
          if Int(next[k].day) != tip.day || next[k].price != tip.price { snapped += 1 }
          next[k] = (Double(tip.day), tip.price)
        } else {
          next[k] = (m.day(atX: p.x), m.price(atY: p.y))
        }
        if abs(next[0].day - next[1].day) < 1 { return }   // keep the dots apart
        pts = next
      }
  }
  private func nudge(_ k: Int, _ d: Double, cur: [(day: Double, price: Double)], range: ClosedRange<Double>) {
    var p = cur
    p[k].price += d * (range.upperBound - range.lowerBound) / 40
    pts = p
  }
}

// MARK: Floor or ceiling (one level)

struct LevelDrill: View {
  let level: AcademyLevel, round: AcademyRound
  let answer: (RoundResult) -> Void; let answered: RoundResult?
  @State private var price: Double?
  @State private var snapped = 0
  var body: some View {
    let floor = level.chapter == 3 ? true : level.chapter == 4 ? false : round.seed % 2 == 0
    let (cs, target) = LineLab.levelChart(floor: floor, seed: round.seed, days: level.days, noise: Double(level.tier) / 5)
    let range = PlotMap.range(cs)
    let cur = price ?? (range.lowerBound + range.upperBound) / 2
    DrillStage(caption: floor ? "Find the floor" : "Find the ceiling") {
      ask(floor ? "Drag the line to the **floor**: where buyers keep showing up." : "Drag the line to the **ceiling**: where sellers keep showing up.")
      LabTip(text: floor ? "Find the low spot the price bounced up from again and again." : "Find the high spot the price kept stopping at.", scaffold: level.scaffold, answered: answered != nil)
    } chart: {
      let chart = LabChart(candles: cs, range: range,
                           levels: (answered != nil ? [LabLevel(price: target, color: Hue.gold.color, dashed: true, band: (range.upperBound - range.lowerBound) * 0.01)] : [])
                             + [LabLevel(price: cur, color: Palette.accent, label: floor ? "Floor \(coins(cur))" : "Ceiling \(coins(cur))")])
      LabCanvas(candles: cs, range: range, chart: chart) { m in
        Color.clear.contentShape(Rectangle())
          .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named(LabSpace.name)).onChanged { g in
            guard answered == nil else { return }
            let p = m.price(atY: g.location.y)
            // Magnet: a nearby swing price pulls the line onto it.
            let r = level.snap / Double(m.pointsPerPrice)
            if let s = LineLab.swings(cs).filter({ $0.high != floor }).map(\.price).min(by: { abs($0 - p) < abs($1 - p) }), abs(s - p) <= r {
              if price != s { snapped += 1 }
              price = s
            } else { price = p }
          })
        LabHandle(color: Palette.accent).position(x: m.plot.maxX - 34, y: m.y(cur)).allowsHitTesting(false)
      }
      .sensoryFeedback(.impact(weight: .light), trigger: snapped)
      .accessibilityElement().accessibilityLabel(floor ? "Floor line at \(coins(cur))" : "Ceiling line at \(coins(cur))")
      .accessibilityAdjustableAction { d in price = cur + (d == .increment ? 1 : -1) * (range.upperBound - range.lowerBound) / 40 }
    } controls: {
      HingeTip(text: "Open or close me to move the line")
      Button(floor ? "That's the floor" : "That's the ceiling") {
        let g = LineLab.grade(level: cur, target: target, candles: cs, tier: level.tier)
        answer(RoundResult(right: g.right, why: g.right ? "\(g.line) A floor is a clue, not a promise: it can break." : g.line))
      }
      .buttonStyle(ChunkyPrimary()).disabled(answered != nil || price == nil)
    }
    .hingeKnob(answered == nil) { f in price = range.lowerBound + f * (range.upperBound - range.lowerBound) }
  }
}

// MARK: Draw the lane (channel)

struct LaneDrill: View {
  let level: AcademyLevel, round: AcademyRound
  let answer: (RoundResult) -> Void; let answered: RoundResult?
  @State private var offset: Double?
  var body: some View {
    let up = round.seed % 2 == 0
    let (cs, t) = LineLab.trendChart(up: up, seed: round.seed, days: level.days, noise: Double(level.tier) / 6)
    let ideal = LineLab.channelOffset(cs, t)
    let range = PlotMap.range(cs, extra: [t.line.at(0) + ideal, t.line.at(Double(cs.count - 1)) + ideal])
    let cur = offset ?? ideal * 0.4
    DrillStage(caption: "A lane") {
      ask(up ? "The bottom rail is drawn. Drag the **top rail** onto the highs." : "The top rail is drawn. Drag the **bottom rail** onto the lows.")
      LabTip(text: "The two rails stay the same distance apart, like train tracks.", scaffold: level.scaffold, answered: answered != nil)
    } chart: {
      let chart = LabChart(candles: cs, range: range,
                           strokes: [LabStroke(line: t.line, color: Hue.teal.color, from: Double(t.anchors.0))]
                             + (answered != nil ? [LabStroke(line: t.line.shifted(ideal), color: Hue.gold.color, dashed: true, from: Double(t.anchors.0))] : [])
                             + [LabStroke(line: t.line.shifted(cur), color: Palette.accent, from: Double(t.anchors.0))])
      LabCanvas(candles: cs, range: range, chart: chart) { m in
        let x = Double(cs.count - 1) - 1.5
        Color.clear.contentShape(Rectangle())
          .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named(LabSpace.name)).onChanged { g in
            guard answered == nil else { return }
            offset = m.price(atY: g.location.y) - t.line.at(m.day(atX: g.location.x))
          })
        LabHandle(color: Palette.accent).position(m.point(day: x, price: t.line.at(x) + cur)).allowsHitTesting(false)
      }
      .accessibilityElement().accessibilityLabel("Second rail")
      .accessibilityAdjustableAction { d in offset = cur + (d == .increment ? 1 : -1) * (range.upperBound - range.lowerBound) / 40 }
    } controls: {
      HingeTip(text: "Open or close me to slide the rail")
      Button("Check my lane") {
        let g = LineLab.grade(laneOffset: cur, ideal: ideal, candles: cs, tier: level.tier)
        answer(RoundResult(right: g.right, why: g.right ? "The price rides between your rails." : "The gold rail touches the far tips. Rails stay the same distance apart."))
      }
      .buttonStyle(ChunkyPrimary()).disabled(answered != nil || offset == nil)
    }
    .hingeKnob(answered == nil) { f in offset = (up ? 1 : -1) * f * abs(ideal) * 2 }
  }
}

// MARK: Breakouts

struct BreakoutDrill: View {
  let level: AcademyLevel, round: AcademyRound
  let answer: (RoundResult) -> Void; let answered: RoundResult?
  @State private var tapped: Int?
  var body: some View {
    let ceiling = round.seed % 2 == 0
    let b = LineLab.breakout(ceiling: ceiling, held: round.seed % 3 != 0, seed: round.seed, days: level.days)
    let slack = level.tier >= 4 ? 0 : 1
    DrillStage(caption: ceiling ? "Ceiling" : "Floor") {
      ask(ceiling ? "Tap the day the price **closed above** the ceiling." : "Tap the day the price **closed below** the floor.")
      LabTip(text: "Look for the first candle whose body ends past the line.", scaffold: level.scaffold, answered: answered != nil)
    } chart: {
      LabCanvas(candles: b.candles, chart: LabChart(candles: b.candles, glow: answered != nil ? [(b.day...b.day, Hue.gold.color)] : [],
                                                      levels: [LabLevel(price: b.level, color: Hue.teal.color, label: ceiling ? "Ceiling" : "Floor")],
                                                      dots: tapped.map { [($0, answered?.right == true ? Palette.good : Palette.bad)] } ?? [])) { m in
        Color.clear.contentShape(Rectangle())
          .onTapGesture(coordinateSpace: .named(LabSpace.name)) { pt in
            guard answered == nil else { return }
            let i = m.index(atX: pt.x)
            tapped = i
            let ok = abs(i - b.day) <= slack
            answer(RoundResult(right: ok, why: ok ? "That's the breakout: the first close past the line." : "The gold day is the first one that closed past the line."))
          }
      }
    } controls: { EmptyView() }
  }
}

struct StickDrill: View {
  let level: AcademyLevel, round: AcademyRound
  let answer: (RoundResult) -> Void; let answered: RoundResult?
  @State private var picked: Int?
  var body: some View {
    let ceiling = round.seed % 2 == 0
    let b = LineLab.breakout(ceiling: ceiling, held: round.seed % 3 != 0, seed: round.seed, days: level.days)
    // Low in the lab: read what happened. Higher: read the crowd on the breakout day, then see.
    let crowdAsk = level.tier >= 3 && round.seed % 2 == 1
    let opts = crowdAsk ? ["A big crowd", "A small crowd"] : ["It stayed past", "It slipped back"]
    let correct = crowdAsk ? (b.bigCrowd ? 0 : 1) : (b.held ? 0 : 1)
    DrillStage(caption: "Volume shows the crowd") {
      ask(crowdAsk ? "It broke through on the glowing day. Was the crowd **big or small**?" : "It broke through. Did it **stay** past the line?")
      LabTip(text: crowdAsk ? "Compare the glowing day's volume bar with the others." : "Look at the days after the glowing one.", scaffold: level.scaffold, answered: answered != nil)
    } chart: {
      LabChart(candles: b.candles, volume: true, glow: [(b.day...b.day, Palette.accent)],
               levels: [LabLevel(price: b.level, color: Hue.teal.color, label: ceiling ? "Ceiling" : "Floor")],
               curtain: crowdAsk && answered == nil ? b.day : nil, volumeGlow: b.day)
    } controls: {
      Choices(options: opts, correct: correct, answered: answered, picked: picked) { i in
        picked = i
        let story = b.held ? "This time it stayed past the line." : "This time it slipped back: a fake-out."
        let crowd = b.bigCrowd ? "The crowd was big." : "The crowd was small."
        answer(RoundResult(right: i == correct, why: "\(crowd) \(story) A big crowd might help a breakout stick, but not always."))
      }
    }
  }
}

// MARK: Moving averages

/// Charts with whole-dollar ends, so the average can be worked out in your head low in the lab.
enum EasyCloses {
  static func chart(seed: Int, days: Int) -> [Candle] {
    var g = Seeded(seed)
    var px = Double(Int.random(in: 10...14, using: &g))
    return (0..<days).map { i in
      let c = max(4, min(22, px + Double(Int.random(in: -2...2, using: &g))))
      let o = px
      let k = Candle(d: "p\(i)", o: o, h: max(o, c) + 0.6, l: min(o, c) - 0.6, c: c, v: Double(Int.random(in: 40...90, using: &g)))
      px = c
      return k
    }
  }
}

struct AverageDotDrill: View {
  let level: AcademyLevel, round: AcademyRound
  let answer: (RoundResult) -> Void; let answered: RoundResult?
  @State private var price: Double?
  var body: some View {
    let window = level.tier <= 1 ? 3 : 5
    let easy = level.tier <= 3
    let cs = easy ? EasyCloses.chart(seed: round.seed, days: 10) : LineLab.waveChart(seed: round.seed, days: max(20, level.days - 8))
    let last = cs.count - 1
    let truth = cs.suffix(window).map(\.c).reduce(0, +) / Double(window)
    let range = PlotMap.range(cs)
    let cur = price ?? (range.lowerBound + range.upperBound) / 2
    let ends = cs.suffix(window).map { coins($0.c) }.joined(separator: ", ")
    DrillStage(caption: "Average of the last \(window) days") {
      ask("Drag the dot to the **average** of the last **\(window)** days' ends.")
      if easy { Text("They ended at **\(ends)**.").font(.callout).frame(maxWidth: .infinity, alignment: .leading) }
      LabTip(text: "Add the \(window) ends, then share them out evenly: divide by \(window).", scaffold: level.scaffold, answered: answered != nil)
    } chart: {
      let chart = LabChart(candles: cs, range: range, glow: [((last - window + 1)...last, Palette.accent.opacity(0.6))],
                           levels: [LabLevel(price: cur, color: Palette.accent.opacity(0.35), dashed: true)] + (answered != nil ? [LabLevel(price: truth, color: Hue.gold.color, dashed: true, label: "Average \(String(format: "$%.2f", truth))")] : []),
                           series: answered != nil ? [LabSeries(values: LineLab.sma(cs, window), color: Hue.gold.color)] : [])
      LabCanvas(candles: cs, range: range, chart: chart) { m in
        Color.clear.contentShape(Rectangle())
          .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named(LabSpace.name)).onChanged { g in
            guard answered == nil else { return }
            let p = m.price(atY: g.location.y)
            price = easy ? (p * 4).rounded() / 4 : p
          })
        LabHandle(color: Palette.accent, selected: true, label: String(format: "$%.2f", cur)).position(m.point(day: Double(last), price: cur)).allowsHitTesting(false)
      }
      .accessibilityElement().accessibilityLabel("Average dot at \(String(format: "$%.2f", cur))")
      .accessibilityAdjustableAction { d in price = cur + (d == .increment ? 0.25 : -0.25) }
    } controls: {
      HingeTip(text: "Open or close me to move the dot")
      Button("That's the average") {
        let g = LineLab.grade(average: cur, truth: truth, candles: cs, tier: level.tier)
        answer(RoundResult(right: g.right, why: "The average is \(String(format: "$%.2f", truth)). Do it every day and you get a smooth line: the moving average."))
      }
      .buttonStyle(ChunkyPrimary()).disabled(answered != nil || price == nil)
    }
    .hingeKnob(answered == nil) { f in price = range.lowerBound + f * (range.upperBound - range.lowerBound) }
  }
}

extension AcademyLevel {
  /// The moving average length the lab uses at this level (5, then 10, then 20 days).
  var maDays: Int { tier <= 1 ? 5 : tier <= 3 ? 10 : 20 }
}

struct AverageSideDrill: View {
  let level: AcademyLevel, round: AcademyRound
  let answer: (RoundResult) -> Void; let answered: RoundResult?
  @State private var picked: Int?
  var body: some View {
    let cs = LineLab.waveChart(seed: round.seed, days: max(30, level.days))
    let ma = LineLab.sma(cs, level.maDays)
    let P = LineLab.span(cs)
    // A day where the price is clearly on one side.
    let days = cs.indices.filter { i in ma[i].map { abs(cs[i].c - $0) > 0.08 * P } ?? false }
    let day = days.isEmpty ? cs.count - 1 : days[abs(round.seed) % days.count]
    let above = cs[day].c > (ma[day] ?? cs[day].c)
    let opts = ["Above", "Below"]
    let correct = above ? 0 : 1
    DrillStage(caption: "\(level.maDays)-day average") {
      ask("On the glowing day, is the price **above** or **below** its average line?")
      LabTip(text: "Find the glowing candle's end, then look at the gold line right there.", scaffold: level.scaffold, answered: answered != nil)
    } chart: {
      LabChart(candles: cs, glow: [(day...day, Palette.accent)], series: [LabSeries(values: ma, color: Hue.gold.color)])
    } controls: {
      Choices(options: opts, correct: correct, answered: answered, picked: picked) { i in
        picked = i
        answer(RoundResult(right: i == correct, why: above ? "It ended above its average: buyers might be doing a bit better lately." : "It ended below its average: sellers might be doing a bit better lately."))
      }
    }
  }
}

struct AveragePickDrill: View {
  let level: AcademyLevel, round: AcademyRound
  let answer: (RoundResult) -> Void; let answered: RoundResult?
  @State private var picked: Int?
  var body: some View {
    let cs = LineLab.waveChart(seed: round.seed, days: max(36, level.days))
    let slowFirst = round.seed % 2 == 0
    let fast = LineLab.sma(cs, 5), slow = LineLab.sma(cs, 20)
    // Two lines, told apart by style (never by colour alone): solid and dashed.
    let solid = slowFirst ? slow : fast, dashed = slowFirst ? fast : slow
    let opts = ["The solid line", "The dashed line"]
    let correct = slowFirst ? 0 : 1
    DrillStage(caption: "Two averages") {
      ask("One line averages **5** days, one averages **20**. Which is the **slow 20-day** line?")
      LabTip(text: "More days in the average make a smoother, calmer line.", scaffold: level.scaffold, answered: answered != nil)
    } chart: {
      LabChart(candles: cs, series: [LabSeries(values: solid, color: Hue.grape.color), LabSeries(values: dashed, color: Hue.orange.color, dashed: true)])
    } controls: {
      Choices(options: opts, correct: correct, answered: answered, picked: picked) { i in
        picked = i
        answer(RoundResult(right: i == correct, why: "The 20-day line is smoother and slower. The 5-day line reacts fast to every wiggle."))
      }
    }
  }
}

struct CrossDrill: View {
  let level: AcademyLevel, round: AcademyRound
  let answer: (RoundResult) -> Void; let answered: RoundResult?
  @State private var tapped: Int?
  var body: some View {
    let cs = LineLab.waveChart(seed: round.seed, days: max(36, level.days), turns: 2)
    let fast = LineLab.sma(cs, 5), slow = LineLab.sma(cs, level.tier >= 4 ? 20 : 15)
    let all = LineLab.crosses(fast: fast, slow: slow, closes: cs.map(\.c))
    let wantUp = all.contains { $0.up } && (round.seed % 2 == 0 || !all.contains { !$0.up })
    let targets = all.filter { $0.up == wantUp }.map(\.day)
    let slack = level.tier >= 4 ? 0 : 1
    DrillStage(caption: "Fast and slow") {
      ask(wantUp ? "Tap where the **fast** (dashed) line crosses **above** the slow one." : "Tap where the **fast** (dashed) line crosses **below** the slow one.")
      LabTip(text: wantUp ? "Find where the dashed line goes from under the solid line to over it." : "Find where the dashed line goes from over the solid line to under it.", scaffold: level.scaffold, answered: answered != nil)
    } chart: {
      LabCanvas(candles: cs, chart: LabChart(candles: cs, glow: answered != nil ? targets.map { ($0...$0, Hue.gold.color) } : [],
                                               series: [LabSeries(values: slow, color: Hue.grape.color), LabSeries(values: fast, color: Hue.orange.color, dashed: true)],
                                               dots: tapped.map { [($0, answered?.right == true ? Palette.good : Palette.bad)] } ?? [])) { m in
        Color.clear.contentShape(Rectangle())
          .onTapGesture(coordinateSpace: .named(LabSpace.name)) { pt in
            guard answered == nil else { return }
            let i = m.index(atX: pt.x)
            tapped = i
            let ok = targets.contains { abs($0 - i) <= slack }
            answer(RoundResult(right: ok, why: wantUp ? "When the fast line crosses above, buyers might be gaining lately. A clue, not a promise." : "When the fast line crosses below, sellers might be gaining lately. A clue, not a promise."))
          }
      }
    } controls: { EmptyView() }
  }
}

// MARK: Crowds and liquidity

struct CrowdDrill: View {
  let level: AcademyLevel, round: AcademyRound
  let answer: (RoundResult) -> Void; let answered: RoundResult?
  @State private var tapped: Int?
  var body: some View {
    let (cs, big) = Self.chart(seed: round.seed, days: level.days, tier: level.tier)
    DrillStage(caption: "Volume: how many traded") {
      ask("Tap the day with the **biggest crowd** (the tallest volume bar).")
      LabTip(text: "Volume bars sit under the candles. Taller bar = more people in the tug-of-war.", scaffold: level.scaffold, answered: answered != nil)
    } chart: {
      LabCanvas(candles: cs, volume: true, chart: LabChart(candles: cs, volume: true, glow: answered != nil ? [(big...big, Hue.gold.color)] : [],
                                                             dots: tapped.map { [($0, answered?.right == true ? Palette.good : Palette.bad)] } ?? [], volumeGlow: answered != nil ? big : nil)) { m in
        Color.clear.contentShape(Rectangle())
          .onTapGesture(coordinateSpace: .named(LabSpace.name)) { pt in
            guard answered == nil else { return }
            let i = m.index(atX: pt.x)
            tapped = i
            answer(RoundResult(right: i == big, why: "The gold day had the tallest bar: the biggest crowd."))
          }
      }
    } controls: { EmptyView() }
  }
  static func chart(seed: Int, days: Int, tier: Int) -> ([Candle], Int) {
    let cs = LineLab.waveChart(seed: seed, days: days)
    let big = abs(seed / 7) % cs.count
    let boost = [3.0, 2.4, 1.9, 1.6, 1.4, 1.25][tier]
    let vmax = cs.map(\.v).max() ?? 90
    return (cs.enumerated().map { i, k in Candle(d: k.d, o: k.o, h: k.h, l: k.l, c: k.c, v: i == big ? vmax * boost : k.v) }, big)
  }
}

/// A pretend order book: the sellers' prices on top, the buyers' below, with bars for how many shares.
struct BookView: View {
  let book: LineLab.Book
  var title: String
  var highlight = false
  var body: some View {
    let maxShares = Double(max(1, (book.asks + book.bids).map(\.shares).max() ?? 1))
    VStack(alignment: .leading, spacing: 3) {
      Text(title).font(.headline)
      ForEach(Array(book.asks.prefix(3).reversed().enumerated()), id: \.offset) { _, s in row(s, ask: true, max: maxShares) }
      HStack {
        Image(systemName: "arrow.up.and.down").font(.caption2.weight(.bold))
        Text("Gap \(String(format: "$%.2f", book.spread))").font(.caption.weight(.heavy))
      }
      .foregroundStyle(Palette.accent).padding(.vertical, 2)
      ForEach(Array(book.bids.prefix(3).enumerated()), id: \.offset) { _, s in row(s, ask: false, max: maxShares) }
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Palette.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(highlight ? Hue.gold.color : Palette.line, lineWidth: highlight ? 3 : 1))
    .accessibilityElement(children: .combine)
  }
  private func row(_ s: LineLab.Book.Step, ask: Bool, max m: Double) -> some View {
    HStack(spacing: 6) {
      Text(String(format: "$%.2f", s.price)).font(.caption.monospacedDigit().weight(.semibold)).frame(width: 56, alignment: .leading)
      GeometryReader { g in
        Capsule().fill((ask ? CandleInk.down : CandleInk.up).opacity(0.55))
          .frame(width: max(4, g.size.width * CGFloat(log(1 + Double(s.shares)) / log(1 + m))))
      }
      .frame(height: 10)
      Text("\(s.shares)").font(.caption2.monospacedDigit()).foregroundStyle(Palette.ink2).frame(width: 40, alignment: .trailing)
    }
  }
}

struct ThinDrill: View {
  let level: AcademyLevel, round: AcademyRound
  let answer: (RoundResult) -> Void; let answered: RoundResult?
  @State private var picked: Int?
  var body: some View {
    let thinFirst = round.seed % 2 == 0
    let a = LineLab.book(deep: !thinFirst, seed: round.seed), b = LineLab.book(deep: thinFirst, seed: round.seed &+ 1)
    let correct = thinFirst ? 0 : 1
    VStack(spacing: 10) {
      ask("Which market is **quiet**: few shares and a **big gap** between buyers and sellers?")
      LabTip(text: "Red rows are sellers' asks, green rows are buyers' offers. Look at the gap and the bars.", scaffold: level.scaffold, answered: answered != nil)
      ViewThatFits(in: .horizontal) {
        HStack(alignment: .top, spacing: 10) { books(a, b, correct) }
        VStack(spacing: 8) { books(a, b, correct) }
      }
      Choices(options: ["Market A", "Market B"], correct: correct, answered: answered, picked: picked) { i in
        picked = i
        answer(RoundResult(right: i == correct, why: "In a quiet market there are few traders, so a big order might move the price on you. Busy markets are easier to trade."))
      }
    }
  }
  @ViewBuilder private func books(_ a: LineLab.Book, _ b: LineLab.Book, _ correct: Int) -> some View {
    BookView(book: a, title: "Market A", highlight: answered != nil && correct == 0)
    BookView(book: b, title: "Market B", highlight: answered != nil && correct == 1)
  }
}

struct FillDrill: View {
  let level: AcademyLevel, round: AcademyRound
  let answer: (RoundResult) -> Void; let answered: RoundResult?
  @State private var picked: Int?
  var body: some View {
    let book = LineLab.book(deep: false, seed: round.seed)
    let q = book.asks.prefix(3).map(\.shares).reduce(0, +)
    let avg = book.fill(q) ?? book.bestAsk
    let top = book.asks.prefix(3).last?.price ?? book.bestAsk
    let opts = Self.options([book.bestAsk, avg, top + (top - book.bestAsk) * 0.5], seed: round.seed)
    let correct = opts.enumerated().min { abs($0.element - avg) < abs($1.element - avg) }?.offset ?? 0
    VStack(spacing: 10) {
      ask("You want **\(q)** pretend shares. They come from the sellers' top 3 rows. About what's the **average** price?")
      LabTip(text: "The cheapest row runs out first, then you pay the next price up.", scaffold: level.scaffold, answered: answered != nil)
      BookView(book: book, title: "A quiet market", highlight: answered != nil)
      Choices(options: opts.map { String(format: "$%.2f", $0) }, correct: correct, answered: answered, picked: picked) { i in
        picked = i
        answer(RoundResult(right: i == correct, why: "About \(String(format: "$%.2f", avg)): more than the best price \(String(format: "$%.2f", book.bestAsk)), because the cheap shares ran out. That's slipping."))
      }
    }
  }
  static func options(_ xs: [Double], seed: Int) -> [Double] {
    var g = Seeded(seed)
    return Array(Set(xs.map { ($0 * 100).rounded() / 100 })).sorted().shuffled(using: &g)
  }
}
