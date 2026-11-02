// Chart reading for Market World: candles, trends, floors and ceilings, volume and moving averages.
// Pure and deterministic, so every game's answer is checkable in a unit test. Nothing here predicts
// anything — the games teach kids to *read* a chart, and the boss shows that charts can surprise.
import Foundation

public struct Candle: Codable, Hashable, Sendable {
  public let d: String; public let o: Double; public let h: Double; public let l: Double; public let c: Double; public let v: Double
  public init(d: String, o: Double, h: Double, l: Double, c: Double, v: Double = 0) { self.d = d; self.o = o; self.h = max(h, o, c); self.l = min(l, o, c); self.c = c; self.v = v }
  public var up: Bool { c >= o }
  public var bodyTop: Double { max(o, c) }
  public var bodyBottom: Double { min(o, c) }
  public var range: Double { h - l }
  /// How much of the day's range the body covers (0 … 1).
  public var bodyShare: Double { range > 0 ? (bodyTop - bodyBottom) / range : 1 }
  public var changePct: Double { o != 0 ? (c - o) / o * 100 : 0 }
}

public struct CandleSeries: Codable, Hashable, Sendable {
  public let s: String; public let candles: [Candle]
  public init(s: String, candles: [Candle]) { self.s = s; self.candles = candles }
  public func window(_ start: Int, _ n: Int) -> [Candle] {
    let a = max(0, min(start, candles.count)), b = max(a, min(candles.count, start + n))
    return Array(candles[a..<b])
  }
}

/// Compact bundle/endpoint shape: arrays per field (see metaphases `/api/kids/candles`).
public struct CandleBundle: Codable, Sendable {
  public struct Raw: Codable, Sendable { public let s: String; public let d: [String]; public let o: [Double]; public let h: [Double]; public let l: [Double]; public let c: [Double]; public let v: [Double] }
  public let asOf: String; public let series: [Raw]
  public var all: [CandleSeries] {
    series.map { r in
      let n = [r.d.count, r.o.count, r.h.count, r.l.count, r.c.count, r.v.count].min() ?? 0
      return CandleSeries(s: r.s, candles: (0..<n).map { Candle(d: r.d[$0], o: r.o[$0], h: r.h[$0], l: r.l[$0], c: r.c[$0], v: r.v[$0]) })
    }
  }
}

public enum Trend: String, CaseIterable, Codable, Sendable {
  case up, down, sideways
  public var word: String { switch self { case .up: return "Going up"; case .down: return "Going down"; case .sideways: return "Sideways" } }
}

/// What a single day's candle says, in kid words.
public enum DayStory: String, CaseIterable, Sendable {
  case bigUp, smallUp, bigDown, smallDown, tugOfWar
  public var line: String {
    switch self {
    case .bigUp: return "Went up a lot"
    case .smallUp: return "Went up a little"
    case .bigDown: return "Went down a lot"
    case .smallDown: return "Went down a little"
    case .tugOfWar: return "Tug of war: ended near the start"
    }
  }
}

public enum ChartMath {
  /// Least-squares line y = a + b·x over x = 0…n-1.
  public static func fit(_ ys: [Double]) -> (a: Double, b: Double) {
    let n = Double(ys.count)
    guard ys.count > 1 else { return (ys.first ?? 0, 0) }
    let mx = (n - 1) / 2, my = ys.reduce(0, +) / n
    var num = 0.0, den = 0.0
    for (i, y) in ys.enumerated() { let dx = Double(i) - mx; num += dx * (y - my); den += dx * dx }
    let b = den == 0 ? 0 : num / den
    return (my - b * mx, b)
  }

  /// Up, down or sideways: how far the best-fit line travels across the window, relative to the price.
  /// `threshold` 0.06 = the line moves at least 6% of the average price.
  public static func trend(_ closes: [Double], threshold: Double = 0.06) -> Trend {
    guard closes.count > 2 else { return .sideways }
    let f = fit(closes), mean = closes.reduce(0, +) / Double(closes.count)
    let travel = f.b * Double(closes.count - 1) / max(mean, 0.0001)
    return travel > threshold ? .up : travel < -threshold ? .down : .sideways
  }

  /// Simple moving average; nil until the window is full.
  public static func sma(_ xs: [Double], window: Int) -> [Double?] {
    guard window > 0 else { return xs.map { _ in nil } }
    var out: [Double?] = [], sum = 0.0
    for (i, x) in xs.enumerated() {
      sum += x
      if i >= window { sum -= xs[i - window] }
      out.append(i >= window - 1 ? sum / Double(window) : nil)
    }
    return out
  }

  /// The "floor" (support): the average of the lowest fifth of the lows.
  public static func floor(_ candles: [Candle]) -> Double { band(candles.map(\.l), low: true) }
  /// The "ceiling" (resistance): the average of the highest fifth of the highs.
  public static func ceiling(_ candles: [Candle]) -> Double { band(candles.map(\.h), low: false) }
  static func band(_ xs: [Double], low: Bool) -> Double {
    guard !xs.isEmpty else { return 0 }
    let k = max(1, xs.count / 5)
    let pick = low ? Array(xs.sorted().prefix(k)) : Array(xs.sorted(by: >).prefix(k))
    return pick.reduce(0, +) / Double(pick.count)
  }

  public static func busiest(_ candles: [Candle]) -> Int { candles.indices.max { candles[$0].v < candles[$1].v } ?? 0 }

  public static func story(_ c: Candle, typicalMovePct: Double = 1.2) -> DayStory {
    if c.bodyShare < 0.25 && c.range > 0 { return .tugOfWar }
    let big = abs(c.changePct) >= typicalMovePct
    return c.up ? (big ? .bigUp : .smallUp) : (big ? .bigDown : .smallDown)
  }

  /// Stars for placing a level (a price) near a target, judged against the chart's height.
  public static func levelStars(guess: Double, target: Double, chartRange: Double) -> Int {
    guard chartRange > 0 else { return 1 }
    let e = abs(guess - target) / chartRange
    return e <= 0.07 ? 3 : e <= 0.15 ? 2 : 1
  }

  /// Stars for a finger-drawn trendline (start/end prices across the window) against the best fit.
  public static func trendlineStars(start: Double, end: Double, closes: [Double]) -> Int {
    let f = fit(closes), n = Double(max(closes.count - 1, 1))
    let fs = f.a, fe = f.a + f.b * n
    let r = (closes.max() ?? 0) - (closes.min() ?? 0)
    guard r > 0 else { return 1 }
    let e = (abs(start - fs) + abs(end - fe)) / 2 / r
    let sameWay = (end - start).sign == (fe - fs).sign || abs(fe - fs) / r < 0.1
    return !sameWay ? 1 : e <= 0.12 ? 3 : e <= 0.25 ? 2 : 1
  }

  /// Every window of `length` days in the series whose trend is `t` (stepping by `step`).
  public static func windows(_ s: CandleSeries, length: Int, trend t: Trend, step: Int = 5) -> [Int] {
    guard s.candles.count >= length else { return [] }
    return stride(from: 0, through: s.candles.count - length, by: step).filter { trend(s.window($0, length).map(\.c)) == t }
  }
}

/// Deterministic randomness (SplitMix64) so practice charts and rounds are the same for a given seed.
public struct Seeded: RandomNumberGenerator {
  var state: UInt64
  public init(_ seed: Int) { state = UInt64(bitPattern: Int64(seed)) &+ 0x9E3779B97F4A7C15 }
  public mutating func next() -> UInt64 {
    state &+= 0x9E3779B97F4A7C15
    var z = state
    z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
    z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
    return z ^ (z >> 31)
  }
}

/// Chart shapes for Pattern Peaks. Practice charts are drawn from a recipe (labeled "practice chart" in
/// the UI), because clean textbook patterns are rare in real prices.
public enum ChartPattern: String, CaseIterable, Codable, Sendable {
  case bounce, breakout, doubleTop, doubleBottom
  public var name: String {
    switch self {
    case .bounce: return "Bounced off the floor"
    case .breakout: return "Broke through the ceiling"
    case .doubleTop: return "Two hills"
    case .doubleBottom: return "Two valleys"
    }
  }
  public var clue: String {
    switch self {
    case .bounce: return "It fell to the same low spot again and again, then bounced up."
    case .breakout: return "It kept stopping at the same high spot, then pushed through."
    case .doubleTop: return "It climbed to the same high spot twice, then slid down."
    case .doubleBottom: return "It dipped to the same low spot twice, then climbed."
    }
  }
}

public enum Practice {
  /// A practice chart for a pattern: `n` candles around 100, wobble from the seed.
  public static func chart(_ p: ChartPattern, seed: Int, n: Int = 36) -> [Candle] {
    var g = Seeded(seed)
    func path(_ x: Double) -> Double {
      switch p {
      case .bounce: return 100 - 12 * abs(sin(x * .pi * 2.2)) * (1 - x * 0.25) + (x > 0.8 ? (x - 0.8) * 60 : 0)
      case .breakout: return x < 0.7 ? 92 + 8 * abs(sin(x * .pi * 3)) : 100 + (x - 0.7) * 70
      case .doubleTop: return 90 + 12 * max(0, sin(x * .pi * 2.6)) - (x > 0.75 ? (x - 0.75) * 50 : 0)
      case .doubleBottom: return 110 - 12 * max(0, sin(x * .pi * 2.6)) + (x > 0.75 ? (x - 0.75) * 50 : 0)
      }
    }
    var out: [Candle] = []
    var prev = path(0)
    for i in 0..<n {
      let x = Double(i) / Double(n - 1)
      let close = path(x) + Double.random(in: -1.2...1.2, using: &g)
      let open = prev + Double.random(in: -0.8...0.8, using: &g)
      let hi = max(open, close) + Double.random(in: 0.2...1.6, using: &g)
      let lo = min(open, close) - Double.random(in: 0.2...1.6, using: &g)
      out.append(Candle(d: "p\(i)", o: open, h: hi, l: lo, c: close, v: Double.random(in: 40...100, using: &g)))
      prev = close
    }
    return out
  }

  /// A wobbly line for "Smooth it out".
  public static func noisy(seed: Int, n: Int = 40) -> [Double] {
    var g = Seeded(seed), y = 100.0
    let drift = Double.random(in: -0.3...0.4, using: &g)
    return (0..<n).map { _ in y += drift + Double.random(in: -3...3, using: &g); return y }
  }
}
