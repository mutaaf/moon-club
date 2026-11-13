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
}
