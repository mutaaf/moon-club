// Weekly recap, Family League codes and quest chapter math, ported from metaphases
// shared/kidsWeek.ts and shared/kidsQuestContent.ts. League codes are byte-for-byte compatible
// with the web: a code made on an iPad pastes into mutaafaziz.com/metaphases/kids and back.
import Foundation

// MARK: - Weekly recap
public struct RecapPiggy: Codable, Hashable, Sendable { public var started: String; public var history: [String: Double]
  public init(started: String, history: [String: Double]) { self.started = started; self.history = history } }
public struct RecapInput: Hashable, Sendable {
  public var guesses: [Guess]; public var lessonDates: [String: String]; public var piggy: RecapPiggy?; public var points: Int; public var level: Int
  public init(guesses: [Guess], lessonDates: [String: String], piggy: RecapPiggy?, points: Int, level: Int) {
    self.guesses = guesses; self.lessonDates = lessonDates; self.piggy = piggy; self.points = points; self.level = level
  }
}
public struct Recap: Hashable, Sendable {
  public let label: String; public let from: String; public let to: String
  public let guesses: Int; public let right: Int; public let waiting: Int; public let lessons: Int
  public let piggyPct: Double?; public let level: Int; public let points: Int; public let active: Bool
}
/// Fri–Sun → this week; Monday → last week (the "first visit after"); other days → none.
public func recapWeek(_ today: String) -> (from: String, to: String, label: String)? {
  let wd = Day.weekday(today)
  if wd >= 4 { return (Day.mondayOf(today), today, "This week") }
  if wd == 0 { let from = Day.add(today, -7); return (from, Day.add(from, 6), "Last week") }
  return nil
}
public func buildRecap(_ st: RecapInput, today: String, levels: Int) -> Recap? {
  guard let w = recapWeek(today) else { return nil }
  let inWeek: (String?) -> Bool = { d in guard let d, !d.isEmpty else { return false }; return d >= w.from && d <= w.to }
  let gs = st.guesses.filter { inWeek($0.at) }
  let lessons = st.lessonDates.values.filter { inWeek($0) }.count
  var pct: Double?
  if let p = st.piggy {
    let h = p.history.filter { $0.key <= w.to }.sorted { $0.key < $1.key }
    let before = h.filter { $0.key <= w.from }
    let start = before.last ?? h.first, end = h.last
    if let start, let end, start.key != end.key, start.value > 0 { pct = jsRound((end.value / start.value - 1) * 1000) / 10 }
  }
  let right = gs.filter { $0.result == .right }.count
  return Recap(label: w.label, from: w.from, to: w.to, guesses: gs.count, right: right, waiting: gs.filter { $0.result == nil }.count, lessons: lessons,
               piggyPct: pct, level: max(0, min(levels - 1, st.level)), points: st.points, active: !gs.isEmpty || lessons > 0 || pct != nil)
}
private func plural(_ n: Int, _ one: String, _ many: String? = nil) -> String { "\(n) \(n == 1 ? one : (many ?? one + "s"))" }
public func recapLines(_ r: Recap, levels: [Level]) -> [String] {
  var out: [String] = []
  if r.guesses > 0 {
    out.append("You made \(plural(r.guesses, "guess", "guesses")).")
    if r.right > 0 { out.append("You got \(r.right) right! 🎉") }
    else if r.waiting == r.guesses { out.append("Now we wait for the report cards.") }
    else { out.append("None were right yet. Even experts miss a lot!") }
  }
  if r.lessons > 0 { out.append("You finished \(plural(r.lessons, "lesson")) at Moon School.") }
  if let p = r.piggyPct {
    if abs(p) < 0.1 { out.append("Your pretend piggy bank stayed the same.") }
    else { out.append("Your pretend piggy bank went \(p > 0 ? "up" : "down") \(toFixed(abs(p), 1))%.") }
  }
  out.append("You are a \(levels[r.level].name) now, with \(r.points) points.")
  return out
}
public func recapQuery(_ r: Recap) -> String {
  var s = "g=\(r.guesses)&r=\(r.right)&l=\(r.lessons)&lv=\(r.level)"
  if let p = r.piggyPct { s += "&p=\(toFixed(p, 1))" }
  return s
}

// MARK: - Family League codes
public struct LeagueGuess: Codable, Hashable, Sendable { public var s: String; public var d: String; public var pick: Pick; public var price: Direction?
  public init(s: String, d: String, pick: Pick, price: Direction? = nil) { self.s = s; self.d = d; self.pick = pick; self.price = price } }
public struct LeaguePlayer: Codable, Hashable, Sendable, Identifiable { public var emoji: Int; public var guesses: [LeagueGuess]; public var id: Int { emoji }
  public init(emoji: Int, guesses: [LeagueGuess]) { self.emoji = emoji; self.guesses = guesses } }

public enum League {
  static let b32 = Array("0123456789ABCDEFGHJKMNPQRSTVWXYZ") // Crockford: no I, L, O or U
  static let epoch = "2026-01-01", maxDay = 4095, prefix = "MOON", version: Character = "1"
  public static let maxGuesses = 20

  static func idx(_ c: Character) -> Int { b32.firstIndex(of: c) ?? -1 }
  static func checksum(_ body: [Character]) -> Character {
    var s = 7
    for (i, c) in body.enumerated() { s = (s * 31 + idx(c) + i) % 1024 }
    return b32[s % 32]
  }
  static func dayOf(_ d: String) -> Int { Day.between(epoch, d) }

  /// "MOON-1A2B-…": version, player, 4 characters per guess, checksum.
  public static func encode(_ p: LeaguePlayer, companies: [KidCo]) -> String {
    let sorted = p.guesses.enumerated().sorted { $0.element.d == $1.element.d ? $0.offset < $1.offset : $0.element.d > $1.element.d }.map(\.element)
    var body: [Character] = [version, b32[p.emoji & 7]]
    var n = 0
    for g in sorted {
      guard let si = companies.firstIndex(where: { $0.s == g.s }), si <= 31 else { continue }
      let day = dayOf(g.d)
      guard day >= 0 && day <= maxDay else { continue }
      let bits = (si << 15) | (day << 3) | ((g.pick == .miss ? 1 : 0) << 2) | (g.price == .up ? 1 : g.price == .down ? 2 : 0)
      for sh in [15, 10, 5, 0] { body.append(b32[(bits >> sh) & 31]) }
      n += 1
      if n >= maxGuesses { break }
    }
    body.append(checksum(body))
    var groups: [String] = []
    var i = 0
    while i < body.count { groups.append(String(body[i..<min(i + 4, body.count)])); i += 4 }
    return prefix + "-" + groups.joined(separator: "-")
  }

  public enum DecodeError: Error, Equatable { case why(String)
    public var message: String { if case let .why(s) = self { return s }; return "" } }

  public static func decode(_ raw: String, companies: [KidCo], players: Int = 8) -> Result<LeaguePlayer, DecodeError> {
    let clean = String(raw.uppercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber) })
      .replacingOccurrences(of: "I", with: "1").replacingOccurrences(of: "L", with: "1").replacingOccurrences(of: "O", with: "0")
    let pre = prefix.replacingOccurrences(of: "O", with: "0")
    guard clean.hasPrefix(pre) else { return .failure(.why("That doesn't look like a Moon Club code. It starts with MOON.")) }
    let body = Array(clean.dropFirst(pre.count))
    guard body.count >= 3, (body.count - 3) % 4 == 0 else { return .failure(.why("That code is too short or too long. Check every letter.")) }
    guard body[0] == version else { return .failure(.why("That code is from a different version of the club.")) }
    guard body.allSatisfy({ idx($0) >= 0 }) else { return .failure(.why("That code has a letter we don't use.")) }
    guard checksum(Array(body.dropLast())) == body.last! else { return .failure(.why("One letter looks wrong. Check the code again.")) }
    let emoji = idx(body[1])
    guard emoji < players else { return .failure(.why("That code has an unknown player.")) }
    var guesses: [LeagueGuess] = []
    var i = 2
    while i + 4 <= body.count - 1 {
      let bits = body[i..<i + 4].reduce(0) { ($0 << 5) | idx($1) }
      let si = bits >> 15, day = (bits >> 3) & 0xfff, miss = (bits >> 2) & 1, pr = bits & 3
      guard si < companies.count, pr != 3 else { return .failure(.why("One letter looks wrong. Check the code again.")) }
      guesses.append(LeagueGuess(s: companies[si].s, d: Day.add(epoch, day), pick: miss == 1 ? .miss : .beat, price: pr == 0 ? nil : pr == 1 ? .up : .down))
      i += 4
    }
    return .success(LeaguePlayer(emoji: emoji, guesses: guesses))
  }

  public struct Row: Hashable, Sendable, Identifiable { public let key: String; public let s: String; public let d: String; public var picks: [LeagueGuess?]; public var id: String { key } }
  /// One row per report card anyone guessed, newest first.
  public static func rows(_ players: [LeaguePlayer], limit: Int = 10) -> [Row] {
    var order: [String] = []
    var map: [String: Row] = [:]
    for (i, p) in players.enumerated() {
      for g in p.guesses {
        let key = "\(g.s):\(g.d)"
        if map[key] == nil { map[key] = Row(key: key, s: g.s, d: g.d, picks: Array(repeating: nil, count: players.count)); order.append(key) }
        map[key]!.picks[i] = g
      }
    }
    let rows = order.enumerated().map { ($0.offset, map[$0.element]!) }
    return rows.sorted { a, b in a.1.d != b.1.d ? a.1.d > b.1.d : a.1.s != b.1.s ? a.1.s < b.1.s : a.0 < b.0 }.prefix(limit).map(\.1)
  }
}

// MARK: - Quest chapters (fixed math, the same for every kid)
public enum Chapters {
  static let lemonadeStages = ["company", "shares", "price", "report"]
  private static func r2(_ v: Double) -> Double { jsRound(v * 100) / 100 }
  public static func jarPath(_ years: Int, start: Double, rate: Double) -> [Double] {
    var out = [start]
    for i in 0..<years { out.append(r2(out[i] * (1 + rate / 100))) }
    return out
  }
  public static func treePath(_ years: Int, start: Double, path: [Double]) -> [Double] {
    var out = [start]
    for i in 0..<years { out.append(r2(out[i] * (1 + path[i % path.count] / 100))) }
    return out
  }
  public struct Season: Hashable, Sendable { public let spent: Double; public let slices: Double; public let pay: Double }
  public static func snowball(seasons: Int, slices: Double, payPerSlice: Double, slicePrice: Double) -> (spend: [Season], replant: [Season]) {
    var spend = [Season(spent: 0, slices: slices, pay: slices * payPerSlice)]
    var replant = [Season(spent: 0, slices: slices, pay: slices * payPerSlice)]
    for i in 0..<seasons {
      let s = spend[i]
      spend.append(Season(spent: s.spent + s.pay, slices: slices, pay: slices * payPerSlice))
      let r = replant[i]
      let sl = jsRound((r.slices + r.pay / slicePrice) * 100) / 100
      replant.append(Season(spent: 0, slices: sl, pay: r2(sl * payPerSlice)))
    }
    return (spend, replant)
  }
  /// Finished chapters from the quest stage list ("company", …, "save:jar", …).
  public static func done(quest: [String], lemonadeDone: Bool, stages: [String: [String]]) -> [String] {
    var out: [String] = []
    if lemonadeDone || lemonadeStages.allSatisfy(quest.contains) { out.append("lemonade") }
    for id in ["save", "dividends"] { if let st = stages[id], st.allSatisfy({ quest.contains("\(id):\($0)") }) { out.append(id) } }
    return out
  }
}
