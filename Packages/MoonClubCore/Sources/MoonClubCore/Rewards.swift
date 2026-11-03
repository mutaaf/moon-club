// Points that matter (0.11): one earned-only currency (Moon points), a cosmetic Moon Shop, tiered trophies
// and moon-phase ranks. Everything here is pure and derived from KidsState, so every device computes the
// same wallet, and a sync merge can't inflate it:
//   earned  = the web's points (pointsFor) + map stars + trophy tiers + mission chests + banked bonuses
//   spent   = the price of every owned item (owned is a set; a set union can't double-spend one item)
//   wallet  = earned − spent, never below 0
// Banked bonuses are a map "day|source|id" → points, merged by max, so replaying a game on the same day
// keeps your best run instead of farming points. Nothing here is real money, and nothing can be bought.
import Foundation

// MARK: - Where points come from

public enum PointSource: String, CaseIterable, Sendable {
  case lesson, game, boss, quest, guess, piggy, streak, mission, badge
  public var label: String {
    switch self {
    case .lesson: return "Lessons"
    case .game: return "Chart games"
    case .boss: return "Bosses"
    case .quest: return "Quests"
    case .guess: return "Report card guesses"
    case .piggy: return "Piggy Bank"
    case .streak: return "Daily visits"
    case .mission: return "Mission chests"
    case .badge: return "Badges"
    }
  }
  public var symbol: String {
    switch self {
    case .lesson: return "book.fill"
    case .game: return "chart.bar.xaxis"
    case .boss: return "crown.fill"
    case .quest: return "map.fill"
    case .guess: return "target"
    case .piggy: return "banknote.fill"
    case .streak: return "flame.fill"
    case .mission: return "shippingbox.fill"
    case .badge: return "rosette"
    }
  }
}

public struct PointLine: Hashable, Sendable, Identifiable {
  public let source: PointSource; public let points: Int
  public var id: String { source.rawValue }
}

public enum Rewards {
  /// Points for one mission chest (all three of a day's missions done).
  public static let chestPoints = 30
  /// Run points: each right answer is worth this (times the combo), plus 1 for a fast answer.
  public static let perRight = 2
  /// The most one run can bank (so a long lesson can't outweigh everything else).
  public static let runCap = 30
  /// Daily visit bonus: 5 on day one of a streak, +5 a day, up to 25.
  public static func dailyBonus(streak: Int) -> Int { min(25, 5 * max(1, streak)) }
  /// A trophy tier is worth this (bronze, silver, gold).
  public static let tierPoints = [10, 20, 40]
  /// The day 0.11 shipped: chests opened before it keep the rocket skins they unlocked back then.
  public static let shopDay = "2026-11-03"

  /// Total banked bonus points (runs, daily visits).
  public static func banked(_ s: KidsState) -> Int { (s.bonus ?? [:]).values.reduce(0, +) }

  /// Every point the kid has earned, by where it came from. Sums to `s.points(c)`.
  public static func breakdown(_ s: KidsState, _ c: KidsContent) -> [PointLine] {
    var m: [PointSource: Int] = [:]
    let p = s.progress(c)
    m[.lesson, default: 0] += p.lessons.count * 10
    let tries = p.guesses.count * 2
    let right = p.guesses.filter { $0.result == .right }.count * 10 + p.guesses.filter { $0.priceResult == .right }.count * 5
    m[.guess, default: 0] += tries + right
    m[.piggy, default: 0] += p.piggy ? 5 : 0
    let lemonade = p.quest || p.chapters.contains("lemonade")
    m[.quest, default: 0] += (lemonade ? 15 : 0) + (p.chapters.contains("save") ? 15 : 0) + (p.chapters.contains("dividends") ? 15 : 0)
    // Map stars: games vs bosses.
    for n in World.regions(c).flatMap(\.nodes) {
      switch n.kind {
      case .game: m[.game, default: 0] += 5 * World.stars(n, s, c)
      case .review, .timeMachine: m[.boss, default: 0] += 5 * World.stars(n, s, c)
      default: break
      }
    }
    m[.mission, default: 0] += (s.chests ?? []).count * chestPoints
    m[.badge, default: 0] += Trophies.points(s, c)
    for (k, v) in s.bonus ?? [:] {
      let parts = k.split(separator: "|")
      let src = parts.count > 1 ? PointSource(rawValue: String(parts[1])) ?? .game : .game
      m[src, default: 0] += v
    }
    return PointSource.allCases.compactMap { src in m[src].flatMap { $0 > 0 ? PointLine(source: src, points: $0) : nil } }
  }

  /// Points one finished run banks: right answers × combo, capped.
  public static func runPoints(_ coins: Int) -> Int { min(runCap, max(0, coins)) }
}

// MARK: - Ranks (moon phases), extending the web's levels for the app

public struct RankUnlock: Hashable, Sendable { public let item: String }

public enum Ranks {
  /// The web's five moons, then the app's bigger ones. The web's thresholds are kept exactly.
  static let extra: [(Int, String)] = [(250, "Supermoon"), (400, "Blue Moon"), (600, "Harvest Moon"), (850, "Eclipse Explorer"), (1200, "Moon Legend")]
  public static func levels(_ c: KidsContent) -> [Level] {
    let top = c.levels.last?.min ?? 0
    return c.levels + extra.filter { $0.0 > top }.map { Level(min: $0.0, name: $0.1) }
  }
  /// Shop items a rank opens up (so a new rank always unlocks something you can see).
  public static func unlocks(_ index: Int) -> [ShopItem] { Shop.all.filter { $0.rank == index } }
}

// MARK: - The Moon Shop (cosmetic only)

public enum ShopSlot: String, CaseIterable, Sendable {
  case rocket, hat, flag, trail, theme, frame, freeze
  public var title: String {
    switch self {
    case .rocket: return "Rockets"
    case .hat: return "Luna's hats"
    case .flag: return "Map flags"
    case .trail: return "Map trails"
    case .theme: return "App colors"
    case .frame: return "Luna frames"
    case .freeze: return "Streak savers"
    }
  }
}

public struct ShopItem: Hashable, Identifiable, Sendable {
  public let id: String
  public let slot: ShopSlot
  public let name: String
  public let price: Int
  /// An SF Symbol for the item (the app draws rockets and frames itself).
  public let symbol: String
  /// A hue name the app maps to its palette (lemon, coral, grape…).
  public let hue: String
  /// Main color as 0xRRGGBB (trails, themes, flags, frames).
  public let color: UInt32
  /// Rank index needed before it can be bought (nil = any rank).
  public let rank: Int?
  /// A trophy id that must reach bronze first (nil = none).
  public let trophy: String?
  public init(id: String, slot: ShopSlot, name: String, price: Int, symbol: String, hue: String, color: UInt32, rank: Int? = nil, trophy: String? = nil) {
    self.id = id; self.slot = slot; self.name = name; self.price = price; self.symbol = symbol; self.hue = hue; self.color = color; self.rank = rank; self.trophy = trophy
  }
}

public enum Shop {
  static func r(_ s: RocketSkin, _ price: Int, rank: Int? = nil, trophy: String? = nil) -> ShopItem {
    ShopItem(id: "rocket.\(s.id)", slot: .rocket, name: s.name, price: price, symbol: "airplane", hue: "sky", color: s.fin, rank: rank, trophy: trophy)
  }
  /// Free things everyone starts with (one per slot that needs a default).
  public static let starters: Set<String> = ["rocket.classic", "flag.coral", "trail.gold", "theme.ocean", "frame.none"]

  public static let all: [ShopItem] = {
    let sk = Dictionary(uniqueKeysWithValues: Skins.all.map { ($0.id, $0) })
    func skin(_ id: String) -> RocketSkin { sk[id] ?? Skins.all[0] }
    return [
      r(skin("classic"), 0),
      r(skin("mint"), 100),
      r(skin("sunset"), 150),
      r(skin("ocean"), 200, rank: 2),
      r(skin("galaxy"), 300, rank: 3),
      r(skin("gold"), 400, rank: 4, trophy: "boss-slayer"),
      r(skin("night"), 600, rank: 5),

      ShopItem(id: "hat.party", slot: .hat, name: "Party hat", price: 100, symbol: "party.popper.fill", hue: "berry", color: 0xD2508F),
      ShopItem(id: "hat.cap", slot: .hat, name: "Graduation cap", price: 150, symbol: "graduationcap.fill", hue: "ink", color: 0x2346D8, trophy: "bookworm"),
      ShopItem(id: "hat.headphones", slot: .hat, name: "Cool headphones", price: 200, symbol: "headphones", hue: "grape", color: 0x7E62EE),
      ShopItem(id: "hat.glasses", slot: .hat, name: "Chart-reading glasses", price: 250, symbol: "eyeglasses", hue: "slate", color: 0x66708C, trophy: "candle-reader"),
      ShopItem(id: "hat.crown", slot: .hat, name: "Royal crown", price: 500, symbol: "crown.fill", hue: "gold", color: 0xD99A1E, rank: 4),

      ShopItem(id: "flag.coral", slot: .flag, name: "Coral flag", price: 0, symbol: "flag.fill", hue: "coral", color: 0xEC6461),
      ShopItem(id: "flag.mint", slot: .flag, name: "Mint flag", price: 100, symbol: "flag.fill", hue: "mint", color: 0x3DB97F),
      ShopItem(id: "flag.grape", slot: .flag, name: "Grape flag", price: 120, symbol: "flag.fill", hue: "grape", color: 0x7E62EE),
      ShopItem(id: "flag.star", slot: .flag, name: "Star banner", price: 250, symbol: "star.square.fill", hue: "gold", color: 0xD99A1E, trophy: "land-conqueror"),
      ShopItem(id: "flag.moon", slot: .flag, name: "Moon banner", price: 350, symbol: "moon.circle.fill", hue: "sky", color: 0x3F82EE, rank: 4),

      ShopItem(id: "trail.gold", slot: .trail, name: "Gold trail", price: 0, symbol: "point.topleft.down.to.point.bottomright.curvepath.fill", hue: "gold", color: 0xD99A1E),
      ShopItem(id: "trail.mint", slot: .trail, name: "Mint trail", price: 100, symbol: "point.topleft.down.to.point.bottomright.curvepath.fill", hue: "mint", color: 0x3DB97F),
      ShopItem(id: "trail.berry", slot: .trail, name: "Berry trail", price: 120, symbol: "point.topleft.down.to.point.bottomright.curvepath.fill", hue: "berry", color: 0xD2508F),
      ShopItem(id: "trail.rainbow", slot: .trail, name: "Sky trail", price: 300, symbol: "point.topleft.down.to.point.bottomright.curvepath.fill", hue: "sky", color: 0x3F82EE, rank: 3),

      ShopItem(id: "theme.ocean", slot: .theme, name: "Ocean blue", price: 0, symbol: "paintpalette.fill", hue: "ink", color: 0x2346D8),
      ShopItem(id: "theme.grape", slot: .theme, name: "Grape jelly", price: 150, symbol: "paintpalette.fill", hue: "grape", color: 0x6A4BE0),
      ShopItem(id: "theme.forest", slot: .theme, name: "Forest green", price: 150, symbol: "paintpalette.fill", hue: "mint", color: 0x1F8A5B),
      ShopItem(id: "theme.sunset", slot: .theme, name: "Sunset orange", price: 200, symbol: "paintpalette.fill", hue: "orange", color: 0xC8561E, rank: 2),
      ShopItem(id: "theme.berry", slot: .theme, name: "Berry pink", price: 250, symbol: "paintpalette.fill", hue: "berry", color: 0xB8367A, trophy: "streaker"),

      ShopItem(id: "frame.none", slot: .frame, name: "No frame", price: 0, symbol: "circle.dashed", hue: "slate", color: 0x66708C),
      ShopItem(id: "frame.stars", slot: .frame, name: "Star frame", price: 120, symbol: "star.circle.fill", hue: "gold", color: 0xD99A1E, rank: 1),
      ShopItem(id: "frame.leaf", slot: .frame, name: "Leaf frame", price: 150, symbol: "leaf.circle.fill", hue: "mint", color: 0x3DB97F, trophy: "saver"),
      ShopItem(id: "frame.bolt", slot: .frame, name: "Lightning frame", price: 200, symbol: "bolt.circle.fill", hue: "lemon", color: 0xF2BE2E, rank: 3),
      ShopItem(id: "frame.rainbow", slot: .frame, name: "Sparkle frame", price: 400, symbol: "sparkles", hue: "grape", color: 0x7E62EE, rank: 5),

      // The big moons: each one opens something new.
      ShopItem(id: "trail.comet", slot: .trail, name: "Comet trail", price: 350, symbol: "sparkle", hue: "lemon", color: 0xF2BE2E, rank: 6),
      ShopItem(id: "hat.wizard", slot: .hat, name: "Star wand", price: 450, symbol: "wand.and.stars", hue: "grape", color: 0x7E62EE, rank: 7),
      ShopItem(id: "frame.galaxy", slot: .frame, name: "Galaxy frame", price: 500, symbol: "circle.hexagongrid.fill", hue: "sky", color: 0x3F82EE, rank: 8),
      ShopItem(id: "theme.midnight", slot: .theme, name: "Midnight", price: 600, symbol: "paintpalette.fill", hue: "slate", color: 0x34306E, rank: 9),

      ShopItem(id: "freeze", slot: .freeze, name: "Streak saver", price: 60, symbol: "snowflake", hue: "sky", color: 0x3F82EE),
    ]
  }()

  public static func item(_ id: String) -> ShopItem? {
    if id.hasPrefix("freeze#") { return all.first { $0.id == "freeze" } }
    return all.first { $0.id == id }
  }

  /// Skins unlocked by mission chests before the shop existed: they stay owned, free.
  static func legacy(_ s: KidsState) -> Set<String> {
    let old = (s.chests ?? []).filter { $0 < Rewards.shopDay }.count
    return Set(Skins.all.prefix(1 + min(Skins.all.count - 1, old)).map { "rocket.\($0.id)" })
  }

  /// Everything the kid owns (bought, starters, and legacy chest skins). Streak savers are counted separately.
  public static func owned(_ s: KidsState) -> Set<String> {
    starters.union(legacy(s)).union((s.owned ?? []).filter { !$0.hasPrefix("freeze#") })
  }
  public static func spent(_ s: KidsState) -> Int {
    (s.owned ?? []).reduce(0) { acc, id in
      // Legacy and starter items were never paid for, even if a later device also bought one.
      if !id.hasPrefix("freeze#"), starters.contains(id) || legacy(s).contains(id) { return acc }
      return acc + (item(id)?.price ?? 0)
    }
  }
  public static func wallet(_ s: KidsState, _ c: KidsContent) -> Int { max(0, s.points(c) - spent(s)) }

  public enum Lock: Hashable, Sendable { case rank(String), trophy(String), points(Int) }
  /// Why an item can't be bought yet (nil = it can, or it's owned).
  public static func lock(_ it: ShopItem, _ s: KidsState, _ c: KidsContent) -> Lock? {
    if it.slot != .freeze, owned(s).contains(it.id) { return nil }
    if let r = it.rank, s.level(c).index < r { let ls = Ranks.levels(c); return .rank(r < ls.count ? ls[r].name : "a higher rank") }
    if let t = it.trophy, (Trophies.progress(s, c).first { $0.trophy.id == t }?.tier ?? 0) < 1 { return .trophy(Trophies.all.first { $0.id == t }?.name ?? t) }
    if wallet(s, c) < it.price { return .points(it.price - wallet(s, c)) }
    return nil
  }

  /// The equipped item in a slot (the latest pick wins; falls back to the slot's starter).
  public static func equipped(_ slot: ShopSlot, _ s: KidsState) -> ShopItem? {
    let mine = owned(s)
    var id = s.equipped?[slot.rawValue]?.split(separator: "|").last.map(String.init)
    if slot == .rocket, id == nil, let legacy = s.skin?.split(separator: "|").last { id = "rocket.\(legacy)" }
    if let id, mine.contains(id), let it = item(id) { return it }
    return all.first { $0.slot == slot && starters.contains($0.id) }
  }
  public static func rocket(_ s: KidsState) -> RocketSkin {
    let id = equipped(.rocket, s)?.id.replacingOccurrences(of: "rocket.", with: "")
    return Skins.all.first { $0.id == id } ?? Skins.all[0]
  }

  /// Streak savers bought and not yet used.
  public static func freezes(_ s: KidsState) -> Int { (s.owned ?? []).filter { $0.hasPrefix("freeze#") }.count - (s.frozen ?? []).count }
}

// MARK: - Trophies (tiered badges)

public enum TrophyCategory: String, CaseIterable, Sendable {
  case charts, lands, bosses, streaks, guesses, saver, curious, school
  public var title: String {
    switch self {
    case .charts: return "Chart Reader"
    case .lands: return "Land Conqueror"
    case .bosses: return "Boss Slayer"
    case .streaks: return "Streaks"
    case .guesses: return "Report Card Guesser"
    case .saver: return "Saver"
    case .curious: return "Curious"
    case .school: return "Moon School"
    }
  }
}

public struct Trophy: Hashable, Identifiable, Sendable {
  public let id: String
  public let name: String
  public let category: TrophyCategory
  public let symbol: String
  public let hue: String
  /// What is counted, as a short phrase: "stars in Candle Canyon".
  public let unit: String
  /// How to start earning it, for the locked silhouette.
  public let hint: String
}

public struct TrophyProgress: Hashable, Identifiable, Sendable {
  public let trophy: Trophy
  public let count: Int
  /// Bronze, silver and gold targets.
  public let goals: [Int]
  /// 0 = locked, 1 bronze, 2 silver, 3 gold.
  public var tier: Int { goals.filter { count >= $0 }.count }
  public var next: Int? { tier < goals.count ? goals[tier] : nil }
  public var id: String { trophy.id }
  public var tierName: String { ["Locked", "Bronze", "Silver", "Gold"][tier] }
  /// "7/10 stars in Candle Canyon", or "Gold!" when done.
  public var progressLine: String { next.map { "\(min(count, $0))/\($0) \(trophy.unit)" } ?? "Gold! \(count) \(trophy.unit)" }
}

public enum Trophies {
  public static let all: [Trophy] = [
    Trophy(id: "candle-reader", name: "Candle Reader", category: .charts, symbol: "chart.bar.fill", hue: "coral", unit: "stars in Candle Canyon", hint: "Play a game in Candle Canyon."),
    Trophy(id: "trend-tracker", name: "Trend Tracker", category: .charts, symbol: "chart.line.uptrend.xyaxis", hue: "orange", unit: "stars on Trend Trails", hint: "Play a game on Trend Trails."),
    Trophy(id: "pattern-pro", name: "Pattern Pro", category: .charts, symbol: "waveform.path.ecg", hue: "grape", unit: "stars in Pattern Peaks", hint: "Play a game in Pattern Peaks."),
    Trophy(id: "signal-spotter", name: "Signal Spotter", category: .charts, symbol: "antenna.radiowaves.left.and.right", hue: "sky", unit: "stars in Signal Sea", hint: "Play a game in Signal Sea."),
    Trophy(id: "land-conqueror", name: "Land Conqueror", category: .lands, symbol: "flag.fill", hue: "coral", unit: "lands won", hint: "Beat a land's boss to plant your flag."),
    Trophy(id: "boss-slayer", name: "Boss Slayer", category: .bosses, symbol: "crown.fill", hue: "gold", unit: "bosses beaten", hint: "Beat any boss on the map."),
    Trophy(id: "streaker", name: "Moon Streak", category: .streaks, symbol: "flame.fill", hue: "orange", unit: "days in a row", hint: "Visit Moon Club two days in a row."),
    Trophy(id: "guesser", name: "Report Card Guesser", category: .guesses, symbol: "target", hue: "berry", unit: "right guesses", hint: "Guess a report card and wait for the result."),
    Trophy(id: "saver", name: "Super Saver", category: .saver, symbol: "banknote.fill", hue: "mint", unit: "days with your piggy", hint: "Start your pretend Piggy Bank."),
    Trophy(id: "curious", name: "Curious Cat", category: .curious, symbol: "questionmark.bubble.fill", hue: "teal", unit: "questions for Luna", hint: "Ask Luna a money question."),
    Trophy(id: "bookworm", name: "Bookworm", category: .school, symbol: "book.fill", hue: "ink", unit: "lessons done", hint: "Finish a one-minute lesson."),
    Trophy(id: "mission-maker", name: "Mission Maker", category: .streaks, symbol: "shippingbox.fill", hue: "gold", unit: "chests opened", hint: "Finish all 3 of today's missions."),
  ]

  static func regionStars(_ id: String, _ s: KidsState, _ c: KidsContent) -> (Int, Int) {
    guard let r = World.regions(c).first(where: { $0.id == id }) else { return (0, 0) }
    return (r.nodes.reduce(0) { $0 + World.stars($1, s, c) }, max(1, r.nodes.count))
  }

  /// The longest run of days in a row with a visit or a play (streak savers fill single gaps).
  public static func bestStreak(_ s: KidsState) -> Int {
    let days = Set(Streak.activeDays(s)).sorted()
    var best = 0, run = 0
    var prev: String?
    for d in days {
      run = (prev.map { Day.add($0, 1) == d } ?? false) ? run + 1 : 1
      best = max(best, run); prev = d
    }
    return best
  }

  public static func progress(_ s: KidsState, _ c: KidsContent) -> [TrophyProgress] {
    let regions = World.regions(c)
    let bosses = regions.flatMap(\.nodes).filter { if case .review = $0.kind { return true }; if case .timeMachine = $0.kind { return true }; return false }
    let lessons = max(1, c.lessons.count)
    return all.map { t in
      let count: Int; let goals: [Int]
      switch t.id {
      case "candle-reader", "trend-tracker", "pattern-pro", "signal-spotter":
        let region = ["candle-reader": "canyon", "trend-tracker": "trails", "pattern-pro": "peaks", "signal-spotter": "sea"][t.id] ?? ""
        let (have, n) = regionStars(region, s, c)
        count = have; goals = [n, 2 * n, 3 * n]
      case "land-conqueror": count = regions.filter { World.conquered($0, s, c) }.count; goals = [1, 3, max(4, regions.count)]
      case "boss-slayer": count = bosses.filter { World.stars($0, s, c) > 0 }.count; goals = [1, 3, max(4, bosses.count)]
      case "streaker": count = bestStreak(s); goals = [2, 5, 14]
      case "guesser": count = s.guesses.filter { $0.result == .right }.count; goals = [1, 5, 15]
      case "saver": count = s.piggy?.history.count ?? 0; goals = [1, 7, 30]
      case "curious": count = (s.asked ?? [:]).values.reduce(0, +); goals = [1, 10, 30]
      case "bookworm": count = s.lessons.count; goals = [1, Int((Double(lessons) / 2).rounded(.up)), lessons]
      case "mission-maker": count = (s.chests ?? []).count; goals = [1, 7, 30]
      default: count = 0; goals = [1, 2, 3]
      }
      return TrophyProgress(trophy: t, count: count, goals: goals)
    }
  }

  public static func points(_ s: KidsState, _ c: KidsContent) -> Int {
    progress(s, c).reduce(0) { acc, p in acc + Rewards.tierPoints.prefix(p.tier).reduce(0, +) }
  }

  /// Seen-badge ids for trophy tiers ("t:<id>:<tier>"), stored with the web badges in `seenBadges`.
  public static func key(_ p: TrophyProgress, tier: Int? = nil) -> String { "t:\(p.trophy.id):\(tier ?? p.tier)" }
  /// Tiers reached but not celebrated yet (lowest first).
  public static func fresh(_ s: KidsState, _ c: KidsContent) -> [(TrophyProgress, Int)] {
    let seen = Set(s.seenBadges)
    return progress(s, c).flatMap { p in (1...3).compactMap { t in t <= p.tier && !seen.contains(key(p, tier: t)) ? (p, t) : nil } }
  }
  /// Earned count (tiers + web badges), for the league and the header.
  public static func earnedCount(_ s: KidsState, _ c: KidsContent) -> Int { progress(s, c).filter { $0.tier > 0 }.count + s.badges(c).count }
}

// MARK: - Days with activity (streaks)

extension Streak {
  /// Days with a visit, a play, a lesson or a guess, plus days covered by a streak saver.
  public static func activeDays(_ s: KidsState) -> [String] {
    Array(s.lessonDates.values) + (s.played ?? []).compactMap { $0.split(separator: "|").first.map(String.init) } + s.guesses.map(\.at) + (s.frozen ?? [])
  }
}
