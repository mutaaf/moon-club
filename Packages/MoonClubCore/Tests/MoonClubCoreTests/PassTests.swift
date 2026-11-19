import XCTest
@testable import MoonClubCore

final class PassTests: XCTestCase {
  let day = "2026-11-12"

  func testFreeRunWonLevelsAndThePassNeverCount() {
    let empty = PlayLedger()
    for c in Climb.allCases {
      XCTAssertEqual(PlayPlan.check(c, number: PlayPlan.freeRun(c), id: "x", won: false, pass: false, ledger: empty, today: day), .free)
      XCTAssertEqual(PlayPlan.check(c, number: 500, id: "x", won: true, pass: false, ledger: empty, today: day), .free, "replays are free")
      XCTAssertEqual(PlayPlan.check(c, number: 500, id: "x", won: false, pass: true, ledger: empty, today: day), .free)
      XCTAssertEqual(PlayPlan.check(c, number: PlayPlan.freeRun(c) + 1, id: "x", won: false, pass: false, ledger: empty, today: day), .counted(left: PlayPlan.dailyFree - 1))
    }
    XCTAssertEqual(PlayPlan.freeRun(.candles), 20)
    XCTAssertEqual(PlayPlan.freeRun(.tower), 10)
  }

  func testDailyLevelsThenBreaksThenTomorrow() {
    var l = PlayLedger()
    var n = 21
    func play() -> PlayPlan.Decision {
      let d = PlayPlan.check(.candles, number: n, id: "candle-\(n)", won: false, pass: false, ledger: l, today: day)
      l = PlayPlan.record(.candles, number: n, id: "candle-\(n)", won: false, pass: false, ledger: l, today: day)
      if d.allowed { n += 1 }
      return d
    }
    for k in 0..<PlayPlan.dailyFree { XCTAssertEqual(play(), .counted(left: PlayPlan.dailyFree - 1 - k)) }
    XCTAssertEqual(play(), .needsBreak)
    // Reopening a level already opened today is free (quitting and coming back costs nothing).
    XCTAssertEqual(PlayPlan.check(.candles, number: 21, id: "candle-21", won: false, pass: false, ledger: l, today: day), .free)
    for _ in 0..<PlayPlan.breaksPerDay {
      XCTAssertTrue(PlayPlan.canBreak(l, today: day))
      l = PlayPlan.finishBreak(l, today: day)
      for _ in 0..<PlayPlan.perBreak { XCTAssertTrue(play().allowed) }
      XCTAssertFalse(play().allowed)
    }
    XCTAssertEqual(play(), .doneForToday)
    XCTAssertEqual(PlayPlan.finishBreak(l, today: day).breaks, PlayPlan.breaksPerDay, "breaks are capped")
    XCTAssertEqual(l.opened.count, PlayPlan.dailyFree + PlayPlan.perBreak * PlayPlan.breaksPerDay)
    // A new day starts fresh.
    XCTAssertEqual(PlayPlan.check(.candles, number: n, id: "candle-\(n)", won: false, pass: false, ledger: l, today: "2026-11-13"), .counted(left: PlayPlan.dailyFree - 1))
    XCTAssertEqual(PlayPlan.left(l, today: "2026-11-13"), PlayPlan.dailyFree)
  }

  func testRecordOnlyChangesCountedPlays() {
    let l = PlayLedger(day: day)
    XCTAssertEqual(PlayPlan.record(.lines, number: 3, id: "lines-3", won: false, pass: false, ledger: l, today: day), l)
    XCTAssertEqual(PlayPlan.record(.lines, number: 30, id: "lines-30", won: false, pass: true, ledger: l, today: day), l)
    XCTAssertEqual(PlayPlan.record(.lines, number: 30, id: "lines-30", won: false, pass: false, ledger: l, today: day).opened, ["lines-30"])
  }

  func testKidCopyIsSafeAndShort() {
    let lines = [PlayPlan.limitTitle, PlayPlan.limitLine(.needsBreak), PlayPlan.limitLine(.doneForToday), PlayPlan.breakButton, PlayPlan.askButton,
                 PlayPlan.askLine, PlayPlan.chip(.counted(left: 0)), PlayPlan.chip(.counted(left: 2))].compactMap { $0 } + PlayPlan.facts.map(\.line)
    for s in lines {
      let l = " \(s.lowercased()) "
      for bad in [" buy ", " sell ", " pay ", "money", "cash", "should", "hurry", " ad ", " ads ", "watch an ad", "price of the pass", "$"] {
        XCTAssertFalse(l.contains(bad), s)
      }
      XCTAssertLessThanOrEqual(s.count, 100, s)
    }
    XCTAssertEqual(Set(PlayPlan.facts.map(\.line)).count, PlayPlan.facts.count)
    XCTAssertNotEqual(PlayPlan.fact(day: day, n: 0).line, PlayPlan.fact(day: day, n: 1).line)
  }

  func testClockMovedBackNeverGivesAFreshDay() {
    let used = PlayLedger(day: "2026-11-14", opened: ["a", "b", "c"], breaks: 2)
    XCTAssertEqual(PlayPlan.left(used, today: "2026-11-13"), PlayPlan.left(used, today: "2026-11-14"))
    XCTAssertEqual(used.on("2026-11-13").day, "2026-11-13", "carried onto today, so the next real day is fresh")
    XCTAssertEqual(PlayPlan.left(used.on("2026-11-13"), today: "2026-11-14"), PlayPlan.dailyFree)
    XCTAssertEqual(PlayPlan.left(used, today: "2026-11-15"), PlayPlan.dailyFree, "moving forward is a new day")
    XCTAssertEqual(PlayLedger().on(day), PlayLedger(day: day))
  }

  func testTodaySlots() {
    let l = PlayLedger(day: day, opened: ["a", "b", "c", "d"], breaks: 1)
    let t = PlayPlan.today(l, pass: false, today: day)
    XCTAssertEqual(t.used, 4); XCTAssertEqual(t.allowance, PlayPlan.dailyFree + PlayPlan.perBreak); XCTAssertEqual(t.left, 2)
    XCTAssertEqual(t.breaksLeft, PlayPlan.breaksPerDay - 1)
    XCTAssertEqual(t.slots.count, PlayPlan.Today.most)
    XCTAssertEqual(t.slots.filter { $0 == .used }.count, 4)
    XCTAssertEqual(t.slots.filter { $0 == .open }.count, 2)
    XCTAssertEqual(t.slots.filter { $0 == .locked }.count, PlayPlan.Today.most - 6)
    XCTAssertEqual(PlayPlan.today(l, pass: false, today: "2026-11-13").used, 0)
  }

  func testResetLine() {
    XCTAssertEqual(PlayPlan.resetLine(minutes: 1), "New levels in 1 minute")
    XCTAssertEqual(PlayPlan.resetLine(minutes: 0), "New levels in 1 minute")
    XCTAssertEqual(PlayPlan.resetLine(minutes: 45), "New levels in 45 minutes")
    XCTAssertEqual(PlayPlan.resetLine(minutes: 120), "New levels in 2 h")
    XCTAssertEqual(PlayPlan.resetLine(minutes: 312), "New levels in 5 h 12 min")
    let tz = TimeZone(identifier: "America/Chicago")!
    var c = Calendar(identifier: .gregorian); c.timeZone = tz
    let at = c.date(from: DateComponents(year: 2026, month: 11, day: 16, hour: 22, minute: 30))!
    XCTAssertEqual(PlayPlan.minutesToTomorrow(at, tz: tz), 90)
  }

  func testBreakQuizzes() {
    XCTAssertEqual(PlayPlan.quizzes.count, PlayPlan.facts.count)
    var firstRight = 0
    for n in 0..<24 {
      let q = PlayPlan.quiz(day: day, n: n)
      XCTAssertEqual(q.choices.count, 2)
      XCTAssertTrue(q.choices.indices.contains(q.answer))
      if q.answer == 0 { firstRight += 1 }
    }
    XCTAssertTrue((1..<24).contains(firstRight), "the right answer isn't always in the same place")
    // The shuffled copy keeps the same right answer.
    for n in 0..<12 {
      let q = PlayPlan.quiz(day: day, n: n)
      let base = PlayPlan.quizzes.first { $0.question == q.question }!
      XCTAssertEqual(q.choices[q.answer], base.choices[base.answer])
    }
    let lines = PlayPlan.quizzes.flatMap { [$0.fact, $0.question, $0.why] + $0.choices } + [PlayPlan.rightLine, PlayPlan.missLine, PlayPlan.replayButton,
      PlayPlan.collectButton, PlayPlan.collected, PlayPlan.breakButton(left: 1), PlayPlan.resetLine(minutes: 312)]
    for s in lines {
      let l = " \(s.lowercased()) "
      for bad in [" buy ", " sell ", " pay ", "money", "cash", "should", "hurry", " ad ", " ads ", "wrong", "$"] { XCTAssertFalse(l.contains(bad), s) }
      XCTAssertLessThanOrEqual(s.count, 100, s)
    }
  }

  func testOldLevelsStayPlayable() {
    // Tried level 22 yesterday, didn't win; today's new levels are all used: 22 still plays, free.
    var l = PlayPlan.record(.candles, number: 22, id: "candle-22", won: false, pass: false, ledger: PlayLedger(), today: "2026-11-12")
    for n in 30..<(30 + PlayPlan.dailyFree) {
      l = PlayPlan.record(.candles, number: n, id: "candle-\(n)", won: false, pass: false, ledger: l, today: "2026-11-13")
    }
    XCTAssertEqual(PlayPlan.check(.candles, number: 99, id: "candle-99", won: false, pass: false, ledger: l, today: "2026-11-13"), .needsBreak)
    XCTAssertEqual(PlayPlan.check(.candles, number: 22, id: "candle-22", won: false, pass: false, ledger: l, today: "2026-11-13"), .free)
    XCTAssertEqual(PlayPlan.check(.candles, number: 30, id: "candle-30", won: false, pass: false, ledger: l, today: "2026-11-20"), .free)
    XCTAssertEqual(PlayPlan.left(l, today: "2026-11-14"), PlayPlan.dailyFree, "a new day still starts fresh")
  }

  func testLedgerDecodesOldAndDamagedData() throws {
    let old = #"{"day":"2026-11-12","opened":["candle-21","candle-22"],"breaks":1}"#.data(using: .utf8)!
    let l = try JSONDecoder().decode(PlayLedger.self, from: old)
    XCTAssertEqual(l.kept, ["candle-21", "candle-22"])
    XCTAssertEqual(PlayPlan.check(.candles, number: 21, id: "candle-21", won: false, pass: false, ledger: l, today: "2026-11-30"), .free)
    let bad = #"{"day":7,"opened":"x","breaks":-4}"#.data(using: .utf8)!
    let b = try JSONDecoder().decode(PlayLedger.self, from: bad)
    XCTAssertEqual(b, PlayLedger(day: ""))
    let round = try JSONDecoder().decode(PlayLedger.self, from: JSONEncoder().encode(l))
    XCTAssertEqual(round, l)
  }

  func testKeptIsCapped() {
    var l = PlayLedger(day: day, kept: (0..<PlayLedger.keptCap).map { "k\($0)" })
    l = PlayPlan.record(.candles, number: 50, id: "candle-50", won: false, pass: false, ledger: l, today: day)
    XCTAssertEqual(l.kept.count, PlayLedger.keptCap)
    XCTAssertEqual(l.kept.last, "candle-50")
  }
}
