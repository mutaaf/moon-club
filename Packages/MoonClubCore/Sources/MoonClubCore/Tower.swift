// Moon Tower: a climb of 100 levels (then Deep Space, which never ends). Every level is generated from its
// number, the same on every device: which game, how many rounds, how many hearts, how many choices, and a
// twist now and then. Every 10th level is a floor boss that mixes every game you've met. Difficulty climbs
// with the zone (20 levels each) and a little within each floor. Stars live in `KidsState.stars` under
// "tower-<n>" (synced as a per-key max, like the map), so nothing new needs a merge rule.
import Foundation

public enum TowerGame: String, CaseIterable, Codable, Sendable {
  case candleMatch, readDay, candlePop, spotTrend, memory, pattern, findFloor, ladder, busyDay, smooth

  public var title: String {
    switch self {
    case .candleMatch: return "Candle match"
    case .readDay: return "Read the day"
    case .candlePop: return "Candle Pop"
    case .spotTrend: return "Spot the trend"
    case .memory: return "Memory flip"
    case .pattern: return "Pattern detective"
    case .findFloor: return "Find the floor"
    case .ladder: return "Line them up"
    case .busyDay: return "Busy day?"
    case .smooth: return "Smooth it out"
    }
  }
  /// An SF Symbol for the game (never an emoji).
  public var symbol: String {
    switch self {
    case .candleMatch: return "square.grid.3x1.below.line.grid.1x2"
    case .readDay: return "eye.fill"
    case .candlePop: return "hand.tap.fill"
    case .spotTrend: return "arrow.up.right"
    case .memory: return "square.on.square"
    case .pattern: return "magnifyingglass"
    case .findFloor: return "ruler"
    case .ladder: return "list.number"
    case .busyDay: return "speaker.wave.3.fill"
    case .smooth: return "scribble.variable"
    }
  }
  /// One short line: how to play.
  public var how: String {
    switch self {
    case .candleMatch: return "Tap the candle that tells the story."
    case .readDay: return "Look at one day. What did the price do?"
    case .candlePop: return "Candles pop up. Tap the right ones fast!"
    case .spotTrend: return "Is the price going up, down or sideways?"
    case .memory: return "Flip cards. Match each picture to its name."
    case .pattern: return "What shape is the chart making?"
    case .findFloor: return "Drag the line to the floor or ceiling."
    case .ladder: return "Tap from the biggest up day to the biggest down day."
    case .busyDay: return "Tap the day with the tallest volume bar."
    case .smooth: return "Which line is the smooth moving average?"
    }
  }
  /// Inspired by: an old game everyone knows, so grown-ups can explain it in a word.
  public var classic: String {
    switch self {
    case .candlePop: return "Like whack-a-mole"
    case .memory: return "Like the card game Memory"
    case .ladder: return "Like sorting cards in your hand"
    case .candleMatch: return "Like Snap"
    case .readDay, .spotTrend, .pattern, .findFloor, .busyDay, .smooth: return "A chart game"
    }
  }
  /// The level where this game first shows up (and that level always plays it).
  public var debut: Int {
    switch self {
    case .candleMatch: return 1
    case .readDay: return 2
    case .candlePop: return 3
    case .spotTrend: return 4
    case .memory: return 6
    case .pattern: return 12
    case .findFloor: return 16
    case .ladder: return 24
    case .busyDay: return 32
    case .smooth: return 42
    }
  }
}

/// A twist on a level, shown on its card. Never a clock that costs hearts (the speed ring stays bonus only).
public enum TowerTwist: String, CaseIterable, Codable, Sendable {
  case longHaul, fourDoors, glass, longView
  public var title: String {
    switch self {
    case .longHaul: return "Long haul"
    case .fourDoors: return "Four doors"
    case .glass: return "Glass rocket"
    case .longView: return "Long view"
    }
  }
  public var line: String {
    switch self {
    case .longHaul: return "Three extra rounds."
    case .fourDoors: return "Four answers to pick from."
    case .glass: return "Just one heart. Careful!"
    case .longView: return "Longer charts to read."
    }
  }
  public var symbol: String {
    switch self {
    case .longHaul: return "road.lanes"
    case .fourDoors: return "square.grid.2x2.fill"
    case .glass: return "heart.circle"
    case .longView: return "binoculars.fill"
    }
  }
}

public struct TowerZone: Hashable, Sendable {
  public let index: Int
  public let name: String
  public let symbol: String
  public let blurb: String
}

public struct TowerLevel: Identifiable, Hashable, Sendable {
  public let number: Int
  /// The game for each round (one game, or every game you've met on a boss floor).
  public let games: [TowerGame]
  public let rounds: Int
  public let hearts: Int
  /// Answers to pick from in choice games (3 or 4).
  public let choices: Int
  /// 0 (Launch Pad) … 5 (Deep Space).
  public let tier: Int
  public let isBoss: Bool
  public let twist: TowerTwist?
  public let seed: Int

  public var id: String { Tower.id(number) }
  public var floor: Int { (number - 1) / Tower.floorSize + 1 }
  public var zone: TowerZone { Tower.zone(tier) }
  public var mixed: Bool { Set(games).count > 1 }
  public func game(_ round: Int) -> TowerGame { games[((round % games.count) + games.count) % games.count] }
  /// The first game (the one on a normal level's card).
  public var lead: TowerGame { games[0] }
  /// Chart windows get longer as you climb (and with the Long view twist).
  public var chartDays: Int { min(60, [20, 30, 40, 45, 50, 60][tier] + (twist == .longView ? 15 : 0)) }
  /// Is this level's first appearance of a game? (Its card says "New game!")
  public var debut: TowerGame? { !isBoss && games.count == 1 && games[0].debut == number ? games[0] : nil }
}

public enum Tower {
  public static let floorSize = 10
  public static let mainLevels = 100
  static let prefix = "tower-"

  public static func id(_ n: Int) -> String { "\(prefix)\(n)" }
  public static func number(_ id: String) -> Int? { id.hasPrefix(prefix) ? Int(id.dropFirst(prefix.count)) : nil }

  public static let zones: [TowerZone] = [
    TowerZone(index: 0, name: "Launch Pad", symbol: "flag.fill", blurb: "Learn the games."),
    TowerZone(index: 1, name: "Cloud Deck", symbol: "cloud.fill", blurb: "Longer charts, more rounds."),
    TowerZone(index: 2, name: "Sky Bridge", symbol: "wind", blurb: "Four answers now."),
    TowerZone(index: 3, name: "Orbit Ring", symbol: "circle.dashed", blurb: "Three stars need a perfect run."),
    TowerZone(index: 4, name: "Moon Gate", symbol: "moon.fill", blurb: "Only the sharpest eyes."),
    TowerZone(index: 5, name: "Deep Space", symbol: "sparkles", blurb: "It never ends. How high can you go?"),
  ]
  public static func zone(_ tier: Int) -> TowerZone { zones[max(0, min(zones.count - 1, tier))] }
  public static func tier(_ n: Int) -> Int { n > mainLevels ? 5 : max(0, min(4, (n - 1) / 20)) }

  /// The games you've met by level n.
  public static func pool(_ n: Int) -> [TowerGame] { TowerGame.allCases.filter { $0.debut <= n } }

  static func mix(_ x: Int) -> Int {
    var z = UInt64(bitPattern: Int64(x)) &+ 0x9E37_79B9_7F4A_7C15
    z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
    z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
    return Int(truncatingIfNeeded: (z ^ (z >> 31)) & 0x3FFF_FFFF)
  }

  /// A normal level's game: its debut game, or a seeded pick from the pool that isn't the level before's
  /// pick (so the same game rarely plays twice in a row).
  static func pick(_ n: Int) -> TowerGame {
    if let d = TowerGame.allCases.first(where: { $0.debut == n }) { return d }
    let p = pool(n)
    return p[mix(n) % p.count]
  }
  static func game(_ n: Int) -> TowerGame {
    let g = pick(n)
    guard n > 1, TowerGame.allCases.first(where: { $0.debut == n }) == nil else { return g }
    let before = n % floorSize == 1 ? pick(max(1, n - 2)) : pick(n - 1)
    guard g == before else { return g }
    let p = pool(n)
    return p[((p.firstIndex(of: g) ?? 0) + 1 + mix(n &* 31) % max(1, p.count - 1)) % p.count]
  }

  static func twist(_ n: Int) -> TowerTwist? {
    guard n >= 15, n % floorSize != 0 else { return nil }
    let slot = n > mainLevels ? (n % floorSize == 3 || n % floorSize == 7) : n % floorSize == 5
    guard slot else { return nil }
    return TowerTwist.allCases[mix(n &* 7) % TowerTwist.allCases.count]
  }

  public static func level(_ n: Int) -> TowerLevel {
    let n = max(1, n)
    let t = tier(n), boss = n % floorSize == 0
    let inFloor = (n - 1) % floorSize           // 0…9
    let tw = boss ? nil : twist(n)
    let games: [TowerGame]
    if boss {
      var g = Seeded(mix(n))
      games = pool(n).shuffled(using: &g)
    } else {
      games = [game(n)]
    }
    var rounds = 3 + min(t, 4) + (inFloor >= 5 ? 1 : 0) + (n > mainLevels ? (n - mainLevels) / 50 : 0)
    if boss { rounds += 2 }
    if tw == .longHaul { rounds += 3 }
    rounds = min(rounds, 12)
    let hearts = tw == .glass ? 1 : boss && t >= 2 ? 2 : 3
    let choices = t >= 2 || tw == .fourDoors ? 4 : 3
    return TowerLevel(number: n, games: games, rounds: rounds, hearts: hearts, choices: choices, tier: t, isBoss: boss, twist: tw, seed: mix(n &* 2_654_435))
  }

  public static func stars(_ n: Int, _ s: KidsState) -> Int { min(3, s.stars?[id(n)] ?? 0) }

  /// Level 1 is always open; each next level opens once the one before has a star.
  public static func open(_ n: Int, _ s: KidsState) -> Bool { n <= 1 || stars(n - 1, s) > 0 }

  /// The highest open level (where the climber waits).
  public static func current(_ s: KidsState) -> Int {
    let won = (s.stars ?? [:]).keys.compactMap(number).filter { $0 >= 1 }
    var n = 1
    // Walk up from 1 through the levels with stars (a gap stops the climb).
    let set = Set(won)
    while set.contains(n) && (s.stars?[id(n)] ?? 0) > 0 { n += 1 }
    return n
  }

  /// How many levels the tower shows: all 100, then Deep Space a floor past where you are.
  public static func shown(_ s: KidsState) -> Int {
    let c = current(s)
    return max(mainLevels, ((c - 1) / floorSize + 2) * floorSize)
  }

  public static func totalStars(_ s: KidsState) -> Int {
    (s.stars ?? [:]).reduce(0) { acc, kv in number(kv.key) != nil ? acc + min(3, kv.value) : acc }
  }

  /// Stars for a run. From the Orbit Ring up, three stars need a perfect run and two need three in four.
  public static func starsFor(right: Int, of total: Int, tier: Int) -> Int {
    guard total > 0 else { return 0 }
    let r = Double(right) / Double(total)
    if tier >= 3 { return r >= 0.999 ? 3 : r >= 0.75 ? 2 : 1 }
    return r >= 0.99 ? 3 : r >= 0.6 ? 2 : 1
  }
}
