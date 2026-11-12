// Moon Tower: 100 generated levels (then Deep Space), the same on every device, getting harder as you climb.
import XCTest
@testable import MoonClubCore

final class TowerTests: XCTestCase {
  func testLevelsAreTheSameEveryTime() {
    for n in 1...300 { XCTAssertEqual(Tower.level(n), Tower.level(n), "level \(n)") }
    XCTAssertEqual(Tower.level(0).number, 1)
  }

  func testEveryTenthLevelIsABossThatMixesEveryGameMetSoFar() {
    for n in 1...200 {
      let l = Tower.level(n)
      XCTAssertEqual(l.isBoss, n % 10 == 0, "level \(n)")
      if l.isBoss {
        XCTAssertEqual(Set(l.games), Set(Tower.pool(n)), "boss \(n) mixes every game met")
        XCTAssertNil(l.twist)
      } else {
        XCTAssertEqual(l.games.count, 1)
        XCTAssertTrue(Tower.pool(n).contains(l.lead), "level \(n) only plays games already met")
      }
    }
  }

  func testEachGameDebutsOnItsLevelAndEveryGameShowsUp() {
    for g in TowerGame.allCases {
      XCTAssertEqual(Tower.level(g.debut).lead, g, g.rawValue)
      XCTAssertNotNil(Tower.level(g.debut).debut)
      XCTAssertNotEqual(g.debut % 10, 0, "\(g) can't debut on a boss level")
    }
    XCTAssertEqual(Set((1...100).flatMap { Tower.level($0).games }), Set(TowerGame.allCases))
    XCTAssertEqual(Set(TowerGame.allCases.map(\.debut)).count, TowerGame.allCases.count)
  }

  func testTheSameGameRarelyPlaysTwiceInARow() {
    var repeats = 0
    for n in 2...300 where !Tower.level(n).isBoss && !Tower.level(n - 1).isBoss {
      if Tower.level(n).lead == Tower.level(n - 1).lead { repeats += 1 }
    }
    XCTAssertLessThanOrEqual(repeats, 6, "\(repeats) back-to-back repeats")
  }

  func testDifficultyClimbs() {
    // Average rounds per zone never go down, and the far end is harder than the start on every dial.
    func avg(_ r: ClosedRange<Int>) -> Double { Double(r.map { Tower.level($0).rounds }.reduce(0, +)) / Double(r.count) }
    let zones = [1...20, 21...40, 41...60, 61...80, 81...100, 101...200]
    for (a, b) in zip(zones, zones.dropFirst()) { XCTAssertLessThanOrEqual(avg(a), avg(b)) }
    XCTAssertGreaterThan(avg(81...100), avg(1...20) + 2)
    XCTAssertEqual(Tower.level(1).choices, 3)
    XCTAssertEqual(Tower.level(55).choices, 4)
    XCTAssertLessThan(Tower.level(3).chartDays, Tower.level(95).chartDays)
    XCTAssertEqual(Tower.level(1).zone.name, "Launch Pad")
    XCTAssertEqual(Tower.level(100).zone.name, "Moon Gate")
    XCTAssertEqual(Tower.level(101).zone.name, "Deep Space")
    for n in 1...500 {
      let l = Tower.level(n)
      XCTAssertTrue((3...12).contains(l.rounds), "level \(n): \(l.rounds) rounds")
      XCTAssertTrue((1...3).contains(l.hearts))
      XCTAssertTrue((3...4).contains(l.choices))
      XCTAssertLessThanOrEqual(l.chartDays, 60)
    }
  }

  func testTwistsAreRareAndNeverAClock() {
    let twisted = (1...100).filter { Tower.level($0).twist != nil }
    XCTAssertTrue(twisted.allSatisfy { $0 >= 15 && $0 % 10 == 5 })
    XCTAssertGreaterThanOrEqual(twisted.count, 6)
    XCTAssertEqual(Tower.level(25).twist == .glass ? 1 : Tower.level(25).hearts, Tower.level(25).hearts)
    for n in 1...300 where Tower.level(n).twist == .glass { XCTAssertEqual(Tower.level(n).hearts, 1) }
    for n in 1...300 where Tower.level(n).twist == .fourDoors { XCTAssertEqual(Tower.level(n).choices, 4) }
    // Copy is short and kind.
    for t in TowerTwist.allCases { XCTAssertLessThanOrEqual(t.line.count, 30); XCTAssertFalse(t.line.lowercased().contains("hurry")) }
    for g in TowerGame.allCases { XCTAssertLessThanOrEqual(g.how.count, 60, g.rawValue); XCTAssertLessThanOrEqual(g.title.count, 18) }
  }

  func testClimbingOpensTheNextLevelAndNeverLocksAgain() {
    var s = KidsState()
    XCTAssertTrue(Tower.open(1, s)); XCTAssertFalse(Tower.open(2, s))
    XCTAssertEqual(Tower.current(s), 1)
    XCTAssertEqual(Tower.shown(s), 100)
    for n in 1...12 { s.earn(Tower.id(n), stars: n % 3 + 1) }
    XCTAssertTrue(Tower.open(13, s)); XCTAssertFalse(Tower.open(14, s))
    XCTAssertEqual(Tower.current(s), 13)
    XCTAssertEqual(Tower.totalStars(s), (1...12).map { $0 % 3 + 1 }.reduce(0, +))
    // A gap (stars synced from another device out of order) stops the climber at the gap.
    s.earn(Tower.id(20), stars: 3)
    XCTAssertEqual(Tower.current(s), 13)
    // Deep Space keeps growing a floor past where you are.
    for n in 1...104 { s.earn(Tower.id(n), stars: 1) }
    XCTAssertEqual(Tower.current(s), 105)
    XCTAssertEqual(Tower.shown(s), 120)
    // Map stars and tower stars don't mix.
    s.earn("coast-boss", stars: 3)
    XCTAssertEqual(Tower.totalStars(s), (1...104).map { max(1, $0 <= 12 ? $0 % 3 + 1 : $0 == 20 ? 3 : 1) }.reduce(0, +))
    XCTAssertEqual(Tower.number("tower-42"), 42)
    XCTAssertNil(Tower.number("coast-boss"))
  }

  func testHighZonesNeedAPerfectRunForThreeStars() {
    XCTAssertEqual(Tower.starsFor(right: 5, of: 5, tier: 4), 3)
    XCTAssertEqual(Tower.starsFor(right: 6, of: 7, tier: 4), 2)
    XCTAssertEqual(Tower.starsFor(right: 4, of: 7, tier: 4), 1)
    XCTAssertEqual(Tower.starsFor(right: 5, of: 7, tier: 0), 2); XCTAssertEqual(Tower.starsFor(right: 5, of: 7, tier: 4), 1)
    XCTAssertEqual(Tower.starsFor(right: 0, of: 0, tier: 0), 0)
  }
}
