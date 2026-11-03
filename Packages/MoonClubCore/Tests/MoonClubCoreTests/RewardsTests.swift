// Points that matter (0.11): one earned currency, the Moon Shop, trophies, ranks, and sync safety.
import XCTest
@testable import MoonClubCore

final class RewardsTests: XCTestCase {
  lazy var content: KidsContent = {
    let url = Bundle.module.url(forResource: "kids-content", withExtension: "json")!
    return try! KidsContent.load(Data(contentsOf: url))
  }()
  let day = "2026-11-04"

  /// A kid with plenty of points to spend (lessons + banked runs).
  func rich(_ pts: Int = 600) -> KidsState {
    var s = KidsState()
    s.bank(.game, "test", points: pts, today: day)
    return s
  }

  func testBreakdownSumsToPointsAndNamesEverySource() {
    var s = KidsState()
    s.finishLesson("company", today: day)
    s.guess(Guess(s: "DIS", d: "2026-11-10", pick: .beat, at: day, result: .right))
    s.earn("canyon-build", stars: 3)
    s.earn("coast-boss", stars: 2)
    s.openChest(today: day)
    s.checkIn(today: day)
    s.bank(.game, "canyon-build", points: 12, today: day)
    let lines = Rewards.breakdown(s, content)
    XCTAssertEqual(lines.reduce(0) { $0 + $1.points }, s.points(content), "the breakdown explains every point")
    let src = Set(lines.map(\.source))
    for x in [PointSource.lesson, .guess, .game, .boss, .mission, .streak, .badge] { XCTAssertTrue(src.contains(x), "\(x) shows") }
  }

  func testTheWebsPointsAreUnchangedForTheWebsFields() {
    var s = KidsState(); s.finishLesson("company", today: day)
    XCTAssertEqual(pointsFor(s.progress(content)), 10, "the web formula itself is untouched (VectorTests pin it)")
  }

  func testReplayingTheSameGameTheSameDayKeepsTheBestRunOnly() {
    var s = KidsState()
    s.bank(.game, "canyon-build", points: 10, today: day)
    s.bank(.game, "canyon-build", points: 6, today: day)
    s.bank(.game, "canyon-build", points: 14, today: day)
    XCTAssertEqual(Rewards.banked(s), 14)
    s.bank(.game, "canyon-build", points: 8, today: "2026-11-05")
    XCTAssertEqual(Rewards.banked(s), 22, "a new day is a new run")
    XCTAssertEqual(Rewards.runPoints(999), Rewards.runCap)
  }

  func testDailyVisitBonusGrowsWithTheStreakAndIsOncePerDay() {
    var s = KidsState()
    s.checkIn(today: "2026-11-01"); s.checkIn(today: "2026-11-01")
    XCTAssertEqual(Rewards.banked(s), 5)
    s.checkIn(today: "2026-11-02")
    s.checkIn(today: "2026-11-03")
    XCTAssertEqual(Rewards.banked(s), 5 + 10 + 15)
    XCTAssertEqual(Streak.play(s, today: "2026-11-03"), 3)
  }

  func testStreakSaverCoversOneMissedDay() {
    var s = rich()
    s.checkIn(today: "2026-11-01"); s.checkIn(today: "2026-11-02")
    XCTAssertTrue(s.buy("freeze", content, nowMillis: 1))
    XCTAssertEqual(Shop.freezes(s), 1)
    // Skips the 3rd, comes back on the 4th: the saver covers the 3rd.
    s.checkIn(today: "2026-11-04")
    XCTAssertEqual(s.frozen, ["2026-11-03"])
    XCTAssertEqual(Shop.freezes(s), 0)
    XCTAssertEqual(Streak.play(s, today: "2026-11-04"), 4)
    // Without a saver, a missed day just starts a new streak (never a penalty).
    s.checkIn(today: "2026-11-06")
    XCTAssertEqual(Streak.play(s, today: "2026-11-06"), 1)
  }

  func testShopBuyEquipAndLocks() {
    var poor = KidsState()
    let mint = Shop.item("rocket.mint")!
    XCTAssertEqual(Shop.lock(mint, poor, content), .points(100))
    XCTAssertFalse(poor.buy("rocket.mint", content, nowMillis: 1))
    XCTAssertNil(poor.owned)

    var s = rich(200)
    XCTAssertEqual(Shop.wallet(s, content), s.points(content))
    let before = Shop.wallet(s, content)
    XCTAssertTrue(s.buy("rocket.mint", content, nowMillis: 5))
    XCTAssertEqual(Shop.wallet(s, content), before - 100)
    XCTAssertEqual(Skins.current(s).id, "mint", "a new rocket is worn right away")
    XCTAssertFalse(s.buy("rocket.mint", content, nowMillis: 6), "can't buy the same thing twice")
    s.equip("rocket.classic", nowMillis: 7)
    XCTAssertEqual(Skins.current(s).id, "classic")
    s.equip("hat.crown", nowMillis: 8)
    XCTAssertEqual(Shop.equipped(.hat, s)?.id, nil, "an unowned item can't be worn")

    // Rank and trophy gates.
    let crown = Shop.item("hat.crown")!
    XCTAssertEqual(Shop.lock(crown, KidsState(), content), .rank(Ranks.levels(content)[4].name), "the crown needs Full Moon")
    let cap = Shop.item("hat.cap")!
    XCTAssertEqual(Shop.lock(cap, rich(1000), content), .trophy("Bookworm"))
    var reader = rich(1000); reader.finishLesson("company", today: day)
    XCTAssertNil(Shop.lock(cap, reader, content))
  }

  func testEveryShopItemIsValidAndStartersAreFree() {
    XCTAssertEqual(Set(Shop.all.map(\.id)).count, Shop.all.count, "unique ids")
    for id in Shop.starters { XCTAssertEqual(Shop.item(id)?.price, 0, id) }
    for slot in ShopSlot.allCases where slot != .freeze && slot != .hat { XCTAssertNotNil(Shop.equipped(slot, KidsState()), "\(slot) has a default") }
    for it in Shop.all {
      if let t = it.trophy { XCTAssertTrue(Trophies.all.contains { $0.id == t }, "\(it.id) gate \(t)") }
      if let r = it.rank { XCTAssertLessThan(r, Ranks.levels(content).count) }
      XCTAssertGreaterThanOrEqual(it.price, 0)
    }
    for s in Skins.all { XCTAssertNotNil(Shop.item("rocket.\(s.id)"), "every rocket skin is in the shop") }
    // Pricing: the cheapest real item takes about 2–3 sessions (a session earns roughly 40–70).
    let cheapest = Shop.all.filter { $0.price > 0 && $0.slot != .freeze }.map(\.price).min() ?? 0
    XCTAssertTrue((80...150).contains(cheapest))
  }

  func testLegacyChestSkinsStayOwnedAndFree() {
    var s = KidsState()
    s.openChest(today: "2026-11-01"); s.openChest(today: "2026-11-02")
    s.pickSkin("sunset", nowMillis: 9)
    XCTAssertEqual(Set(Skins.unlocked(s).map(\.id)), ["classic", "mint", "sunset"])
    XCTAssertEqual(Skins.current(s).id, "sunset", "the old skin pick still applies")
    XCTAssertEqual(Shop.spent(s), 0)
  }

  func testTrophiesTierUpAndCountTowardPoints() {
    var s = KidsState()
    var p = Trophies.progress(s, content)
    XCTAssertTrue(p.allSatisfy { $0.tier == 0 })
    XCTAssertEqual(Trophies.points(s, content), 0)
    s.finishLesson("company", today: day)
    p = Trophies.progress(s, content)
    let book = p.first { $0.trophy.id == "bookworm" }!
    XCTAssertEqual(book.tier, 1)
    XCTAssertEqual(book.progressLine, "1/\(book.goals[1]) lessons done")
    XCTAssertEqual(Trophies.points(s, content), Rewards.tierPoints[0])
    XCTAssertEqual(Trophies.fresh(s, content).map { $0.0.trophy.id }, ["bookworm"])
    s.seeBadges([Trophies.key(book)])
    XCTAssertTrue(Trophies.fresh(s, content).isEmpty)

    let canyon = World.regions(content).first(where: { $0.id == "canyon" })!
    for n in canyon.nodes { s.earn(n.id, stars: 3) }
    let candle = Trophies.progress(s, content).first { $0.trophy.id == "candle-reader" }!
    XCTAssertEqual(candle.tier, 3)
    XCTAssertNil(candle.next)
    XCTAssertTrue(candle.progressLine.hasPrefix("Gold!"))
  }

  func testRanksKeepTheWebsMoonsThenGoBigger() {
    let ls = Ranks.levels(content)
    XCTAssertEqual(Array(ls.prefix(content.levels.count)), content.levels)
    XCTAssertGreaterThan(ls.count, content.levels.count)
    XCTAssertEqual(ls.map(\.min), ls.map(\.min).sorted())
    XCTAssertEqual(rich(1500).level(content).name, ls.last?.name)
    for i in ls.indices.dropFirst() { XCTAssertFalse(Ranks.unlocks(i).isEmpty, "rank \(i) unlocks something to show at the ceremony") }
  }

  /// Spending on two devices: the wallet is derived, owned is a set, so syncing never mints points.
  func testSpendingMergesSafelyAcrossDevices() {
    let base = rich(300)
    var phone = base, ipad = base
    XCTAssertTrue(phone.buy("rocket.mint", content, nowMillis: 10))
    XCTAssertTrue(ipad.buy("hat.party", content, nowMillis: 20))
    let m = phone.merged(with: ipad)
    XCTAssertEqual(m, ipad.merged(with: phone))
    XCTAssertEqual(Shop.wallet(m, content), base.points(content) - 200)
    XCTAssertEqual(Shop.equipped(.rocket, m)?.id, "rocket.mint")
    XCTAssertEqual(Shop.equipped(.hat, m)?.id, "hat.party")
    // Both devices buy the same rocket: it's paid for once.
    var a = base, b = base
    a.buy("rocket.mint", content, nowMillis: 1); b.buy("rocket.mint", content, nowMillis: 2)
    XCTAssertEqual(Shop.wallet(a.merged(with: b), content), base.points(content) - 100)
    // Two devices each banking the same run: counted once (max), not added.
    var x = KidsState(), y = KidsState()
    x.bank(.game, "n", points: 10, today: day); y.bank(.game, "n", points: 12, today: day)
    XCTAssertEqual(Rewards.banked(x.merged(with: y)), 12)
  }

  func testOldSavesDecodeAndKeepTheirPoints() throws {
    let old = try JSONDecoder().decode(KidsState.self, from: Data(#"{"schema":1,"guesses":[],"lessons":["company"],"lessonDates":{"company":"2026-10-01"},"seenBadges":[],"league":[],"quest":[],"questDone":false}"#.utf8))
    XCTAssertNil(old.bonus); XCTAssertNil(old.owned); XCTAssertNil(old.equipped)
    XCTAssertGreaterThanOrEqual(old.points(content), 10, "old points are still there")
    XCTAssertEqual(Shop.wallet(old, content), old.points(content))
  }
}
