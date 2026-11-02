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

  // MARK: Derived
  public func chapters(_ c: KidsContent) -> [String] { Chapters.done(quest: quest, lemonadeDone: questDone, stages: c.questChapters?.CH_STAGES ?? [:]) }
  public func progress(_ c: KidsContent) -> KidsProgress {
    KidsProgress(guesses: guesses, lessons: lessons, piggy: piggy != nil, piggyCount: piggy?.holdings.count ?? 0, quest: questDone, chapters: chapters(c))
  }
  public func points(_ c: KidsContent) -> Int { pointsFor(progress(c)) }
  public func level(_ c: KidsContent) -> LevelInfo { levelFor(points(c), levels: c.levels) }
  public func badges(_ c: KidsContent) -> [String] { badgesFor(progress(c), totalLessons: c.lessons.count) }
  public func freshBadges(_ c: KidsContent) -> [String] { badges(c).filter { !seenBadges.contains($0) } }
  public func recap(_ c: KidsContent, today: String) -> Recap? {
    buildRecap(RecapInput(guesses: guesses, lessonDates: lessonDates, piggy: piggy.map { RecapPiggy(started: $0.started, history: $0.history) }, points: points(c), level: level(c).index), today: today, levels: c.levels.count)
  }
}
