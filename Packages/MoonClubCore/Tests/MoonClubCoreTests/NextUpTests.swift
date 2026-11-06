// Start here: given progress, the one next step (NextUp.swift).
import XCTest
@testable import MoonClubCore

final class NextUpTests: XCTestCase {
  lazy var content: KidsContent = {
    let url = Bundle.module.url(forResource: "kids-content", withExtension: "json")!
    return try! KidsContent.load(Data(contentsOf: url))
  }()
  let day = "2026-11-02"

  /// Finish today's missions up to `n` (in order: lesson, chart game, guess).
  func doMissions(_ n: Int, _ s: inout KidsState) {
    let ms = Missions.today(day, s, content)
    for m in ms.prefix(n) {
      switch m.target {
      case let .lesson(id): s.finishLesson(id, today: day)
      case let .node(id): s.play("game", id, today: day)
      case .guess: s.guess(Guess(s: "DIS", d: "2026-11-10", pick: .beat, at: day))
      }
    }
  }

  func testBrandNewStartsWithTheFirstMission() {
    var s = KidsState()
    s.checkIn(today: day)
    XCTAssertTrue(NextUp.isNew(s), "opening the app isn't playing")
    let n = NextUp.step(day, s, content)
    XCTAssertEqual(n.reason, .mission)
    XCTAssertEqual(n.target, .lesson(content.lessons[0].id))
    XCTAssertEqual(n.verb, "Learn")
    XCTAssertEqual(n.label, "Learn: \(content.lessons[0].title)")
    XCTAssertEqual(n.minutes, 2)
    XCTAssertNil(NextUp.dotTab(n), "the first step lives on Story")
    XCTAssertEqual(NextUp.greeting(n, day, s, content), "Hi! Let's start here.")
  }

  func testAHalfDoneUnitSaysKeepGoing() {
    var s = KidsState()
    s.finishLesson(content.lessons[0].id, today: "2026-10-30")
    let n = NextUp.step(day, s, content)
    XCTAssertEqual(n.target, .lesson(content.lessons[1].id))
    XCTAssertTrue(n.keepGoing)
    XCTAssertEqual(n.label, "Keep going: \(content.lessons[1].title)")
    XCTAssertEqual(NextUp.greeting(n, day, s, content), "Welcome back!")
  }

  func testWalksTheMissionsInOrder() {
    var s = KidsState()
    s.finishLesson("unused-so-not-new", today: "2026-10-01")
    doMissions(1, &s)
    var n = NextUp.step(day, s, content)
    guard case .node = n.target else { return XCTFail("after the lesson comes the chart game, got \(n.target)") }
    XCTAssertEqual(n.verb, "Play")
    XCTAssertEqual(NextUp.greeting(n, day, s, content), "Nice! Next up:")
    doMissions(2, &s)
    n = NextUp.step(day, s, content)
    XCTAssertEqual(n.target, .guess)
    XCTAssertEqual(n.label, "Play: Guess a report card")
    XCTAssertEqual(NextUp.dotTab(n), .guess, "the Guess tab gets the dot")
  }

  func testAllDoneOpensTheChestThenTheMap() {
    var s = KidsState()
    doMissions(3, &s)
    var n = NextUp.step(day, s, content)
    XCTAssertEqual(n.reason, .chest)
    XCTAssertEqual(n.target, .chest)
    XCTAssertNil(n.minutes)
    s.openChest(today: day)
    n = NextUp.step(day, s, content)
    XCTAssertEqual(n.reason, .world, "continue where the rocket waits")
    let rs = World.regions(content)
    let at = World.current(rs, s, content)
    XCTAssertEqual(n.target, .node(rs[at.region].nodes[at.node].id))
    XCTAssertEqual(NextUp.dotTab(n), .school, "the World tab gets the dot")
    XCTAssertEqual(NextUp.greeting(n, day, s, content), "Missions done! Next up:")
  }

  func testAStartedQuestComesFirst() {
    var s = KidsState()
    s.questStage("save:jar")
    let n = NextUp.step(day, s, content)
    XCTAssertEqual(n.target, .quest("save"))
    XCTAssertTrue(n.keepGoing)
    XCTAssertEqual(n.reason, .keepGoing)
    // Lemonade half done counts too; a finished chapter doesn't.
    var t = KidsState(); t.questStage("company")
    XCTAssertEqual(NextUp.step(day, t, content).target, .quest("lemonade"))
    t.finishLemonade()
    XCTAssertNotEqual(NextUp.step(day, t, content).target, .quest("lemonade"))
  }

  func testEverythingDoneIsSomethingFun() {
    var s = KidsState()
    let rs = World.regions(content)
    for r in rs { for n in r.nodes {
      switch n.kind {
      case let .unit(u): for l in content.lessons where l.unit == u { s.finishLesson(l.id, today: "2026-10-01") }
      case let .lesson(l): s.finishLesson(l, today: "2026-10-01")
      case let .quest(q): if q == "lemonade" { s.finishLemonade() } else { for st in content.questChapters?.CH_STAGES[q] ?? [] { s.questStage("\(q):\(st)") } }
      default: s.earn(n.id, stars: 3)
      }
    } }
    doMissionsOn(day, &s); s.openChest(today: day)
    var n = NextUp.step(day, s, content)
    XCTAssertEqual(n.reason, .fun)
    XCTAssertEqual(n.target, .piggy, "no piggy bank yet: start one")
    XCTAssertEqual(NextUp.greeting(n, day, s, content), "All done today! Just for fun:")
    s.startPiggy([PiggyHolding(s: "DIS", coins: 1000, shares: 10, start: 100)], today: day, value: 1000)
    let days = (0..<6).map { Day.add(day, $0) }
    let targets = Set(days.map { d -> NextTarget in var x = s; doMissionsOn(d, &x); x.openChest(today: d); return NextUp.step(d, x, content).target })
    XCTAssertEqual(targets, [.guess, .piggy], "fun alternates between Guess and the piggy bank")
    n = NextUp.step(day, s, content)
    XCTAssertEqual(n.reason, .fun)
  }

  func doMissionsOn(_ d: String, _ s: inout KidsState) {
    for m in Missions.today(d, s, content) {
      switch m.target {
      case let .lesson(id): s.play("lesson", id, today: d)
      case let .node(id): s.play("game", id, today: d)
      case .guess: s.play("guess", "x", today: d)
      }
    }
  }

  func testDeterministicAndKidSafeCopy() {
    var s = KidsState()
    for k in 0...3 {
      var x = s; doMissions(k, &x)
      XCTAssertEqual(NextUp.step(day, x, content), NextUp.step(day, x, content))
      let n = NextUp.step(day, x, content)
      let g = NextUp.greeting(n, day, x, content)
      for w in [n.label, g] {
        XCTAssertLessThanOrEqual(w.split(separator: " ").count, 9, "short: \(w)")
        for bad in ["buy", "hurry", "lose", "kids"] { XCTAssertFalse(w.lowercased().split(separator: " ").contains(Substring(bad)), "\(bad) in \(w)") }
      }
    }
    s.finishLesson("x", today: day)
    XCTAssertFalse(NextUp.isNew(s))
  }
}
