// Retrieval practice + spaced review, on the device only (docs/CURRICULUM.md). Every check question is a
// review ITEM ("<lesson id>#<step index>"). A miss puts it in box 0; each right answer at a Review stop moves
// it up a box, and box b comes back after `intervals[b]` days; at `retireAt` it's learned. Lessons finished at
// least a day ago also come back once (spacing), even with no miss. A Review stop mixes units (interleaving).
// State: `KidsState.review` = item -> "yyyy-MM-dd|box" (merge: max per key, a join). Nothing leaves the device.
import Foundation

public struct ReviewItem: Hashable, Sendable, Identifiable {
  public let id: String; public let lesson: String; public let unit: String; public let check: Check
}

public enum Mastery: Int, Comparable, Sendable, CaseIterable {
  case notStarted, learning, practicing, mastered
  public static func < (a: Mastery, b: Mastery) -> Bool { a.rawValue < b.rawValue }
  public var label: String { ["Not started", "Learning", "Practicing", "Mastered"][rawValue] }
}

public enum Review {
  public static func config(_ c: KidsContent) -> ReviewConfig { c.review ?? .standard }
  public static func itemId(_ lesson: String, _ step: Int) -> String { "\(lesson)#\(step)" }

  /// Every check question in the curriculum, as review items.
  public static func items(_ c: KidsContent) -> [ReviewItem] {
    c.lessons.flatMap { l in l.steps.enumerated().compactMap { i, s -> ReviewItem? in
      if case let .check(ch) = s { return ReviewItem(id: itemId(l.id, i), lesson: l.id, unit: l.unit, check: ch) }
      return nil
    } }
  }

  /// (last day, box) for a tracked item.
  public static func entry(_ s: KidsState, _ id: String) -> (day: String, box: Int)? {
    guard let v = s.review?[id] else { return nil }
    let p = v.split(separator: "|")
    guard p.count == 2, let b = Int(p[1]) else { return nil }
    return (String(p[0]), b)
  }

  /// Items due today, misses first (lowest box, oldest), then spaced first reviews of lessons finished at least
  /// a day ago, interleaved round-robin across units. `lessons` scopes it (a region's Review stop); nil = all.
  public static func due(_ s: KidsState, _ c: KidsContent, today: String, lessons scope: Set<String>? = nil, limit: Int? = nil) -> [ReviewItem] {
    let cfg = config(c)
    let all = items(c).filter { scope?.contains($0.lesson) ?? true }
    var misses: [(ReviewItem, Int, String)] = [], spaced: [(ReviewItem, String)] = []
    for it in all {
      if let e = entry(s, it.id) {
        guard e.box < cfg.retireAt else { continue }
        let wait = cfg.intervals[min(e.box, cfg.intervals.count - 1)]
        if Day.add(e.day, wait) <= today { misses.append((it, e.box, e.day)) }
      } else if let done = s.lessonDates[it.lesson], s.lessons.contains(it.lesson), Day.add(done, 1) <= today {
        spaced.append((it, done))
      }
    }
    let first = misses.sorted { ($0.1, $0.2, $0.0.id) < ($1.1, $1.2, $1.0.id) }.map(\.0)
    let then = spaced.sorted { ($0.1, $0.0.id) < ($1.1, $1.0.id) }.map(\.0)
    return Array(interleave(first + then).prefix(limit ?? cfg.perStop))
  }

  /// Round-robin by unit, keeping each unit's own order (mixing topics is "interleaving").
  static func interleave(_ xs: [ReviewItem]) -> [ReviewItem] {
    var byUnit: [String: [ReviewItem]] = [:], order: [String] = []
    for x in xs { if byUnit[x.unit] == nil { order.append(x.unit) }; byUnit[x.unit, default: []].append(x) }
    var out: [ReviewItem] = [], i = 0
    while out.count < xs.count {
      for u in order where i < byUnit[u]!.count { out.append(byUnit[u]![i]) }
      i += 1
    }
    return out
  }

  /// Mastery of a unit, from finished lessons and the review boxes of its questions. Optional (challenge)
  /// lessons never hold mastery back, and their questions don't count against it.
  public static func mastery(_ unit: String, _ s: KidsState, _ c: KidsContent) -> Mastery {
    let ls = c.requiredLessons(unit)
    let done = ls.filter { s.lessons.contains($0.id) }.count
    guard done > 0 else { return .notStarted }
    guard done == ls.count else { return .learning }
    let required = Set(ls.map(\.id))
    let its = items(c).filter { $0.unit == unit && required.contains($0.lesson) }
    guard !its.isEmpty else { return .mastered }
    let known = its.filter { entry(s, $0.id).map { $0.box >= 2 } ?? true }.count
    let pass = c.assessments?.first { $0.unit == unit }?.pass ?? config(c).pass
    return Double(known) / Double(its.count) >= pass ? .mastered : .practicing
  }

  /// Lessons worth replaying ("Luna's refresh"): a finished lesson comes back when retrieval failed AFTER it was
  /// learned (a question missed at a Review stop, or on a later replay, still in box 0), or when most of its
  /// questions were missed the day it was played. Replaying it today clears the first case, since the miss is
  /// then older than the last play. Ordered like the curriculum; at most `limit`.
  public static func refresh(_ s: KidsState, _ c: KidsContent, limit: Int = 3) -> [Lesson] {
    var lastPlay: [String: String] = [:]
    for e in s.played ?? [] {
      let p = e.split(separator: "|", maxSplits: 2).map(String.init)
      if p.count == 3, p[1] == "lesson", p[0] > (lastPlay[p[2]] ?? "") { lastPlay[p[2]] = p[0] }
    }
    let byLesson = Dictionary(grouping: items(c), by: \.lesson)
    return c.lessons.filter { l in
      guard s.lessons.contains(l.id), let its = byLesson[l.id], !its.isEmpty else { return false }
      let last = max(lastPlay[l.id] ?? "", s.lessonDates[l.id] ?? "")
      let zero = its.compactMap { entry(s, $0.id) }.filter { $0.box == 0 }
      let missedLater = zero.contains { $0.day > last }
      let struggled = zero.filter { $0.day == last }.count * 2 > its.count && its.count >= 2
      return missedLater || struggled
    }.prefix(limit).map { $0 }
  }
}

extension KidsState {
  /// Record an answer to a review item. In a lesson (`review: false`) only a miss is recorded (box 0): a right
  /// answer on a lesson replay doesn't skip the spacing. At a Review stop, right moves the item up a box (a first
  /// spaced review starts at box 2), wrong sends it back to box 0.
  public mutating func answer(_ item: String, right: Bool, today: String, review inReview: Bool, retireAt: Int = 4) {
    var r = self.review ?? [:]
    let cur = Review.entry(self, item)
    if !right { r[item] = "\(today)|0" }
    else if let cur, inReview { r[item] = "\(today)|\(min(retireAt, cur.box + 1))" }
    else if cur == nil, inReview { r[item] = "\(today)|2" }
    else { return }
    self.review = r
  }
}
