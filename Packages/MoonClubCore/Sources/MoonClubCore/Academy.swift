// Chart Academy: two climbs of generated levels, the same on every device.
//  • Candle Academy: 15 chapters × 20 levels = 300 levels, 39 candle patterns, 10 kinds of drill.
//  • Line Lab: 11 chapters × 20 levels = 220 levels: trend lines, floors and ceilings, lanes,
//    breakouts, moving averages, volume and liquidity, then the whole picture.
// After the last chapter both keep going as endless mixes.
//
// Built from two research briefs (docs/CHART_ACADEMY.md): a market technician's rules (what each pattern
// and tool is, exactly) and a teacher's design (watch → finish → alone; 60% new / 25% last chapter / 15%
// older; a review level every 5; a mini-boss at 10 and a chapter boss at 20; never punitive).
// Stars live in `KidsState.stars["candle-N"]` / `["lines-N"]` (per-key max in Sync: no new field).
import Foundation

public enum AcademyTrack: String, CaseIterable, Codable, Sendable {
  case candles, lines
  public var title: String { self == .candles ? "Candle Academy" : "Line Lab" }
  public var symbol: String { self == .candles ? "chart.bar.xaxis" : "chart.line.uptrend.xyaxis" }
  public var blurb: String {
    self == .candles ? "39 candle patterns, one clue at a time." : "Draw trend lines, floors, lanes and averages."
  }
  var prefix: String { self == .candles ? "candle-" : "lines-" }
  public var chapters: [AcademyChapter] { self == .candles ? Academy.candleChapters : Academy.lineChapters }
  public var mainLevels: Int { chapters.count * Academy.chapterSize }
}

/// Kinds of round.
public enum Drill: String, CaseIterable, Codable, Sendable {
  // candles
  case tug, parts, story, build, fix, name, spot, odd, next, catchIt
  // lines
  case trendWay, trendLine, level, lane, breakout, stick, maDot, maSide, maPick, cross, crowd, thin, fill

  public var track: AcademyTrack {
    switch self {
    case .tug, .parts, .story, .build, .fix, .name, .spot, .odd, .next, .catchIt: return .candles
    default: return .lines
    }
  }
  public var title: String {
    switch self {
    case .tug: return "Who won?"
    case .parts: return "Candle parts"
    case .story: return "Story to candle"
    case .build: return "Build it"
    case .fix: return "Fix the candle"
    case .name: return "Name it"
    case .spot: return "Spot it"
    case .odd: return "Odd one out"
    case .next: return "What might happen?"
    case .catchIt: return "Catch it"
    case .trendWay: return "Which way?"
    case .trendLine: return "Draw the trend"
    case .level: return "Floor or ceiling"
    case .lane: return "Draw the lane"
    case .breakout: return "Find the breakout"
    case .stick: return "Did it stick?"
    case .maDot: return "Make the average"
    case .maSide: return "Above or below?"
    case .maPick: return "Fast or slow?"
    case .cross: return "Find the cross"
    case .crowd: return "Biggest crowd"
    case .thin: return "Busy or quiet?"
    case .fill: return "Big order"
    }
  }
  public var how: String {
    switch self {
    case .tug: return "Buyers or sellers: who won the tug-of-war?"
    case .parts: return "Tap the part of the candle that's asked."
    case .story: return "Read the day's story. Tap its candle."
    case .build: return "Drag the handles to build the candle."
    case .fix: return "One handle is wrong. Drag it to fix the candle."
    case .name: return "Look at the glowing days. What's the pattern?"
    case .spot: return "Find the pattern in the chart and tap it."
    case .odd: return "Three match. Tap the one that doesn't."
    case .next: return "Find the clue. What might happen next?"
    case .catchIt: return "Days appear one by one. Tap when you see it!"
    case .trendWay: return "Is the price going up, down or sideways?"
    case .trendLine: return "Drag the two dots to draw the trend line."
    case .level: return "Drag the line to the floor or ceiling."
    case .lane: return "Line up both rails of the lane."
    case .breakout: return "Tap the day the price broke through."
    case .stick: return "It broke through. Did it stay there?"
    case .maDot: return "Drag the dot to the average of the last days."
    case .maSide: return "Is the price above or below its average line?"
    case .maPick: return "Which line is the slow, smooth average?"
    case .cross: return "Tap where the fast line crosses the slow one."
    case .crowd: return "Tap the day with the biggest crowd."
    case .thin: return "Which market is quiet, with a big gap?"
    case .fill: return "Pick up the shares. About what's the average price?"
    }
  }
  public var symbol: String {
    switch self {
    case .tug: return "figure.strengthtraining.functional"
    case .parts: return "hand.point.up.left.fill"
    case .story: return "text.book.closed.fill"
    case .build: return "slider.vertical.3"
    case .fix: return "wrench.adjustable.fill"
    case .name: return "tag.fill"
    case .spot: return "scope"
    case .odd: return "square.grid.2x2.fill"
    case .next: return "questionmark.circle.fill"
    case .catchIt: return "hand.raised.fill"
    case .trendWay: return "arrow.up.right"
    case .trendLine: return "line.diagonal"
    case .level: return "ruler"
    case .lane: return "road.lanes"
    case .breakout: return "arrow.up.to.line"
    case .stick: return "pin.fill"
    case .maDot: return "smallcircle.filled.circle"
    case .maSide: return "arrow.up.arrow.down"
    case .maPick: return "tortoise.fill"
    case .cross: return "xmark"
    case .crowd: return "person.3.fill"
    case .thin: return "drop.fill"
    case .fill: return "cart.fill"
    }
  }
  /// A game everyone knows, so a grown-up can explain it in a word.
  public var classic: String? {
    switch self {
    case .spot: return "Like a hidden-picture puzzle"
    case .odd: return "Like Which one doesn't belong?"
    case .catchIt: return "Like Snap"
    case .tug: return "Like tug-of-war"
    case .build, .fix: return "Like a puzzle"
    case .trendLine, .lane: return "Like connect the dots"
    case .crowd: return "Like spot the tallest"
    default: return nil
    }
  }
}

/// What a line drill is about this round (the generator picks the chart from it).
public enum LineTopic: String, CaseIterable, Codable, Sendable { case upTrend, downTrend, sideways, floor, ceiling, upLane, downLane, ma5, ma10, ma20 }

public struct AcademyChapter: Hashable, Sendable {
  public let name: String
  public let symbol: String
  public let line: String
  public let drills: [Drill]
  /// The patterns met in this chapter (candles).
  public let patterns: [CandlePattern]
}

public enum LevelKind: String, Sendable { case learn, practice, review, miniBoss, boss, endless }

public struct AcademyRound: Hashable, Sendable {
  public let drill: Drill
  /// The pattern this round is about (candles) — and its twin/look-alike for choices.
  public let pattern: CandlePattern
  public let seed: Int
}

public struct AcademyLevel: Identifiable, Hashable, Sendable {
  public let track: AcademyTrack
  public let number: Int
  public let chapter: Int        // 0-based; endless = chapters.count
  public let kind: LevelKind
  /// 0 (first steps) … 5 (sharpest). Dials chart length, choices, tolerances and look-alikes.
  public let tier: Int
  public let rounds: [AcademyRound]
  public let hearts: Int
  public let choices: Int
  /// 2 = worked example (the answer glows, just tap it) · 1 = the hint shows on its own · 0 = on your own.
  public let scaffold: Int
  public let seed: Int

  public var id: String { track.prefix + "\(number)" }
  public var isBoss: Bool { kind == .boss || kind == .miniBoss }
  public var drills: [Drill] { Array(Set(rounds.map(\.drill))).sorted { $0.rawValue < $1.rawValue } }
  public var lead: Drill { rounds.first?.drill ?? .name }
  public var mixed: Bool { Set(rounds.map(\.drill)).count > 1 }
  public var chapterInfo: AcademyChapter? { track.chapters.indices.contains(chapter) ? track.chapters[chapter] : nil }
  /// Chart length for this level's charts.
  public var days: Int { [18, 22, 26, 30, 36, 42][tier] }
  /// Line Lab drag tolerance (share of the visible span) and magnet radius.
  public var tolerance: Double { LineLab.tolerance(tier) }
  public var snap: Double { LineLab.snapRadius(tier) }
  /// New patterns this level teaches (shown on its card).
  public var teaches: [CandlePattern] {
    guard kind == .learn, let c = chapterInfo else { return [] }
    return c.patterns
  }
}

public enum Academy {
  public static let chapterSize = 20

  public static let candleChapters: [AcademyChapter] = [
    AcademyChapter(name: "Rope Town", symbol: "figure.strengthtraining.functional", line: "Every candle is a tug-of-war.",
                   drills: [.tug, .parts, .story, .build], patterns: [.bigUpCandle, .bigDownCandle]),
    AcademyChapter(name: "Wick Woods", symbol: "tree.fill", line: "Wicks show how far each team pulled.",
                   drills: [.parts, .build, .name, .odd], patterns: [.marubozuUp, .marubozuDown]),
    AcademyChapter(name: "Tie Town", symbol: "equal.circle.fill", line: "Sometimes nobody wins.",
                   drills: [.name, .tug, .build, .odd, .spot], patterns: [.doji, .spinningTop, .longLeggedDoji]),
    AcademyChapter(name: "Hammer Hill", symbol: "hammer.fill", line: "Long wicks after a slide or a climb.",
                   drills: [.name, .spot, .build, .next, .catchIt], patterns: [.hammer, .shootingStar]),
    AcademyChapter(name: "Tail Tunnel", symbol: "arrow.down.to.line", line: "Same shape, different place.",
                   drills: [.name, .odd, .spot, .fix, .next], patterns: [.hangingMan, .invertedHammer, .dragonflyDoji, .gravestoneDoji]),
    AcademyChapter(name: "Swallow Sea", symbol: "water.waves", line: "One day swallows the day before.",
                   drills: [.name, .spot, .next, .catchIt, .odd], patterns: [.bullishEngulfing, .bearishEngulfing]),
    AcademyChapter(name: "Baby Bay", symbol: "circle.circle.fill", line: "A little candle hides in a big one.",
                   drills: [.name, .odd, .spot, .catchIt, .next], patterns: [.bullishHarami, .bearishHarami, .bullishHaramiCross, .bearishHaramiCross]),
    AcademyChapter(name: "Middle Mountain", symbol: "mountain.2.fill", line: "Past the middle of yesterday.",
                   drills: [.name, .spot, .odd, .next, .fix], patterns: [.piercingLine, .darkCloudCover]),
    AcademyChapter(name: "Tweezer Town", symbol: "arrowtriangle.left.and.line.vertical.and.arrowtriangle.right.fill", line: "Same floor twice, and big jumps.",
                   drills: [.name, .spot, .odd, .catchIt, .next], patterns: [.tweezerBottom, .tweezerTop, .bullishKicker, .bearishKicker]),
    AcademyChapter(name: "Star Field", symbol: "sparkles", line: "Big day, tiny day, big day.",
                   drills: [.name, .spot, .catchIt, .next, .odd], patterns: [.morningStar, .eveningStar]),
    AcademyChapter(name: "Tie Stars", symbol: "star.circle.fill", line: "Stars with a tie in the middle.",
                   drills: [.name, .odd, .spot, .catchIt, .next], patterns: [.morningDojiStar, .eveningDojiStar, .bullishAbandonedBaby, .bearishAbandonedBaby]),
    AcademyChapter(name: "Marching Band", symbol: "figure.walk", line: "Three strong days in a row.",
                   drills: [.name, .spot, .catchIt, .next, .odd], patterns: [.threeWhiteSoldiers, .threeBlackCrows]),
    AcademyChapter(name: "Inside Out", symbol: "square.on.square.dashed", line: "A baby or a swallow, then one more day.",
                   drills: [.name, .odd, .spot, .catchIt, .next], patterns: [.threeInsideUp, .threeInsideDown, .threeOutsideUp, .threeOutsideDown]),
    AcademyChapter(name: "Rest Stop", symbol: "cup.and.saucer.fill", line: "A short rest, then the same way again.",
                   drills: [.name, .spot, .catchIt, .next, .odd], patterns: [.risingThreeMethods, .fallingThreeMethods]),
    AcademyChapter(name: "Pattern Detective", symbol: "magnifyingglass", line: "Every pattern, all mixed up.",
                   drills: [.spot, .name, .odd, .next, .catchIt, .fix], patterns: []),
  ]

  public static let lineChapters: [AcademyChapter] = [
    AcademyChapter(name: "Which Way?", symbol: "arrow.up.right", line: "Up, down or sideways.", drills: [.trendWay, .crowd], patterns: []),
    AcademyChapter(name: "Up Lines", symbol: "line.diagonal", line: "Connect the lows of a climb.", drills: [.trendLine, .trendWay], patterns: []),
    AcademyChapter(name: "Down Lines", symbol: "line.diagonal.arrow", line: "Connect the highs of a slide.", drills: [.trendLine, .trendWay], patterns: []),
    AcademyChapter(name: "Floors", symbol: "arrow.down.to.line", line: "Where buyers keep showing up.", drills: [.level, .trendLine], patterns: []),
    AcademyChapter(name: "Ceilings", symbol: "arrow.up.to.line", line: "Where sellers keep showing up.", drills: [.level, .trendWay], patterns: []),
    AcademyChapter(name: "Lanes", symbol: "road.lanes", line: "Two rails the price rides between.", drills: [.lane, .trendLine, .level], patterns: []),
    AcademyChapter(name: "Breakouts", symbol: "arrow.up.forward.circle.fill", line: "Through the ceiling. Will it stick?", drills: [.breakout, .stick, .level], patterns: []),
    AcademyChapter(name: "Average River", symbol: "water.waves", line: "The price, smoothed out.", drills: [.maDot, .maSide, .maPick], patterns: []),
    AcademyChapter(name: "Crossings", symbol: "xmark", line: "When the fast line crosses the slow one.", drills: [.cross, .maPick, .maSide, .maDot], patterns: []),
    AcademyChapter(name: "Crowd Market", symbol: "person.3.fill", line: "Volume and how easy it is to trade.", drills: [.crowd, .stick, .thin, .fill], patterns: []),
    AcademyChapter(name: "The Whole Picture", symbol: "eye.fill", line: "Trend, floor, average and crowd together.",
                   drills: [.trendLine, .level, .lane, .breakout, .stick, .cross, .maSide, .thin, .fill], patterns: []),
  ]

  static func mix(_ x: Int) -> Int { Tower.mix(x) }

  public static func id(_ t: AcademyTrack, _ n: Int) -> String { t.prefix + "\(n)" }
  public static func number(_ t: AcademyTrack, _ id: String) -> Int? { id.hasPrefix(t.prefix) ? Int(id.dropFirst(t.prefix.count)) : nil }

  /// Patterns met by the end of chapter c.
  static func met(_ c: Int) -> [CandlePattern] { candleChapters.prefix(c + 1).flatMap(\.patterns) }

  public static func level(_ t: AcademyTrack, _ n: Int) -> AcademyLevel {
    let n = max(1, n)
    let chs = t.chapters
    let ch = min((n - 1) / chapterSize, chs.count)            // == count: endless
    let k = (n - 1) % chapterSize + 1                          // 1…20
    let endless = ch >= chs.count
    let kind: LevelKind = endless ? (n % 10 == 0 ? .boss : .endless)
      : k == 20 ? .boss : k == 10 ? .miniBoss : k <= 3 ? .learn : k % 5 == 0 ? .review : .practice
    let tier = endless ? 5 : min(5, ch * 6 / chs.count + (k >= 14 ? 1 : 0))
    let seed = mix(n &* 7_919 &+ (t == .candles ? 1 : 2) &* 1_000_003)
    var g = Seeded(seed)
    let chapterIdx = min(ch, chs.count - 1)
    let here = chs[chapterIdx]

    // Which drills this level plays.
    var pool: [Drill]
    switch kind {
    case .learn: pool = [here.drills[0]]
    case .practice: pool = [here.drills[(k - 4 + chapterIdx + (k > 10 ? 1 : 0)) % here.drills.count]]
    case .review:
      let older = chs.prefix(max(1, chapterIdx)).flatMap(\.drills)
      pool = Array(Set(older + [here.drills[0]])).sorted { $0.rawValue < $1.rawValue }
    case .miniBoss: pool = here.drills
    case .boss, .endless: pool = Array(Set(chs.prefix(chapterIdx + 1).flatMap(\.drills))).sorted { $0.rawValue < $1.rawValue }
    }
    // Line chapter 0 has no "draw" yet; Candle chapter 0's build is a story build.
    let count = min(12, 4 + tier / 2 + (kind == .boss ? 3 : kind == .miniBoss ? 2 : 0) + (endless ? (n - t.mainLevels) / 60 : 0))
    let shuffled = pool.shuffled(using: &g)
    var rounds: [AcademyRound] = []
    for i in 0..<count {
      let drill = kind == .learn || kind == .practice ? pool[0] : shuffled[i % shuffled.count]
      rounds.append(AcademyRound(drill: drill, pattern: t == .candles ? pickPattern(chapter: chapterIdx, kind: kind, g: &g) : .bigUpCandle, seed: mix(seed &+ i &* 104_729)))
    }
    let scaffold = kind == .learn ? 3 - k : 0      // levels 1, 2, 3 of a chapter: 2, 1, 0
    let hearts = kind == .boss && tier >= 2 ? 2 : 3
    let choices = tier >= 2 ? 4 : 3
    return AcademyLevel(track: t, number: n, chapter: ch, kind: kind, tier: tier, rounds: rounds, hearts: hearts, choices: choices, scaffold: scaffold, seed: seed)
  }

  /// 60% this chapter's patterns, 25% the chapter before, 15% older (the teacher's interleaving).
  static func pickPattern(chapter c: Int, kind: LevelKind, g: inout Seeded) -> CandlePattern {
    let here = candleChapters[c].patterns
    let before = c > 0 ? candleChapters[c - 1].patterns : []
    let older = c > 1 ? met(c - 2) : []
    let all = met(c)
    if here.isEmpty { return all.randomElement(using: &g) ?? .bigUpCandle }
    if kind == .learn { return here.randomElement(using: &g) ?? .bigUpCandle }
    let r = Double.random(in: 0..<1, using: &g)
    if kind == .review, let p = (before + older).randomElement(using: &g) { return p }
    if r < 0.6 || (before.isEmpty && older.isEmpty) { return here.randomElement(using: &g) ?? .bigUpCandle }
    if r < 0.85 || older.isEmpty, let p = before.randomElement(using: &g) { return p }
    return older.randomElement(using: &g) ?? here[0]
  }

  // MARK: progress

  public static func stars(_ t: AcademyTrack, _ n: Int, _ s: KidsState) -> Int { min(3, s.stars?[id(t, n)] ?? 0) }
  public static func open(_ t: AcademyTrack, _ n: Int, _ s: KidsState) -> Bool { n <= 1 || stars(t, n - 1, s) > 0 }
  /// The first level without a star.
  public static func current(_ t: AcademyTrack, _ s: KidsState) -> Int {
    var n = 1
    while (s.stars?[id(t, n)] ?? 0) > 0 { n += 1 }
    return n
  }
  public static func totalStars(_ t: AcademyTrack, _ s: KidsState) -> Int {
    (s.stars ?? [:]).reduce(0) { acc, kv in number(t, kv.key) != nil ? acc + min(3, kv.value) : acc }
  }
  /// How many levels to list: every main level, then the endless ones a chapter past the climber.
  public static func shown(_ t: AcademyTrack, _ s: KidsState) -> Int {
    max(t.mainLevels, ((current(t, s) - 1) / chapterSize + 2) * chapterSize)
  }
  /// Stars for a run: finishing is always a star; 3 in 5 right is two; nearly all right is three.
  public static func starsFor(right: Int, of total: Int) -> Int {
    guard total > 0 else { return 0 }
    let r = Double(right) / Double(total)
    return r >= 0.85 ? 3 : r >= 0.6 ? 2 : 1
  }
  /// The chapter name for a level (or "Endless mix").
  public static func chapterName(_ t: AcademyTrack, _ c: Int) -> String { t.chapters.indices.contains(c) ? t.chapters[c].name : "Endless mix" }
}
