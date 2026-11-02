// Widgets & Live Activities: the pure half. The app builds a tiny `WidgetSnapshot` from its state and
// writes it to the App Group; widgets only read it (no network, no decoding of the big content file),
// so timelines are instant. Everything here is unit-tested.
//
// Privacy: the snapshot holds only app content (company nicknames, lesson titles), small numbers and
// dates — never free text, never a name, never anything a kid typed. `WidgetSnapshot.allowedKeys` is
// enforced by a test.
import Foundation

// MARK: - Snapshot

public struct WidgetSnapshot: Codable, Hashable, Sendable {
  public struct Report: Codable, Hashable, Sendable, Identifiable {
    public var s: String; public var nick: String; public var emoji: String
    public var d: String; public var h: Session
    public var pick: Pick?
    public var id: String { "\(s):\(d)" }
    public init(s: String, nick: String, emoji: String, d: String, h: Session, pick: Pick?) {
      self.s = s; self.nick = nick; self.emoji = emoji; self.d = d; self.h = h; self.pick = pick
    }
  }
  public struct NextLesson: Codable, Hashable, Sendable { public var id: String; public var title: String; public var emoji: String; public var steps: Int
    public init(id: String, title: String, emoji: String, steps: Int) { self.id = id; self.title = title; self.emoji = emoji; self.steps = steps } }
  public struct PiggyLine: Codable, Hashable, Sendable { public var value: Double; public var start: Double; public var spark: [Double]
    public init(value: Double, start: Double, spark: [Double]) { self.value = value; self.start = start; self.spark = spark }
    public var change: Double { start > 0 ? value / start - 1 : 0 } }

  public var v = 1
  public var day: String
  public var mood: Int?
  public var storyRead: Bool
  public var reports: [Report]           // next few report cards for kid companies, soonest first (≤ 4)
  public var piggy: PiggyLine?
  public var streak: Int
  public var lessonsDone: Int; public var lessonsTotal: Int
  public var nextLesson: NextLesson?
  public var level: String; public var levelProgress: Double; public var points: Int

  public init(day: String, mood: Int?, storyRead: Bool, reports: [Report], piggy: PiggyLine?, streak: Int, lessonsDone: Int, lessonsTotal: Int, nextLesson: NextLesson?, level: String, levelProgress: Double, points: Int) {
    self.day = day; self.mood = mood; self.storyRead = storyRead; self.reports = reports; self.piggy = piggy; self.streak = streak
    self.lessonsDone = lessonsDone; self.lessonsTotal = lessonsTotal; self.nextLesson = nextLesson; self.level = level; self.levelProgress = levelProgress; self.points = points
  }

  /// Every JSON key the snapshot may ever contain (privacy test).
  public static let allowedKeys: Set<String> = ["v", "day", "mood", "storyRead", "reports", "piggy", "streak", "lessonsDone", "lessonsTotal", "nextLesson", "level", "levelProgress", "points",
                                                "s", "nick", "emoji", "d", "h", "pick", "id", "title", "steps", "value", "start", "spark"]

  public var weather: Weather? { mood.map { weatherFor(Double($0)) } }
  /// The report card the widget leads with: the soonest one you guessed, else the soonest one.
  public var headline: Report? { reports.first { $0.pick != nil } ?? reports.first }

  public func encoded() -> Data { (try? JSONEncoder().encode(self)) ?? Data() }
  public static func decode(_ d: Data) -> WidgetSnapshot? { try? JSONDecoder().decode(WidgetSnapshot.self, from: d) }

  /// What a widget shows before the app has ever run (and in the gallery).
  public static let placeholder = WidgetSnapshot(
    day: "2026-10-31", mood: 62, storyRead: false,
    reports: [Report(s: "AAPL", nick: "Apple", emoji: "🍎", d: "2026-10-31", h: .amc, pick: .beat), Report(s: "NKE", nick: "Nike", emoji: "👟", d: "2026-11-02", h: .amc, pick: nil)],
    piggy: PiggyLine(value: 1043.2, start: 1000, spark: [1000, 996, 1004, 1011, 1008, 1019, 1027, 1022, 1036, 1043.2]),
    streak: 3, lessonsDone: 6, lessonsTotal: 28, nextLesson: NextLesson(id: "what-is-a-share", title: "What is a share?", emoji: "🍕", steps: 5),
    level: "Moon Cadet", levelProgress: 0.45, points: 85)
}

public enum WidgetSnapshots {
  /// Build the snapshot from app state. `events` are the calendar rows the app already loaded.
  public static func build(state: KidsState, content: KidsContent, events: [EarningsEvent], mood: Double?, today: String) -> WidgetSnapshot {
    let cos = content.companyBySymbol
    let guesses = Dictionary(state.guesses.map { ("\($0.s):\($0.d)", $0.pick) }, uniquingKeysWith: { a, _ in a })
    let reports = events.filter { cos[$0.s] != nil && $0.d >= today }
      .sorted { ($0.d, $0.s) < ($1.d, $1.s) }
      .prefix(4)
      .map { e in WidgetSnapshot.Report(s: e.s, nick: cos[e.s]!.nick, emoji: cos[e.s]!.emoji, d: e.d, h: e.h, pick: guesses[e.id]) }
    let piggy = state.piggy.map { p -> WidgetSnapshot.PiggyLine in
      let vals = p.history.sorted { $0.key < $1.key }.map(\.value)
      return .init(value: vals.last ?? content.startCoins, start: content.startCoins, spark: Array(vals.suffix(14)))
    }
    let next = content.lessons.first { !state.lessons.contains($0.id) }
    let lv = state.level(content)
    return WidgetSnapshot(
      day: today, mood: mood.map { Int($0.rounded()) }, storyRead: state.storyRead == today,
      reports: Array(reports), piggy: piggy,
      streak: Streak.days(Array(state.lessonDates.values), today: today),
      lessonsDone: state.lessons.count, lessonsTotal: content.lessons.count,
      nextLesson: next.map { .init(id: $0.id, title: $0.title, emoji: $0.emoji, steps: $0.steps.count) },
      level: lv.name, levelProgress: lv.progress, points: state.points(content))
  }

  /// Optimistic update for a widget tap: the snapshot changes immediately, the state file follows.
  public static func applyingGuess(_ snap: WidgetSnapshot, s: String, d: String, pick: Pick) -> WidgetSnapshot {
    var out = snap
    for i in out.reports.indices where out.reports[i].s == s && out.reports[i].d == d { out.reports[i].pick = pick }
    return out
  }
}

// MARK: - Streak

public enum Streak {
  /// Consecutive days with a finished lesson, ending today — or yesterday, so a streak isn't "lost" before today's lesson.
  public static func days(_ lessonDays: [String], today: String) -> Int {
    let set = Set(lessonDays)
    var d = set.contains(today) ? today : Day.add(today, -1)
    var n = 0
    while set.contains(d) { n += 1; d = Day.add(d, -1) }
    return n
  }
}

// MARK: - Report clock

/// When a report card "comes out", in New York time: before school → 8:00, during the day → 12:00, after school → 16:05.
public enum ReportClock {
  static let ny: Calendar = { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "America/New_York")!; return c }()

  public static func time(_ d: String, _ h: Session) -> Date? {
    let hm: (Int, Int)
    switch h { case .bmo: hm = (8, 0); case .dmh: hm = (12, 0); case .amc: hm = (16, 5); case .none: return nil }
    let p = d.split(separator: "-").compactMap { Int($0) }
    guard p.count == 3 else { return nil }
    return ny.date(from: DateComponents(year: p[0], month: p[1], day: p[2], hour: hm.0, minute: hm.1))
  }

  public enum Phase: Hashable, Sendable {
    case later(days: Int)          // not today
    case today                     // today, time unknown
    case countdown(to: Date)       // today, before the report time
    case resultsIn                 // the report is out
  }

  /// `today` is the app's calendar day (a "YYYY-MM-DD" string); `now` decides countdown vs results.
  public static func phase(_ r: WidgetSnapshot.Report, today: String, now: Date) -> Phase {
    let days = Day.between(today, r.d)
    if days < 0 { return .resultsIn }
    if days > 0 { return .later(days: days) }
    guard let t = time(r.d, r.h) else { return .today }
    return now < t ? .countdown(to: t) : .resultsIn
  }
}

// MARK: - Lunar phase (the real sky)

public enum LunarPhase {
  static let synodic = 29.530588853
  static let knownNew = Date(timeIntervalSince1970: 947_182_440) // 2000-01-06 18:14 UTC

  /// 0 = new moon, 0.5 = full moon, → 1 = new again.
  public static func fraction(_ date: Date) -> Double {
    let days = date.timeIntervalSince(knownNew) / 86400
    let f = (days / synodic).truncatingRemainder(dividingBy: 1)
    return f < 0 ? f + 1 : f
  }
  /// How much of the moon is lit, 0…1.
  public static func illumination(_ date: Date) -> Double { (1 - cos(fraction(date) * 2 * .pi)) / 2 }

  public static func name(_ date: Date) -> (name: String, emoji: String) {
    let f = fraction(date)
    let names: [(String, String)] = [("New moon", "🌑"), ("Waxing crescent", "🌒"), ("First quarter", "🌓"), ("Waxing gibbous", "🌔"),
                                     ("Full moon", "🌕"), ("Waning gibbous", "🌖"), ("Last quarter", "🌗"), ("Waning crescent", "🌘")]
    return names[Int((f * 8).rounded()) % 8]
  }
}

// MARK: - Timeline

public enum WidgetTimeline {
  /// The few moments a widget's look actually changes: now, each report time today, and the next midnight.
  /// Countdowns tick on their own (`Text(timerInterval:)`), so no per-minute entries.
  public static func entryDates(_ snap: WidgetSnapshot, now: Date, calendar: Calendar = .current) -> [Date] {
    var out: [Date] = [now]
    for r in snap.reports where r.d == snap.day {
      if let t = ReportClock.time(r.d, r.h), t > now { out.append(t) }
    }
    if let midnight = calendar.nextDate(after: now, matching: DateComponents(hour: 0, minute: 0), matchingPolicy: .nextTime) { out.append(midnight) }
    return Array(Set(out)).sorted()
  }
}

// MARK: - Live Activity content (pure)

public enum LiveReport {
  /// The report card worth a Live Activity right now: one you guessed, reporting today, with a known time.
  public static func candidate(_ snap: WidgetSnapshot, now: Date) -> WidgetSnapshot.Report? {
    snap.reports.first { r in
      guard r.pick != nil, r.d == snap.day, let t = ReportClock.time(r.d, r.h) else { return false }
      return now < t.addingTimeInterval(2 * 3600) // keep it up for a bit after "Results are in!"
    }
  }
}
