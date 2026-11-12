// Line Lab: the chart tools after candles. Trend lines, floors and ceilings, lanes (channels), breakouts,
// moving averages, volume and liquidity. Each tool has a practice-chart generator, the ground truth
// computed from the candles (the market technician's rules in docs/CHART_ACADEMY.md), and a grader for
// what a finger drew. Grading is in days and prices, never in points, so a line passes the same on every
// screen (see `PlotMap`). Words: clues, not promises; never "buy" or "sell".
import Foundation

public struct Swing: Equatable, Sendable {
  public let index: Int
  public let price: Double
  public let high: Bool
}

/// A straight line through two (day, price) points; extends both ways.
public struct ChartLine: Equatable, Sendable {
  public var x1: Double, y1: Double, x2: Double, y2: Double
  public init(x1: Double, y1: Double, x2: Double, y2: Double) { self.x1 = x1; self.y1 = y1; self.x2 = x2; self.y2 = y2 }
  public var slope: Double { x2 == x1 ? 0 : (y2 - y1) / (x2 - x1) }
  public func at(_ x: Double) -> Double { y1 + (x - x1) * slope }
  public func shifted(_ d: Double) -> ChartLine { ChartLine(x1: x1, y1: y1 + d, x2: x2, y2: y2 + d) }
}

/// How a drawn line did. `stars` 0 = not yet; 1 = close but no; 2 = right; 3 = spot on.
public struct LineGrade: Equatable, Sendable {
  public enum Why: String, Sendable { case spotOn, close, wrongWay, cutsCandles, oneTouch, tooShort, far }
  public let stars: Int
  public let why: Why
  public var right: Bool { stars >= 2 }
  /// The kid line for the feedback card.
  public var line: String {
    switch why {
    case .spotOn: return "Spot on! Your line sits right on the turning points."
    case .close: return "So close! The gold line shows the exact spot."
    case .wrongWay: return "Your line goes the other way. Follow the price from left to right."
    case .cutsCandles: return "Your line cuts through candle bodies. It should only touch the tips."
    case .oneTouch: return "Your line touches only one turning point. A good line touches two or more."
    case .tooShort: return "Make your line longer, so it covers most of the chart."
    case .far: return "The gold line shows where the turning points are. Try again!"
    }
  }
}

public enum LineLab {
  // MARK: shared

  /// The visible span (max high − min low).
  public static func span(_ cs: [Candle]) -> Double { max(0.0001, (cs.map(\.h).max() ?? 1) - (cs.map(\.l).min() ?? 0)) }
  static func avgRange(_ cs: [Candle]) -> Double { cs.isEmpty ? 1 : cs.map(\.range).reduce(0, +) / Double(cs.count) }

  /// How far off a line may be (share of the visible span), by difficulty 0…5. Generous low, sharp high.
  public static func tolerance(_ tier: Int) -> Double { [0.08, 0.065, 0.05, 0.04, 0.03, 0.025][max(0, min(5, tier))] }
  /// The finger's magnet radius (points) by difficulty: it pulls a handle onto a wick tip. 0 = off.
  public static func snapRadius(_ tier: Int) -> Double { [44, 36, 28, 20, 12, 0][max(0, min(5, tier))] }

  // MARK: swing points

  /// Swing highs and lows (window N by chart length), thinned to alternate and to differ by ≥ 5% of the span.
  public static func swings(_ cs: [Candle]) -> [Swing] {
    let n = cs.count <= 40 ? 2 : cs.count <= 80 ? 3 : 4
    var raw: [Swing] = []
    guard cs.count > 2 * n else { return [] }
    for i in n..<(cs.count - n) {
      let h = cs[i].h, l = cs[i].l
      if (i - n..<i).allSatisfy({ h > cs[$0].h }) && (i + 1...i + n).allSatisfy({ h >= cs[$0].h }) { raw.append(Swing(index: i, price: h, high: true)) }
      if (i - n..<i).allSatisfy({ l < cs[$0].l }) && (i + 1...i + n).allSatisfy({ l <= cs[$0].l }) { raw.append(Swing(index: i, price: l, high: false)) }
    }
    let P = span(cs)
    var kept: [Swing] = []
    for s in raw {
      if let last = kept.last {
        if last.high == s.high {
          // Two of a kind in a row: keep the more extreme one.
          if (s.high && s.price > last.price) || (!s.high && s.price < last.price) { kept[kept.count - 1] = s }
          continue
        }
        if abs(s.price - last.price) < 0.05 * P { continue }
      }
      kept.append(s)
    }
    return kept
  }

  // MARK: trend lines

  public struct Trendline: Equatable, Sendable {
    public let line: ChartLine
    public let anchors: (Int, Int)
    public let touches: [Int]
    public let up: Bool
    public static func == (a: Trendline, b: Trendline) -> Bool { a.line == b.line && a.anchors == b.anchors && a.touches == b.touches && a.up == b.up }
  }

  /// The best trend line: under the lows for an up trend (over the highs for a down trend). No close goes
  /// through it, at most one wick pokes past, two or more swing points touch it.
  public static func trendline(_ cs: [Candle], up: Bool) -> Trendline? {
    let P = span(cs)
    let pts = swings(cs).filter { $0.high != up }
    var best: (score: Double, t: Trendline)?
    for i in pts.indices { for j in pts.indices where j > i {
      let a = pts[i], b = pts[j]
      guard up ? b.price > a.price : b.price < a.price else { continue }
      let line = ChartLine(x1: Double(a.index), y1: a.price, x2: Double(b.index), y2: b.price)
      var pokes = 0, ok = true
      for x in a.index..<cs.count {
        let y = line.at(Double(x)), k = cs[x]
        if up {
          if k.c < y - 0.005 * P { ok = false; break }
          if k.l < y - 0.015 * P { pokes += 1 }
        } else {
          if k.c > y + 0.005 * P { ok = false; break }
          if k.h > y + 0.015 * P { pokes += 1 }
        }
      }
      guard ok, pokes <= 1 else { continue }
      let touches = pts.filter { abs($0.price - line.at(Double($0.index))) <= 0.015 * P }.map(\.index)
      guard touches.count >= 2 else { continue }
      let score = 10 * Double(touches.count) + 0.2 * Double(cs.count - 1 - a.index) - 3 * Double(pokes)
      if best == nil || score > best!.score { best = (score, Trendline(line: line, anchors: (a.index, b.index), touches: touches, up: up)) }
    } }
    return best?.t
  }

  /// Grades a drawn trend line against the best one (`tol` = share of the span; `tolerance(tier)`).
  public static func grade(trend player: ChartLine, ideal: Trendline, candles cs: [Candle], tol: Double) -> LineGrade {
    let P = span(cs)
    let (a, b) = ideal.anchors
    let err = max(abs(player.at(Double(a)) - ideal.line.at(Double(a))), abs(player.at(Double(b)) - ideal.line.at(Double(b)))) / P
    let wantUp = ideal.up
    let idealSlope = ideal.line.slope, ps = player.slope
    let flat = abs(idealSlope) * Double(cs.count) / P < 0.1
    if !flat && (ps > 0) != (idealSlope > 0) { return LineGrade(stars: 0, why: .wrongWay) }
    if err <= tol / 2 { return LineGrade(stars: 3, why: .spotOn) }
    if err <= tol { return LineGrade(stars: 2, why: .spotOn) }
    // Another fair line (not the exact one): long enough, under (over) the candles, two touches.
    let lo = Int(min(player.x1, player.x2).rounded()), hi = Int(max(player.x1, player.x2).rounded())
    let s = max(0, lo), e = min(cs.count - 1, hi)
    if Double(e - s + 1) < 0.3 * Double(cs.count) { return LineGrade(stars: 1, why: err <= 2 * tol ? .tooShort : .far) }
    var wicksOK = 0, closesOK = true
    for x in s...e {
      let y = player.at(Double(x)), k = cs[x]
      if wantUp { if k.l >= y - 0.015 * P { wicksOK += 1 }; if k.c < y - 0.005 * P { closesOK = false } }
      else { if k.h <= y + 0.015 * P { wicksOK += 1 }; if k.c > y + 0.005 * P { closesOK = false } }
    }
    let touches = swings(cs).filter { $0.high != wantUp && $0.index >= s && $0.index <= e && abs($0.price - player.at(Double($0.index))) <= 0.02 * P }.count
    if !closesOK { return LineGrade(stars: 1, why: .cutsCandles) }
    if Double(wicksOK) >= 0.9 * Double(e - s + 1) && touches >= 2 { return LineGrade(stars: 2, why: .spotOn) }
    if touches < 2 && err <= 2 * tol { return LineGrade(stars: 1, why: .oneTouch) }
    return LineGrade(stars: 1, why: err <= 2 * tol ? .close : .far)
  }

  /// A zigzag practice chart whose trend line is clean: lows (highs) sit on a straight rail.
  public static func trendChart(up: Bool, seed: Int, days n: Int, noise: Double = 0.2) -> (candles: [Candle], line: Trendline) {
    for salt in 0..<40 {
      var r = CandleLab.Gen(g: Seeded(seed &+ salt &* 104_729))
      let P = 30.0
      let rise = (up ? 1 : -1) * P * r.u(0.45, 0.7)
      let base = up ? 100.0 : 100.0 - rise
      // Rail: y = base + rise * x/(n-1). Pivots alternate: touch the rail, swing away by the lane width.
      let width = P * r.u(0.25, 0.4)
      var pivots: [(Double, Double)] = []
      var x = 0.0, onRail = r.coin()
      while x < Double(n - 1) {
        let rail = base + rise * x / Double(n - 1)
        let y = onRail ? rail : (up ? rail + width * r.u(0.7, 1.0) : rail - width * r.u(0.7, 1.0))
        pivots.append((x, y))
        x += Double(Int(r.u(max(3, Double(n) / 7), max(4.5, Double(n) / 4.5))))
        onRail.toggle()
      }
      let lastRail = base + rise
      pivots.append((Double(n - 1), onRail ? lastRail : (up ? lastRail + width * 0.8 : lastRail - width * 0.8)))
      func path(_ i: Double) -> Double {
        guard let k = pivots.lastIndex(where: { $0.0 <= i }), k + 1 < pivots.count else { return pivots.last?.1 ?? 100 }
        let (x0, y0) = pivots[k], (x1, y1) = pivots[k + 1]
        let t = (i - x0) / max(1, x1 - x0)
        return y0 + (y1 - y0) * (0.5 - cos(t * .pi) / 2)
      }
      let pivotSet = Dictionary(pivots.map { (Int($0.0), $0.1) }, uniquingKeysWith: { a, _ in a })
      var cs: [Candle] = []
      var prev = path(0)
      let wig = P * 0.02 * (1 + noise * 3)
      for i in 0..<n {
        let rail = base + rise * Double(i) / Double(n - 1)
        var c = path(Double(i)) + r.u(-wig, wig)
        var o = prev + r.u(-wig / 2, wig / 2)
        var h = max(o, c) + r.u(0.15, 0.9) * wig * 2
        var l = min(o, c) - r.u(0.15, 0.9) * wig * 2
        // Keep the rail clean: nothing crosses it, and the rail pivots touch it exactly.
        if up {
          let floor = rail + 0.004 * P
          if min(o, c) < floor { let lift = floor - min(o, c); o += lift; c += lift; h += lift }
          l = max(l, rail + 0.002 * P)
          if let py = pivotSet[i], abs(py - rail) < 0.001 { l = rail }
        } else {
          let ceil = rail - 0.004 * P
          if max(o, c) > ceil { let drop = max(o, c) - ceil; o -= drop; c -= drop; l -= drop }
          h = min(h, rail - 0.002 * P)
          if let py = pivotSet[i], abs(py - rail) < 0.001 { h = rail }
        }
        cs.append(Candle(d: "p\(i)", o: o, h: max(h, o, c), l: min(l, o, c), c: c, v: r.u(40, 90)))
        prev = c
      }
      if let t = trendline(cs, up: up), t.touches.count >= 2 { return (cs, t) }
    }
    let cs = Practice.chart(up ? .bounce : .doubleTop, seed: seed, n: n)
    let fallback = Trendline(line: ChartLine(x1: 0, y1: cs[0].l, x2: Double(n - 1), y2: cs[n - 1].l), anchors: (0, n - 1), touches: [0, n - 1], up: up)
    return (cs, fallback)
  }

  // MARK: floors and ceilings

  public struct Level: Equatable, Sendable {
    public let price: Double
    public let members: [Int]
    public var strong: Bool { members.count >= 3 }
  }

  /// Floors and ceilings: swing points that cluster within 1.5% of the span, at least two, 5+ days apart.
  public static func levels(_ cs: [Candle]) -> [Level] {
    let P = span(cs)
    let pts = swings(cs).sorted { $0.price < $1.price }
    var groups: [[Swing]] = []
    for s in pts {
      if let last = groups.last?.last, s.price - last.price <= 0.015 * P { groups[groups.count - 1].append(s) } else { groups.append([s]) }
    }
    return groups.compactMap { g in
      let idx = g.map(\.index).sorted()
      guard g.count >= 2, let f = idx.first, let l = idx.last, l - f >= 5 else { return nil }
      let prices = g.map(\.price).sorted()
      let median = prices.count % 2 == 1 ? prices[prices.count / 2] : (prices[prices.count / 2 - 1] + prices[prices.count / 2]) / 2
      return Level(price: median, members: idx)
    }
  }

  /// Stars for a dragged level against the true one (1% / 2% / 3% of the span; the tier widens it low down).
  public static func grade(level guess: Double, target: Double, candles cs: [Candle], tier: Int) -> LineGrade {
    let e = abs(guess - target) / span(cs)
    let tol = tolerance(tier) * 0.6
    if e <= tol / 2 { return LineGrade(stars: 3, why: .spotOn) }
    if e <= tol { return LineGrade(stars: 2, why: .spotOn) }
    return LineGrade(stars: 1, why: e <= 2 * tol ? .close : .far)
  }

  /// A chart that keeps bouncing off a floor (or stopping at a ceiling), 3 to 4 times.
  public static func levelChart(floor: Bool, seed: Int, days n: Int, noise: Double = 0.2) -> (candles: [Candle], level: Double) {
    for salt in 0..<40 {
      var r = CandleLab.Gen(g: Seeded(seed &+ salt &* 7_717))
      let P = 24.0, L = 100.0
      var pivots: [(Double, Double)] = []
      var x = 0.0, touch = false
      while x < Double(n - 1) {
        let away = P * r.u(0.55, 1.0)
        pivots.append((x, touch ? L : (floor ? L + away : L - away)))
        x += Double(Int(r.u(4, 7.99))); touch.toggle()
      }
      pivots.append((Double(n - 1), floor ? L + P * 0.5 : L - P * 0.5))
      let touchDays = Set(pivots.filter { $0.1 == L }.map { Int($0.0) })
      func path(_ i: Double) -> Double {
        guard let k = pivots.lastIndex(where: { $0.0 <= i }), k + 1 < pivots.count else { return pivots.last?.1 ?? L }
        let (x0, y0) = pivots[k], (x1, y1) = pivots[k + 1]
        let t = (i - x0) / max(1, x1 - x0)
        return y0 + (y1 - y0) * (0.5 - cos(t * .pi) / 2)
      }
      let wig = P * 0.02 * (1 + noise * 3)
      var cs: [Candle] = [], prev = path(0)
      for i in 0..<n {
        var c = path(Double(i)) + r.u(-wig, wig), o = prev + r.u(-wig / 2, wig / 2)
        if floor { c = max(c, L + 0.006 * P); o = max(o, L + 0.006 * P) } else { c = min(c, L - 0.006 * P); o = min(o, L - 0.006 * P) }
        var h = max(o, c) + r.u(0.2, 1) * wig * 1.5, l = min(o, c) - r.u(0.2, 1) * wig * 1.5
        if floor { l = touchDays.contains(i) ? L - r.u(0, 0.004) * P : max(l, L + 0.012 * P) }
        else { h = touchDays.contains(i) ? L + r.u(0, 0.004) * P : min(h, L - 0.012 * P) }
        cs.append(Candle(d: "p\(i)", o: o, h: max(h, o, c), l: min(l, o, c), c: c, v: r.u(40, 90)))
        prev = c
      }
      let lv = levels(cs).filter { abs($0.price - L) <= 0.02 * span(cs) }.max { $0.members.count < $1.members.count }
      if let lv, lv.members.count >= 2 { return (cs, lv.price) }
    }
    let cs = Practice.chart(floor ? .bounce : .breakout, seed: seed, n: n)
    return (cs, floor ? ChartMath.floor(cs) : ChartMath.ceiling(cs))
  }

  // MARK: lanes (channels)

  /// The other side of the lane: the trend line shifted to the farthest high (low).
  public static func channelOffset(_ cs: [Candle], _ t: Trendline) -> Double {
    let a = t.anchors.0
    let ds = (a..<cs.count).map { x in t.up ? cs[x].h - t.line.at(Double(x)) : cs[x].l - t.line.at(Double(x)) }
    return t.up ? (ds.max() ?? 0) : (ds.min() ?? 0)
  }

  /// Grades the second rail of a lane (the first rail is the trend line, graded on its own).
  public static func grade(laneOffset guess: Double, ideal: Double, candles cs: [Candle], tier: Int) -> LineGrade {
    grade(level: guess, target: ideal, candles: cs, tier: tier)
  }

  // MARK: breakouts

  public struct Breakout: Equatable, Sendable {
    public let candles: [Candle]
    public let level: Double
    /// The day it closed past the level.
    public let day: Int
    /// Did it stay past the level for the next days?
    public let held: Bool
    /// Was the crowd big that day (volume at least 1.5x its 20-day average)?
    public let bigCrowd: Bool
    public let ceiling: Bool
  }

  /// A chart that pushes through a ceiling (or under a floor) and then holds, or slips back (a fake-out).
  /// Big volume usually comes with the ones that hold; about 1 in 5 holds without it (a clue, not a rule).
  public static func breakout(ceiling: Bool, held: Bool, seed: Int, days n: Int) -> Breakout {
    var r = CandleLab.Gen(g: Seeded(seed))
    let base = levelChart(floor: !ceiling, seed: seed, days: max(14, n - 6))
    var cs = base.candles
    let L = base.level, P = span(cs)
    let way: Double = ceiling ? 1 : -1
    let avgV = cs.map(\.v).reduce(0, +) / Double(cs.count)
    let quiet = held && r.u(0, 1) < 0.2
    // Walk up to the level, then the push.
    var px = cs.last?.c ?? L
    let toLevel = 2
    for k in 0..<toLevel {
      let target = L - way * P * (0.12 - 0.05 * Double(k))
      let o = px, c = target
      cs.append(Candle(d: "", o: o, h: max(o, c) + P * 0.01, l: min(o, c) - P * 0.01, c: c, v: avgV * r.u(0.8, 1.1)))
      px = c
    }
    let pushC = L + way * P * r.u(0.06, 0.1)
    let vol = avgV * (held && !quiet ? r.u(1.8, 3.0) : r.u(0.7, 1.15))
    cs.append(Candle(d: "", o: px, h: max(px, pushC) + P * 0.01, l: min(px, pushC) - P * 0.01, c: pushC, v: vol))
    let day = cs.count - 1
    px = pushC
    let remaining = max(3, n - cs.count)
    for k in 0..<remaining {
      let c: Double
      if held { c = px + way * P * r.u(0.01, 0.05) }
      else { c = k == 0 ? L - way * P * r.u(0.02, 0.04) : px - way * P * r.u(0.01, 0.04) }
      let o = px
      cs.append(Candle(d: "", o: o, h: max(o, c) + P * 0.01, l: min(o, c) - P * 0.01, c: c, v: avgV * r.u(0.7, 1.1)))
      px = c
    }
    cs = cs.enumerated().map { i, k in Candle(d: "p\(i)", o: k.o, h: k.h, l: k.l, c: k.c, v: k.v) }
    let prior = cs[max(0, day - 20)..<day].map(\.v)
    let big = cs[day].v >= 1.5 * (prior.reduce(0, +) / Double(max(1, prior.count)))
    return Breakout(candles: cs, level: L, day: day, held: held, bigCrowd: big, ceiling: ceiling)
  }

  /// The day the price first *closed* past a level by more than 1.5% of the span.
  public static func breakoutDay(_ cs: [Candle], level L: Double, ceiling: Bool) -> Int? {
    let P = span(cs)
    return cs.indices.dropFirst().first { t in
      ceiling ? cs[t].c > L + 0.015 * P && cs[t - 1].c <= L + 0.015 * P : cs[t].c < L - 0.015 * P && cs[t - 1].c >= L - 0.015 * P
    }
  }

  // MARK: moving averages

  public static func sma(_ cs: [Candle], _ n: Int) -> [Double?] { ChartMath.sma(cs.map(\.c), window: n) }

  public enum Side: String, Sendable { case above, below, touching }
  public static func side(_ c: Double, _ ma: Double) -> Side { c > ma * 1.002 ? .above : c < ma * 0.998 ? .below : .touching }

  /// Days where the fast line crosses the slow one (`up`: fast goes above). Whipsaws are left out.
  public static func crosses(fast: [Double?], slow: [Double?], closes: [Double]) -> [(day: Int, up: Bool)] {
    var out: [(Int, Bool)] = []
    for t in 1..<min(fast.count, slow.count) {
      guard let f0 = fast[t - 1], let s0 = slow[t - 1], let f1 = fast[t], let s1 = slow[t] else { continue }
      if f0 <= s0 && f1 > s1 { out.append((t, true)) } else if f0 >= s0 && f1 < s1 { out.append((t, false)) }
    }
    // Whipsaw filter: a tiny cross undone within 3 days doesn't count.
    return out.enumerated().filter { k, c in
      let gap = abs((fast[c.0] ?? 0) - (slow[c.0] ?? 0))
      let undone = k + 1 < out.count && out[k + 1].0 - c.0 <= 3
      return !(gap < 0.002 * closes[c.0] && undone)
    }.map { (day: $0.element.0, up: $0.element.1) }
  }

  /// A wavy chart for averages: one or two clear turns, so the fast line crosses the slow one.
  public static func waveChart(seed: Int, days n: Int, turns: Int = 1) -> [Candle] {
    var r = CandleLab.Gen(g: Seeded(seed))
    let P = 26.0, phase = r.u(0, .pi)
    let drift = r.u(-0.15, 0.15) * P / Double(n)
    var cs: [Candle] = [], prev = 100.0
    for i in 0..<n {
      let x = Double(i) / Double(n - 1)
      let c = 100 + P * 0.5 * sin(phase + x * .pi * (Double(turns) + 0.6)) + drift * Double(i) + r.u(-0.9, 0.9)
      let o = prev + r.u(-0.4, 0.4)
      cs.append(Candle(d: "p\(i)", o: o, h: max(o, c) + r.u(0.2, 1.2), l: min(o, c) - r.u(0.2, 1.2), c: c, v: r.u(40, 90)))
      prev = c
    }
    return cs
  }

  /// Grades a dot placed for the average of the last n closes (pass within 2% of the span; 1% spot on,
  /// widened low in the lab).
  public static func grade(average guess: Double, truth: Double, candles cs: [Candle], tier: Int) -> LineGrade {
    let e = abs(guess - truth) / span(cs)
    let tol = max(0.02, tolerance(tier) * 0.5)
    if e <= tol / 2 { return LineGrade(stars: 3, why: .spotOn) }
    if e <= tol { return LineGrade(stars: 2, why: .spotOn) }
    return LineGrade(stars: 1, why: e <= 2 * tol ? .close : .far)
  }

  // MARK: liquidity

  /// A pretend order book: 5 steps a side. Deep = many shares and a tiny gap; thin = few shares, a wide gap.
  public struct Book: Equatable, Sendable {
    public struct Step: Equatable, Sendable { public let price: Double; public let shares: Int }
    public let bids: [Step]   // best (highest) first
    public let asks: [Step]   // best (lowest) first
    public var bestBid: Double { bids.first?.price ?? 0 }
    public var bestAsk: Double { asks.first?.price ?? 0 }
    /// The gap between what buyers offer and sellers ask.
    public var spread: Double { bestAsk - bestBid }
    public var spreadShare: Double { spread / max(0.0001, (bestAsk + bestBid) / 2) }
    public var topShares: Int { min(bids.first?.shares ?? 0, asks.first?.shares ?? 0) }

    /// The average price paid to pick up `q` pretend shares from the sellers' side (nil: not enough shares).
    public func fill(_ q: Int) -> Double? {
      var left = q, cost = 0.0
      for s in asks { let take = min(left, s.shares); cost += Double(take) * s.price; left -= take; if left == 0 { break } }
      return left > 0 ? nil : cost / Double(q)
    }
    /// How far the average price slid past the best price.
    public func slip(_ q: Int) -> Double? { fill(q).map { $0 - bestAsk } }
  }

  public static func book(deep: Bool, seed: Int, mid: Double = 20) -> Book {
    var r = CandleLab.Gen(g: Seeded(seed))
    let spreadPct = deep ? r.u(0.0003, 0.001) : r.u(0.012, 0.03)
    let half = mid * spreadPct / 2
    let tick = deep ? max(0.01, mid * 0.0005) : max(0.05, mid * 0.006)
    func size() -> Int { deep ? Int(r.u(600, 5000) / 10) * 10 : Int(r.u(10, 120)) }
    let bids = (0..<5).map { k in Book.Step(price: ((mid - half - Double(k) * tick) * 100).rounded(.down) / 100, shares: size()) }
    let asks = (0..<5).map { k in Book.Step(price: ((mid + half + Double(k) * tick) * 100).rounded(.up) / 100, shares: size()) }
    return Book(bids: bids, asks: asks)
  }
}
