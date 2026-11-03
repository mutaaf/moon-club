// The kid's progress: one Codable value, mutated only through the pure reducer methods below
// (unidirectional: views send intents → state changes → views re-render). Same shape as the web's
// `metaphases:kids:v1`, and it never leaves the device.
import Foundation

public struct Piggy: Codable, Hashable, Sendable {
  public var started: String; public var holdings: [PiggyHolding]; public var history: [String: Double]
}

public struct KidsState: Codable, Hashable, Sendable {
  public var schema = 1
  public var guesses: [Guess] = []
  public var piggy: Piggy?
  public var lessons: [String] = []
  public var lessonDates: [String: String] = [:]
  public var seenBadges: [String] = []
  public var me: Int?
  public var league: [LeaguePlayer] = []
  public var recapSeen: String?
  public var quest: [String] = []
  public var questDone = false
  /// Bumped by "reset on all devices" (see Sync.swift). Optional so saves from before sync still decode.
  public var resetEpoch: Int?
  /// The day the kid last marked today's Story as read (from the app or a widget). Optional, so old files decode.
  public var storyRead: String?
  /// Market World: best stars (0–3) per map node id. Optional so older saves decode.
  public var stars: [String: Int]?
  /// Game On (0.10): what was played each day, as "yyyy-MM-dd|kind|id" (kind: lesson, game, boss, quest, guess).
  /// Feeds Today's missions and the play streak. Optional so older saves decode; merge = union.
  public var played: [String]?
  /// Days whose mission chest was opened (union). Each chest unlocks the next rocket skin (cosmetic only).
  public var chests: [String]?
  /// The rocket skin the kid picked, as "<millis>|<skin id>": the later pick wins on merge (max).
  public var skin: String?
  /// Points that matter (0.11). All optional so older saves decode; each has a merge rule in Sync.swift.
  /// Banked bonus points, "yyyy-MM-dd|source|id" -> points (merge: max per key, so a replay can't farm).
  public var bonus: [String: Int]?
  /// Moon Shop items owned (merge: union). Streak savers are "freeze#<millis>", one id per saver.
  public var owned: [String]?
  /// Equipped item per shop slot, "<millis>|<item id>" (merge: max per slot, so the later pick wins).
  public var equipped: [String: String]?
  /// Days a streak saver covered (merge: union).
  public var frozen: [String]?
  /// Questions asked Luna per day, a count only (never the words). Merge: max per day.
  public var asked: [String: Int]?
  /// The highest rank whose ceremony has been shown (merge: max).
  public var rankSeen: Int?
  /// iPhone Duo things done ("book", "tabletop", "hinge", "night") -> count (merge: max per key). See Party.swift `DuoUse`.
  public var duo: [String: Int]?
  /// Spaced review (Review.swift): question id "<lesson>#<step>" -> "yyyy-MM-dd|box". Optional so older saves
  /// decode; merge = max per key (the later day wins, then the higher box).
  public var review: [String: String]?
  public init() {}

  // MARK: Intents (pure reducers)
  public mutating func guess(_ g: Guess) { guesses.removeAll { $0.s == g.s && $0.d == g.d }; guesses.append(g) }
  public mutating func resolve(s: String, d: String, result: Outcome?, priceResult: Outcome?) {
    for i in guesses.indices where guesses[i].s == s && guesses[i].d == d {
      if let result { guesses[i].result = result }
      if let priceResult { guesses[i].priceResult = priceResult }
    }
  }
  public mutating func startPiggy(_ h: [PiggyHolding], today: String, value: Double) {
    piggy = Piggy(started: today, holdings: h, history: [today: (value * 100).rounded() / 100])
  }
  public mutating func recordValue(today: String, value: Double) {
    guard var p = piggy else { return }
    let v = (value * 100).rounded() / 100
    if p.history[today] == v { return }
    p.history[today] = v
    let keys = p.history.keys.sorted()
    if keys.count > 120 { for k in keys.prefix(keys.count - 120) { p.history[k] = nil } }
    piggy = p
  }
  public mutating func resetPiggy() { piggy = nil }
  public mutating func finishLesson(_ id: String, today: String) {
    guard !lessons.contains(id) else { return }
    lessons.append(id); lessonDates[id] = today
  }
  public mutating func seeBadges(_ ids: [String]) { seenBadges = Array(Set(seenBadges).union(ids)).sorted() }
  public mutating func setMe(_ emoji: Int) { me = emoji; league.removeAll { $0.emoji == emoji } }
  public mutating func addPlayer(_ p: LeaguePlayer) { league.removeAll { $0.emoji == p.emoji }; league.append(p); if league.count > 6 { league.removeFirst(league.count - 6) } }
  public mutating func removePlayer(_ emoji: Int) { league.removeAll { $0.emoji == emoji } }
  public mutating func closeRecap(_ monday: String) { recapSeen = monday }
  public mutating func questStage(_ id: String) { if !quest.contains(id) { quest.append(id) } }
  public mutating func finishLemonade() { questDone = true }
  public mutating func readStory(today: String) { storyRead = today }
  /// Keep the best result for a Market World node (stars never go down).
  /// Logs one play for today's missions and the streak. Capped at the newest 400 entries when written.
  public mutating func play(_ kind: String, _ id: String, today: String) {
    let e = "\(today)|\(kind)|\(id)"
    var p = played ?? []
    if !p.contains(e) { p.append(e); p.sort(); if p.count > 400 { p.removeFirst(p.count - 400) } }
    played = p
  }
  public mutating func openChest(today: String) { var c = Set(chests ?? []); c.insert(today); chests = c.sorted() }
  public mutating func pickSkin(_ id: String, nowMillis: Int) { skin = "\(nowMillis)|\(id)" }
  /// Banks a bonus (keeps the best for the same day, source and id).
  public mutating func bank(_ source: PointSource, _ id: String, points: Int, today: String) {
    guard points > 0 else { return }
    let k = "\(today)|\(source.rawValue)|\(id)"
    var b = bonus ?? [:]; b[k] = max(b[k] ?? 0, points); bonus = b
  }
  /// Buys a shop item if it isn't locked. Returns false (and changes nothing) otherwise.
  @discardableResult public mutating func buy(_ id: String, _ c: KidsContent, nowMillis: Int) -> Bool {
    guard let it = Shop.item(id), Shop.lock(it, self, c) == nil else { return false }
    var o = Set(owned ?? [])
    if it.slot == .freeze { o.insert("freeze#\(nowMillis)") }
    else { guard !Shop.owned(self).contains(id) else { return false }; o.insert(id) }
    owned = o.sorted()
    if it.slot != .freeze { equip(id, nowMillis: nowMillis) }
    return true
  }
  /// Puts on an owned item (the later pick wins across devices).
  public mutating func equip(_ id: String, nowMillis: Int) {
    guard let it = Shop.item(id), it.slot != .freeze, Shop.owned(self).contains(id) else { return }
    var e = equipped ?? [:]; e[it.slot.rawValue] = "\(String(format: "%015d", nowMillis))|\(id)"; equipped = e
  }
  /// The app opened today: logs the visit, lets a streak saver cover yesterday if needed, banks the daily bonus.
  public mutating func checkIn(today: String) {
    let y = Day.add(today, -1), yy = Day.add(today, -2)
    let active = Set(Streak.activeDays(self))
    if !active.contains(y), active.contains(yy), !active.contains(today), Shop.freezes(self) > 0 {
      var f = Set(frozen ?? []); f.insert(y); frozen = f.sorted()
    }
    play("visit", "app", today: today)
    bank(.streak, "daily", points: Rewards.dailyBonus(streak: Streak.days(Streak.activeDays(self), today: today)), today: today)
  }
  /// Counts a question for the Curious trophy (only the number, never what was asked).
  public mutating func askLuna(today: String) { var a = asked ?? [:]; a[today] = (a[today] ?? 0) + 1; asked = a }
  public mutating func seeRank(_ i: Int) { rankSeen = max(rankSeen ?? 0, i) }
  public mutating func earn(_ node: String, stars n: Int) { var m = stars ?? [:]; m[node] = max(m[node] ?? 0, min(3, max(0, n))); stars = m }

  // MARK: Derived
  /// Family League players to show: everyone imported, minus this device's own player (after a sync merge,
  /// "me" can also arrive as an imported player from another device).
  public var leaguePlayers: [LeaguePlayer] { league.filter { $0.emoji != me } }
  public func chapters(_ c: KidsContent) -> [String] { Chapters.done(quest: quest, lemonadeDone: questDone, stages: c.questChapters?.CH_STAGES ?? [:]) }
  public func progress(_ c: KidsContent) -> KidsProgress {
    KidsProgress(guesses: guesses, lessons: lessons, piggy: piggy != nil, piggyCount: piggy?.holdings.count ?? 0, quest: questDone, chapters: chapters(c))
  }
  /// Every point earned (see Rewards.swift). The first two terms are the web's formula, unchanged.
  public func points(_ c: KidsContent) -> Int {
    pointsFor(progress(c)) + World.points(self, c) + Trophies.points(self, c) + (chests ?? []).count * Rewards.chestPoints + Rewards.banked(self)
  }
  public func level(_ c: KidsContent) -> LevelInfo { levelFor(points(c), levels: Ranks.levels(c)) }
  public func badges(_ c: KidsContent) -> [String] { badgesFor(progress(c), totalLessons: c.lessons.count) }
  public func freshBadges(_ c: KidsContent) -> [String] { badges(c).filter { !seenBadges.contains($0) } }
  public func recap(_ c: KidsContent, today: String) -> Recap? {
    buildRecap(RecapInput(guesses: guesses, lessonDates: lessonDates, piggy: piggy.map { RecapPiggy(started: $0.started, history: $0.history) }, points: points(c), level: level(c).index), today: today, levels: Ranks.levels(c).count)
  }
}
