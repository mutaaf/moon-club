import XCTest
@testable import MoonClubCore

/// Widgets & Live Activities: snapshot privacy, countdown states, streaks, moon phase, timelines.
final class WidgetTests: XCTestCase {
  var content: KidsContent { VectorTests.content }
  let ny: Calendar = { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "America/New_York")!; return c }()
  func nyDate(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int = 0) -> Date { ny.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))! }

  func seeded() -> (KidsState, [EarningsEvent]) {
    let syms = content.companies.prefix(3).map(\.s)
    var s = KidsState()
    s.guess(Guess(s: syms[1], d: "2026-10-31", pick: .miss, at: "2026-10-30"))
    s.finishLesson(content.lessons[0].id, today: "2026-10-30")
    s.finishLesson(content.lessons[1].id, today: "2026-10-31")
    s.startPiggy([PiggyHolding(s: syms[0], coins: 1000, shares: 10, start: 100)], today: "2026-10-29", value: 1000)
    s.recordValue(today: "2026-10-30", value: 1012.5)
    s.recordValue(today: "2026-10-31", value: 1030)
    let ev = [
      EarningsEvent(s: syms[0], d: "2026-11-03", h: .bmo, eE: 1, eA: nil),
      EarningsEvent(s: syms[1], d: "2026-10-31", h: .amc, eE: 1, eA: nil),
      EarningsEvent(s: syms[2], d: "2026-10-20", h: .amc, eE: 1, eA: 1.2), // past: dropped
      EarningsEvent(s: "ZZZZ", d: "2026-11-01", h: .amc, eE: 1, eA: nil),   // not a kid company: dropped
    ]
    return (s, ev)
  }

  func testSnapshotBuildsSoonestFirstWithYourPick() {
    let (s, ev) = seeded()
    let snap = WidgetSnapshots.build(state: s, content: content, events: ev, mood: 61.6, today: "2026-10-31")
    XCTAssertEqual(snap.reports.map(\.d), ["2026-10-31", "2026-11-03"])
    XCTAssertEqual(snap.reports.first?.pick, .miss)
    XCTAssertEqual(snap.headline?.s, ev[1].s)
    XCTAssertEqual(snap.mood, 62); XCTAssertEqual(snap.weather?.title, "Sunny")
    XCTAssertEqual(snap.piggy?.value, 1030); XCTAssertEqual(snap.piggy?.spark, [1000, 1012.5, 1030])
    XCTAssertEqual(snap.streak, 2)
    XCTAssertEqual(snap.lessonsDone, 2); XCTAssertEqual(snap.nextLesson?.id, content.lessons[2].id)
    XCTAssertFalse(snap.storyRead)
  }

  func testSnapshotRoundTripsAndStaysTiny() {
    let (s, ev) = seeded()
    let snap = WidgetSnapshots.build(state: s, content: content, events: ev, mood: 40, today: "2026-10-31")
    let data = snap.encoded()
    XCTAssertEqual(WidgetSnapshot.decode(data), snap)
    XCTAssertLessThan(data.count, 2048, "widgets decode this on every timeline; keep it small")
    XCTAssertNil(WidgetSnapshot.decode(Data("garbage".utf8)))
  }

  /// Privacy: only known keys; nothing from free text (league names, Luna questions) can sneak in.
  func testSnapshotHoldsNoFreeTextOrNames() throws {
    var (s, ev) = seeded()
    s.setMe(2)
    s.addPlayer(LeaguePlayer(emoji: 3, guesses: []))
    let snap = WidgetSnapshots.build(state: s, content: content, events: ev, mood: 50, today: "2026-10-31")
    func keys(_ o: Any) -> Set<String> {
      if let d = o as? [String: Any] { return Set(d.keys).union(d.values.flatMap { keys($0) }) }
      if let a = o as? [Any] { return a.reduce(into: Set<String>()) { $0.formUnion(keys($1)) } }
      return []
    }
    let json = try JSONSerialization.jsonObject(with: snap.encoded())
    XCTAssertTrue(keys(json).isSubset(of: WidgetSnapshot.allowedKeys), "unexpected keys: \(keys(json).subtracting(WidgetSnapshot.allowedKeys))")
    let text = String(data: snap.encoded(), encoding: .utf8)!
    for n in content.playerNames { XCTAssertFalse(text.contains("\"\(n)\""), "player name \(n) leaked") }
  }

  func testStoryReadIsPerDay() {
    var s = KidsState(); s.readStory(today: "2026-10-31")
    XCTAssertTrue(WidgetSnapshots.build(state: s, content: content, events: [], mood: nil, today: "2026-10-31").storyRead)
    XCTAssertFalse(WidgetSnapshots.build(state: s, content: content, events: [], mood: nil, today: "2026-11-01").storyRead)
  }

  func testOldProgressFilesStillDecode() throws {
    let old = #"{"schema":1,"guesses":[],"lessons":[],"lessonDates":{},"seenBadges":[],"league":[],"quest":[],"questDone":false}"#
    XCTAssertNil(try JSONDecoder().decode(KidsState.self, from: Data(old.utf8)).storyRead)
  }

  func testOptimisticGuessChangesOnlyThatReport() {
    let snap = WidgetSnapshot.placeholder
    let out = WidgetSnapshots.applyingGuess(snap, s: "NKE", d: "2026-11-02", pick: .miss)
    XCTAssertEqual(out.reports[1].pick, .miss)
    XCTAssertEqual(out.reports[0], snap.reports[0])
  }

  func testStreak() {
    XCTAssertEqual(Streak.days(["2026-10-29", "2026-10-30", "2026-10-31"], today: "2026-10-31"), 3)
    XCTAssertEqual(Streak.days(["2026-10-29", "2026-10-30"], today: "2026-10-31"), 2, "yesterday still counts until today ends")
    XCTAssertEqual(Streak.days(["2026-10-28"], today: "2026-10-31"), 0)
    XCTAssertEqual(Streak.days([], today: "2026-10-31"), 0)
    XCTAssertEqual(Streak.days(["2026-10-31", "2026-10-31"], today: "2026-10-31"), 1)
  }

  func testReportClockAndPhases() {
    XCTAssertEqual(ReportClock.time("2026-10-31", .amc), nyDate(2026, 10, 31, 16, 5))
    XCTAssertEqual(ReportClock.time("2026-10-31", .bmo), nyDate(2026, 10, 31, 8))
    XCTAssertNil(ReportClock.time("2026-10-31", .none))
    let r = WidgetSnapshot.Report(s: "AAPL", nick: "Apple", emoji: "🍎", d: "2026-10-31", h: .amc, pick: .beat)
    XCTAssertEqual(ReportClock.phase(r, today: "2026-10-31", now: nyDate(2026, 10, 31, 9)), .countdown(to: nyDate(2026, 10, 31, 16, 5)))
    XCTAssertEqual(ReportClock.phase(r, today: "2026-10-31", now: nyDate(2026, 10, 31, 16, 6)), .resultsIn)
    XCTAssertEqual(ReportClock.phase(r, today: "2026-10-29", now: nyDate(2026, 10, 29, 9)), .later(days: 2))
    XCTAssertEqual(ReportClock.phase(r, today: "2026-11-01", now: nyDate(2026, 11, 1, 9)), .resultsIn)
    var unknown = r; unknown.h = .none
    XCTAssertEqual(ReportClock.phase(unknown, today: "2026-10-31", now: nyDate(2026, 10, 31, 9)), .today)
  }

  func testTimelineOnlyHasMomentsThatChangeTheLook() {
    var snap = WidgetSnapshot.placeholder
    snap.day = "2026-10-31"
    let now = nyDate(2026, 10, 31, 9)
    let dates = WidgetTimeline.entryDates(snap, now: now, calendar: ny)
    XCTAssertEqual(dates.first, now)
    XCTAssertTrue(dates.contains(nyDate(2026, 10, 31, 16, 5)), "flip to Results are in!")
    XCTAssertEqual(dates.last, nyDate(2026, 11, 1, 0), "a new day")
    XCTAssertLessThanOrEqual(dates.count, 6)
    XCTAssertEqual(dates, dates.sorted())
  }

  func testLiveReportCandidate() {
    var snap = WidgetSnapshot.placeholder; snap.day = "2026-10-31"
    XCTAssertEqual(LiveReport.candidate(snap, now: nyDate(2026, 10, 31, 9))?.s, "AAPL")
    XCTAssertEqual(LiveReport.candidate(snap, now: nyDate(2026, 10, 31, 17))?.s, "AAPL", "stays up a while after results")
    XCTAssertNil(LiveReport.candidate(snap, now: nyDate(2026, 10, 31, 19)))
    snap.reports[0].pick = nil
    XCTAssertNil(LiveReport.candidate(snap, now: nyDate(2026, 10, 31, 9)), "only for a report card you guessed")
  }

  func testMoonPhase() {
    let utc: Calendar = { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }()
    // Known: full moon 2026-10-26 04:12 UTC, new moon 2026-11-09 07:02 UTC.
    let full = utc.date(from: DateComponents(year: 2026, month: 10, day: 26, hour: 4))!
    let new = utc.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 7))!
    XCTAssertEqual(LunarPhase.name(full).name, "Full moon")
    XCTAssertGreaterThan(LunarPhase.illumination(full), 0.97)
    XCTAssertEqual(LunarPhase.name(new).name, "New moon")
    XCTAssertLessThan(LunarPhase.illumination(new), 0.03)
  }
}
