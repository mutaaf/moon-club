import XCTest
@testable import MoonClubCore

final class PartyTests: XCTestCase {
  lazy var content: KidsContent = {
    let url = Bundle.module.url(forResource: "kids-content", withExtension: "json")!
    return try! KidsContent.load(Data(contentsOf: url))
  }()

  func testSeedIsStableAndPicksFromTheList() {
    XCTAssertEqual(Seed.of("moon"), Seed.of("moon"))
    XCTAssertNotEqual(Seed.of("moon"), Seed.of("moon!"))
    XCTAssertNil(Seed.pick([Int](), "x"))
    XCTAssertEqual(Seed.pick([1, 2, 3], "a"), Seed.pick([1, 2, 3], "a"))
  }

  func testCelebrationTiers() {
    XCTAssertEqual(PartyMoment.right.tier, .small)
    XCTAssertEqual(PartyMoment.combo(2).tier, .small)
    XCTAssertEqual(PartyMoment.combo(3).tier, .medium)
    XCTAssertEqual(PartyMoment.perfectRound.tier, .medium)
    XCTAssertEqual(PartyMoment.badgeTier.tier, .medium)
    for m in [PartyMoment.bossBeaten, .landWon, .rankUp, .chest] { XCTAssertEqual(m.tier, .large) }
    XCTAssertEqual(PartyMoment.streak(3).tier, .large)
    XCTAssertEqual(PartyMoment.streak(4).tier, .small)
    XCTAssertEqual(PartyMoment.streak(7).tier, .large)
    XCTAssertEqual(PartyMoment.streak(30).tier, .large)
    XCTAssertEqual(PartyMoment.streak(100).tier, .large)
    XCTAssertTrue(CelebrationTier.small < .large)
  }

  func testLunaLinesAreShortKindAndStable() {
    var count = 0
    for l in LunaLine.allCases {
      XCTAssertFalse(l.lines.isEmpty)
      for s in l.lines {
        count += 1
        XCTAssertLessThanOrEqual(s.split(separator: " ").count, 9, s)   // short enough to read at a glance
        XCTAssertFalse(s.lowercased().contains("buy"), s)              // never advice
        XCTAssertFalse(s.lowercased().contains("hurry"), s)            // never pressure
        XCTAssertFalse(s.lowercased().contains("lose"), s)
      }
      XCTAssertEqual(l.line("k"), l.line("k"))
    }
    XCTAssertGreaterThanOrEqual(count, 40)
    XCTAssertEqual(LunaLine.after(right: false, combo: 0, missedBefore: false, firstOfDay: false), .miss)
    XCTAssertEqual(LunaLine.after(right: true, combo: 1, missedBefore: false, firstOfDay: true), .firstWin)
    XCTAssertEqual(LunaLine.after(right: true, combo: 1, missedBefore: true, firstOfDay: false), .comeback)
    XCTAssertEqual(LunaLine.after(right: true, combo: 3, missedBefore: false, firstOfDay: false), .combo)
    XCTAssertNil(LunaLine.after(right: true, combo: 2, missedBefore: false, firstOfDay: false))
  }

  func testMysteryStopIsAnOpenGameStableForTheDayAndClaimedOnce() {
    var s = KidsState()
    XCTAssertNil(Mystery.node(s, content, today: "2026-11-03"), "a brand-new map has no open game yet")
    for r in World.regions(content).prefix(3) { for n in r.nodes { s.earn(n.id, stars: 1) } }
    s.questDone = true
    let a = Mystery.node(s, content, today: "2026-11-03")
    XCTAssertNotNil(a)
    if case .game? = a?.kind {} else { XCTFail("mystery must be a game") }
    XCTAssertEqual(a, Mystery.node(s, content, today: "2026-11-03"))
    XCTAssertFalse(Mystery.claimed(s, today: "2026-11-03"))
    s.bank(.game, Mystery.bonusID, points: Mystery.points, today: "2026-11-03")
    s.bank(.game, Mystery.bonusID, points: Mystery.points, today: "2026-11-03")
    XCTAssertTrue(Mystery.claimed(s, today: "2026-11-03"))
    XCTAssertEqual(Rewards.banked(s), Mystery.points, "claiming twice banks once")
    let days = (0..<14).map { Day.add("2026-11-03", $0) }
    XCTAssertGreaterThan(Set(days.compactMap { Mystery.node(s, content, today: $0)?.id }).count, 1, "it moves around")
  }

  func testNudgesAreFriendlyFacts() {
    var s = KidsState()
    let r = World.regions(content)[2]
    guard let game = r.nodes.first(where: { if case .game = $0.kind { return true }; return false }) else { return XCTFail("no game") }
    s.earn(game.id, stars: 1)
    let n = Nudge.after(game, stars: 1, s, content)
    XCTAssertFalse(n.isEmpty)
    XCTAssertTrue(n[0].contains("2 more stars"), n[0])
    XCTAssertLessThanOrEqual(n.count, 2)
    XCTAssertTrue(Nudge.after(game, stars: 3, s, content).allSatisfy { !$0.contains("perfect") })
  }

  func testStickersFollowTheMap() {
    var s = KidsState()
    let before = Stickers.count(s, content)
    XCTAssertEqual(before.have, 0)
    XCTAssertEqual(before.of, World.regions(content).reduce(0) { $0 + 1 + $1.nodes.count })
    let r = World.regions(content)[0]
    s.earn(r.boss.id, stars: 3)
    let all = Stickers.all(s, content)
    XCTAssertTrue(all.first { $0.id == "land.\(r.id)" }?.shiny ?? false)
    XCTAssertTrue(all.first { $0.id == "stop.\(r.boss.id)" }?.shiny ?? false)
  }

  func testBedtimeIsGentle() {
    let t0 = Date(timeIntervalSince1970: 0)
    XCTAssertFalse(Bedtime.sleepy(sessionStart: t0, lastAsked: nil, now: t0.addingTimeInterval(19 * 60)))
    XCTAssertTrue(Bedtime.sleepy(sessionStart: t0, lastAsked: nil, now: t0.addingTimeInterval(20 * 60)))
    let asked = t0.addingTimeInterval(20 * 60)
    XCTAssertFalse(Bedtime.sleepy(sessionStart: t0, lastAsked: asked, now: asked.addingTimeInterval(5 * 60)))
    XCTAssertTrue(Bedtime.sleepy(sessionStart: t0, lastAsked: asked, now: asked.addingTimeInterval(10 * 60)))
  }

  func testHingeDialAndLaunch() {
    XCTAssertEqual(HingeDial.value(0, in: 4...12), 4)
    XCTAssertEqual(HingeDial.value(30, in: 4...12), 4)
    XCTAssertEqual(HingeDial.value(100, in: 4...12), 8)
    XCTAssertEqual(HingeDial.value(170, in: 4...12), 12)
    XCTAssertEqual(HingeDial.value(180, in: 4...12), 12)
    let half = HingeReading(.partiallyOpen, degrees: 90)
    XCTAssertTrue(HingeLaunch.launches(from: half, to: HingeReading(.fullyOpen, degrees: 180)))
    XCTAssertTrue(HingeLaunch.launches(from: HingeReading(.closed, degrees: 0), to: HingeReading(.partiallyOpen, degrees: 168)))
    XCTAssertFalse(HingeLaunch.launches(from: half, to: HingeReading(.partiallyOpen, degrees: 120)))
    XCTAssertFalse(HingeLaunch.launches(from: HingeReading(.fullyOpen, degrees: 180), to: HingeReading(.fullyOpen, degrees: 180)))
    XCTAssertFalse(HingeLaunch.launches(from: nil, to: half))
  }

  func testDuoTrophiesAndShopItemOnlyShowWithAHinge() {
    var s = KidsState()
    XCTAssertFalse(Trophies.visible(hinge: false, s).contains { $0.category == .duo })
    XCTAssertEqual(Trophies.visible(hinge: true, s).filter { $0.category == .duo }.count, 7, "three from 0.12, four from 0.14")
    XCTAssertEqual(Trophies.points(s, content), 0)
    XCTAssertTrue(Shop.visible(hinge: false, s).allSatisfy { $0.id != "frame.fold" })
    XCTAssertTrue(Shop.visible(hinge: true, s).contains { $0.id == "frame.fold" })
    s.useDuo(.book)
    XCTAssertTrue(s.playedOnDuo)
    XCTAssertTrue(Trophies.visible(hinge: false, s).contains { $0.id == "duo-book" }, "once earned, it stays in the cabinet")
    XCTAssertEqual(Trophies.progress(s, content).first { $0.trophy.id == "duo-book" }?.tier, 1)
    XCTAssertEqual(Shop.item("frame.fold")?.trophy, "duo-book")
  }

  func testDuoCountsMergeByMax() {
    var a = KidsState(), b = KidsState()
    a.useDuo(.book); a.useDuo(.book); b.useDuo(.book); b.useDuo(.hinge)
    let m = a.merged(with: b)
    XCTAssertEqual(m.duoCount(.book), 2)
    XCTAssertEqual(m.duoCount(.hinge), 1)
    XCTAssertEqual(m.merged(with: m), m)
  }
}
