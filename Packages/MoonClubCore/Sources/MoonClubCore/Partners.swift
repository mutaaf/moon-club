import Foundation

/// Grown-up picks: parent-facing partner links (a kids' money book, a learning account…), shown ONLY in the
/// grown-up corner behind the parental gate, with a plain disclosure. **Off by default: the list ships empty.**
/// Joining an affiliate program and choosing partners involves money, so it's the owner's call (docs/LINKS.md,
/// "Affiliate slots"). No partner SDK, pixel or tracking parameter about the family is ever added: a partner
/// link is a plain https URL that opens in Safari.
public struct Partner: Hashable, Sendable, Identifiable {
  public let id: String
  /// What it is, for a grown-up ("Money Ninja: a picture book about saving").
  public let title: String
  /// One plain sentence on why it's here. Never advice, never "buy now".
  public let blurb: String
  /// https only, on the partner's own host. May carry the program's affiliate tag; never anything about the child.
  public let url: String
  public init(id: String, title: String, blurb: String, url: String) { self.id = id; self.title = title; self.blurb = blurb; self.url = url }
}

public enum Partners {
  /// EMPTY on purpose. Add entries only after the owner has joined a program and picked the partner.
  public static let list: [Partner] = []
  /// FTC-style disclosure shown above the picks, every time.
  public static let disclosure = "Grown-ups only. These are partner links: we may earn a fee if you sign up or buy. Nothing here is investment advice, and your child never sees this section."

  public static let bannedWords = ["guaranteed", "get rich", "buy now", "hurry", "free money", "you should"]

  /// The only picks the app will draw: https, a real host, no URLs in the words, no hype.
  public static func valid(_ p: Partner) -> Bool {
    guard let u = URL(string: p.url), u.scheme == "https", let h = u.host, h.contains("."), u.user == nil else { return false }
    let words = (p.title + " " + p.blurb).lowercased()
    guard !p.title.isEmpty, !p.blurb.isEmpty, !words.contains("http"), !words.contains("www.") else { return false }
    return !bannedWords.contains { words.contains($0) }
  }

  public static var shown: [Partner] { list.filter(valid) }
}
