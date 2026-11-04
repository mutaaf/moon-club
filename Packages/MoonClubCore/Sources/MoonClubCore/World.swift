// Market World: the conquer-the-map learning journey. Regions hold nodes (a lesson trail, a quest, a
// game or a boss); each node earns 0–3 stars. Pure rules, so unlocking, stars and points are tested
// and merge cleanly across devices (stars are a per-node max in Sync.swift).
import Foundation

public enum GameKind: String, Codable, CaseIterable, Sendable {
  case buildCandle, readDay, candleMatch, spotTrend, drawTrend, findFloor, patternDetective, busyDay, smoothLine
}

public enum NodeKind: Hashable, Sendable {
  case unit(String)          // a Moon School unit played as a trail of one-minute lessons
  case lesson(String)        // one lesson
  case quest(String)         // a Luna quest chapter
  case game(GameKind)
  case guess                 // Guess the Report Card (opens the Guess screen)
  case review(String)        // boss: a captain's quiz over the region's lessons
  case timeMachine(String)   // boss: Chart Time Machine on a real company's chart
  case practice              // Review stop: spaced retrieval of missed and older questions (Review.swift). Optional.

  /// From a pack's node spec (kind + ref); nil for kinds or refs this build doesn't know.
  public init?(kind: String, ref: String?) {
    switch (kind, ref) {
    case let ("unit", r?): self = .unit(r)
    case let ("lesson", r?): self = .lesson(r)
    case let ("quest", r?): self = .quest(r)
    case let ("game", r?): guard let g = GameKind(rawValue: r) else { return nil }; self = .game(g)
    case ("guess", _): self = .guess
    case let ("review", r?): self = .review(r)
    case let ("timeMachine", r?): self = .timeMachine(r)
    case ("practice", _): self = .practice
    default: return nil
    }
  }
}

public struct WorldNode: Identifiable, Hashable, Sendable {
  public let id: String; public let title: String; public let art: String; public let kind: NodeKind
  public init(id: String, title: String, art: String, kind: NodeKind) { self.id = id; self.title = title; self.art = art; self.kind = kind }
  public var isBoss: Bool { if case .review = kind { return true }; if case .timeMachine = kind { return true }; return false }
  /// Optional stops (Review stops) never block the trail or the boss, and don't count toward map stars.
  public var isOptional: Bool { if case .practice = kind { return true }; return false }
}

public struct Region: Identifiable, Hashable, Sendable {
  public let id: String; public let name: String; public let blurb: String; public let art: String
  public let hue: String
  public let nodes: [WorldNode]
  public var boss: WorldNode { nodes[nodes.count - 1] }
}

public enum World {
  /// The seven regions, bottom of the map to the top. Nodes that point at content this build doesn't have
  /// (e.g. a lesson not exported yet) are dropped, never shown broken.
  public static func regions(_ c: KidsContent) -> [Region] {
    if let specs = c.regions, !specs.isEmpty {
      return specs.map { r in Region(id: r.id, name: r.name, blurb: r.blurb, art: r.art, hue: r.hue,
                                     nodes: r.nodes.compactMap { n in NodeKind(kind: n.kind, ref: n.ref).map { WorldNode(id: n.id, title: n.title, art: n.art, kind: $0) } }) }
        .map(dropMissing(c)).filter { $0.nodes.filter { !$0.isOptional }.count >= 2 }
    }
    return builtIn(c)
  }

  /// Nodes that point at content this build doesn't have are dropped, never shown broken.
  static func dropMissing(_ c: KidsContent) -> (Region) -> Region {
    let lessonIds = Set(c.lessons.map(\.id)), unitIds = Set(c.units.map(\.id))
    let chapterIds = Set(c.questChapters?.CHAPTERS.map(\.id) ?? []).union(["lemonade"])
    return { r in
      Region(id: r.id, name: r.name, blurb: r.blurb, art: r.art, hue: r.hue, nodes: r.nodes.filter { n in
        switch n.kind {
        case let .unit(u): return unitIds.contains(u)
        case let .lesson(l): return lessonIds.contains(l)
        case let .quest(q): return chapterIds.contains(q)
        default: return true
        }
      })
    }
  }

  /// The map before lesson packs (content without `regions`).
  static func builtIn(_ c: KidsContent) -> [Region] {
    let lessonIds = Set(c.lessons.map(\.id)), unitIds = Set(c.units.map(\.id))
    let chapterIds = Set(c.questChapters?.CHAPTERS.map(\.id) ?? []).union(["lemonade"])
    func ok(_ n: WorldNode) -> Bool {
      switch n.kind {
      case let .unit(u): return unitIds.contains(u)
      case let .lesson(l): return lessonIds.contains(l)
      case let .quest(q): return chapterIds.contains(q)
      default: return true
      }
    }
    func n(_ id: String, _ t: String, _ a: String, _ k: NodeKind) -> WorldNode { WorldNode(id: id, title: t, art: a, kind: k) }
    let all: [Region] = [
      Region(id: "coast", name: "Lemonade Coast", blurb: "Companies, shares and prices", art: "🍋", hue: "lemon", nodes: [
        n("coast-quest", "Luna's Lemonade Stand", "🍋", .quest("lemonade")),
        n("coast-money", "Money basics", "💰", .unit("money")),
        n("coast-companies", "Companies", "🏪", .unit("companies")),
        n("coast-shares", "Shares and the market", "🍕", .unit("shares")),
        n("coast-boss", "Captain's Quiz", "👑", .review("coast")),
      ]),
      Region(id: "isle", name: "Saver's Isle", blurb: "Saving, investing and dividends", art: "🌳", hue: "mint", nodes: [
        n("isle-growing", "Saving and investing", "🌱", .unit("growing")),
        n("isle-save", "Save or Grow?", "🌳", .quest("save")),
        n("isle-dividends", "Dividends", "🍰", .unit("dividends")),
        n("isle-slice", "Your Slice Pays You", "🪙", .quest("dividends")),
        n("isle-smart", "Money-smart", "🧠", .unit("smart")),
        n("isle-boss", "Island Quiz", "👑", .review("isle")),
      ]),
      Region(id: "canyon", name: "Candle Canyon", blurb: "A whole day in one picture", art: "🕯️", hue: "coral", nodes: [
        n("canyon-candle", "What's a candle?", "🕯️", .lesson("candle")),
        n("canyon-build", "Build the candle", "🧱", .game(.buildCandle)),
        n("canyon-wicks", "Wicks and colors", "📊", .lesson("wicks")),
        n("canyon-read", "Read the day", "👀", .game(.readDay)),
        n("canyon-tug", "Tug-of-war days", "🤝", .lesson("tug-of-war")),
        n("canyon-match", "Candle match", "🧩", .game(.candleMatch)),
        n("canyon-boss", "Chart Time Machine", "⏳", .timeMachine("AAPL")),
      ]),
      Region(id: "trails", name: "Trend Trails", blurb: "Up, down or sideways?", art: "🛤️", hue: "orange", nodes: [
        n("trails-trend", "What's a trend?", "📈", .lesson("trend")),
        n("trails-spot", "Spot the trend", "🔍", .game(.spotTrend)),
        n("trails-sideways", "Sideways days", "〰️", .lesson("sideways")),
        n("trails-draw", "Draw the trendline", "🛤️", .game(.drawTrend)),
        n("trails-zoom", "Zoom out", "🔭", .lesson("zoom-out")),
        n("trails-boss", "Chart Time Machine", "⏳", .timeMachine("DIS")),
      ]),
      Region(id: "peaks", name: "Pattern Peaks", blurb: "Floors, ceilings and clues", art: "⛰️", hue: "grape", nodes: [
        n("peaks-floor", "Floors and ceilings", "🪜", .lesson("floor-ceiling")),
        n("peaks-find", "Find the floor", "🔍", .game(.findFloor)),
        n("peaks-breakout", "Breakouts", "🚀", .lesson("breakout")),
        n("peaks-detective", "Pattern detective", "🕵️", .game(.patternDetective)),
        n("peaks-clues", "Clues, not promises", "🤞", .lesson("clues")),
        n("peaks-boss", "Chart Time Machine", "⏳", .timeMachine("NKE")),
      ]),
      Region(id: "sea", name: "Signal Sea", blurb: "Busy days and smooth lines", art: "🌊", hue: "sky", nodes: [
        n("sea-volume", "Volume", "🔊", .lesson("volume")),
        n("sea-busy", "Busy day?", "📣", .game(.busyDay)),
        n("sea-smooth", "The smooth line", "〰️", .lesson("moving-average")),
        n("sea-smooth-game", "Smooth it out", "📈", .game(.smoothLine)),
        n("sea-jump", "Report-day jumps", "🎢", .lesson("report-jump")),
        n("sea-boss", "Chart Time Machine", "⏳", .timeMachine("KO")),
      ]),
      Region(id: "castle", name: "Report Card Castle", blurb: "Earnings day: beat or miss", art: "🏰", hue: "berry", nodes: [
        n("castle-report", "Report cards", "📝", .unit("report")),
        n("castle-guess", "Guess the Report Card", "🎯", .guess),
        n("castle-boss", "Chart Time Machine", "⏳", .timeMachine("MCD")),
      ]),
    ]
    return all.map { r in Region(id: r.id, name: r.name, blurb: r.blurb, art: r.art, hue: r.hue, nodes: r.nodes.filter(ok)) }
      .filter { $0.nodes.count >= 2 }
  }

  /// The lessons a node covers (for review bosses and the "explain" panel).
  public static func lessons(of r: Region, _ c: KidsContent) -> [Lesson] {
    r.nodes.flatMap { n -> [Lesson] in
      switch n.kind {
      case let .unit(u): return c.lessons.filter { $0.unit == u }
      case let .lesson(l): return c.lessons.filter { $0.id == l }
      default: return []
      }
    }
  }

  /// 0–3 stars for a node. Lesson-based nodes earn stars from finished lessons; games and bosses store theirs.
  public static func stars(_ n: WorldNode, _ s: KidsState, _ c: KidsContent) -> Int {
    let stored = min(3, s.stars?[n.id] ?? 0)
    switch n.kind {
    case let .unit(u):
      // Optional (challenge) lessons never count. Lessons added to a unit later (`since`) are a bonus: a child
      // who finished the unit as it was keeps their stars when it grows.
      let ls = c.requiredLessons(u)
      func score(_ ls: [Lesson]) -> Int {
        let done = ls.filter { s.lessons.contains($0.id) }.count
        guard !ls.isEmpty, done > 0 else { return 0 }
        return done == ls.count ? 3 : done * 2 >= ls.count ? 2 : 1
      }
      return max(stored, score(ls), score(ls.filter { $0.since == nil }))
    case let .lesson(l): return max(stored, s.lessons.contains(l) ? 3 : 0)
    case let .quest(q):
      let done = q == "lemonade" ? s.questDone : s.chapters(c).contains(q)
      return max(stored, done ? 3 : 0)
    case .guess:
      let right = s.guesses.filter { $0.result == .right }.count
      return max(stored, s.guesses.isEmpty ? 0 : right >= 3 ? 3 : right >= 1 ? 2 : 1)
    case .game, .review, .timeMachine, .practice: return stored
    }
  }

  public static func conquered(_ r: Region, _ s: KidsState, _ c: KidsContent) -> Bool { stars(r.boss, s, c) > 0 }

  /// The lessons a Review stop in this region draws from: this region's and every earlier region's.
  public static func reviewScope(_ r: Region, _ rs: [Region], _ c: KidsContent) -> Set<String> {
    let upTo = rs.prefix { $0.id != r.id } + [r]
    return Set(upTo.flatMap { lessons(of: $0, c) }.map(\.id))
  }

  /// Region 0 is always open; the next opens once the one before is conquered (its boss has a star).
  public static func regionOpen(_ i: Int, _ rs: [Region], _ s: KidsState, _ c: KidsContent) -> Bool {
    i <= 0 || (i < rs.count && conquered(rs[i - 1], s, c))
  }

  /// A node opens once the node before it has a star; the boss opens once every other node has one.
  public static func nodeOpen(_ n: WorldNode, in r: Region, regionOpen: Bool, _ s: KidsState, _ c: KidsContent) -> Bool {
    guard regionOpen, let i = r.nodes.firstIndex(of: n) else { return false }
    if n.isOptional { return true }
    // A stop you already have stars on never locks again (new stops can appear before it when the map grows).
    if stars(n, s, c) > 0 { return true }
    if n.isBoss { return r.nodes.dropLast().filter { !$0.isOptional }.allSatisfy { stars($0, s, c) > 0 } }
    guard let prev = r.nodes[..<i].last(where: { !$0.isOptional }) else { return true }
    return stars(prev, s, c) > 0
  }

  /// Where Luna's rocket waits: the first open node without a star in the first land not yet conquered (new
  /// stops in a conquered land don't pull the rocket back); then any open node without a star; then the last boss.
  public static func current(_ rs: [Region], _ s: KidsState, _ c: KidsContent) -> (region: Int, node: Int) {
    for (ri, r) in rs.enumerated() where regionOpen(ri, rs, s, c) && !conquered(r, s, c) {
      for (ni, n) in r.nodes.enumerated() where !n.isOptional && nodeOpen(n, in: r, regionOpen: true, s, c) && stars(n, s, c) == 0 { return (ri, ni) }
    }
    for (ri, r) in rs.enumerated() where regionOpen(ri, rs, s, c) {
      for (ni, n) in r.nodes.enumerated() where !n.isOptional && nodeOpen(n, in: r, regionOpen: true, s, c) && stars(n, s, c) == 0 { return (ri, ni) }
    }
    guard !rs.isEmpty else { return (0, 0) }
    let last = rs.indices.last { regionOpen($0, rs, s, c) } ?? 0
    return (last, rs[last].nodes.count - 1)
  }

  /// Points from the map: 5 per star on games and bosses (lessons and quests already score on their own).
  public static func points(_ s: KidsState, _ c: KidsContent) -> Int {
    guard let st = s.stars, !st.isEmpty else { return 0 }
    return regions(c).flatMap(\.nodes).reduce(0) { acc, n in
      switch n.kind { case .game, .review, .timeMachine: return acc + 5 * stars(n, s, c); default: return acc }
    }
  }

  public static func totalStars(_ s: KidsState, _ c: KidsContent) -> (have: Int, of: Int) {
    let ns = regions(c).flatMap(\.nodes).filter { !$0.isOptional }
    return (ns.reduce(0) { $0 + stars($1, s, c) }, ns.count * 3)
  }

  /// Stars from a round score (right answers out of total).
  public static func starsFor(right: Int, of total: Int) -> Int {
    guard total > 0 else { return 0 }
    let r = Double(right) / Double(total)
    return r >= 0.99 ? 3 : r >= 0.6 ? 2 : 1
  }
}
