// Moon Garden (0.13): "paper trading without the paper trading". A kid plants Moon points in kid-known
// companies; the planting grows or shrinks with real daily closing prices; the kid harvests some or all of
// it back at any time. Moon points are pretend: never money, never cashed out.
//
// Event-sourced, so devices can't double count:
//   • every plant and harvest is a `GardenEvent` with a unique id; the synced log is a set union (Sync.swift)
//   • holdings, harvest payouts and the wallet are DERIVED by replaying the log in one canonical order
//     (day, then id) — never a counter that two devices could both add to
//   • a harvest stores the price it used, so its payout is the same on every device; a harvest that finds
//     less growing than it asked for (two devices harvested the same plant offline) pays only what's there
//   • seeds are whole micro-seeds (Int), so replays are exact
//
// The ledger (pure, `Garden.balance`):
//   balance = earned + harvest gains − shop costs − points planted right now
// where harvest gains = what harvests paid − the planted points they took back (negative after a dip).
import Foundation

public struct GardenEvent: Codable, Hashable, Sendable, Identifiable {
  public enum Kind: String, Codable, Sendable { case plant = "p", harvest = "h" }
  /// "<15-digit millis>-<4 hex>": unique per device action, and sorts by time within a day.
  public let id: String
  public let k: Kind
  /// Company symbol.
  public let s: String
  /// Day of the action (yyyy-MM-dd).
  public let d: String
  /// Plant: points planted. Harvest: the points the kid saw when harvesting (display only; the payout is replayed).
  public let pts: Int
  /// Micro-seeds: plant = seeds added (pts / price × 1e6, rounded down); harvest = seeds asked for.
  public let u: Int
  /// The price used (a daily close), stored so every device replays the same numbers.
  public let px: Double
  public init(id: String, k: Kind, s: String, d: String, pts: Int, u: Int, px: Double) {
    self.id = id; self.k = k; self.s = s; self.d = d; self.pts = pts; self.u = u; self.px = px
  }
  /// Canonical replay order (and a total order, so a merge's sort is deterministic).
  static func before(_ a: GardenEvent, _ b: GardenEvent) -> Bool {
    if (a.d, a.id, a.k.rawValue, a.s) != (b.d, b.id, b.k.rawValue, b.s) { return (a.d, a.id, a.k.rawValue, a.s) < (b.d, b.id, b.k.rawValue, b.s) }
    return (a.u, a.pts, a.px) < (b.u, b.pts, b.px)
  }
}

/// One company's patch: what's growing there now.
public struct Plot: Hashable, Sendable, Identifiable {
  public let s: String
  /// Micro-seeds growing.
  public var micro: Int
  /// Planted points still in the ground (the cost of what's growing).
  public var principal: Int
  /// The day this patch was first planted (since it was last empty).
  public var since: String
  public var id: String { s }
  /// What the patch is worth at a price, in whole points.
  public func value(_ price: Double?) -> Int { price.map { Garden.points(micro, $0) } ?? principal }
}

/// A finished harvest, for the history list and "why did it move?".
public struct HarvestLine: Hashable, Sendable, Identifiable {
  public let id: String; public let s: String; public let d: String
  /// Points paid back and the planted points they took out of the ground.
  public let paid: Int; public let released: Int
  public var gain: Int { paid - released }
}

/// The whole garden, replayed from the event log.
public struct GardenBook: Hashable, Sendable {
  public var plots: [String: Plot] = [:]
  public var harvests: [HarvestLine] = []
  /// Points planted per day (for the daily planting limit).
  public var plantedOn: [String: Int] = [:]
  /// The most companies growing at the same time, ever (Spread it out).
  public var mostAtOnce = 0
  /// Finished holds: the longest a patch grew before it was emptied, in days.
  public var longestClosedHold = 0

  /// Planted points in the ground right now.
  public var principal: Int { plots.values.reduce(0) { $0 + $1.principal } }
  /// Harvest gains so far (can be below zero after harvesting in a dip).
  public var gains: Int { harvests.reduce(0) { $0 + $1.gain } }
  public var growing: [Plot] { plots.values.filter { $0.micro > 0 }.sorted { $0.s < $1.s } }
  /// The longest any patch has grown (still growing ones count up to `asOf`).
  public func longestHold(asOf: String) -> Int {
    plots.values.map { max(0, Day.between($0.since, asOf)) }.reduce(longestClosedHold, max)
  }
}

public enum Garden {
  public static let micro = 1_000_000
  /// Daily planting limit as a percent of the points you could spend (grown-ups can change it; 0 pauses planting).
  public static let defaultLimit = 50
  public static let limitChoices = [0, 25, 50, 75, 100]
  /// The smallest planting.
  public static let minPlant = 5

  public static func points(_ micro: Int, _ price: Double) -> Int {
    guard price > 0, micro > 0 else { return 0 }
    return Int((Double(micro) * price / Double(Self.micro)).rounded(.down))
  }
  public static func seeds(points: Int, price: Double) -> Int {
    guard price > 0, points > 0 else { return 0 }
    return Int((Double(points) * Double(micro) / price).rounded(.down))
  }

  /// Replays the log in canonical order. Harvests take at most what's growing (no double counting after a merge).
  public static func book(_ events: [GardenEvent]) -> GardenBook {
    var b = GardenBook()
    for e in events.sorted(by: GardenEvent.before) {
      switch e.k {
      case .plant:
        guard e.u > 0, e.pts > 0 else { continue }
        var p = b.plots[e.s] ?? Plot(s: e.s, micro: 0, principal: 0, since: e.d)
        if p.micro == 0 { p.since = e.d }
        p.micro += e.u; p.principal += e.pts
        b.plots[e.s] = p
        b.plantedOn[e.d, default: 0] += e.pts
        b.mostAtOnce = max(b.mostAtOnce, b.plots.values.filter { $0.micro > 0 }.count)
      case .harvest:
        guard var p = b.plots[e.s], p.micro > 0, e.u > 0 else { continue }
        let take = min(e.u, p.micro)
        // Principal comes out in proportion; a full harvest takes all of it (no crumbs left behind).
        let released = take == p.micro ? p.principal : Int((Double(p.principal) * Double(take) / Double(p.micro)).rounded(.down))
        let paid = points(take, e.px)
        b.harvests.append(HarvestLine(id: e.id, s: e.s, d: e.d, paid: paid, released: released))
        p.micro -= take; p.principal -= released
        if p.micro == 0 { b.longestClosedHold = max(b.longestClosedHold, max(0, Day.between(p.since, e.d))); p.principal = 0 }
        b.plots[e.s] = p
      }
    }
    b.plots = b.plots.filter { $0.value.micro > 0 }
    return b
  }

  /// THE ledger: points you can spend or plant.
  ///   balance = earned + harvest gains − shop costs − points planted right now   (never below 0)
  public static func balance(earned: Int, gains: Int, spent: Int, planted: Int) -> Int {
    max(0, earned + gains - spent - planted)
  }

  /// How many more points may be planted today: `limit`% of (balance + already planted today), minus what's
  /// already planted today, and never more than the balance. 0 pauses planting.
  public static func allowance(balance: Int, plantedToday: Int, limit: Int) -> Int {
    let pct = max(0, min(100, limit))
    return max(0, min(balance, (balance + plantedToday) * pct / 100 - plantedToday))
  }

  /// A unique event id: zero-padded millis (so it sorts by time) plus a little randomness.
  public static func eventId(nowMillis: Int, salt: UInt16) -> String { String(format: "%015ld-%04x", nowMillis, Int(salt)) }

  // MARK: Prices (daily closes only; nothing ticks)

  /// The latest close on or before `day`.
  public static func close(_ series: CandleSeries?, onOrBefore day: String) -> (d: String, c: Double)? {
    guard let cs = series?.candles else { return nil }
    return cs.last { $0.d <= day }.map { ($0.d, $0.c) }
  }
  /// Percent move between the last two closes on or before `day`.
  public static func dayMove(_ series: CandleSeries?, onOrBefore day: String) -> Double? {
    guard let cs = series?.candles.filter({ $0.d <= day }), cs.count >= 2, let a = cs.dropLast().last, let b = cs.last, a.c > 0 else { return nil }
    return (b.c - a.c) / a.c * 100
  }
  /// Its usual daily wiggle: the average size of a daily move over the last `n` days.
  public static func normalMove(_ series: CandleSeries?, n: Int = 60) -> Double? {
    guard let cs = series?.candles.suffix(n + 1), cs.count >= 10 else { return nil }
    let a = Array(cs)
    let moves = zip(a.dropLast(), a.dropFirst()).compactMap { $0.c > 0 ? abs($1.c - $0.c) / $0.c * 100 : nil }
    return moves.isEmpty ? nil : moves.reduce(0, +) / Double(moves.count)
  }
  /// Closes for a sparkline (oldest first): from the planting day if it's in range, else the last `n`.
  public static func spark(_ series: CandleSeries?, from: String?, upTo day: String, n: Int = 30) -> [Double] {
    guard let cs = series?.candles.filter({ $0.d <= day }) else { return [] }
    let since = from.map { f in cs.filter { $0.d >= f } } ?? []
    let pick = since.count >= 2 ? Array(since.suffix(90)) : Array(cs.suffix(n))
    return pick.map(\.c)
  }

  /// "The market is sleeping" (weekends, nights) — told simply. `hour` is the hour in New York.
  public static func marketNote(weekday: Int, hour: Int) -> String {
    if weekday == 1 || weekday == 7 { return "The market is sleeping for the weekend. Prices change on Monday." }
    if hour < 16 { return "The market is open today. Your garden updates once a day, after it closes." }
    return "The market is sleeping. Prices change tomorrow."
  }

  // MARK: Teaching moments

  /// "All your points are in one basket": one company holds most of what's growing.
  public static func basketNudge(_ b: GardenBook) -> String? {
    let g = b.growing
    guard let top = g.max(by: { $0.principal < $1.principal }), b.principal > 0 else { return nil }
    if g.count == 1 { return "All your points are in one basket. Planting in a few different companies means one bad day hurts less." }
    if Double(top.principal) / Double(b.principal) >= 0.75 { return "Most of your points are in one basket. Spreading them out means one bad day hurts less." }
    return nil
  }
  /// A calm habit card, a different one each day.
  public static let wisdom = [
    "Gardens grow slowly. Checking once a day is plenty, and once a week is even better.",
    "Prices wiggle every day. A wiggle is not a story.",
    "Patient planters look at months, not minutes.",
    "Up days and down days both happen. That's normal!",
    "Patterns are clues, not promises. Nobody knows what comes next.",
    "A down day is like a rainy day. It doesn't mean you made a mistake.",
  ]
  public static func wisdom(today: String) -> String {
    let n = today.unicodeScalars.reduce(0) { $0 + Int($1.value) }
    return wisdom[n % wisdom.count]
  }
}
