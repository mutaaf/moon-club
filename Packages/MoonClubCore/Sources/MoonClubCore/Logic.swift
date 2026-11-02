// Pure logic ported 1:1 from metaphases shared/kids.ts. Every function here is checked against the
// vectors exported from the web (Tests/VectorTests.swift), so the app and the site always agree.
// Safety model (same as the web): everything is PRETEND money that follows real prices.
import Foundation

// MARK: - Dates (ISO "YYYY-MM-DD" strings, UTC noon like the web's parse())
public enum Day {
  static let cal: Calendar = { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }()
  public static func parse(_ s: String) -> Date {
    let p = s.split(separator: "-").compactMap { Int($0) }
    guard p.count == 3 else { return Date(timeIntervalSince1970: 0) }
    return cal.date(from: DateComponents(year: p[0], month: p[1], day: p[2], hour: 12)) ?? Date(timeIntervalSince1970: 0)
  }
  public static func format(_ d: Date) -> String {
    let c = cal.dateComponents([.year, .month, .day], from: d)
    return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
  }
  public static func add(_ s: String, _ n: Int) -> String { format(cal.date(byAdding: .day, value: n, to: parse(s))!) }
  public static func between(_ a: String, _ b: String) -> Int { Int((parse(b).timeIntervalSince(parse(a)) / 86400).rounded()) }
  /// 0 = Monday … 6 = Sunday.
  public static func weekday(_ s: String) -> Int { (cal.component(.weekday, from: parse(s)) + 5) % 7 }
  public static func mondayOf(_ s: String) -> String { add(s, -weekday(s)) }
  /// Today in the device's own time zone (the kid's calendar day).
  public static func today(_ now: Date = Date(), tz: TimeZone = .current) -> String {
    var c = Calendar(identifier: .gregorian); c.timeZone = tz
    let x = c.dateComponents([.year, .month, .day], from: now)
    return String(format: "%04d-%02d-%02d", x.year!, x.month!, x.day!)
  }
  public static func en(_ fmt: String, _ s: String) -> String {
    let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = TimeZone(identifier: "UTC"); f.dateFormat = fmt
    return f.string(from: parse(s))
  }
}

/// JavaScript's Number.prototype.toFixed: ties round away from zero (printf rounds them to even).
public func toFixed(_ x: Double, _ digits: Int) -> String {
  let p = pow(10.0, Double(digits)), s = abs(x) * p
  if s - s.rounded(.down) == 0.5 { // an exact binary tie, e.g. 0.125 → "0.13" in JS
    let r = (s.rounded(.up)) / p * (x < 0 ? -1 : 1)
    return String(format: "%.\(digits)f", r)
  }
  return String(format: "%.\(digits)f", x)
}

// MARK: - Words a kid uses
public enum Session: String, Codable, Sendable { case bmo, dmh, amc, none = "" }
let kidSession: [Session: String] = [.bmo: "before school starts", .dmh: "during the school day", .amc: "after school", .none: "(the time isn't set yet)"]

/// "tomorrow after school", "Tuesday before school starts", "on Nov 17 after school".
public func kidWhen(_ date: String, _ session: Session, today: String) -> String {
  let n = Day.between(today, date)
  let day: String
  switch n {
  case 0: day = "today"
  case 1: day = "tomorrow"
  case -1: day = "yesterday"
  case 2..<7: day = Day.en("EEEE", date)
  default: day = "on \(Day.en("MMM d", date))"
  }
  return "\(day) \(kidSession[session]!)"
}

public struct Weather: Codable, Hashable, Sendable { public let icon: String; public let emoji: String; public let title: String; public let line: String }
/// Market Mood (0 fear → 100 greed) as weather.
public func weatherFor(_ score: Double) -> Weather {
  if score < 25 { return Weather(icon: "storm", emoji: "⛈️", title: "Stormy", line: "People feel scared. Lots of them are selling, so prices can bounce around a lot.") }
  if score < 45 { return Weather(icon: "cloud", emoji: "☁️", title: "Cloudy", line: "People are a bit worried. They are being careful with their money.") }
  if score <= 55 { return Weather(icon: "partly", emoji: "⛅", title: "Partly sunny", line: "People feel calm. Not scared, not too excited.") }
  if score <= 75 { return Weather(icon: "sun", emoji: "☀️", title: "Sunny", line: "People feel brave. Lots of them want to buy shares.") }
  return Weather(icon: "bright", emoji: "🌞", title: "Super sunny", line: "Everyone feels very brave. Maybe a little too brave!")
}

func dollars(_ v: Double) -> String { "$" + toFixed(v, 2) }
public func moveAnalogy(_ move: Double) -> String {
  let after = 10 * (1 + move / 100)
  return move >= 0 ? "That's like $10 of pocket money turning into \(dollars(after))!" : "That's like $10 of pocket money shrinking to \(dollars(after))."
}
public func lastTimeLine(_ move: Double?) -> String {
  guard let move else { return "We don't know yet how the price moved last time." }
  return "Last time it got its report card, the price \(move >= 0 ? "went up" : "went down") \(toFixed(abs(move), 1))%. \(moveAnalogy(move))"
}
public func expectLine(_ epsE: Double?) -> String {
  guard let e = epsE else { return "Grown-ups haven't guessed a number yet." }
  if e < 0 { return "Grown-ups expect it to lose about \(dollars(abs(e))) for every share. Some companies spend more than they make while they grow." }
  return "Grown-ups expect it to make about \(dollars(e)) of profit for every share."
}

// MARK: - Guess the Report Card
public enum Pick: String, Codable, Sendable, CaseIterable { case beat, miss }
public enum Direction: String, Codable, Sendable { case up, down }
public enum Outcome: String, Codable, Sendable { case right, wrong }
public enum Resolution: String, Codable, Sendable { case pending, right, wrong, unknown }
public struct Guess: Codable, Hashable, Sendable {
  public var s: String; public var d: String; public var pick: Pick; public var price: Direction?; public var at: String
  public var result: Outcome?; public var priceResult: Outcome?
  public init(s: String, d: String, pick: Pick, price: Direction? = nil, at: String, result: Outcome? = nil, priceResult: Outcome? = nil) {
    self.s = s; self.d = d; self.pick = pick; self.price = price; self.at = at; self.result = result; self.priceResult = priceResult
  }
}
public struct Report: Hashable, Sendable { public let eA: Double?; public let eE: Double?; public init(eA: Double?, eE: Double?) { self.eA = eA; self.eE = eE } }
/// Beat = the real profit per share was at least what grown-ups expected.
public func resolveGuess(_ pick: Pick, _ e: Report?) -> Resolution {
  guard let e, let a = e.eA else { return .pending }
  guard let x = e.eE else { return .unknown }
  return (pick == .beat) == (a >= x) ? .right : .wrong
}
public func resolvePrice(_ pick: Direction?, _ move: Double?) -> Resolution {
  guard let pick else { return .unknown }
  guard let move else { return .pending }
  return (pick == .up) == (move >= 0) ? .right : .wrong
}
public func whyLine(_ nick: String, _ e: Report) -> String {
  guard let a = e.eA, let x = e.eE else { return "\(nick) hasn't shared its report card yet." }
  let beat = a >= x
  return "Grown-ups expected \(dollars(x)) a share. \(nick) made \(dollars(a)). That's \(beat ? "more" : "less") than expected, so it \(beat ? "BEAT" : "MISSED")!"
}

// MARK: - Pretend Piggy Bank
public struct PiggyHolding: Codable, Hashable, Sendable { public let s: String; public let coins: Double; public let shares: Double; public let start: Double
  public init(s: String, coins: Double, shares: Double, start: Double) { self.s = s; self.coins = coins; self.shares = shares; self.start = start } }
/// Split coins evenly across picks in steps of 10, remainder to the first pick.
public func evenSplit(_ syms: [String], total: Int = 1000) -> [String: Int] {
  guard let first = syms.first else { return [:] }
  let each = Int((Double(total) / Double(syms.count) / 10).rounded(.down)) * 10
  var out = Dictionary(syms.map { ($0, each) }, uniquingKeysWith: { a, _ in a })
  out[first, default: 0] += total - each * syms.count
  return out
}
/// Coins → pretend shares at today's prices, in pick order. Skips companies without a price.
public func buyPretend(_ coins: [(String, Double)], prices: [String: Double]) -> [PiggyHolding] {
  coins.compactMap { s, c in
    guard c > 0, let p = prices[s], p > 0 else { return nil }
    return PiggyHolding(s: s, coins: c, shares: c / p, start: p)
  }
}
public func piggyValue(_ h: [PiggyHolding], prices: [String: Double]) -> Double { h.reduce(0) { $0 + $1.shares * (prices[$1.s] ?? $1.start) } }
public func holdingChange(_ x: PiggyHolding, price: Double?) -> Double { ((price ?? x.start) / x.start - 1) * 100 }
public func biggestMover(_ h: [PiggyHolding], prices: [String: Double]) -> (s: String, change: Double)? {
  var best: (s: String, change: Double)?
  for x in h { let c = holdingChange(x, price: prices[x.s]); if best == nil || abs(c) > abs(best!.change) { best = (x.s, c) } }
  return best
}
public func basketTip(_ n: Int) -> String {
  if n <= 1 { return "All your eggs are in one basket! If that one company has a bad day, all your pretend money feels it." }
  if n == 2 { return "Two baskets is safer than one. Adding more companies spreads out the bumps." }
  if n < 5 { return "\(n) baskets! If one company has a bad day, the others can help balance it out." }
  return "5 baskets: nicely spread out! One bad day won't spoil the whole bunch."
}

// MARK: - Points, levels, badges
public struct LevelInfo: Hashable, Sendable { public let index: Int; public let name: String; public let next: Int?; public let progress: Double }
public func levelFor(_ points: Int, levels: [Level]) -> LevelInfo {
  var i = 0
  for (k, l) in levels.enumerated() where points >= l.min { i = k }
  let next = i + 1 < levels.count ? levels[i + 1].min : nil
  let progress = next.map { Double(points - levels[i].min) / Double($0 - levels[i].min) } ?? 1
  return LevelInfo(index: i, name: levels[i].name, next: next, progress: max(0, min(1, progress)))
}
public struct KidsProgress: Hashable, Sendable {
  public var guesses: [Guess]; public var lessons: [String]; public var piggy: Bool; public var piggyCount: Int; public var quest: Bool; public var chapters: [String]
  public init(guesses: [Guess] = [], lessons: [String] = [], piggy: Bool = false, piggyCount: Int = 0, quest: Bool = false, chapters: [String] = []) {
    self.guesses = guesses; self.lessons = lessons; self.piggy = piggy; self.piggyCount = piggyCount; self.quest = quest; self.chapters = chapters
  }
}
public func pointsFor(_ p: KidsProgress) -> Int {
  let tries = p.guesses.count * 2
  let right = p.guesses.filter { $0.result == .right }.count * 10 + p.guesses.filter { $0.priceResult == .right }.count * 5
  let lemonade = p.quest || p.chapters.contains("lemonade")
  return tries + right + p.lessons.count * 10 + (p.piggy ? 5 : 0) + (lemonade ? 15 : 0) + (p.chapters.contains("save") ? 15 : 0) + (p.chapters.contains("dividends") ? 15 : 0)
}
public func badgesFor(_ p: KidsProgress, totalLessons: Int) -> [String] {
  var out: [String] = []
  if p.quest || p.chapters.contains("lemonade") { out.append("lemonade") }
  if p.chapters.contains("save") { out.append("smart-saver") }
  if p.chapters.contains("dividends") { out.append("dividend-detective") }
  if !p.guesses.isEmpty { out.append("first-guess") }
  if p.guesses.contains(where: { $0.result == .right }) { out.append("good-guess") }
  let resolved = p.guesses.enumerated().filter { $0.element.result != nil }.sorted { $0.element.d == $1.element.d ? $0.offset < $1.offset : $0.element.d < $1.element.d }.map(\.element)
  var run = 0, best = 0
  for g in resolved { run = g.result == .right ? run + 1 : 0; best = max(best, run) }
  if best >= 3 { out.append("streak-3") }
  if p.piggy { out.append("piggy") }
  if p.piggyCount >= 5 { out.append("five-baskets") }
  if p.lessons.count >= 1 { out.append("first-lesson") }
  if Double(p.lessons.count) >= (Double(totalLessons) / 2).rounded(.up) { out.append("half-school") }
  if totalLessons > 0 && p.lessons.count >= totalLessons { out.append("all-school") }
  return out
}

// MARK: - Reading level (Flesch–Kincaid grade), for keeping kid copy simple
private func matches(_ pattern: String, _ s: String) -> Int {
  (try? NSRegularExpression(pattern: pattern))?.numberOfMatches(in: s, range: NSRange(s.startIndex..., in: s)) ?? 0
}
private func replace(_ pattern: String, _ s: String, _ with: String = "") -> String {
  (try? NSRegularExpression(pattern: pattern))?.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: with) ?? s
}
public func syllables(_ word: String) -> Int {
  let w = replace("[^a-z]", word.lowercased())
  if w.isEmpty { return 0 }
  if w.count <= 3 { return 1 }
  let trimmed = replace("^y", replace("(?:[^laeiouy]es|ed|[^laeiouy]e)$", w))
  return max(1, matches("[aeiouy]{1,2}", trimmed))
}
public func fkGrade(_ text: String) -> Double {
  let sentences = max(1, matches("[.!?]+(\\s|$)", text))
  let words = text.split(whereSeparator: { $0.isWhitespace }).map { replace("[^A-Za-z']", String($0)) }.filter { !$0.isEmpty }
  if words.isEmpty { return 0 }
  let syl = words.reduce(0) { $0 + syllables($1) }
  return 0.39 * (Double(words.count) / Double(sentences)) + 11.8 * (Double(syl) / Double(words.count)) - 15.59
}

/// A deterministic pick for "of the day" content (same all day, changes tomorrow).
public func ofTheDayIndex(count: Int, today: String, salt: Int = 0) -> Int {
  guard count > 0 else { return 0 }
  let n = Day.parse(today).timeIntervalSince1970 / 86400
  return abs(Int(n.rounded(.down)) + salt) % count
}
public func ofTheDay<T>(_ items: [T], today: String, salt: Int = 0) -> T { items[ofTheDayIndex(count: items.count, today: today, salt: salt)] }

/// JavaScript's Math.round: halves round toward +∞ (-2.5 → -2), unlike Swift's .toNearestOrAwayFromZero.
public func jsRound(_ x: Double) -> Double { (x + 0.5).rounded(.down) }
