// Content model for Moon Club, decoded from kids-content.json (exported by metaphases
// `npm run export:kids`). The content is versioned and validated at load: a malformed or
// incompatible file is rejected with a readable error instead of crashing a screen later.
import Foundation

public struct KidCo: Codable, Hashable, Sendable { public let s: String; public let nick: String; public let hook: String; public let emoji: String }
public struct KidWord: Codable, Hashable, Sendable { public let word: String; public let means: String; public let example: String }
public struct KidTerm: Codable, Hashable, Sendable { public let word: String; public let emoji: String; public let means: String; public let example: String; public let play: String? }
public struct Unit: Codable, Hashable, Sendable, Identifiable { public let id: String; public let title: String; public let emoji: String; public let blurb: String }
public struct Badge: Codable, Hashable, Sendable, Identifiable { public let id: String; public let name: String; public let why: String; public let phase: Int }
public struct Level: Codable, Hashable, Sendable { public let min: Int; public let name: String }

public struct SortItem: Codable, Hashable, Sendable { public let emoji: String; public let text: String; public let b: Int }
public enum Step: Codable, Hashable, Sendable {
  case say(emoji: String, text: String)
  case check(Check)
  case sort(q: String, buckets: [String], items: [SortItem], why: String)

  private enum K: String, CodingKey { case t, emoji, text, q, options, answer, why, buckets, items }
  public init(from d: Decoder) throws {
    let c = try d.container(keyedBy: K.self)
    switch try c.decode(String.self, forKey: .t) {
    case "say": self = .say(emoji: try c.decode(String.self, forKey: .emoji), text: try c.decode(String.self, forKey: .text))
    case "check": self = .check(Check(q: try c.decode(String.self, forKey: .q), options: try c.decode([String].self, forKey: .options), answer: try c.decode(Int.self, forKey: .answer), why: try c.decode(String.self, forKey: .why)))
    case "sort": self = .sort(q: try c.decode(String.self, forKey: .q), buckets: try c.decode([String].self, forKey: .buckets), items: try c.decode([SortItem].self, forKey: .items), why: try c.decode(String.self, forKey: .why))
    case let t: throw DecodingError.dataCorruptedError(forKey: .t, in: c, debugDescription: "Unknown step type \(t)")
    }
  }
  public func encode(to e: Encoder) throws {
    var c = e.container(keyedBy: K.self)
    switch self {
    case let .say(emoji, text): try c.encode("say", forKey: .t); try c.encode(emoji, forKey: .emoji); try c.encode(text, forKey: .text)
    case let .check(x): try c.encode("check", forKey: .t); try c.encode(x.q, forKey: .q); try c.encode(x.options, forKey: .options); try c.encode(x.answer, forKey: .answer); try c.encode(x.why, forKey: .why)
    case let .sort(q, buckets, items, why): try c.encode("sort", forKey: .t); try c.encode(q, forKey: .q); try c.encode(buckets, forKey: .buckets); try c.encode(items, forKey: .items); try c.encode(why, forKey: .why)
    }
  }
}
public struct Check: Codable, Hashable, Sendable { public let q: String; public let options: [String]; public let answer: Int; public let why: String }
public struct Lesson: Codable, Hashable, Sendable, Identifiable { public let id: String; public let unit: String; public let title: String; public let emoji: String; public let steps: [Step] }

/// Any quest copy block: every field optional, so chapters can carry different words per stage.
public struct StageText: Codable, Hashable, Sendable {
  public let title, ask, tap, done, remember, up, down, reveal, result, downYear, upYear, yes, no: String?
}
public struct LemonadeText: Codable, Hashable, Sendable {
  public let intro: String; public let company: StageText; public let shares: StageText; public let price: StageText; public let report: StageText; public let finish: String
}
public struct ChapterText: Codable, Hashable, Sendable {
  public let intro: String; public let finish: String; public let stages: [String: StageText]
  private struct Dyn: CodingKey { var stringValue: String; var intValue: Int? { nil }; init(stringValue: String) { self.stringValue = stringValue }; init?(intValue: Int) { nil } }
  public init(from d: Decoder) throws {
    let c = try d.container(keyedBy: Dyn.self)
    intro = try c.decode(String.self, forKey: Dyn(stringValue: "intro"))
    finish = try c.decode(String.self, forKey: Dyn(stringValue: "finish"))
    var st: [String: StageText] = [:]
    for k in c.allKeys where k.stringValue != "intro" && k.stringValue != "finish" { st[k.stringValue] = try c.decode(StageText.self, forKey: k) }
    stages = st
  }
  public func encode(to e: Encoder) throws {
    var c = e.container(keyedBy: Dyn.self)
    try c.encode(intro, forKey: Dyn(stringValue: "intro")); try c.encode(finish, forKey: Dyn(stringValue: "finish"))
    for (k, v) in stages { try c.encode(v, forKey: Dyn(stringValue: k)) }
  }
  public subscript(_ stage: String) -> StageText { stages[stage] ?? StageText(title: nil, ask: nil, tap: nil, done: nil, remember: nil, up: nil, down: nil, reveal: nil, result: nil, downYear: nil, upYear: nil, yes: nil, no: nil) }
}
public struct ChapterMeta: Codable, Hashable, Sendable, Identifiable { public let id: String; public let emoji: String; public let title: String; public let blurb: String; public let badge: String
  public init(id: String, emoji: String, title: String, blurb: String, badge: String) { self.id = id; self.emoji = emoji; self.title = title; self.blurb = blurb; self.badge = badge } }
public struct ChapterSortItem: Codable, Hashable, Sendable, Identifiable { public let id: String; public let emoji: String; public let text: String; public let answer: String; public let why: String }
public struct DivCard: Codable, Hashable, Sendable { public let s: String; public let pays: Bool }
public struct QuestChapters: Codable, Hashable, Sendable {
  public let CHAPTERS: [ChapterMeta]
  public let CH_STAGES: [String: [String]]
  public let SAVE: ChapterText
  public let DIV: ChapterText
  public let SORT_ITEMS: [ChapterSortItem]
  public let SAVE_CHECK: [Check]
  public let DIV_CHECK: [Check]
  public let DIV_CARDS: [DivCard]
  public let START: Double
  public let JAR_RATE: Double
  public let TREE_YEARS: [Double]
  public let SLICES: Double
  public let PAY_PER_SLICE: Double
  public let SLICE_PRICE: Double
  public let SEASONS: Int
}

public struct KidsContent: Codable, Sendable {
  public let version: Int
  public let generated: String
  public let companies: [KidCo]
  public let words: [KidWord]
  public let terms: [String: KidTerm]
  public let quest: LemonadeText
  public let questChapters: QuestChapters?
  public let units: [Unit]
  public let lessons: [Lesson]
  public let badges: [Badge]
  public let levels: [Level]
  public let startCoins: Double
  public let maxPicks: Int
  public let players: [String]
  public let playerNames: [String]
  public let maxCodeGuesses: Int

  public static let supportedVersion = 1

  public enum LoadError: Error, Equatable, CustomStringConvertible {
    case unsupportedVersion(Int), invalid(String)
    public var description: String {
      switch self {
      case let .unsupportedVersion(v): return "Content version \(v) is newer than this app understands (\(KidsContent.supportedVersion))."
      case let .invalid(why): return "Content is invalid: \(why)"
      }
    }
  }

  /// Decode + validate. Throws a LoadError (never a crash) when something is off.
  public static func load(_ data: Data) throws -> KidsContent {
    let c: KidsContent
    do { c = try JSONDecoder().decode(KidsContent.self, from: data) } catch { throw LoadError.invalid(String(describing: error)) }
    guard c.version == supportedVersion else { throw LoadError.unsupportedVersion(c.version) }
    try c.validate()
    return c
  }

  public func validate() throws {
    func need(_ ok: Bool, _ why: String) throws { if !ok { throw LoadError.invalid(why) } }
    try need(!companies.isEmpty && companies.count <= 32, "companies must be 1…32 (League codes use 5 bits)")
    try need(Set(lessons.map(\.id)).count == lessons.count, "lesson ids must be unique")
    try need(!lessons.isEmpty, "no lessons")
    for l in lessons {
      try need(units.contains { $0.id == l.unit }, "lesson \(l.id) has unknown unit \(l.unit)")
      try need(!l.steps.isEmpty, "lesson \(l.id) has no steps")
      for s in l.steps {
        switch s {
        case let .check(c): try need(c.answer >= 0 && c.answer < c.options.count, "lesson \(l.id): answer out of range")
        case let .sort(_, b, items, _): try need(b.count == 2 && items.allSatisfy { $0.b == 0 || $0.b == 1 }, "lesson \(l.id): sort needs 2 buckets")
        case .say: break
        }
      }
    }
    try need(levels.first?.min == 0 && zip(levels, levels.dropFirst()).allSatisfy { $0.min < $1.min }, "levels must start at 0 and rise")
    try need(players.count == playerNames.count && players.count == 8, "8 League players")
    for (_, t) in terms { if let p = t.play { try need(["company", "shares", "price", "report"].contains(p) || p.contains(":") || p.hasPrefix("save") || p.hasPrefix("div"), "term play target \(p)") } }
  }

  public var companyBySymbol: [String: KidCo] { Dictionary(uniqueKeysWithValues: companies.map { ($0.s, $0) }) }
  public func unit(of l: Lesson) -> Unit? { units.first { $0.id == l.unit } }
  public var allChecks: [Check] { lessons.flatMap { $0.steps.compactMap { if case let .check(c) = $0 { return c } else { return nil } } } }
}
