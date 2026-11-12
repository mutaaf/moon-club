// Candle Academy's pattern book: 39 candlestick patterns with exact, numeric rules (from a market
// technician's spec, docs/CHART_ACADEMY.md), a checker for each, and a seeded generator that draws a
// practice chart where the pattern really is there. The generator and the checker test each other
// (CandlePatternTests): every generated pattern passes its own rule, and its look-alike fails it.
//
// Words: buyers and sellers are two teams in a tug-of-war. A pattern is a clue, never a promise:
// "might", never "will", and nothing here ever says to buy or sell.
import Foundation

public enum CandlePattern: String, CaseIterable, Codable, Sendable {
  // one candle
  case bigUpCandle, bigDownCandle, marubozuUp, marubozuDown, doji, longLeggedDoji, dragonflyDoji, gravestoneDoji,
       spinningTop, hammer, hangingMan, invertedHammer, shootingStar
  // two candles
  case bullishEngulfing, bearishEngulfing, bullishHarami, bearishHarami, bullishHaramiCross, bearishHaramiCross,
       piercingLine, darkCloudCover, tweezerBottom, tweezerTop, bullishKicker, bearishKicker
  // three (and five) candles
  case morningStar, eveningStar, morningDojiStar, eveningDojiStar, threeWhiteSoldiers, threeBlackCrows,
       threeInsideUp, threeInsideDown, threeOutsideUp, threeOutsideDown, bullishAbandonedBaby, bearishAbandonedBaby,
       risingThreeMethods, fallingThreeMethods

  /// The shape family, drawn the "buyers win" way up; `mirrored` flips it for the sellers' twin.
  enum Shape { case bigUp, marubozu, doji, longLegged, dragonfly, spinning, hammer, hangingMan, engulfing, harami,
               haramiCross, piercing, tweezer, kicker, star, dojiStar, soldiers, insideThree, outsideThree, abandoned, risingThree }

  var shape: (Shape, mirrored: Bool) {
    switch self {
    case .bigUpCandle: return (.bigUp, false)
    case .bigDownCandle: return (.bigUp, true)
    case .marubozuUp: return (.marubozu, false)
    case .marubozuDown: return (.marubozu, true)
    case .doji: return (.doji, false)
    case .longLeggedDoji: return (.longLegged, false)
    case .dragonflyDoji: return (.dragonfly, false)
    case .gravestoneDoji: return (.dragonfly, true)
    case .spinningTop: return (.spinning, false)
    case .hammer: return (.hammer, false)
    case .shootingStar: return (.hammer, true)
    case .hangingMan: return (.hangingMan, false)
    case .invertedHammer: return (.hangingMan, true)
    case .bullishEngulfing: return (.engulfing, false)
    case .bearishEngulfing: return (.engulfing, true)
    case .bullishHarami: return (.harami, false)
    case .bearishHarami: return (.harami, true)
    case .bullishHaramiCross: return (.haramiCross, false)
    case .bearishHaramiCross: return (.haramiCross, true)
    case .piercingLine: return (.piercing, false)
    case .darkCloudCover: return (.piercing, true)
    case .tweezerBottom: return (.tweezer, false)
    case .tweezerTop: return (.tweezer, true)
    case .bullishKicker: return (.kicker, false)
    case .bearishKicker: return (.kicker, true)
    case .morningStar: return (.star, false)
    case .eveningStar: return (.star, true)
    case .morningDojiStar: return (.dojiStar, false)
    case .eveningDojiStar: return (.dojiStar, true)
    case .threeWhiteSoldiers: return (.soldiers, false)
    case .threeBlackCrows: return (.soldiers, true)
    case .threeInsideUp: return (.insideThree, false)
    case .threeInsideDown: return (.insideThree, true)
    case .threeOutsideUp: return (.outsideThree, false)
    case .threeOutsideDown: return (.outsideThree, true)
    case .bullishAbandonedBaby: return (.abandoned, false)
    case .bearishAbandonedBaby: return (.abandoned, true)
    case .risingThreeMethods: return (.risingThree, false)
    case .fallingThreeMethods: return (.risingThree, true)
    }
  }

  /// How many candles the pattern takes.
  public var count: Int {
    switch shape.0 {
    case .bigUp, .marubozu, .doji, .longLegged, .dragonfly, .spinning, .hammer, .hangingMan: return 1
    case .engulfing, .harami, .haramiCross, .piercing, .tweezer, .kicker: return 2
    case .star, .dojiStar, .soldiers, .insideThree, .outsideThree, .abandoned: return 3
    case .risingThree: return 5
    }
  }

  /// The days before it that it needs (in the buyers-win orientation; mirrored for the twin).
  public enum Lead: String, Sendable { case none, down, up }
  var leadUp: Lead {
    switch shape.0 {
    case .hammer, .engulfing, .harami, .haramiCross, .piercing, .tweezer, .star, .dojiStar, .insideThree, .outsideThree, .abandoned: return .down
    case .hangingMan, .risingThree: return .up
    case .bigUp, .marubozu, .doji, .longLegged, .dragonfly, .spinning, .kicker, .soldiers: return .none
    }
  }
  /// The trend that has to come before it ("after a slide" / "after a climb").
  public var lead: Lead {
    let l = leadUp
    guard shape.mirrored else { return l }
    return l == .down ? .up : l == .up ? .down : .none
  }

  /// What the pattern might hint (a clue, not a promise).
  public enum Hint: String, Sendable { case up, down, unsure }
  public var hint: Hint {
    switch self {
    case .doji, .longLeggedDoji, .spinningTop: return .unsure
    case .bigUpCandle, .marubozuUp, .dragonflyDoji, .hammer, .invertedHammer, .bullishEngulfing, .bullishHarami, .bullishHaramiCross,
         .piercingLine, .tweezerBottom, .bullishKicker, .morningStar, .morningDojiStar, .threeWhiteSoldiers, .threeInsideUp,
         .threeOutsideUp, .bullishAbandonedBaby, .risingThreeMethods: return .up
    default: return .down
    }
  }
  /// Who won the tug-of-war on the pattern's last day.
  public var winner: Hint {
    switch shape.0 {
    case .doji, .longLegged, .spinning, .dragonfly: return .unsure
    default: return shape.mirrored ? .down : .up
    }
  }

  /// 1 (first lessons) … 5 (rare and tricky).
  public var difficulty: Int {
    switch self {
    case .bigUpCandle, .bigDownCandle, .doji: return 1
    case .marubozuUp, .marubozuDown, .longLeggedDoji, .spinningTop, .hammer, .bullishEngulfing, .bearishEngulfing,
         .threeWhiteSoldiers, .threeBlackCrows: return 2
    case .dragonflyDoji, .gravestoneDoji, .hangingMan, .invertedHammer, .shootingStar, .bullishHarami, .bearishHarami,
         .piercingLine, .darkCloudCover, .tweezerBottom, .tweezerTop, .morningStar, .eveningStar: return 3
    case .bullishHaramiCross, .bearishHaramiCross, .bullishKicker, .bearishKicker, .morningDojiStar, .eveningDojiStar,
         .threeInsideUp, .threeInsideDown, .threeOutsideUp, .threeOutsideDown: return 4
    case .bullishAbandonedBaby, .bearishAbandonedBaby, .risingThreeMethods, .fallingThreeMethods: return 5
    }
  }

  public var name: String {
    switch self {
    case .bigUpCandle: return "Big up candle"
    case .bigDownCandle: return "Big down candle"
    case .marubozuUp: return "Up marubozu"
    case .marubozuDown: return "Down marubozu"
    case .doji: return "Doji"
    case .longLeggedDoji: return "Long-legged doji"
    case .dragonflyDoji: return "Dragonfly doji"
    case .gravestoneDoji: return "Gravestone doji"
    case .spinningTop: return "Spinning top"
    case .hammer: return "Hammer"
    case .hangingMan: return "Hanging man"
    case .invertedHammer: return "Upside-down hammer"
    case .shootingStar: return "Shooting star"
    case .bullishEngulfing: return "Up swallow"
    case .bearishEngulfing: return "Down swallow"
    case .bullishHarami: return "Up baby"
    case .bearishHarami: return "Down baby"
    case .bullishHaramiCross: return "Up baby tie"
    case .bearishHaramiCross: return "Down baby tie"
    case .piercingLine: return "Piercing line"
    case .darkCloudCover: return "Dark cloud"
    case .tweezerBottom: return "Tweezer bottom"
    case .tweezerTop: return "Tweezer top"
    case .bullishKicker: return "Up kicker"
    case .bearishKicker: return "Down kicker"
    case .morningStar: return "Morning star"
    case .eveningStar: return "Evening star"
    case .morningDojiStar: return "Morning tie star"
    case .eveningDojiStar: return "Evening tie star"
    case .threeWhiteSoldiers: return "Three marchers up"
    case .threeBlackCrows: return "Three crows"
    case .threeInsideUp: return "Three inside up"
    case .threeInsideDown: return "Three inside down"
    case .threeOutsideUp: return "Three outside up"
    case .threeOutsideDown: return "Three outside down"
    case .bullishAbandonedBaby: return "Lonely baby up"
    case .bearishAbandonedBaby: return "Lonely baby down"
    case .risingThreeMethods: return "Rest then climb"
    case .fallingThreeMethods: return "Rest then slide"
    }
  }
  /// The grown-up name, for the pattern card (engulfing, harami...).
  public var bookName: String {
    switch self {
    case .bullishEngulfing: return "Bullish engulfing"
    case .bearishEngulfing: return "Bearish engulfing"
    case .bullishHarami: return "Bullish harami"
    case .bearishHarami: return "Bearish harami"
    case .bullishHaramiCross: return "Bullish harami cross"
    case .bearishHaramiCross: return "Bearish harami cross"
    case .bullishKicker: return "Bullish kicker"
    case .bearishKicker: return "Bearish kicker"
    case .morningDojiStar: return "Morning doji star"
    case .eveningDojiStar: return "Evening doji star"
    case .threeWhiteSoldiers: return "Three white soldiers"
    case .threeBlackCrows: return "Three black crows"
    case .bullishAbandonedBaby: return "Bullish abandoned baby"
    case .bearishAbandonedBaby: return "Bearish abandoned baby"
    case .risingThreeMethods: return "Rising three methods"
    case .fallingThreeMethods: return "Falling three methods"
    case .invertedHammer: return "Inverted hammer"
    default: return name
    }
  }

  /// What it says, grade 3 words, always "might".
  public var says: String {
    switch self {
    case .bigUpCandle: return "Buyers won the day by a lot."
    case .bigDownCandle: return "Sellers won the day by a lot."
    case .marubozuUp: return "Buyers were in charge from start to end."
    case .marubozuDown: return "Sellers were in charge all day long."
    case .doji: return "A tie. Nobody won the tug-of-war."
    case .longLeggedDoji: return "A big fight that ended in a tie."
    case .dragonflyDoji: return "Sellers pulled down, then buyers pulled all the way back."
    case .gravestoneDoji: return "Buyers pulled up, then sellers pulled all the way back."
    case .spinningTop: return "Lots of back and forth. Nobody is sure."
    case .hammer: return "Sellers pushed down, but buyers fought back."
    case .hangingMan: return "A hammer shape at the top. Buyers might be tired."
    case .invertedHammer: return "Buyers tried to climb. Sellers might be slowing."
    case .shootingStar: return "Buyers jumped up, but sellers knocked it back."
    case .bullishEngulfing: return "The buyers' candle swallowed the sellers' candle."
    case .bearishEngulfing: return "The sellers' candle swallowed the buyers' candle."
    case .bullishHarami: return "A baby candle hides inside a big down day."
    case .bearishHarami: return "A baby candle hides inside a big up day."
    case .bullishHaramiCross: return "A tie hides inside a big down day."
    case .bearishHaramiCross: return "A tie hides inside a big up day."
    case .piercingLine: return "Buyers pushed back past the middle of a big down day."
    case .darkCloudCover: return "Sellers pushed back past the middle of a big up day."
    case .tweezerBottom: return "Two days stopped at the same floor."
    case .tweezerTop: return "Two days bumped the same ceiling."
    case .bullishKicker: return "Buyers jumped in so hard the price leaped over yesterday."
    case .bearishKicker: return "Sellers jumped in so hard the price fell below yesterday."
    case .morningStar: return "Down day, tiny pause, then a strong up day."
    case .eveningStar: return "Up day, tiny pause, then a strong down day."
    case .morningDojiStar: return "Like a morning star, with a perfect tie in the middle."
    case .eveningDojiStar: return "Like an evening star, with a perfect tie in the middle."
    case .threeWhiteSoldiers: return "Three strong up days in a row. Buyers are marching."
    case .threeBlackCrows: return "Three strong down days in a row. Sellers are marching."
    case .threeInsideUp: return "A baby inside a big down day, then buyers finish the job."
    case .threeInsideDown: return "A baby inside a big up day, then sellers finish the job."
    case .threeOutsideUp: return "An up swallow, then one more up day."
    case .threeOutsideDown: return "A down swallow, then one more down day."
    case .bullishAbandonedBaby: return "A lonely tie left alone below two gaps."
    case .bearishAbandonedBaby: return "A lonely tie left alone above two gaps."
    case .risingThreeMethods: return "Buyers took a short rest, then kept climbing."
    case .fallingThreeMethods: return "Sellers took a short rest, then kept pushing down."
    }
  }
  /// The one rule to look for, for hints ("Look for...").
  public var lookFor: String {
    switch shape.0 {
    case .bigUp: return "a long body with short wicks"
    case .marubozu: return "a body with no wicks at all"
    case .doji: return "a flat line for a body, wicks both ways"
    case .longLegged: return "a flat body with very long wicks both ways"
    case .dragonfly: return shape.mirrored ? "a flat body at the bottom, one long wick up" : "a flat body at the top, one long wick down"
    case .spinning: return "a small body in the middle, wicks both ways"
    case .hammer: return shape.mirrored ? "a long wick up after a climb" : "a long wick down after a slide"
    case .hangingMan: return shape.mirrored ? "a long wick up after a slide" : "a long wick down after a climb"
    case .engulfing: return "a big candle that covers all of yesterday's body"
    case .harami: return "a small body inside yesterday's big body"
    case .haramiCross: return "a tie inside yesterday's big body"
    case .piercing: return "a candle that gets past the middle of yesterday"
    case .tweezer: return shape.mirrored ? "two highs at the very same price" : "two lows at the very same price"
    case .kicker: return "a jump with a gap between two strong days"
    case .star, .dojiStar: return "big day, tiny day, big day the other way"
    case .soldiers: return "three strong candles in a row, the same way"
    case .insideThree: return "a baby inside, then a strong third day"
    case .outsideThree: return "a swallow, then one more day the same way"
    case .abandoned: return "a tiny tie with gaps on both sides"
    case .risingThree: return "a big day, three small rest days, a big day"
    }
  }

  /// The pattern most often mixed up with this one (for odd-one-out and near answers).
  public var lookalike: CandlePattern {
    switch self {
    case .bigUpCandle: return .marubozuUp
    case .bigDownCandle: return .marubozuDown
    case .marubozuUp: return .bigUpCandle
    case .marubozuDown: return .bigDownCandle
    case .doji: return .spinningTop
    case .longLeggedDoji: return .doji
    case .dragonflyDoji: return .hammer
    case .gravestoneDoji: return .shootingStar
    case .spinningTop: return .doji
    case .hammer: return .hangingMan
    case .hangingMan: return .hammer
    case .invertedHammer: return .shootingStar
    case .shootingStar: return .invertedHammer
    case .bullishEngulfing: return .piercingLine
    case .bearishEngulfing: return .darkCloudCover
    case .bullishHarami: return .bullishEngulfing
    case .bearishHarami: return .bearishEngulfing
    case .bullishHaramiCross: return .bullishHarami
    case .bearishHaramiCross: return .bearishHarami
    case .piercingLine: return .bullishEngulfing
    case .darkCloudCover: return .bearishEngulfing
    case .tweezerBottom: return .piercingLine
    case .tweezerTop: return .darkCloudCover
    case .bullishKicker: return .bullishEngulfing
    case .bearishKicker: return .bearishEngulfing
    case .morningStar: return .morningDojiStar
    case .eveningStar: return .eveningDojiStar
    case .morningDojiStar: return .morningStar
    case .eveningDojiStar: return .eveningStar
    case .threeWhiteSoldiers: return .threeOutsideUp
    case .threeBlackCrows: return .threeOutsideDown
    case .threeInsideUp: return .threeOutsideUp
    case .threeInsideDown: return .threeOutsideDown
    case .threeOutsideUp: return .threeInsideUp
    case .threeOutsideDown: return .threeInsideDown
    case .bullishAbandonedBaby: return .morningDojiStar
    case .bearishAbandonedBaby: return .eveningDojiStar
    case .risingThreeMethods: return .threeWhiteSoldiers
    case .fallingThreeMethods: return .threeBlackCrows
    }
  }

  /// The sellers' (or buyers') twin: the same shape upside down.
  public var twin: CandlePattern {
    let s = shape
    return CandlePattern.allCases.first { $0 != self && $0.shape.0 == s.0 && $0.shape.mirrored != s.mirrored } ?? self
  }
}

/// A practice chart with one pattern in it.
public struct PatternChart: Equatable, Sendable {
  public let pattern: CandlePattern
  public let candles: [Candle]
  /// Index of the pattern's first candle.
  public let start: Int
  public var end: Int { start + pattern.count - 1 }
  public var range: ClosedRange<Int> { start...end }
  /// Did the days after go the way the pattern hinted? (Only sometimes: a clue, not a promise.)
  public let followed: Bool?
  public let after: Int
}

public enum CandleLab {
  // MARK: measuring

  struct M {
    let o, h, l, c: Double
    init(_ k: Candle) { o = k.o; h = k.h; l = k.l; c = k.c }
    var R: Double { h - l }
    var B: Double { abs(c - o) }
    var top: Double { max(o, c) }
    var bot: Double { min(o, c) }
    var US: Double { h - top }
    var LS: Double { bot - l }
    var mid: Double { (o + c) / 2 }
    var bull: Bool { c > o }
    var bear: Bool { c < o }
  }

  /// Mean range and body of (up to) the 10 days before `s`.
  static func averages(_ cs: [Candle], before s: Int) -> (r: Double, b: Double) {
    let from = max(0, s - 10)
    guard s > from else { return (1, 0.5) }
    let w = cs[from..<s].map(M.init)
    return (w.map(\.R).reduce(0, +) / Double(w.count), w.map(\.B).reduce(0, +) / Double(w.count))
  }

  /// The slide or climb before `s` (the spec's rule): the close 1 day before is at least 1.5 average
  /// ranges past the close 6 days before, and 3 of the last 5 days went that way.
  public static func lead(_ cs: [Candle], before s: Int) -> CandlePattern.Lead {
    guard s >= 6 else { return .none }
    let a = averages(cs, before: s).r
    let last5 = cs[(s - 5)..<s].map(M.init)
    if cs[s - 1].c <= cs[s - 6].c - 1.5 * a && last5.filter(\.bear).count >= 3 { return .down }
    if cs[s - 1].c >= cs[s - 6].c + 1.5 * a && last5.filter(\.bull).count >= 3 { return .up }
    return .none
  }

  static func mirror(_ k: Candle, around p: Double) -> Candle { Candle(d: k.d, o: 2 * p - k.o, h: 2 * p - k.l, l: 2 * p - k.h, c: 2 * p - k.c, v: k.v) }

  /// Does `p` sit at `s` (its first candle) in these candles?
  public static func matches(_ p: CandlePattern, in cs: [Candle], at s: Int) -> Bool {
    guard s >= 3, s + p.count <= cs.count else { return false }
    let (shape, mirrored) = p.shape
    let pivot = 1000.0
    let w = mirrored ? cs.map { mirror($0, around: pivot) } : cs
    return check(shape, w, s)
  }

  /// Every place `p` shows up.
  public static func find(_ p: CandlePattern, in cs: [Candle]) -> [Int] { cs.indices.filter { matches(p, in: cs, at: $0) } }

  static func long(_ k: M, _ a: Double) -> Bool { k.B >= 0.6 * k.R && k.R >= 1.2 * a }
  static func isDoji(_ k: M) -> Bool { k.R > 0 && k.B <= 0.05 * k.R }

  static func check(_ shape: CandlePattern.Shape, _ cs: [Candle], _ s: Int) -> Bool {
    let (a, ab) = averages(cs, before: s)
    let ld = lead(cs, before: s)
    let k = (s..<min(cs.count, s + 5)).map { M(cs[$0]) }
    let c1 = k[0]
    guard c1.R > 0 else { return false }
    switch shape {
    case .bigUp:
      return c1.bull && c1.B >= 0.7 * c1.R && c1.R >= 1.3 * a && c1.US + c1.LS >= 0.05 * c1.R
    case .marubozu:
      return c1.bull && c1.B >= 0.95 * c1.R && c1.R >= 1.3 * a
    case .doji:
      return isDoji(c1) && c1.US >= 0.15 * c1.R && c1.LS >= 0.15 * c1.R && c1.R < 1.5 * a
    case .longLegged:
      return isDoji(c1) && c1.US >= 0.35 * c1.R && c1.LS >= 0.35 * c1.R && c1.R >= 1.5 * a
    case .dragonfly:
      return isDoji(c1) && c1.US <= 0.05 * c1.R && c1.LS >= 0.85 * c1.R
    case .spinning:
      return c1.B >= 0.1 * c1.R && c1.B <= 0.3 * c1.R && c1.US >= 0.3 * c1.R && c1.LS >= 0.3 * c1.R
    case .hammer, .hangingMan:
      let shapeOK = c1.B >= 0.1 * c1.R && c1.B <= 0.3 * c1.R && c1.LS >= 2 * c1.B && c1.LS >= 0.6 * c1.R && c1.US <= 0.1 * c1.R
      return shapeOK && ld == (shape == .hammer ? .down : .up)
    case .engulfing:
      let c2 = k[1]
      return ld == .down && engulf(c1, c2)
    case .harami:
      let c2 = k[1]
      return ld == .down && harami(c1, c2, a) && c2.B > 0.05 * c2.R
    case .haramiCross:
      let c2 = k[1]
      return ld == .down && harami(c1, c2, a) && isDoji(c2)
    case .piercing:
      let c2 = k[1]
      return ld == .down && c1.bear && long(c1, a) && c2.bull && c2.o < c1.c && c2.c > c1.c + 0.5 * c1.B && c2.c < c1.o
    case .tweezer:
      let c2 = k[1]
      return ld == .down && abs(c1.l - c2.l) <= 0.05 * a && c1.bear && c2.bull && c1.R >= 0.8 * a && c2.R >= 0.8 * a
    case .kicker:
      let c2 = k[1]
      return c1.bear && c1.B >= 0.8 * c1.R && c2.bull && c2.B >= 0.8 * c2.R && c2.l >= c1.o
    case .star, .dojiStar, .abandoned:
      let c2 = k[1], c3 = k[2]
      let base = ld == .down && c1.bear && long(c1, a) && c2.B <= 0.3 * c1.B && c2.top <= c1.c
        && c3.bull && c3.B >= 0.5 * c3.R && c3.c >= c1.mid
      guard base else { return false }
      switch shape {
      case .star: return c2.B > 0.05 * c2.R && c2.B <= 0.3 * c2.R
      case .dojiStar: return isDoji(c2) && !(c2.h < c1.l && c2.h < c3.l)
      default: return isDoji(c2) && c2.h < c1.l && c2.h < c3.l
      }
    case .soldiers:
      guard k.count >= 3 else { return false }
      let t = Array(k.prefix(3))
      for (i, x) in t.enumerated() {
        guard x.bull, x.B >= 0.6 * x.R, x.US <= 0.2 * x.R, x.B >= 0.8 * ab else { return false }
        if i > 0 { let p = t[i - 1]; guard x.c > p.c, x.o >= p.bot, x.o <= p.top else { return false } }
      }
      return true
    case .insideThree:
      let c2 = k[1], c3 = k[2]
      return ld == .down && harami(c1, c2, a) && c2.B > 0.05 * c2.R && c3.bull && c3.c > c1.o
    case .outsideThree:
      let c2 = k[1], c3 = k[2]
      return ld == .down && engulf(c1, c2) && c3.bull && c3.c > c2.c
    case .risingThree:
      guard k.count >= 5 else { return false }
      let rest = k[1...3], c5 = k[4]
      return ld == .up && c1.bull && long(c1, a)
        && rest.allSatisfy { $0.B <= 0.5 * c1.B && $0.h <= c1.h && $0.l >= c1.l }
        && rest.filter(\.bear).count >= 2 && k[3].c < k[1].c
        && c5.bull && long(c5, a) && c5.c > c1.c
    }
  }
  static func engulf(_ c1: M, _ c2: M) -> Bool {
    c1.bear && c1.B >= 0.1 * c1.R && c2.bull && c2.o <= c1.c && c2.c >= c1.o && c2.B >= 1.1 * c1.B
  }
  static func harami(_ c1: M, _ c2: M, _ a: Double) -> Bool {
    c1.bear && long(c1, a) && c2.o >= c1.c && c2.c <= c1.o && c2.bot >= c1.c && c2.top <= c1.o && c2.B <= 0.5 * c1.B
  }

  // MARK: making

  /// A practice chart: `lead` days that set the scene, the pattern, then `after` days. `follow` forces the
  /// days after to go (or not go) the hinted way; nil rolls it (about 60% go the hinted way).
  public static func make(_ p: CandlePattern, seed: Int, lead leadDays: Int = 8, after: Int = 0, follow: Bool? = nil) -> PatternChart {
    for salt in 0..<24 {
      let chart = build(p, seed: seed &+ salt &* 7_919, leadDays: max(6, leadDays), after: after, follow: follow)
      // The pattern has to be there, and nowhere else (so "find it" has one answer).
      if find(p, in: chart.candles) == [chart.start] { return chart }
    }
    return build(p, seed: seed, leadDays: max(6, leadDays), after: after, follow: follow)
  }

  struct Gen {
    var g: Seeded
    mutating func u(_ a: Double, _ b: Double) -> Double { Double.random(in: a...b, using: &g) }
    mutating func coin() -> Bool { Bool.random(using: &g) }
  }

  static func candle(o: Double, c: Double, us: Double, ls: Double, v: Double = 60) -> Candle {
    Candle(d: "", o: o, h: max(o, c) + max(0, us), l: min(o, c) - max(0, ls), c: c, v: v)
  }

  static func build(_ p: CandlePattern, seed: Int, leadDays: Int, after: Int, follow: Bool?) -> PatternChart {
    var r = Gen(g: Seeded(seed))
    let (shape, mirrored) = p.shape
    let pivot = 100.0
    // Lead-in, drawn the buyers-win way up; the whole chart flips afterwards for the sellers' twin.
    var cs: [Candle] = []
    var price = 100.0
    let dir: Double = { switch p.leadUp { case .down: return -1; case .up: return 1; case .none: return 0 } }()
    let unit = 4.0
    for i in 0..<leadDays {
      let counter = dir != 0 && i == leadDays - 5
      let d: Double
      if dir == 0 { d = (r.coin() ? 1 : -1) * unit * r.u(0.25, 0.5) }
      else if counter { d = -dir * unit * r.u(0.15, 0.25) }
      else { d = dir * unit * r.u(0.6, 0.9) }
      let o = price + r.u(-0.15, 0.15)
      let c = o + d
      let body = abs(d)
      let R = body / r.u(0.62, 0.82)
      let up = r.u(0.3, 0.7) * (R - body)
      cs.append(candle(o: o, c: c, us: up, ls: R - body - up, v: r.u(40, 70)))
      price = c
    }
    let s = cs.count
    let (a, ab) = averages(cs, before: s)
    let last = cs[s - 1]
    let p0 = last.c
    var pat: [Candle] = []
    func add(_ o: Double, _ c: Double, us: Double, ls: Double) { pat.append(candle(o: o, c: c, us: us, ls: ls, v: r.u(70, 110))) }

    switch shape {
    case .bigUp:
      let R = a * r.u(1.6, 2.0), B = R * r.u(0.76, 0.86), us = (R - B) * r.u(0.3, 0.7)
      add(p0, p0 + B, us: us, ls: R - B - us)
    case .marubozu:
      let R = a * r.u(1.6, 2.0), B = R * 0.98
      add(p0, p0 + B, us: R * 0.01, ls: R * 0.01)
    case .doji:
      let R = a * r.u(0.8, 1.1), B = R * r.u(0, 0.02), us = (R - B) * r.u(0.38, 0.62)
      add(p0, p0 + (r.coin() ? B : -B), us: us, ls: R - B - us)
    case .longLegged:
      let R = a * r.u(2.0, 2.5), B = R * r.u(0, 0.02), us = (R - B) * r.u(0.44, 0.56)
      add(p0, p0 + (r.coin() ? B : -B), us: us, ls: R - B - us)
    case .dragonfly:
      let R = a * r.u(1.0, 1.4)
      let o = p0 + R * 0.4
      add(o, o + R * 0.01, us: R * 0.01, ls: R * 0.98)
    case .spinning:
      let R = a * r.u(0.8, 1.2), B = R * r.u(0.18, 0.22), us = (R - B) * r.u(0.45, 0.55)
      add(p0, p0 + (r.coin() ? B : -B), us: us, ls: R - B - us)
    case .hammer, .hangingMan:
      let R = a * r.u(1.0, 1.4), B = R * r.u(0.17, 0.23), us = R * r.u(0, 0.04)
      let top = shape == .hammer ? p0 + B * 0.5 : p0 + R * 0.4 + B
      let upDay = r.coin()
      add(upDay ? top - B : top, upDay ? top : top - B, us: us, ls: R - B - us)
    case .engulfing:
      let R1 = a * r.u(0.8, 1.0), B1 = R1 * 0.6
      let o1 = p0, c1 = o1 - B1
      add(o1, c1, us: (R1 - B1) / 2, ls: (R1 - B1) / 2)
      let o2 = c1 - B1 * r.u(0.02, 0.1), c2 = o1 + B1 * r.u(0.2, 0.35)
      add(o2, c2, us: B1 * 0.08, ls: B1 * 0.08)
    case .harami, .haramiCross, .insideThree:
      let R1 = a * r.u(1.5, 1.8), B1 = R1 * 0.75
      let o1 = p0, c1 = o1 - B1
      add(o1, c1, us: (R1 - B1) / 2, ls: (R1 - B1) / 2)
      if shape == .haramiCross {
        let o2 = c1 + B1 * 0.5, R2 = a * r.u(0.6, 0.8)
        add(o2, o2 + R2 * 0.01, us: R2 * 0.49, ls: R2 * 0.49)
      } else {
        let B2 = B1 * r.u(0.25, 0.35), o2 = c1 + B1 * r.u(0.2, 0.35), R2 = B2 / r.u(0.55, 0.7)
        add(o2, o2 + B2, us: (R2 - B2) / 2, ls: (R2 - B2) / 2)
      }
      if shape == .insideThree {
        let o3 = pat[1].c, c3 = o1 + B1 * r.u(0.15, 0.3), B3 = c3 - o3
        add(o3, c3, us: B3 * 0.1, ls: B3 * 0.1)
      }
    case .piercing:
      let R1 = a * r.u(1.5, 1.8), B1 = R1 * 0.75
      let o1 = p0, c1 = o1 - B1
      add(o1, c1, us: (R1 - B1) / 2, ls: (R1 - B1) / 2)
      let o2 = c1 - B1 * r.u(0.08, 0.2), c2 = c1 + B1 * r.u(0.62, 0.85)
      add(o2, c2, us: B1 * 0.05, ls: B1 * 0.05)
    case .tweezer:
      let R1 = a * r.u(1.0, 1.2), B1 = R1 * 0.5
      let o1 = p0, c1 = o1 - B1, low = c1 - (R1 - B1) * 0.6
      add(o1, c1, us: (R1 - B1) * 0.4, ls: c1 - low)
      let R2 = a * r.u(1.0, 1.2), B2 = R2 * 0.5, low2 = low + a * r.u(0, 0.02)
      let o2 = low2 + (R2 - B2) * 0.6
      add(o2, o2 + B2, us: (R2 - B2) * 0.4, ls: o2 - low2)
    case .kicker:
      let R1 = a * r.u(1.0, 1.3), B1 = R1 * 0.9
      let o1 = p0, c1 = o1 - B1
      add(o1, c1, us: (R1 - B1) / 2, ls: (R1 - B1) / 2)
      let R2 = a * r.u(1.0, 1.3), B2 = R2 * 0.9
      let low2 = o1 + a * r.u(0.15, 0.3), o2 = low2 + (R2 - B2) / 2
      add(o2, o2 + B2, us: (R2 - B2) / 2, ls: (R2 - B2) / 2)
    case .star, .dojiStar, .abandoned:
      let R1 = a * r.u(1.5, 1.8), B1 = R1 * 0.75
      let o1 = p0, c1 = o1 - B1
      add(o1, c1, us: (R1 - B1) / 2, ls: (R1 - B1) / 2)
      let low1 = c1 - (R1 - B1) / 2
      switch shape {
      case .star:
        let B2 = B1 * r.u(0.15, 0.22), R2 = B2 / r.u(0.2, 0.26)
        let top2 = c1 - B1 * r.u(0.05, 0.15)
        add(top2, top2 - B2, us: (R2 - B2) / 2, ls: (R2 - B2) / 2)
      case .dojiStar:
        let R2 = a * r.u(0.5, 0.7), o2 = c1 - B1 * r.u(0.05, 0.12)
        // The tie's top wick reaches above the first day's low, so it isn't left alone (that's the lonely baby).
        add(o2, o2 - R2 * 0.01, us: max(R2 * 0.5, o2 - low1 + a * 0.1), ls: R2 * 0.49)
      default:
        let R2 = a * r.u(0.5, 0.7), h2 = low1 - a * r.u(0.3, 0.5)
        let o2 = h2 - R2 * 0.49
        add(o2, o2 - R2 * 0.01, us: R2 * 0.49, ls: R2 * 0.5)
      }
      let gapLow = shape == .abandoned ? pat[1].h + a * r.u(0.3, 0.5) : pat[1].bodyTop + a * 0.05
      let c3 = (o1 + c1) / 2 + B1 * r.u(0.12, 0.28)
      let o3 = shape == .abandoned ? gapLow + a * 0.05 : max(pat[1].bodyTop, gapLow)
      let B3 = c3 - o3, R3 = B3 / r.u(0.68, 0.8)
      let ls3 = shape == .abandoned ? min((R3 - B3) / 2, o3 - gapLow) : (R3 - B3) / 2
      add(o3, c3, us: R3 - B3 - ls3, ls: ls3)
    case .soldiers:
      var o = p0
      var prevB = 0.0
      for i in 0..<3 {
        let B = max(ab * r.u(1.1, 1.3), a * 0.6), R = B / r.u(0.75, 0.82)
        if i > 0 { o = pat[i - 1].c - prevB * r.u(0.2, 0.4) }
        add(o, o + B, us: (R - B) * 0.25, ls: (R - B) * 0.75)
        prevB = B
      }
    case .outsideThree:
      let R1 = a * r.u(0.8, 1.0), B1 = R1 * 0.6
      let o1 = p0, c1 = o1 - B1
      add(o1, c1, us: (R1 - B1) / 2, ls: (R1 - B1) / 2)
      let o2 = c1 - B1 * r.u(0.02, 0.1), c2 = o1 + B1 * r.u(0.2, 0.35)
      add(o2, c2, us: B1 * 0.08, ls: B1 * 0.08)
      let o3 = c2 - B1 * 0.1, c3 = c2 + B1 * r.u(0.4, 0.7)
      add(o3, c3, us: B1 * 0.08, ls: B1 * 0.08)
    case .risingThree:
      let R1 = a * r.u(1.7, 1.9), B1 = R1 * 0.8
      let o1 = p0, c1 = o1 + B1
      add(o1, c1, us: (R1 - B1) / 2, ls: (R1 - B1) / 2)
      let o2 = c1 - B1 * 0.05, c2 = o2 - B1 * 0.22
      add(o2, c2, us: B1 * 0.04, ls: B1 * 0.04)
      let o3 = c2 - B1 * 0.02, c3 = o3 - B1 * 0.2
      add(o3, c3, us: B1 * 0.04, ls: B1 * 0.04)
      let o4 = c3 - B1 * 0.02, c4 = o4 + B1 * 0.1
      add(o4, c4, us: B1 * 0.04, ls: B1 * 0.04)
      let o5 = c4, c5 = c1 + B1 * r.u(0.45, 0.6), B5 = c5 - o5, R5 = B5 / 0.85
      add(o5, c5, us: (R5 - B5) / 2, ls: (R5 - B5) / 2)
    }
    cs += pat
    // The days after: a clue, not a promise.
    let hinted: Double = p.hint == .up ? 1 : p.hint == .down ? -1 : 0
    let went: Bool? = after > 0 ? (follow ?? (r.u(0, 1) < 0.6)) : nil
    if after > 0 {
      // Drawn in the buyers-win frame, so "up" here is the hint's way before any flip.
      let frameHint = mirrored ? -hinted : hinted
      let way = frameHint == 0 ? (r.coin() ? 1.0 : -1.0) : (went == true ? frameHint : -frameHint)
      var px = cs[cs.count - 1].c
      for i in 0..<after {
        let d = way * a * r.u(0.35, 0.7) * (i == 1 ? -0.3 : 1)
        let o = px + r.u(-0.1, 0.1), c = o + d, body = abs(d), R = body / r.u(0.55, 0.75)
        let us = (R - body) * r.u(0.3, 0.7)
        cs.append(candle(o: o, c: c, us: us, ls: R - body - us, v: r.u(40, 80)))
        px = c
      }
    }
    if mirrored { cs = cs.map { mirror($0, around: pivot) } }
    cs = cs.enumerated().map { i, k in Candle(d: "p\(i)", o: k.o, h: k.h, l: k.l, c: k.c, v: k.v) }
    return PatternChart(pattern: p, candles: cs, start: s, followed: hinted == 0 ? nil : went, after: after)
  }

  /// Plain days for a busy chart (spot-it): small trends that never form a named pattern by themselves.
  public static func filler(seed: Int, n: Int, from start: Double = 100) -> [Candle] {
    var r = Gen(g: Seeded(seed))
    var px = start, out: [Candle] = []
    var dir = r.coin() ? 1.0 : -1.0
    for i in 0..<n {
      if i % 4 == 0 && r.coin() { dir = -dir }
      let d = dir * 4 * r.u(0.3, 0.55) * (r.u(0, 1) < 0.2 ? -0.6 : 1)
      let o = px + r.u(-0.1, 0.1), c = o + d, body = abs(d), R = body / r.u(0.45, 0.6), us = (R - body) * r.u(0.35, 0.65)
      out.append(candle(o: o, c: c, us: us, ls: R - body - us, v: r.u(40, 80)))
      px = c
    }
    return out
  }

  /// A longer chart with the pattern hidden somewhere in the middle, for "spot it". The answer is the only
  /// place the pattern shows up.
  public static func hide(_ p: CandlePattern, seed: Int, days: Int) -> PatternChart {
    for salt in 0..<30 {
      let core = make(p, seed: seed &+ salt &* 31, lead: 8, after: 2, follow: true)
      let before = max(0, (days - core.candles.count) * 2 / 3)
      let afterN = max(0, days - core.candles.count - before)
      var head = filler(seed: seed &+ salt, n: before, from: core.candles[0].o)
      // Join: the head ends where the core starts.
      if let lastHead = head.last { let shift = core.candles[0].o - lastHead.c; head = head.map { Candle(d: "", o: $0.o + shift, h: $0.h + shift, l: $0.l + shift, c: $0.c + shift, v: $0.v) } }
      let tail = filler(seed: seed &+ salt &+ 77, n: afterN, from: core.candles.last?.c ?? 100)
      let all = (head + core.candles + tail).enumerated().map { i, k in Candle(d: "p\(i)", o: k.o, h: k.h, l: k.l, c: k.c, v: k.v) }
      let s = head.count + core.start
      if find(p, in: all) == [s] { return PatternChart(pattern: p, candles: all, start: s, followed: core.followed, after: core.after) }
    }
    return make(p, seed: seed, lead: 8)
  }
}

// MARK: - Building one candle (Build it / Fix the candle)

/// One candle on a whole-number $0…$12 grid, built with four handles.
public struct GridCandle: Hashable, Sendable {
  public var o: Int, h: Int, l: Int, c: Int
  public init(o: Int, h: Int, l: Int, c: Int) { self.o = o; self.h = h; self.l = l; self.c = c }
  public var valid: Bool { h >= max(o, c) && l <= min(o, c) && h > l && (0...12).contains(l) && (0...12).contains(h) }
  public var candle: Candle { Candle(d: "", o: Double(o), h: Double(h), l: Double(l), c: Double(c)) }
}

extension CandleLab {
  /// Patterns you can build from one candle. (Hammer and hanging man share a shape, and so do the
  /// upside-down hammer and the shooting star: the days before name them.)
  public static let buildable: [CandlePattern] = [.bigUpCandle, .bigDownCandle, .marubozuUp, .marubozuDown, .doji, .longLeggedDoji,
                                                  .dragonflyDoji, .gravestoneDoji, .spinningTop, .hammer, .hangingMan, .invertedHammer, .shootingStar]

  /// The shape rule alone (no days before, no averages), for a candle a kid built.
  public static func shapeOK(_ p: CandlePattern, _ g: GridCandle) -> Bool {
    guard g.valid else { return false }
    let k = M(g.candle)
    let R = k.R
    switch p.shape.0 {
    case .bigUp: return (p.shape.mirrored ? k.bear : k.bull) && k.B >= 0.7 * R && k.US + k.LS >= 0.05 * R && R >= 6
    case .marubozu: return (p.shape.mirrored ? k.bear : k.bull) && k.B >= 0.95 * R && R >= 6
    case .doji: return isDoji(k) && k.US >= 0.15 * R && k.LS >= 0.15 * R
    case .longLegged: return isDoji(k) && k.US >= 0.35 * R && k.LS >= 0.35 * R && R >= 8
    case .dragonfly:
      return isDoji(k) && (p.shape.mirrored ? (k.LS <= 0.05 * R && k.US >= 0.85 * R) : (k.US <= 0.05 * R && k.LS >= 0.85 * R))
    case .spinning: return k.B >= 0.1 * R && k.B <= 0.3 * R && k.US >= 0.3 * R && k.LS >= 0.3 * R
    case .hammer, .hangingMan:
      // hammer & hanging man: long wick down; their mirrored twins (shooting star, upside-down hammer): long wick up.
      let wickDown = !p.shape.mirrored
      let long = wickDown ? k.LS : k.US, short = wickDown ? k.US : k.LS
      return k.B >= 0.1 * R && k.B <= 0.3 * R && long >= 2 * k.B && long >= 0.6 * R && short <= 0.1 * R
    default: return false
    }
  }

  /// One right answer for each buildable shape.
  public static func template(_ p: CandlePattern) -> GridCandle? {
    switch p {
    case .bigUpCandle: return GridCandle(o: 3, h: 11, l: 2, c: 10)
    case .bigDownCandle: return GridCandle(o: 10, h: 11, l: 2, c: 3)
    case .marubozuUp: return GridCandle(o: 2, h: 10, l: 2, c: 10)
    case .marubozuDown: return GridCandle(o: 10, h: 10, l: 2, c: 2)
    case .doji: return GridCandle(o: 6, h: 10, l: 2, c: 6)
    case .longLeggedDoji: return GridCandle(o: 6, h: 12, l: 0, c: 6)
    case .dragonflyDoji: return GridCandle(o: 10, h: 10, l: 2, c: 10)
    case .gravestoneDoji: return GridCandle(o: 2, h: 10, l: 2, c: 2)
    case .spinningTop: return GridCandle(o: 6, h: 10, l: 3, c: 7)
    case .hammer, .hangingMan: return GridCandle(o: 9, h: 10, l: 2, c: 10)
    case .invertedHammer, .shootingStar: return GridCandle(o: 3, h: 10, l: 2, c: 2)
    default: return nil
    }
  }

  /// A candle that's ONE handle away from the shape (Fix the candle). Returns the candle and which handle
  /// (0 start, 1 end, 2 high, 3 low) is wrong.
  public static func nearMiss(_ p: CandlePattern, seed: Int) -> (GridCandle, Int)? {
    guard let t = template(p) else { return nil }
    var g = Seeded(seed)
    let tries = (0..<4).shuffled(using: &g)
    for k in tries {
      for d in [3, -3, 4, -4, 2, -2, 5, -5].shuffled(using: &g) {
        var x = t
        switch k { case 0: x.o += d; case 1: x.c += d; case 2: x.h += d; default: x.l += d }
        guard x.valid, (0...12).contains(x.o), (0...12).contains(x.c), !shapeOK(p, x) else { continue }
        // Moving only the broken handle back must fix it.
        return (x, k)
      }
    }
    return nil
  }

  /// A day's story on the $0…$12 grid (Story to candle): a target and look-alikes that each get one
  /// thing wrong (start and end swapped, a different high, a different low).
  public static func story(seed: Int, choices: Int) -> (target: GridCandle, options: [GridCandle]) {
    var g = Seeded(seed)
    func n(_ r: ClosedRange<Int>) -> Int { Int.random(in: r, using: &g) }
    let up = Bool.random(using: &g)
    let lo = n(1...3), hi = n(9...11)
    let a = n(lo + 1...lo + 2), b = n(hi - 3...hi - 1)
    let t = up ? GridCandle(o: a, h: hi, l: lo, c: b) : GridCandle(o: b, h: hi, l: lo, c: a)
    var opts: [GridCandle] = [t, GridCandle(o: t.c, h: t.h, l: t.l, c: t.o)]
    let more = [GridCandle(o: t.o, h: min(12, t.h + 1) == t.h ? t.h - 1 : min(12, max(t.h + 1, max(t.o, t.c))), l: t.l, c: t.c),
                GridCandle(o: t.o, h: t.h, l: max(0, t.l - 1) == t.l ? t.l + 1 : t.l - 1, c: t.c),
                GridCandle(o: t.o, h: max(t.o, t.c) + 0 == t.h ? t.h : max(t.o, t.c), l: t.l, c: t.c)]
    for m in more where m.valid && !opts.contains(m) { opts.append(m) }
    opts = Array(opts.prefix(max(2, choices))).shuffled(using: &g)
    return (t, opts)
  }
}
