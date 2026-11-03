// Cross-device progress: a pure, CRDT-style merge. `a.merged(with: b)` is commutative, associative and
// idempotent, so devices that sync through iCloud in any order, any number of times, converge on the same
// state, with no server of ours in between. Points, level and badges are derived from the merged state
// (never summed), so syncing can't inflate them.
//
// Field rules (each is its own join-semilattice, so the whole merge is one):
//   lessons + dates        union; a lesson's date is the earliest either device saw
//   badges, quest stages   union;  questDone is OR
//   guesses                one per (company, report day); the most-resolved wins, then the later `at`,
//                          then a fixed tiebreak. Results fill in from either side (a result is a fact).
//   piggy                  the later `started` wins outright (a new piggy replaces the old one); same start:
//                          history is the union by date, a clash takes the larger value
//   league                 union by player emoji; each player's guesses union by (company, day)
//   me / recapSeen         larger wins (deterministic); the league view hides the player that is "me"
//   played, chests         union (sorted); skin is the max of "<millis>|<id>", so the later pick wins
//   resetEpoch             "reset on all devices" bumps it; a larger epoch wins outright, so older data from
//                          a device that hasn't heard about the reset can't bring progress back
import Foundation

extension KidsState {
  /// The reset epoch (0 = never reset everywhere). Stored optional so older saves still decode.
  public var epoch: Int { resetEpoch ?? 0 }

  /// "Reset all progress on all devices": a fresh state whose epoch beats everything synced before.
  public static func resetEverywhere(from s: KidsState, nowMillis: Int) -> KidsState {
    var r = KidsState(); r.resetEpoch = max(s.epoch + 1, nowMillis); return r
  }

  public func merged(with o: KidsState) -> KidsState {
    if epoch != o.epoch { return (epoch > o.epoch ? self : o).normalized() }
    return Sync.join(self, o)
  }

  /// The canonical form merge produces (sorted, deduplicated); merge(x, x) == x.normalized().
  public func normalized() -> KidsState { var e = KidsState(); e.resetEpoch = resetEpoch; return Sync.join(self, e) }
}

public enum Sync {
  /// Field-wise join of two states with the same epoch.
  static func join(_ a: KidsState, _ o: KidsState) -> KidsState {
    var r = KidsState()
    r.schema = max(a.schema, o.schema)
    r.resetEpoch = a.resetEpoch ?? o.resetEpoch
    var dates = a.lessonDates
    for (k, v) in o.lessonDates { dates[k] = dates[k].map { min($0, v) } ?? v }
    r.lessonDates = dates
    r.lessons = Set(a.lessons).union(o.lessons).sorted { (dates[$0] ?? "", $0) < (dates[$1] ?? "", $1) }
    r.seenBadges = Set(a.seenBadges).union(o.seenBadges).sorted()
    r.quest = Set(a.quest).union(o.quest).sorted()
    r.questDone = a.questDone || o.questDone
    r.guesses = mergeGuesses(a.guesses, o.guesses)
    r.piggy = mergePiggy(a.piggy, o.piggy)
    r.me = maxOpt(a.me, o.me)
    r.recapSeen = maxOpt(a.recapSeen, o.recapSeen)
    r.storyRead = maxOpt(a.storyRead, o.storyRead) // latest day the Story was marked read (app or widget)
    r.league = mergeLeague(a.league, o.league)  // "me" is filtered where the league is shown (filtering here would break associativity)
    r.stars = mergeStars(a.stars, o.stars)     // Market World: best stars per node (max is a semilattice)
    r.played = unionOpt(a.played, o.played)    // Game On play log (the 400 cap applies when writing, never here)
    r.chests = unionOpt(a.chests, o.chests)
    r.skin = maxOpt(a.skin, o.skin)            // "<millis>|<id>": the later pick wins
    return r
  }

  static func mergeStars(_ a: [String: Int]?, _ b: [String: Int]?) -> [String: Int]? {
    guard a != nil || b != nil else { return nil }
    var m = a ?? [:]
    for (k, v) in b ?? [:] { m[k] = max(m[k] ?? 0, v) }
    return m
  }

  static func unionOpt(_ a: [String]?, _ b: [String]?) -> [String]? {
    guard a != nil || b != nil else { return nil }
    return Set((a ?? []) + (b ?? [])).sorted()
  }

  static func maxOpt<T: Comparable>(_ a: T?, _ b: T?) -> T? {
    switch (a, b) { case let (x?, y?): return max(x, y); case let (x?, nil): return x; case let (nil, y): return y }
  }
  static func key(_ g: Guess) -> String { "\(g.s)|\(g.d)" }
  /// One total order per guess, so "keep the bigger one" is a semilattice: more resolved first
  /// (a result is a fact about the report), then the later edit, then a fixed tiebreak on the value.
  static func order(_ g: Guess) -> String {
    let resolved = (g.result == nil ? 0 : 1) + (g.priceResult == nil ? 0 : 1)
    return "\(resolved)|\(g.at)|\(g.pick.rawValue)|\(g.price?.rawValue ?? "")|\(g.result?.rawValue ?? "")|\(g.priceResult?.rawValue ?? "")"
  }
  static func joinGuess(_ a: Guess, _ b: Guess) -> Guess { order(a) >= order(b) ? a : b }

  static func mergeGuesses(_ a: [Guess], _ b: [Guess]) -> [Guess] {
    var m: [String: Guess] = [:]
    for g in a + b { m[key(g)] = m[key(g)].map { joinGuess($0, g) } ?? g }
    return m.values.sorted { ($0.d, $0.s) < ($1.d, $1.s) }
  }

  static func mergePiggy(_ a: Piggy?, _ b: Piggy?) -> Piggy? {
    guard let a else { return b.map { mergePiggy($0, nil) ?? $0 } }
    guard let b else {
      // canonical form: holdings in a fixed order
      var p = a; p.holdings = a.holdings.sorted { ($0.s, $0.coins) < ($1.s, $1.coins) }; return p
    }
    if a.started != b.started { return mergePiggy(a.started > b.started ? a : b, nil) }
    var p = a
    for (d, v) in b.history { p.history[d] = p.history[d].map { max($0, v) } ?? v }
    let ha = a.holdings.sorted { ($0.s, $0.coins) < ($1.s, $1.coins) }, hb = b.holdings.sorted { ($0.s, $0.coins) < ($1.s, $1.coins) }
    p.holdings = holdingsKey(ha) >= holdingsKey(hb) ? ha : hb
    return p
  }
  static func holdingsKey(_ h: [PiggyHolding]) -> String { h.map { "\($0.s):\($0.coins):\($0.shares):\($0.start)" }.joined(separator: ",") }

  static func leagueGuessKey(_ g: LeagueGuess) -> String { "\(g.s)|\(g.d)" }
  static func mergeLeague(_ a: [LeaguePlayer], _ b: [LeaguePlayer]) -> [LeaguePlayer] {
    var m: [Int: [String: LeagueGuess]] = [:]
    for p in a + b {
      var gs = m[p.emoji] ?? [:]
      for g in p.guesses {
        let k = leagueGuessKey(g)
        if let x = gs[k] { gs[k] = "\(x.pick.rawValue)\(x.price?.rawValue ?? "")" >= "\(g.pick.rawValue)\(g.price?.rawValue ?? "")" ? x : g } else { gs[k] = g }
      }
      m[p.emoji] = gs
    }
    return m.keys.sorted().map { e in LeaguePlayer(emoji: e, guesses: m[e]!.values.sorted { $0.d != $1.d ? $0.d > $1.d : $0.s < $1.s }) }
  }

  // MARK: iCloud payload (compact JSON, bounded size)

  /// iCloud key-value storage allows 1 MB total and 1 MB per key; we stay far below it.
  public static let maxPayloadBytes = 200_000
  /// Guesses kept in the synced copy (newest first). Older ones stay on the device that has them.
  public static let maxSyncedGuesses = 400

  /// The copy that goes to iCloud: the state minus device-only fields, trimmed to a safe size.
  public static func payload(_ s: KidsState) -> Data {
    var c = s.normalized()
    c.recapSeen = nil  // a per-device nudge, not progress
    if c.guesses.count > maxSyncedGuesses { c.guesses = Array(c.guesses.sorted { $0.d > $1.d }.prefix(maxSyncedGuesses)).sorted { ($0.d, $0.s) < ($1.d, $1.s) } }
    let enc = JSONEncoder(); enc.outputFormatting = [.sortedKeys]
    var d = (try? enc.encode(c)) ?? Data()
    while d.count > maxPayloadBytes, !c.guesses.isEmpty {
      c.guesses.removeFirst(max(1, c.guesses.count / 4))
      d = (try? enc.encode(c)) ?? Data()
    }
    return d
  }
  public static func decode(_ d: Data) -> KidsState? { try? JSONDecoder().decode(KidsState.self, from: d) }
}
