// Lesson Packs: the versioned curriculum format shared with the web (metaphases shared/kidsPacks.ts,
// packs/pack.schema.json). Core ships as kids-content.json; other packs (guest / creator packs) ship in its
// `packs` list or arrive on the signed remote channel. A grown-up turns packs on behind the gate.
//
// The validator here is a port of the web's `validatePack`, and the `packValidate` vectors prove both report
// the same error codes. Kids rules live in code: reading level, glyph coverage, no links, no advice or
// promotion phrases, ids that resolve, and expert sign-offs on every non-core pack.
import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

public struct PackLesson: Codable, Hashable, Sendable { public let id: String; public let title: String; public let emoji: String; public let track: String?; public let objectives: [String]?; public var since: String? = nil; public let steps: [Step] }
public struct PackUnit: Codable, Hashable, Sendable { public let id: String; public let title: String; public let emoji: String; public let blurb: String; public let track: String?; public let objectives: [String]?; public var talk: [String]? = nil; public let lessons: [PackLesson] }
public struct PackNode: Codable, Hashable, Sendable { public let id: String; public let title: String; public let art: String; public let kind: String; public let ref: String? }
public struct RegionSpec: Codable, Hashable, Sendable { public let id: String; public let name: String; public let blurb: String; public let art: String; public let hue: String; public let nodes: [PackNode] }
public struct PackPerson: Codable, Hashable, Sendable { public let name: String; public let role: String; public let signedOff: String?; public let note: String? }
public struct PackCreator: Codable, Hashable, Sendable { public let name: String; public let fictional: Bool; public let bio: String; public let voice: String }
public struct PackObjective: Codable, Hashable, Sendable { public let id: String; public let text: String; public let standards: [String] }
/// `optional`: a challenge track whose lessons never gate map stars, mastery or boss quizzes.
public struct PackTrack: Codable, Hashable, Sendable { public let id: String; public let title: String; public let blurb: String; public var optional: Bool? = nil }
public struct PackRequires: Codable, Hashable, Sendable { public let content: Int; public let app: String?; public let core: String? }
public struct PackAges: Codable, Hashable, Sendable { public let min: Int; public let max: Int }
public struct GameSpec: Codable, Hashable, Sendable { public let id: String; public let unit: String; public let rounds: Int }
public struct GuessCourse: Codable, Hashable, Sendable {
  public struct Reveal: Codable, Hashable, Sendable { public let beatUp, beatDown, missDown, missUp, unknown, inLine, tryAgain: String }
  public let unit: String; public let ladder: [String]; public let tips: [String: String]; public let reveal: Reveal
  /// After a reveal, the lesson that explains it (reveal key → lesson id).
  public var learn: [String: String]? = nil
}
/// `garden`: the Moon Garden side's own ladder (growth, baskets, fees).
public struct PiggyCourse: Codable, Hashable, Sendable { public let unit: String; public let ladder: [String]; public var garden: [String]? = nil; public let peekLimit: Int; public let tips: [String: String] }
public struct ReviewConfig: Codable, Hashable, Sendable {
  public let intervals: [Int]; public let retireAt: Int; public let perStop: Int; public let pass: Double
  public init(intervals: [Int], retireAt: Int, perStop: Int, pass: Double) { self.intervals = intervals; self.retireAt = retireAt; self.perStop = perStop; self.pass = pass }
  public static let standard = ReviewConfig(intervals: [0, 1, 3, 7], retireAt: 4, perStop: 5, pass: 0.8)
}
public struct Assessment: Codable, Hashable, Sendable { public let id: String; public let unit: String; public let title: String; public let pass: Double; public let items: [String]? }

/// Core's manifest, as exported at the top of kids-content.json (`pack`).
public struct PackMeta: Codable, Hashable, Sendable {
  public let id: String; public let title: String; public let version: String; public let kind: String
  public let requires: PackRequires; public let ages: PackAges; public let tracks: [PackTrack]; public let curators: [PackPerson]; public let reviewers: [PackPerson]
}

public struct LessonPack: Codable, Hashable, Sendable, Identifiable {
  public var format: Int
  public var id: String
  public var title: String
  public var version: String
  public var kind: String           // core | extend | replace
  public var requires: PackRequires
  public var ages: PackAges
  public var tracks: [PackTrack]
  public var curators: [PackPerson]
  public var reviewers: [PackPerson]
  public var creator: PackCreator?
  public var objectives: [PackObjective]
  public var units: [PackUnit]
  public var glossary: [String: KidTerm]
  public var words: [KidWord]
  public var games: [GameSpec]
  public var guess: GuessCourse?
  public var piggy: PiggyCourse?
  public var review: ReviewConfig?
  public var assessments: [Assessment]
  public var regions: [RegionSpec]
  public var glyphs: [String]

  /// Shown to kids before a creator's lessons: guest hosts are always disclosed on screen.
  public var hostBadge: String? { creator.map { $0.fictional ? "Made-up guest host" : "Guest host" } }
  public var lessonCount: Int { units.reduce(0) { $0 + $1.lessons.count } }
  public var signedBy: [String] { reviewers.compactMap { (p: PackPerson) -> String? in (p.signedOff ?? "").isEmpty ? nil : p.role } }
}

public struct PackIssue: Hashable, Sendable { public let code: String; public let at: String; public let msg: String }

/// Card fit limits (characters): the same as the web's FIT and what CardFitTests lays out at iPhone SE size.
public enum Fit { public static let title = 40, say = 110, q = 90, option = 42, why = 100, sortQ = 60, bucket = 14, label = 20, talk = 160 }
/// Bounds for a `grow` step (the web's GROW).
public enum GrowBounds { public static let minYears = 2, maxYears = 10; public static let maxRate = 30.0, maxStart = 100000.0 }

public enum PackRules {
  public static let format = 1
  /// The kids-content version this build understands.
  public static let contentVersion = KidsContent.supportedVersion
  public static let nodeKinds = ["unit", "lesson", "quest", "game", "guess", "review", "timeMachine", "practice"]
  public static let gameIds = GameKind.allCases.map(\.rawValue)
  public static let questIds = ["lemonade", "save", "dividends"]
  public static let hues = ["lemon", "orange", "coral", "berry", "grape", "sky", "teal", "mint", "gold", "slate", "choco", "ink"]
  /// Same lists as the web (shared/kidsPacks.ts); the vectors prove they agree.
  public static let linkPatterns = ["https?://", "www\\.", "\\b[a-z0-9-]+\\.(com|net|org|io|app|tv|gg|ly|co|me)\\b", "(^|\\s)@[a-z0-9_]{2,}", "(^|\\s)#[a-z][a-z0-9_]+"]
  public static let bannedPhrases = [
    "buy now", "sell now", "buy it now", "buy today", "sell today", "you should buy", "you should sell", "buy when", "sell when",
    "time to buy", "time to sell", "must buy", "guaranteed", "guarantee", "can't lose", "cannot lose", "risk-free", "risk free", "sure thing",
    "will go up", "will double", "will skyrocket", "to the moon", "price target", "strong buy",
    "follow me", "follow us", "subscribe", "link in bio", "promo code", "discount code", "sponsored", "sponsor", "my channel", "my videos",
    "my store", "merch", "download", "sign up",
  ]
  /// Compiled once: the validator runs thousands of checks per pack (at boot when packs are on).
  private static let cache = RegexCache()
  final class RegexCache: @unchecked Sendable {
    private var m: [String: NSRegularExpression] = [:]; private let lock = NSLock()
    func get(_ p: String, _ o: NSRegularExpression.Options) -> NSRegularExpression? {
      lock.withLock {
        let k = "\(o.rawValue)|\(p)"
        if let r = m[k] { return r }
        let r = try? NSRegularExpression(pattern: p, options: o); m[k] = r; return r
      }
    }
  }
  static func has(_ pattern: String, _ s: String, _ opts: NSRegularExpression.Options = [.caseInsensitive]) -> Bool {
    guard let re = cache.get(pattern, opts) else { return false }
    return re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) != nil
  }
  static func unquoted(_ s: String) -> String {
    guard let re = cache.get("\"[^\"]*\"|“[^”]*”", []) else { return s }
    return re.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: " ")
  }
  static func lower(_ s: String) -> String { s.lowercased().replacingOccurrences(of: "’", with: "'") }
  static func words(_ s: String) -> Int { s.split(whereSeparator: { $0.isWhitespace }).count }
  static func hasEmoji(_ s: String) -> Bool { has("\\p{Extended_Pictographic}", s, []) }

  /// Every kid-visible string, with where it lives and whether advice phrases are allowed there (wrong answers).
  public static func texts(_ p: LessonPack) -> [(at: String, text: String, distractor: Bool)] {
    var out: [(String, String, Bool)] = []
    func add(_ at: String, _ t: String?, _ d: Bool = false) { if let t, !t.isEmpty { out.append((at, t, d)) } }
    add("title", p.title)
    if let c = p.creator { add("creator.bio", c.bio); add("creator.voice", c.voice) }
    for t in p.tracks { add("tracks.\(t.id)", t.title); add("tracks.\(t.id)", t.blurb) }
    for u in p.units {
      add("units.\(u.id)", u.title); add("units.\(u.id)", u.blurb)
      for (i, t) in (u.talk ?? []).enumerated() { add("units.\(u.id).talk.\(i)", t) }
      for l in u.lessons {
        add("lessons.\(l.id)", l.title)
        for (i, s) in l.steps.enumerated() {
          let at = "lessons.\(l.id).\(i)"
          switch s {
          case let .say(_, text): add(at, text)
          case let .check(c): add(at, c.q); add(at, c.why); for (k, o) in c.options.enumerated() { add(at, o, k != c.answer) }
          case let .sort(q, buckets, items, why): add(at, q); add(at, why); buckets.forEach { add(at, $0) }; items.forEach { add(at, $0.text) }
          case let .example(x): add(at, x.text); x.lines.forEach { add(at, $0) }
          case let .grow(g): add(at, g.text); add(at, g.label); add(at, g.vs?.label)
          }
        }
      }
    }
    for (k, t) in p.glossary { add("glossary.\(k)", t.word); add("glossary.\(k)", t.means); add("glossary.\(k)", t.example) }
    for (i, w) in p.words.enumerated() { add("words.\(i)", w.word); add("words.\(i)", w.means); add("words.\(i)", w.example) }
    if let g = p.guess {
      for (k, v) in g.tips { add("guess.tips.\(k)", v) }
      let r = g.reveal
      for (k, v) in [("beatUp", r.beatUp), ("beatDown", r.beatDown), ("missDown", r.missDown), ("missUp", r.missUp), ("unknown", r.unknown), ("inLine", r.inLine), ("tryAgain", r.tryAgain)] { add("guess.reveal.\(k)", v) }
    }
    if let pg = p.piggy { for (k, v) in pg.tips { add("piggy.tips.\(k)", v) } }
    for r in p.regions { add("regions.\(r.id)", r.name); add("regions.\(r.id)", r.blurb); for n in r.nodes { add("regions.\(r.id).\(n.id)", n.title) } }
    return out
  }

  /// Every emoji (glyph key) a pack draws.
  public static func glyphs(_ p: LessonPack) -> Set<String> {
    var g = Set<String>()
    for u in p.units {
      g.insert(u.emoji)
      for l in u.lessons {
        g.insert(l.emoji)
        for s in l.steps {
          if case let .say(e, _) = s { g.insert(e) }
          if case let .example(x) = s { g.insert(x.emoji) }
          if case let .sort(_, _, items, _) = s { items.forEach { g.insert($0.emoji) } }
        }
      }
    }
    for t in p.glossary.values { g.insert(t.emoji) }
    for r in p.regions { g.insert(r.art); r.nodes.forEach { g.insert($0.art) } }
    return g
  }

  /// The prose a step reads out (worked-example lines are working, not prose, so they count only in `all`).
  static func prose(_ s: Step) -> String? {
    switch s { case let .say(_, t): return t; case let .example(x): return x.text; case let .grow(g): return g.text; default: return nil }
  }
  public static func lessonGrade(_ l: PackLesson) -> (say: Double, all: Double) {
    let say = l.steps.compactMap(prose).joined(separator: " ")
    let all = l.steps.map { s -> String in
      switch s {
      case let .say(_, t): return t; case let .check(c): return "\(c.q) \(c.why)"; case let .sort(q, _, _, why): return "\(q) \(why)"
      case let .example(x): return "\(x.text) \(x.lines.joined(separator: " "))"; case let .grow(g): return g.text
      }
    }.joined(separator: " ")
    return (say.isEmpty ? 0 : fkGrade(say), fkGrade(all))
  }

  /// Port of the web's validatePack. `base` = the Core pack an extend/replace pack builds on.
  public static func validate(_ p: LessonPack, base: LessonPack? = nil) -> [PackIssue] {
    var issues: [PackIssue] = []
    func bad(_ code: String, _ at: String, _ msg: String) { issues.append(PackIssue(code: code, at: at, msg: msg)) }
    if p.format != format { bad("format", "format", "format \(p.format) is not \(format)") }
    if !has("^[a-z0-9][a-z0-9-]{1,40}$", p.id, []) { bad("id", "id", "id must be 2–41 lowercase letters, digits or dashes") }
    if !has("^\\d+\\.\\d+\\.\\d+$", p.version, []) { bad("version", "version", "version must be semver") }
    if !["core", "extend", "replace"].contains(p.kind) { bad("kind", "kind", "unknown kind \(p.kind)") }
    if p.requires.content > contentVersion { bad("requires", "requires.content", "needs content version \(p.requires.content)") }
    if p.ages.min < 4 || p.ages.max > 13 || p.ages.min > p.ages.max { bad("ages", "ages", "ages must sit inside 4–13") }
    if p.units.isEmpty { bad("units", "units", "a pack needs at least one unit") }
    let trackIds = Set(p.tracks.map(\.id) + ["all"] + (base?.tracks.map(\.id) ?? []))
    let objIds = Set(p.objectives.map(\.id) + (base?.objectives.map(\.id) ?? []))
    let extendBase = p.kind == "extend" ? base : nil
    let baseUnits = Set(extendBase?.units.map(\.id) ?? [])
    let baseLessons = Set(extendBase?.units.flatMap { $0.lessons.map(\.id) } ?? [])
    var seenU = Set<String>(), seenL = Set<String>()
    for u in p.units {
      if seenU.contains(u.id) { bad("unit.dup", "units.\(u.id)", "duplicate unit id") }
      if baseUnits.contains(u.id) { bad("collide", "units.\(u.id)", "unit id already used by Core") }
      seenU.insert(u.id)
      if let t = u.track, !trackIds.contains(t) { bad("track", "units.\(u.id)", "unknown track \(t)") }
      if u.lessons.isEmpty { bad("unit.empty", "units.\(u.id)", "unit has no lessons") }
      if let talk = u.talk, talk.isEmpty || talk.count > 3 || talk.contains(where: { $0.trimmingCharacters(in: .whitespaces).isEmpty || $0.count > Fit.talk }) { bad("talk", "units.\(u.id)", "1–3 dinner-table prompts") }
      for l in u.lessons {
        let at = "lessons.\(l.id)"
        if seenL.contains(l.id) { bad("lesson.dup", at, "duplicate lesson id") }
        if baseLessons.contains(l.id) { bad("collide", at, "lesson id already used by Core") }
        seenL.insert(l.id)
        if let t = l.track, !trackIds.contains(t) { bad("track", at, "unknown track \(t)") }
        for o in l.objectives ?? [] where !objIds.contains(o) { bad("objective.ref", at, "unknown objective \(o)") }
        if let since = l.since, !has("^\\d+\\.\\d+\\.\\d+$", since, []) { bad("since", at, "since must be a pack version") }
        // Fit: every step shows on one card with no scrolling (iPhone SE at large text).
        if l.title.count > Fit.title { bad("fit", at, "title too long") }
        for (i, s) in l.steps.enumerated() {
          let long: Bool
          switch s {
          case let .say(_, t): long = t.count > Fit.say
          case let .check(c): long = c.q.count > Fit.q || c.options.count > 3 || c.options.contains { $0.count > Fit.option } || c.why.count > Fit.why
          case let .sort(q, buckets, items, _): long = q.count > Fit.sortQ || items.count > 6 || items.contains { $0.text.count > Fit.option } || buckets.contains { $0.count > Fit.bucket }
          case let .example(x): long = x.text.count > Fit.say || x.lines.count > 4 || x.lines.contains { $0.count > Fit.option }
          case let .grow(g): long = g.text.count > Fit.say || g.label.count > Fit.label || (g.vs?.label.count ?? 0) > Fit.label
          }
          if long { bad("fit", "\(at).\(i)", "too long to fit one card") }
        }
        if l.steps.count < 3 || l.steps.count > 7 { bad("lesson.steps", at, "a lesson has 3–7 steps") }
        if !l.steps.contains(where: \.isQuiz) { bad("lesson.steps", at, "a lesson needs a check or a sort") }
        for (i, s) in l.steps.enumerated() {
          let sat = "\(at).\(i)"
          switch s {
          case let .say(_, text): if words(text) > 22 { bad("say.long", sat, "a say card is at most 22 words") }
          case let .check(c):
            if c.options.count < 2 || c.options.count > 4 { bad("check.options", sat, "2–4 options") }
            if !(c.answer >= 0 && c.answer < c.options.count) { bad("check.answer", sat, "answer out of range") }
            if Set(c.options).count != c.options.count { bad("check.options", sat, "options repeat") }
          case let .sort(_, buckets, items, _):
            if buckets.count != 2 { bad("sort.buckets", sat, "a sort has 2 buckets") }
            if items.count < 4 || Set(items.map(\.b)).count != 2 || items.contains(where: { $0.b != 0 && $0.b != 1 }) { bad("sort.items", sat, "4+ items across both buckets") }
          case let .example(x):
            if words(x.text) > 22 { bad("say.long", sat, "an example's setup is at most 22 words") }
            if x.lines.count < 2 || x.lines.count > 4 || x.lines.contains(where: { $0.trimmingCharacters(in: .whitespaces).isEmpty }) { bad("example.lines", sat, "a worked example has 2–4 lines") }
          case let .grow(g):
            if words(g.text) > 22 { bad("say.long", sat, "a grow card is at most 22 words") }
            func okRate(_ v: Double?) -> Bool { v.map { $0.isFinite && $0 > 0 && $0 <= GrowBounds.maxRate } ?? false }
            if !["garden", "price", "owe"].contains(g.show) { bad("grow", sat, "unknown picture") }
            if g.years < GrowBounds.minYears || g.years > GrowBounds.maxYears { bad("grow", sat, "years out of range") }
            if !okRate(g.rate) { bad("grow", sat, "rate out of range") }
            if !(g.start >= 1 && g.start <= GrowBounds.maxStart && g.start.rounded() == g.start) { bad("grow", sat, "start must be a whole number") }
            if g.label.trimmingCharacters(in: .whitespaces).isEmpty { bad("grow", sat, "a grow step names its row") }
            if let v = g.vs, !["jar", "simple", "rate"].contains(v.kind) || v.label.trimmingCharacters(in: .whitespaces).isEmpty || (v.kind == "rate" && (!okRate(v.rate) || v.rate == g.rate)) { bad("grow", sat, "bad comparison row") }
          }
        }
        if !l.steps.isEmpty { let g = lessonGrade(l); if g.say > 5 || g.all > 5.5 { bad("readability", at, "reading grade above 5 / 5.5") } }
      }
    }
    let baseTerms = Set(extendBase?.glossary.keys.map { $0 } ?? [])
    for (k, t) in p.glossary {
      if !has("^[a-z][a-z0-9-]*$", k, []) { bad("glossary.key", "glossary.\(k)", "glossary keys are lowercase") }
      if baseTerms.contains(k) { bad("collide", "glossary.\(k)", "word already in Core") }
      if fkGrade("\(t.means) \(t.example)") > 5 { bad("readability", "glossary.\(k)", "glossary card reads above grade 5") }
    }
    let termText = (p.glossary.values.map { "\($0.means) \($0.example)" } + p.words.map { "\($0.means) \($0.example)" }).joined(separator: " ")
    if !termText.isEmpty && fkGrade(termText) > 5 { bad("readability", "glossary", "glossary + words read above grade 5") }

    let allLessons = seenL.union(base?.units.flatMap { $0.lessons.map(\.id) } ?? [])
    let allUnits = seenU.union(base?.units.map(\.id) ?? [])
    if p.kind == "core" && (p.guess == nil || p.piggy == nil || p.review == nil) { bad("course", "guess", "Core needs guess, piggy and review") }
    for (name, unit, ladder) in [("guess", p.guess?.unit, p.guess?.ladder), ("piggy", p.piggy?.unit, p.piggy?.ladder)] {
      guard let unit, let ladder else { continue }
      if !allUnits.contains(unit) { bad("course", "\(name).unit", "unknown unit \(unit)") }
      for id in ladder where !allLessons.contains(id) { bad("course", "\(name).ladder", "unknown lesson \(id)") }
    }
    if let g = p.guess { for id in g.ladder where g.tips[id] == nil { bad("course", "guess.tips", "no tip for \(id)") } }
    for (k, id) in p.guess?.learn ?? [:] where !allLessons.contains(id) { bad("course", "guess.learn.\(k)", "unknown lesson \(id)") }
    for id in p.piggy?.garden ?? [] where !allLessons.contains(id) { bad("course", "piggy.garden", "unknown lesson \(id)") }
    if let r = p.review, r.perStop < 1 || r.retireAt != r.intervals.count || r.pass <= 0 || r.pass > 1 { bad("course", "review", "review config") }
    for a in p.assessments where !allUnits.contains(a.unit) { bad("assessment", "assessments.\(a.id)", "unknown unit \(a.unit)") }

    if (p.kind == "core" || p.kind == "replace") && p.regions.isEmpty { bad("regions", "regions", "Core and replace packs draw the map") }
    let baseRegions = Set(extendBase?.regions.map(\.id) ?? [])
    let baseNodes = Set(extendBase?.regions.flatMap { $0.nodes.map(\.id) } ?? [])
    var seenN = Set<String>()
    for r in p.regions {
      if baseRegions.contains(r.id) { bad("collide", "regions.\(r.id)", "region id already used by Core") }
      if !hues.contains(r.hue) { bad("region.hue", "regions.\(r.id)", "unknown hue \(r.hue)") }
      if r.nodes.count < 2 { bad("region.nodes", "regions.\(r.id)", "a region needs 2+ stops") }
      if let last = r.nodes.last, last.kind == "review" || last.kind == "timeMachine" {} else { bad("region.boss", "regions.\(r.id)", "a region ends with a boss") }
      for n in r.nodes {
        let at = "regions.\(r.id).\(n.id)"
        if seenN.contains(n.id) || baseNodes.contains(n.id) { bad("node.dup", at, "duplicate map stop id") }
        seenN.insert(n.id)
        guard nodeKinds.contains(n.kind) else { bad("node.kind", at, "unknown kind \(n.kind)"); continue }
        let ref = n.ref ?? ""
        let ok: Bool
        switch n.kind {
        case "unit": ok = allUnits.contains(ref)
        case "lesson": ok = allLessons.contains(ref)
        case "quest": ok = questIds.contains(ref)
        case "game": ok = gameIds.contains(ref)
        case "review": ok = p.regions.contains { $0.id == ref }
        case "timeMachine": ok = has("^[A-Z.]{1,6}$", ref, [])
        default: ok = true
        }
        if !ok { bad("node.ref", at, "\(n.kind) points at \(ref)") }
      }
    }
    let declared = Set(p.glyphs)
    for g in glyphs(p) where !declared.contains(g) { bad("glyphs", "glyphs", "\(g) is drawn but not declared") }
    for (at, text, distractor) in texts(p) {
      let t = lower(text)
      if linkPatterns.contains(where: { has($0, t) }) { bad("link", at, "looks like a link or handle") }
      if !distractor { let u = lower(unquoted(text)); if bannedPhrases.contains(where: { u.contains($0) }) { bad("banned", at, "reads as advice or promotion") } }
      if !at.hasPrefix("title") && hasEmoji(text) { bad("emoji.text", at, "emoji belong in glyph fields") }
    }
    if p.kind != "core" {
      if p.creator == nil { bad("creator", "creator", "guest and replace packs name their creator") }
      for role in ["teacher", "markets"] where !p.reviewers.contains(where: { $0.role == role && !($0.signedOff ?? "").isEmpty }) { bad("review", "reviewers", "needs a \(role) sign-off") }
    }
    return issues
  }

  /// On the remote channel only with both experts AND a human signed off.
  public static func channelReady(_ p: LessonPack) -> Bool {
    validate(p).filter { $0.code != "collide" }.isEmpty && ["teacher", "markets", "human"].allSatisfy { r in p.reviewers.contains { $0.role == r && !($0.signedOff ?? "").isEmpty } }
  }
}

// MARK: Composition: Core + enabled packs → the one curriculum a kid sees

extension KidsContent {
  /// Core as a LessonPack (what extend packs are validated against).
  public var corePack: LessonPack {
    LessonPack(format: 1, id: pack?.id ?? "core", title: pack?.title ?? "Moon Club Core", version: pack?.version ?? "1.0.0", kind: "core",
               requires: pack?.requires ?? PackRequires(content: 1, app: nil, core: nil), ages: pack?.ages ?? PackAges(min: 6, max: 11),
               tracks: pack?.tracks ?? [], curators: pack?.curators ?? [], reviewers: pack?.reviewers ?? [], creator: nil, objectives: objectives ?? [],
               units: units.map { u in PackUnit(id: u.id, title: u.title, emoji: u.emoji, blurb: u.blurb, track: u.track, objectives: nil, talk: u.talk,
                                                 lessons: lessons.filter { $0.unit == u.id }.map { PackLesson(id: $0.id, title: $0.title, emoji: $0.emoji, track: $0.track, objectives: $0.objectives, since: $0.since, steps: $0.steps) }) },
               glossary: terms, words: words, games: games ?? [], guess: guessCourse, piggy: piggyCourse, review: review, assessments: assessments ?? [],
               regions: regions ?? [], glyphs: glyphs ?? [])
  }

  /// Bundled packs (Core is always on; these are the optional ones).
  public var bundledPacks: [LessonPack] { packs ?? [] }

  /// Core + the given packs. A replace pack swaps units, lessons, words and the map; extend packs add to them.
  /// Invalid packs are skipped (never shown broken).
  public func with(packs enabled: [LessonPack]) -> KidsContent {
    let base = corePack
    let ok = enabled.filter { $0.kind != "core" && PackRules.validate($0, base: base).isEmpty }
    guard !ok.isEmpty else { return self }
    var c = self
    func add(_ p: LessonPack) {
      c.units += p.units.map { Unit(id: $0.id, title: $0.title, emoji: $0.emoji, blurb: $0.blurb, track: $0.track, talk: $0.talk) }
      c.lessons += p.units.flatMap { u in u.lessons.map { Lesson(id: $0.id, unit: u.id, title: $0.title, emoji: $0.emoji, track: $0.track, objectives: $0.objectives, since: $0.since, steps: $0.steps) } }
      for (k, v) in p.glossary { c.terms[k] = v }
      c.words += p.words
      c.regions = (c.regions ?? []) + p.regions
      c.assessments = (c.assessments ?? []) + p.assessments
      c.glyphs = Array(Set(c.glyphs ?? []).union(p.glyphs)).sorted()
      c.objectives = (c.objectives ?? []) + p.objectives
    }
    if let rep = ok.first(where: { $0.kind == "replace" }) {
      c.units = []; c.lessons = []; c.regions = []; c.assessments = []
      if !rep.words.isEmpty { c.words = [] }
      add(rep)
    }
    for p in ok where p.kind == "extend" { add(p) }
    c.activePacks = ok.map(\.id)
    return c
  }
}

// MARK: The curated remote channel (signed manifests from mutaafaziz.com/metaphases/api/kids/packs)

public enum PackChannel {
  /// The remote channel is OFF in this build: packs ship in the app bundle. Flip to true (or launch a DEBUG
  /// build with -packsRemote) once a human has signed a pack and `npm run packs:sign` marked it ready.
  public static let remoteEnabled = false
  public static let indexPath = "api/kids/packs"
  public struct Entry: Codable, Hashable, Sendable { public let id: String; public let version: String; public let title: String; public let kind: String; public let creator: String?; public let ready: Bool?; public let sha256: String; public let sig: String }
  public struct Index: Codable, Sendable { public let format: Int; public let publicKey: String; public let packs: [Entry] }
  public enum Rejection: Error, Equatable, Sendable { case badSignature, wrongKey, notJSON(String), invalid([String]), notReady }

  /// Ed25519 over the exact bytes served. The key the app trusts ships in kids-content.json (`channel.publicKey`),
  /// never the one the server sends.
  public static func verify(body: Data, signature: String, publicKey: String) -> Bool {
    #if canImport(CryptoKit)
    guard let k = Data(base64Encoded: publicKey), let s = Data(base64Encoded: signature),
          let key = try? Curve25519.Signing.PublicKey(rawRepresentation: k) else { return false }
    return key.isValidSignature(s, for: body)
    #else
    return false
    #endif
  }

  /// Everything a downloaded pack must pass before a grown-up even sees it: the signature (with OUR key),
  /// decoding, the kids-rules validator against Core, and every sign-off including a human's.
  public static func accept(body: Data, signature: String, trustedKey: String, core: LessonPack) -> Result<LessonPack, Rejection> {
    guard verify(body: body, signature: signature, publicKey: trustedKey) else { return .failure(.badSignature) }
    let p: LessonPack
    do { p = try JSONDecoder().decode(LessonPack.self, from: body) } catch { return .failure(.notJSON(String(describing: error))) }
    let issues = PackRules.validate(p, base: core)
    guard issues.isEmpty else { return .failure(.invalid(issues.map(\.code))) }
    guard PackRules.channelReady(p) else { return .failure(.notReady) }
    return .success(p)
  }

  public static func indexRequest(base: URL = apiBase) -> URLRequest { URLRequest(url: base.appendingPathComponent(indexPath)) }
  public static func packRequest(_ id: String, base: URL = apiBase) -> URLRequest { URLRequest(url: base.appendingPathComponent("\(indexPath)/\(id)")) }
}
