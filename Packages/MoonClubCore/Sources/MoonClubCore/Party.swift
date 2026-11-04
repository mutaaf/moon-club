// 0.12 "Party Moon": the pure rules behind celebrations, Luna's lines, the daily Mystery Stop, "almost
// there" nudges, the sticker book, the gentle goodnight and the iPhone Duo play mechanics. Everything is
// deterministic (seeded by the day or the event), so it is unit-tested and every device agrees.
// Kid-safe on purpose: no countdowns, no "you'll lose it" pressure, nothing that punishes stopping.
import Foundation

/// A stable string hash (FNV-1a), so "random" picks are the same on every device and every launch.
public enum Seed {
  public static func of(_ s: String) -> UInt64 {
    var h: UInt64 = 0xcbf29ce484222325
    for b in s.utf8 { h ^= UInt64(b); h = h &* 0x100000001b3 }
    return h
  }
  public static func pick<T>(_ xs: [T], _ key: String) -> T? { xs.isEmpty ? nil : xs[Int(of(key) % UInt64(xs.count))] }
}

// MARK: - Celebrations

/// How big a party a moment gets. The app maps each tier to particles, glow, haptics and sound.
public enum CelebrationTier: Int, Comparable, Sendable, CaseIterable {
  /// Every right answer: a sparkle where you tapped, coins to the HUD, a Luna bounce.
  case small
  /// Combo x3, a perfect round, a badge tier: confetti, an edge glow, Luna's flip.
  case medium
  /// A boss beaten, a land won, a rank-up, a chest, a streak milestone: fireworks and confetti cannons.
  case large
  public static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }
}

public enum PartyMoment: Equatable, Sendable {
  case right, combo(Int), perfectRound, badgeTier, bossBeaten, landWon, rankUp, chest, streak(Int), mystery

  public var tier: CelebrationTier {
    switch self {
    case .right: return .small
    case let .combo(n): return n >= 3 ? .medium : .small
    case .perfectRound, .badgeTier, .mystery: return .medium
    case .bossBeaten, .landWon, .rankUp, .chest: return .large
    case let .streak(n): return StreakMilestone.isMilestone(n) ? .large : .small
    }
  }
}

/// Streak days that get their own party (3, 7, 30, then every 50).
public enum StreakMilestone {
  public static let days = [3, 7, 30]
  public static func isMilestone(_ n: Int) -> Bool { days.contains(n) || (n > 30 && n % 50 == 0) }
  /// A short title for the moment ("3 days in a row!").
  public static func title(_ n: Int) -> String {
    switch n {
    case 3: return "3 days in a row!"
    case 7: return "A whole week!"
    case 30: return "30 days! A moon month!"
    default: return "\(n) days in a row!"
    }
  }
}

// MARK: - Luna's lines

/// Luna reacts to what just happened. Short lines, reading grade ≤ 5, never advice, never pressure.
public enum LunaLine: String, CaseIterable, Sendable {
  case firstWin, comeback, combo, perfect, boss, miss, streak, mystery, duoBook, duoTabletop, duoLaunch, sleepy

  public var lines: [String] {
    switch self {
    case .firstWin: return ["First win today! Hi, friend!", "There you are! Great start!", "Good morning, chart star!", "Your first win today. Yay!"]
    case .comeback: return ["You got it now!", "See? You figured it out!", "Back on track!", "That's the way!", "Missing one is how we learn."]
    case .combo: return ["You're on fire!", "Three in a row! Wow!", "Keep the streak going!", "Combo time!", "You're zooming!"]
    case .perfect: return ["Perfect! Every single one!", "Not one miss! Amazing!", "All stars! Woo-hoo!"]
    case .boss: return ["You beat the boss!", "The boss is no match for you!", "Flag planted! This land is yours!"]
    case .miss: return ["Oops! Try the next one.", "Hmm, tricky one!", "That's okay. Charts are tricky.", "Good guess! Let's keep going."]
    case .streak: return ["You came back! I missed you.", "Another day, another moon!", "Your streak is growing!"]
    case .mystery: return ["A mystery stop! Let's see!", "Surprise! Bonus points inside!", "Ooh, a secret game!"]
    case .duoBook: return ["Ooh, a storybook!", "Two pages! Just like a book.", "Read along, page by page!"]
    case .duoTabletop: return ["Tabletop mode! The top is the chart.", "Use the bottom like a game pad!", "Set me down and play!"]
    case .duoLaunch: return ["Open wide to launch!", "Three, two, one, liftoff!", "Whoosh! Open me up!"]
    case .sleepy: return ["I'm getting sleepy. Want to rest?", "Yawn! Great playing today.", "Let's save some fun for tomorrow!"]
    }
  }

  /// One line, stable for the same key (e.g. "2026-11-03|run-3"), so a redraw never swaps the words.
  public func line(_ key: String) -> String { Seed.pick(lines, "\(rawValue)|\(key)") ?? lines[0] }

  /// What Luna says after an answer, or nil (she doesn't talk every time).
  /// `firstOfDay` is true when this is today's first right answer anywhere in the app.
  public static func after(right: Bool, combo: Int, missedBefore: Bool, firstOfDay: Bool) -> LunaLine? {
    if !right { return .miss }
    if firstOfDay { return .firstWin }
    if missedBefore && combo == 1 { return .comeback }
    if combo == 3 || combo == 6 { return .combo }
    return nil
  }
}

// MARK: - Mystery Stop

/// One open game a day gets a sparkle and bonus points. Same pick on every device; changes daily;
/// claiming it is just finishing that game today (banked by max, so it can't be farmed).
public enum Mystery {
  public static let points = 15
  public static let bonusID = "mystery"

  public static func node(_ s: KidsState, _ c: KidsContent, today: String) -> WorldNode? {
    let rs = World.regions(c)
    var open: [WorldNode] = []
    for (ri, r) in rs.enumerated() where World.regionOpen(ri, rs, s, c) {
      for n in r.nodes where !n.isBoss && World.nodeOpen(n, in: r, regionOpen: true, s, c) {
        if case .game = n.kind { open.append(n) }
      }
    }
    return Seed.pick(open, "mystery|\(today)")
  }

  public static func claimed(_ s: KidsState, today: String) -> Bool {
    (s.bonus ?? [:])["\(today)|\(PointSource.game.rawValue)|\(bonusID)"] != nil
  }
}

// MARK: - Almost there

/// Friendly "you're close" lines for the results screen. Facts only, never a deadline.
public enum Nudge {
  public static func after(_ node: WorldNode, stars: Int, _ s: KidsState, _ c: KidsContent) -> [String] {
    var out: [String] = []
    if stars > 0 && stars < 3 { out.append("\(3 - stars) more \(3 - stars == 1 ? "star" : "stars") for a perfect \(node.title)!") }
    let rs = World.regions(c)
    if let r = rs.first(where: { $0.nodes.contains(node) }), !World.conquered(r, s, c) {
      let left = r.nodes.filter { World.stars($0, s, c) == 0 }.count
      if left == 1 { out.append("1 stop left to win \(r.name)!") }
      else if left > 1 && left <= 3 { out.append("\(left) stops left to win \(r.name).") }
    }
    if let p = Trophies.progress(s, c).filter({ $0.next != nil && $0.count > 0 }).min(by: { gap($0) < gap($1) }), let next = p.next, next - p.count <= 3 {
      let tier = ["bronze", "silver", "gold"][min(2, p.tier)]
      out.append("\(next - p.count) more \(p.trophy.unit) to \(tier) \(p.trophy.name)!")
    }
    return Array(out.prefix(2))
  }
  static func gap(_ p: TrophyProgress) -> Int { (p.next ?? .max) - p.count }
}

// MARK: - Sticker book

public struct Sticker: Hashable, Identifiable, Sendable {
  public let id: String
  public let title: String
  /// The emoji key the app draws with Glyph (never as text).
  public let art: String
  public let hue: String
  public let earned: Bool
  /// Shiny: a perfect (3-star) stop or a won land.
  public let shiny: Bool
}

/// One sticker per Market World stop (earned with any star, shiny at 3) and one per land won.
/// Derived from the map, so it needs no new saved state and syncs for free.
public enum Stickers {
  public static func all(_ s: KidsState, _ c: KidsContent) -> [Sticker] {
    World.regions(c).flatMap { r -> [Sticker] in
      let won = World.conquered(r, s, c)
      let land = Sticker(id: "land.\(r.id)", title: r.name, art: r.art, hue: r.hue, earned: won, shiny: won)
      return [land] + r.nodes.map { n in
        let st = World.stars(n, s, c)
        return Sticker(id: "stop.\(n.id)", title: n.title, art: n.art, hue: r.hue, earned: st > 0, shiny: st >= 3)
      }
    }
  }
  public static func count(_ s: KidsState, _ c: KidsContent) -> (have: Int, of: Int) {
    let a = all(s, c); return (a.filter(\.earned).count, a.count)
  }
}

// MARK: - Goodnight

/// Healthy screen time: after a while Luna gets sleepy and offers a goodnight. Never blocks, never nags:
/// "One more game" snoozes it for a while, and it only asks again after another stretch.
public enum Bedtime {
  public static let firstAfter: TimeInterval = 20 * 60
  public static let snooze: TimeInterval = 10 * 60
  public static func sleepy(sessionStart: Date, lastAsked: Date?, now: Date) -> Bool {
    if let lastAsked { return now.timeIntervalSince(lastAsked) >= snooze }
    return now.timeIntervalSince(sessionStart) >= firstAfter
  }
}

// MARK: - iPhone Duo play

/// The hinge as a game controller. Opening the phone from ~30° to ~170° sweeps a value across a range,
/// so "set the candle's high price" is a physical move. Pure, so the mapping is tested.
public enum HingeDial {
  public static let low = 30.0, high = 170.0
  /// 0…1 across the usable hinge range (clamped).
  public static func fraction(_ degrees: Double) -> Double { max(0, min(1, (degrees - low) / (high - low))) }
  /// A whole-number value in `range` for the hinge angle.
  public static func value(_ degrees: Double, in range: ClosedRange<Int>) -> Int {
    let f = fraction(degrees)
    return range.lowerBound + Int((f * Double(range.upperBound - range.lowerBound)).rounded())
  }
}

/// "Open wide to launch": a reveal waits until the phone goes from closed or half open to flat.
public enum HingeLaunch {
  public static func launches(from old: HingeReading?, to new: HingeReading?) -> Bool {
    guard let old, let new else { return false }
    return old.status != .fullyOpen && (new.status == .fullyOpen || new.degrees >= 165)
  }
}

/// iPhone Duo things a kid did, counted for the Duo-only trophies (merge: max per key, so syncing never
/// inflates them). Only devices with a hinge ever write these.
public enum DuoUse: String, CaseIterable, Sendable {
  /// A lesson finished as a two-page storybook (book pose or open flat).
  case book
  /// A boss or Game Night round played in tabletop mode.
  case tabletop
  /// A hinge move used as a control (a hinge candle or an open-wide launch).
  case hinge
  /// A Game Night played on the two halves.
  case night
  /// A puppet show given in tent mode (0.14).
  case puppet
  /// A Market Race finished on the flat phone (0.14).
  case race
  /// An atlas page turned in book mode, by swipe or fold flick (0.14).
  case atlas
  /// A Moon Garden planting saved by folding the phone shut (0.14).
  case fold
}

extension KidsState {
  public mutating func useDuo(_ u: DuoUse) { var d = duo ?? [:]; d[u.rawValue] = (d[u.rawValue] ?? 0) + 1; duo = d }
  public func duoCount(_ u: DuoUse) -> Int { duo?[u.rawValue] ?? 0 }
  /// True once this kid has played on an iPhone Duo (any device).
  public var playedOnDuo: Bool { !(duo ?? [:]).isEmpty }
}
