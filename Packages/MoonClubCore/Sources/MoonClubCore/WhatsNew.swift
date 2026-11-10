import Foundation

/// "What's new" after an update. Every release-notes/<version>.md has a `## Luna's news` section, the one
/// source for the in-app update modal (the rest of the file is TestFlight's "What to Test", the GitHub release
/// and the App Store "What's New"):
///
///     ## Luna's news
///     > Moon Club got a super suit!                      ← hero headline (≤ 40 characters)
///     - [hand.point.up.left.fill] **Super button!** Tap it. I pick your next step!
///       ↑ art: an SF Symbol, a `custom.*` mark or an `Art` emoji key; **title** (a few words); one short line
///     - [sparkles] **Lights, camera, lessons!** Every lesson card is a little show. → moon-school
///       ↑ optional `→ <place>` at the end: the card gets a button that closes the modal and opens that place
///         (`NewsPlace`: a kid-side `DeepLink` route like `story`, `world`, `guess`, `piggy`, `luna`, or `moon-school`)
///
/// Since 0.17.0 the current version must have a headline and 2–4 titled cards (`lint`). Older notes are plain
/// `- [symbol] Text` lines; they still parse (no headline, no titles). A fresh install sees nothing.
public struct ReleaseNews: Equatable, Sendable {
  public struct Item: Equatable, Sendable {
    public let symbol: String
    public let title: String?
    public let text: String
    /// Where the card's button goes (nil = a plain card: the feature has no place to open).
    public let go: NewsPlace?
    public init(symbol: String, title: String? = nil, text: String, go: NewsPlace? = nil) {
      self.symbol = symbol; self.title = title; self.text = text; self.go = go
    }
  }
  public let version: String
  public let title: String
  public let headline: String?
  public let items: [Item]
  /// `→ place` tokens that didn't resolve to a kid place (the card stays plain; `lint` reports them).
  public let badPlaces: [String]
  public init(version: String, title: String, headline: String? = nil, items: [Item], badPlaces: [String] = []) {
    self.version = version; self.title = title; self.headline = headline; self.items = items; self.badPlaces = badPlaces
  }
}

/// A place a What's-new card can open. Kid places only: anything behind the parental gate (`DeepLink.needsGrownUp`)
/// is refused, so a card never leads a kid toward settings.
public enum NewsPlace: Equatable, Hashable, Sendable {
  /// A tab or kid place reachable by a link (Story, World, a lesson, Guess, Game Night, Piggy, Garden, Ask Luna).
  case link(DeepLink)
  /// Moon School: the lesson list (pushed on the World map; it has no web page, so no `DeepLink`).
  case moonSchool

  /// `moon-school`, or any kid route `DeepLink` knows (`story`, `world`, `school/<lesson id>`, `guess`, …).
  /// Unknown, malformed or grown-up places are nil.
  public init?(_ token: String) {
    let t = token.trimmingCharacters(in: .whitespaces).lowercased()
    if t == "moon-school" { self = .moonSchool; return }
    let segs = t.split(separator: "/").map(String.init)
    guard !segs.isEmpty, segs.count <= 2 else { return nil }
    let l = DeepLink.route(segs)
    // `route` sends anything it doesn't know Home; only a real home token may mean Home.
    if l == .home, !["home", "story"].contains(t) { return nil }
    guard !l.needsGrownUp else { return nil }
    self = .link(l)
  }
}

public enum WhatsNew {
  public static let heading = "## Luna's news"
  /// The modal shows at most this many cards (2–4 per version is the house style).
  public static let maxCards = 4
  /// Kid-sized copy: a hero headline, card titles of a few words, one short line each.
  public static let headlineMax = 40, titleMax = 26, lineMax = 64, titleWordsMax = 4
  /// The first version written in the headline + titled-card format (older notes are grandfathered).
  public static let cardsSince = "0.17.0"
  /// Marks a card's destination at the end of its line: `… line → moon-school`.
  public static let goMark = "→"

  public static func parse(version: String, markdown: String) -> ReleaseNews {
    let lines = markdown.components(separatedBy: "\n")
    let title = lines.first { $0.hasPrefix("# ") }.map { String($0.dropFirst(2)).trimmingCharacters(in: .whitespaces) } ?? "Moon Club \(version)"
    var items: [ReleaseNews.Item] = []
    var headline: String?
    var badGo: [String] = []
    var inside = false
    for raw in lines {
      let line = raw.trimmingCharacters(in: .whitespaces)
      if line.hasPrefix("## ") { inside = line == heading; continue }
      guard inside else { continue }
      if line.hasPrefix(">"), headline == nil {
        let h = line.dropFirst().replacingOccurrences(of: "**", with: "").trimmingCharacters(in: .whitespaces)
        if !h.isEmpty { headline = h }
        continue
      }
      guard line.hasPrefix("- ["), let close = line.firstIndex(of: "]") else { continue }
      let symbol = String(line[line.index(line.startIndex, offsetBy: 3)..<close]).trimmingCharacters(in: .whitespaces)
      var text = String(line[line.index(after: close)...]).trimmingCharacters(in: .whitespaces)
      var cardTitle: String?
      if text.hasPrefix("**"), let end = text.dropFirst(2).range(of: "**") {
        cardTitle = String(text[text.index(text.startIndex, offsetBy: 2)..<end.lowerBound]).trimmingCharacters(in: .whitespaces)
        text = String(text[end.upperBound...]).trimmingCharacters(in: .whitespaces)
        if cardTitle?.isEmpty == true { cardTitle = nil }
      }
      var go: NewsPlace?
      // Only a single word after the last arrow is a place; "A → B" inside a sentence stays text.
      if let arrow = text.range(of: goMark, options: .backwards),
         case let token = String(text[arrow.upperBound...]).trimmingCharacters(in: .whitespaces), !token.contains(" ") {
        go = NewsPlace(token)
        text = String(text[..<arrow.lowerBound]).trimmingCharacters(in: .whitespaces)
        if go == nil { badGo.append(token) }
      }
      if !symbol.isEmpty, !text.isEmpty { items.append(.init(symbol: symbol, title: cardTitle, text: text, go: go)) }
    }
    return ReleaseNews(version: version, title: title, headline: headline, items: items, badPlaces: badGo)
  }

  /// Problems with a version's kid copy (empty = fine). Same rules as `asc.mjs notes`.
  public static func lint(_ n: ReleaseNews) -> [String] {
    var out: [String] = n.badPlaces.map { "unknown card place → \($0) (see release-notes/README.md)" }
    guard !less(n.version, cardsSince) else {
      if !(1...4).contains(n.items.count) { out.append("Luna's news needs 1–4 lines") }
      for i in n.items where i.text.count > 90 { out.append("line over 90 characters: \(i.text)") }
      return out
    }
    guard let h = n.headline else { return out + ["Luna's news needs a \"> headline\" line"] }
    if h.count > headlineMax { out.append("headline over \(headlineMax) characters: \(h)") }
    if !(2...maxCards).contains(n.items.count) { out.append("Luna's news needs 2–\(maxCards) cards, has \(n.items.count)") }
    for i in n.items {
      guard let t = i.title else { out.append("card needs a **Title**: \(i.text)"); continue }
      if t.count > titleMax || t.split(separator: " ").count > titleWordsMax { out.append("card title too long (≤ \(titleWordsMax) words, \(titleMax) characters): \(t)") }
      if i.text.count > lineMax { out.append("card line over \(lineMax) characters: \(i.text)") }
    }
    return out
  }

  /// Semantic-version compare ("0.10.0" > "0.9.1").
  public static func less(_ a: String, _ b: String) -> Bool {
    let pa = a.split(separator: ".").map { Int($0) ?? 0 }, pb = b.split(separator: ".").map { Int($0) ?? 0 }
    for i in 0..<max(pa.count, pb.count) {
      let x = i < pa.count ? pa[i] : 0, y = i < pb.count ? pb[i] : 0
      if x != y { return x < y }
    }
    return false
  }

  /// The news to show after updating from `lastSeen` to `current`: the newest version in that range that has
  /// cards (its notes cover everything since the last App Store release), trimmed to `maxCards`.
  /// `lastSeen == nil` means a fresh install: nothing to show.
  public static func news(lastSeen: String?, current: String, all: [ReleaseNews]) -> ReleaseNews? {
    guard let lastSeen, less(lastSeen, current) else { return nil }
    let n = all.filter { less(lastSeen, $0.version) && !less(current, $0.version) && !$0.items.isEmpty }
      .max { less($0.version, $1.version) }
    return n.map { ReleaseNews(version: $0.version, title: $0.title, headline: $0.headline, items: Array($0.items.prefix(maxCards))) }
  }

  /// Launch args that keep the modal away: screenshots, store capture and Lobby (`-demo`), UI tests (`-uitest`).
  public static let quietArgs: Set<String> = ["-demo", "-uitest"]
  /// Set by Xcode when the app hosts a test bundle.
  public static let testEnvKey = "XCTestConfigurationFilePath"

  public struct Launch: Equatable, Sendable {
    /// What to show now (nil = nothing).
    public let news: ReleaseNews?
    /// The version to store as seen right away (nil = leave the stored value alone).
    public let record: String?
  }

  /// The whole once-per-version rule, pure. The version is recorded as soon as the modal is decided, so a kid
  /// who quits mid-modal never sees it twice. `forceFrom` is the DEBUG `-whatsNew` / `-whatsnewFrom` override:
  /// it shows the notes as if updated from that version and records nothing.
  public static func launch(lastSeen: String?, current: String, all: [ReleaseNews], args: [String], env: [String: String], forceFrom: String? = nil) -> Launch {
    if let forceFrom { return Launch(news: news(lastSeen: forceFrom, current: current, all: all), record: nil) }
    if env[testEnvKey] != nil || args.contains(where: quietArgs.contains) { return Launch(news: nil, record: nil) }
    guard let lastSeen else { return Launch(news: nil, record: current) } // fresh install: everything is new anyway
    guard less(lastSeen, current) else { return Launch(news: nil, record: nil) }
    return Launch(news: news(lastSeen: lastSeen, current: current, all: all), record: current)
  }
}
