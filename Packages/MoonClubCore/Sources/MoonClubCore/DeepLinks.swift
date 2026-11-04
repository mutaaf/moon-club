import Foundation

/// Every way into the app from outside it: universal links on mutaafaziz.com/metaphases/kids/… (the same
/// URLs are real web pages when the app isn't installed) and the `moonclub://` scheme (widgets, Live
/// Activities, the simulator). Pure and unit-tested (DeepLinkTests); the app applies the result in RootView.
///
/// Rules (docs/LINKS.md):
/// - Unknown or malformed links land on `.home`. Nothing traps, nothing half-opens.
/// - `.league` and `.pack` change settings, so they're `needsGrownUp`: the app shows the parental gate first
///   and only then offers them inside the grown-up corner. No link ever skips the gate.
/// - Packs come only from the app's own bundled, reviewed set (`KidsContent.bundledPacks`); the remote pack
///   channel stays off. A link can't carry a pack, only name one the app already has.
/// - Query strings (`?ref=` for App Store campaign credit on the web) are ignored by the app.
public enum DeepLink: Equatable, Hashable, Sendable {
  case home
  case world
  case lesson(String)
  case guess
  case gameNight
  case piggy
  case garden
  case luna
  case league(String)
  case pack(String)

  public static let scheme = "moonclub"
  public static let hosts: Set<String> = ["mutaafaziz.com", "www.mutaafaziz.com"]
  public static let webRoot = "/metaphases/kids"
  public static let web = "https://mutaafaziz.com/metaphases/kids"
  static let maxURL = 512

  /// Changes a setting, so it waits behind the parental gate.
  public var needsGrownUp: Bool {
    switch self { case .league, .pack: return true; default: return false }
  }

  /// The web path under /metaphases/kids ("" for home). The web app serves every one of these.
  public var path: String {
    switch self {
    case .home: return ""
    case .world: return "/school"
    case .lesson(let id): return "/school/\(id)"
    case .guess: return "/guess"
    case .gameNight: return "/gamenight"
    case .piggy: return "/piggy"
    case .garden: return "/garden"
    case .luna: return "/ask"
    case .league(let code): return "/league/\(code)"
    case .pack(let id): return "/pack/\(id)"
    }
  }

  /// The shareable https link. `ref` is an allow-listed campaign slug (see `Campaign`), never anything about a child.
  public func webURL(ref: String? = nil) -> URL {
    var s = DeepLink.web + path
    if let ref, Campaign.isSlug(ref) { s += "?ref=\(ref)" }
    return URL(string: s) ?? URL(string: DeepLink.web)!
  }

  /// The custom-scheme form (moonclub://guess, moonclub://school/<id>…).
  public var appURL: URL {
    let p = path.isEmpty ? "home" : String(path.dropFirst())
    return URL(string: "\(DeepLink.scheme)://\(p)") ?? URL(string: "\(DeepLink.scheme)://home")!
  }

  // MARK: Parsing

  static func isId(_ s: String) -> Bool {
    (1...48).contains(s.count) && s.allSatisfy { ($0.isASCII && ($0.isLowercase || $0.isNumber)) || $0 == "-" } && s.first != "-"
  }
  static func isCode(_ s: String) -> Bool {
    (8...140).contains(s.count) && s.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }
  }

  /// Syntax only. Use `resolve(_:in:)` to also check the lesson, pack or league code against this build's content.
  public static func parse(_ url: URL) -> DeepLink {
    guard url.absoluteString.count <= maxURL, url.user == nil, url.password == nil, url.port == nil else { return .home }
    let segs: [String]
    switch url.scheme?.lowercased() {
    case scheme?:
      segs = ([url.host ?? ""] + url.pathComponents).filter { !$0.isEmpty && $0 != "/" }
    case "https"?:
      guard let h = url.host?.lowercased(), hosts.contains(h) else { return .home }
      let p = url.path
      guard p == webRoot || p.hasPrefix(webRoot + "/") else { return .home }
      segs = p.dropFirst(webRoot.count).split(separator: "/").map(String.init)
    default:
      return .home
    }
    return route(segs)
  }

  static func route(_ s: [String]) -> DeepLink {
    guard let head = s.first?.lowercased() else { return .home }
    let rest = Array(s.dropFirst())
    switch (head, rest.count) {
    case ("home", 0), ("story", 0): return .home
    case ("school", 0), ("world", 0): return .world
    case ("school", 1), ("lesson", 1): return isId(rest[0]) ? .lesson(rest[0]) : .home
    case ("guess", 0): return .guess
    case ("gamenight", 0): return .gameNight
    case ("piggy", 0): return .piggy
    case ("garden", 0): return .garden
    case ("ask", 0), ("luna", 0): return .luna
    case ("league", 1): return isCode(rest[0]) ? .league(rest[0].uppercased()) : .home
    case ("pack", 1): return isId(rest[0]) ? .pack(rest[0]) : .home
    // Widgets and Live Activities (0.7): moonclub://tab/<name>.
    case ("tab", 1):
      return ["story": .home, "guess": .guess, "piggy": .piggy, "school": .world, "luna": .luna][rest[0]] ?? .home
    default: return .home
    }
  }

  /// Parse, then check against what this build actually has. A lesson this build (or the packs turned on)
  /// doesn't have opens the World map; a pack that isn't bundled, or a league code that doesn't decode, goes Home.
  public static func resolve(_ url: URL, in c: KidsContent) -> DeepLink {
    let l = parse(url)
    switch l {
    case .lesson(let id): return c.lessons.contains { $0.id == id } ? l : .world
    case .pack(let id): return c.bundledPacks.contains { $0.id == id } ? l : .home
    case .league(let code):
      if case .success = League.decode(code, companies: c.companies, players: c.players.count) { return l }
      return .home
    default: return l
    }
  }
}

/// App Store campaign tokens (App Analytics → Sources → Campaigns). A `?ref=` slug on the web becomes `ct=`
/// on the App Store link. Slugs are short, lowercase and allow-listed in metaphases `shared/kidsLinks.ts`;
/// they name a channel (a share, a creator pack), never a person or a child.
public enum Campaign {
  public static let share = "share"
  public static let league = "league"
  public static func pack(_ id: String) -> String { String("pack-\(id)".prefix(40)) }
  /// 1–40 characters, lowercase letters, digits and dashes (Apple's ct limit is 40).
  public static func isSlug(_ s: String) -> Bool {
    (1...40).contains(s.count) && s.allSatisfy { ($0.isASCII && ($0.isLowercase || $0.isNumber)) || $0 == "-" }
  }
}
