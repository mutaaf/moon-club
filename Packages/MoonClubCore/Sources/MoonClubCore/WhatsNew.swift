import Foundation

/// "What's new" after an update. Every release-notes/<version>.md has a `## Luna's news` section:
/// 1–4 kid-sized lines, each `- [sf.symbol.name] Text`. The modal shows the lines from every version
/// the device hasn't seen yet, newest first. A fresh install sees none (it's all new anyway).
public struct ReleaseNews: Equatable, Sendable {
  public struct Item: Equatable, Sendable { public let symbol: String; public let text: String }
  public let version: String
  public let title: String
  public let items: [Item]
}

public enum WhatsNew {
  public static let heading = "## Luna's news"
  public static let maxCards = 5

  public static func parse(version: String, markdown: String) -> ReleaseNews {
    let lines = markdown.components(separatedBy: "\n")
    let title = lines.first { $0.hasPrefix("# ") }.map { String($0.dropFirst(2)).trimmingCharacters(in: .whitespaces) } ?? "Moon Club \(version)"
    var items: [ReleaseNews.Item] = []
    var inside = false
    for raw in lines {
      let line = raw.trimmingCharacters(in: .whitespaces)
      if line.hasPrefix("## ") { inside = line == heading; continue }
      guard inside, line.hasPrefix("- [") , let close = line.firstIndex(of: "]") else { continue }
      let symbol = String(line[line.index(line.startIndex, offsetBy: 3)..<close]).trimmingCharacters(in: .whitespaces)
      let text = String(line[line.index(after: close)...]).trimmingCharacters(in: .whitespaces)
      if !symbol.isEmpty, !text.isEmpty { items.append(.init(symbol: symbol, text: text)) }
    }
    return ReleaseNews(version: version, title: title, items: items)
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

  /// Versions newer than `lastSeen` and not newer than `current`, newest first, trimmed to `maxCards` lines in total.
  /// `lastSeen == nil` means a fresh install: nothing to show.
  public static func pending(lastSeen: String?, current: String, all: [ReleaseNews]) -> [ReleaseNews] {
    guard let lastSeen, less(lastSeen, current) else { return [] }
    var budget = maxCards
    var out: [ReleaseNews] = []
    for n in all.sorted(by: { less($1.version, $0.version) }) where less(lastSeen, n.version) && !less(current, n.version) && !n.items.isEmpty {
      guard budget > 0 else { break }
      let take = Array(n.items.prefix(budget))
      budget -= take.count
      out.append(ReleaseNews(version: n.version, title: n.title, items: take))
    }
    return out
  }
}
