// Game On: Today's missions, the chest, the play streak and rocket skins.
import XCTest
@testable import MoonClubCore

final class MissionsTests: XCTestCase {
  lazy var content: KidsContent = {
    let url = Bundle.module.url(forResource: "kids-content", withExtension: "json")!
    return try! KidsContent.load(Data(contentsOf: url))
  }()
  let day = "2026-11-02"

  func testThreeMissionsOneOfEachKindAndDeterministic() {
    let s = KidsState()
    let m = Missions.today(day, s, content)
    XCTAssertEqual(m.map(\.kind), [.lesson, .chart, .guess])
    XCTAssertEqual(m, Missions.today(day, s, content), "same day + state → same missions")
    XCTAssertFalse(m.contains(where: \.done))
    if case let .lesson(id) = m[0].target { XCTAssertEqual(id, content.lessons.first?.id, "a new kid starts with the first lesson") } else { XCTFail() }
    if case let .node(id) = m[1].target { XCTAssertTrue(World.regions(content).flatMap(\.nodes).contains { $0.id == id }) } else { XCTFail() }
  }

  func testMissionsFillInAndTheChestOpensOncePerDay() {
    var s = KidsState()
    let m = Missions.today(day, s, content)
    guard case let .lesson(l) = m[0].target else { return XCTFail() }
    s.finishLesson(l, today: day)
    var now = Missions.today(day, s, content)
    XCTAssertTrue(now[0].done)
    XCTAssertEqual(now[0].target, .lesson(l), "the finished lesson stays the mission, it doesn't jump to the next one")
    s.play("game", "canyon-build", today: day)
    s.guess(Guess(s: "DIS", d: "2026-11-10", pick: .beat, at: day))
    now = Missions.today(day, s, content)
    XCTAssertTrue(now.allSatisfy(\.done))
    XCTAssertTrue(Missions.chestReady(day, s, content))
    s.openChest(today: day)
    XCTAssertFalse(Missions.chestReady(day, s, content))
    XCTAssertTrue(Missions.chestOpened(day, s))
    // Yesterday's plays don't count today.
    XCTAssertEqual(Missions.doneCount("2026-11-03", s, content), 0)
  }

  func testPlayStreakCountsAnyKindOfPlay() {
    var s = KidsState()
    s.play("game", "x", today: "2026-10-31")
    s.guess(Guess(s: "DIS", d: "2026-11-10", pick: .beat, at: "2026-11-01"))
    s.finishLesson("company", today: day)
    XCTAssertEqual(Streak.play(s, today: day), 3)
    XCTAssertEqual(Streak.play(s, today: "2026-11-03"), 3, "yesterday still counts before today's play")
    XCTAssertEqual(Streak.play(s, today: "2026-11-05"), 0)
  }

  func testSkinsUnlockFromChestsAndTheLaterPickWinsOnMerge() {
    var s = KidsState()
    XCTAssertEqual(Skins.unlocked(s).map(\.id), ["classic"])
    XCTAssertEqual(Skins.current(s).id, "classic")
    s.pickSkin("galaxy", nowMillis: 1)
    XCTAssertEqual(Skins.current(s).id, "classic", "a locked skin can't be worn")
    s.openChest(today: "2026-11-01"); s.openChest(today: day); s.openChest(today: "2026-11-03")
    XCTAssertEqual(Skins.unlocked(s).count, 4)
    var a = s, b = s
    a.pickSkin("mint", nowMillis: 1_700_000_000_000)
    b.pickSkin("galaxy", nowMillis: 1_800_000_000_000)
    XCTAssertEqual(Skins.current(a.merged(with: b)).id, "galaxy")
    XCTAssertEqual(Skins.current(b.merged(with: a)).id, "galaxy")
  }

  func testPlayLogIsCappedAndOldSavesDecode() throws {
    var s = KidsState()
    for i in 0..<450 { s.play("game", "n\(i)", today: day) }
    XCTAssertEqual(s.played?.count, 400)
    let old = try JSONDecoder().decode(KidsState.self, from: Data(#"{"schema":1,"guesses":[],"lessons":[],"lessonDates":{},"seenBadges":[],"league":[],"quest":[],"questDone":false}"#.utf8))
    XCTAssertNil(old.played); XCTAssertNil(old.chests); XCTAssertNil(old.skin)
  }
}
