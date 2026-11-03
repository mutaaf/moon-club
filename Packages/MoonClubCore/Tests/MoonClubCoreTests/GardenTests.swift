// Moon Garden (0.13): planting Moon points in companies. The ledger, the guardrails, deterministic harvests,
// and sync that can't double count.
import XCTest
@testable import MoonClubCore

final class GardenTests: XCTestCase {
  lazy var content: KidsContent = {
    let url = Bundle.module.url(forResource: "kids-content", withExtension: "json")!
    return try! KidsContent.load(Data(contentsOf: url))
  }()
  let day = "2026-11-04"
  func rich(_ pts: Int = 400) -> KidsState { var s = KidsState(); s.bank(.game, "test", points: pts, today: day); return s }
  func eid(_ i: Int) -> String { Garden.eventId(nowMillis: 1_790_000_000_000 + i, salt: UInt16(i)) }

  // MARK: The ledger

  func testLedgerFormula() {
    XCTAssertEqual(Garden.balance(earned: 500, gains: 0, spent: 100, planted: 0), 400)
    XCTAssertEqual(Garden.balance(earned: 500, gains: 12, spent: 100, planted: 150), 262, "earned + gains − spent − planted")
    XCTAssertEqual(Garden.balance(earned: 500, gains: -20, spent: 100, planted: 0), 380, "a harvest in a dip is a real (gentle) loss")
    XCTAssertEqual(Garden.balance(earned: 10, gains: 0, spent: 100, planted: 0), 0, "never below zero")
  }

  func testPlantingMovesPointsOutOfTheWalletAndHarvestBringsThemBack() {
    var s = rich()
    let before = Shop.wallet(s, content)
    XCTAssertTrue(s.plant("DIS", points: 100, price: 100, today: day, id: eid(1), content))
    XCTAssertEqual(Shop.wallet(s, content), before - 100, "planted points leave the spendable balance")
    XCTAssertEqual(s.points(content), rich().points(content), "planting never changes what was earned")
    // The price grows 10%: harvest everything at 110.
    let value = s.gardenBook.plots["DIS"]?.value(110) ?? 0
    XCTAssertEqual(value, 110, "100 points at 100 grow to 110 points at 110")
    XCTAssertTrue(s.harvest("DIS", points: value, price: 110, today: Day.add(day, 8), id: eid(2)))
    XCTAssertTrue(s.gardenBook.plots.isEmpty)
    XCTAssertEqual(s.gardenBook.gains, 10)
    XCTAssertEqual(Shop.wallet(s, content), before + 10 + 10, "the gain, plus Patient planter bronze for 8 days of growing")
  }

  func testPartialHarvestTakesPrincipalInProportion() {
    var s = rich()
    s.plant("KO", points: 100, price: 50, today: day, id: eid(1), content)
    XCTAssertTrue(s.harvest("KO", points: 40, price: 40, today: day, id: eid(2)))   // price fell 20%: 80 left in value
    let b = s.gardenBook
    XCTAssertEqual(b.harvests.first?.paid, 40)
    XCTAssertEqual(b.harvests.first?.released, 50, "half the seeds take half the planted points")
    XCTAssertEqual(b.principal, 50)
    XCTAssertEqual(b.gains, -10, "harvesting in a dip is a small real loss")
  }

  // MARK: Guardrails

  func testDailyPlantingLimit() {
    var s = rich(200)
    XCTAssertEqual(s.gardenAllowance(content, today: day), 100, "50% of the balance by default")
    XCTAssertFalse(s.plant("DIS", points: 101, price: 100, today: day, id: eid(1), content))
    XCTAssertTrue(s.plant("DIS", points: 60, price: 100, today: day, id: eid(2), content))
    XCTAssertEqual(s.gardenAllowance(content, today: day), 40, "the limit counts what's already planted today")
    XCTAssertTrue(s.plant("NKE", points: 40, price: 100, today: day, id: eid(3), content))
    XCTAssertEqual(s.gardenAllowance(content, today: day), 0)
    XCTAssertFalse(s.plant("KO", points: 5, price: 100, today: day, id: eid(4), content))
    XCTAssertEqual(s.gardenAllowance(content, today: Day.add(day, 1)), 50, "a new day: 50% of what's left")
    XCTAssertEqual(Shop.wallet(s, content), 100, "shop money is never wiped out in one go")
  }

  func testGrownUpLimitAndPause() {
    var s = rich(200)
    s.setGardenLimit(0, nowMillis: 5)
    XCTAssertEqual(s.gardenAllowance(content, today: day), 0, "0% pauses planting")
    s.setGardenLimit(100, nowMillis: 6)
    XCTAssertEqual(s.gardenAllowance(content, today: day), 200)
    var other = s; other.setGardenLimit(25, nowMillis: 4) // an older pick on another device
    XCTAssertEqual(s.merged(with: other).gardenLimitPct, 100, "the later grown-up pick wins")
  }

  func testNoBorrowingAndNoTinyOrUnknownPlantings() {
    var s = KidsState()
    XCTAssertFalse(s.plant("DIS", points: 10, price: 100, today: day, id: eid(1), content), "no points, no planting: there's no borrowing")
    s = rich(100)
    XCTAssertFalse(s.plant("DIS", points: 4, price: 100, today: day, id: eid(2), content), "at least 5 points")
    XCTAssertFalse(s.plant("ZZZZ", points: 10, price: 100, today: day, id: eid(3), content), "only kid-known companies")
    XCTAssertFalse(s.plant("DIS", points: 10, price: 0, today: day, id: eid(4), content), "no price, no planting")
  }

  func testPlantedPointsCantBeSpentInTheShop() {
    var s = rich(220)
    s.setGardenLimit(100, nowMillis: 1)
    s.plant("DIS", points: 150, price: 100, today: day, id: eid(1), content)
    XCTAssertEqual(Shop.wallet(s, content), 70)
    XCTAssertFalse(s.buy("hat.party", content, nowMillis: 2), "a 100-point hat waits until points are harvested")
  }

  // MARK: Sync

  /// Two devices both harvest the whole patch while offline: after merging, it's paid once.
  func testDoubleHarvestAfterMergeIsPaidOnce() {
    var a = rich(); a.plant("DIS", points: 100, price: 100, today: day, id: eid(1), content)
    var b = a
    a.harvest("DIS", points: 999, price: 120, today: Day.add(day, 3), id: eid(2))
    b.harvest("DIS", points: 999, price: 110, today: Day.add(day, 3), id: eid(3))
    let m = a.merged(with: b)
    XCTAssertEqual(m, b.merged(with: a))
    let book = m.gardenBook
    XCTAssertEqual(book.harvests.count, 1, "the second harvest finds nothing growing")
    XCTAssertEqual(book.harvests.first?.paid, 120, "the earlier event (by id) is the one replayed, at the price it stored")
    XCTAssertEqual(Shop.wallet(m, content), Shop.wallet(rich(), content) + 20)
  }

  func testPlantsFromTwoDevicesBothCountAndRemergingIsHarmless() {
    var a = rich(), b = rich()
    a.plant("DIS", points: 50, price: 100, today: day, id: eid(1), content)
    b.plant("KO", points: 30, price: 60, today: day, id: eid(2), content)
    let m = a.merged(with: b)
    XCTAssertEqual(Set(m.gardenBook.plots.keys), ["DIS", "KO"])
    XCTAssertEqual(m.merged(with: a).merged(with: b), m)
    XCTAssertEqual(m.gardenBook.principal, 80)
  }

  func testOldSavesWithoutAGardenDecode() throws {
    let old = #"{"schema":1,"guesses":[],"lessons":["company"],"lessonDates":{"company":"2026-10-28"},"seenBadges":[],"league":[],"quest":[],"questDone":false,"bonus":{"2026-10-28|game|x":20}}"#
    let s = try JSONDecoder().decode(KidsState.self, from: Data(old.utf8))
    XCTAssertNil(s.garden); XCTAssertEqual(s.gardenLimitPct, 50)
    XCTAssertEqual(Shop.wallet(s, content), s.points(content))
  }

  func testEventsRoundTripThroughTheSyncPayload() {
    var s = rich(); s.plant("DIS", points: 50, price: 113.5, today: day, id: eid(1), content)
    let back = Sync.decode(Sync.payload(s))
    XCTAssertEqual(back?.garden, s.garden)
    XCTAssertEqual(back.map { Shop.wallet($0, content) }, Shop.wallet(s, content))
  }

  // MARK: Badges and teaching moments

  func testSpreadItOutAndPatientPlanter() {
    var s = rich(1000); s.setGardenLimit(100, nowMillis: 1)
    for (i, sym) in ["DIS", "KO", "NKE"].enumerated() { s.plant(sym, points: 20, price: 100, today: day, id: eid(i + 1), content) }
    let spread = Trophies.progress(s, content).first { $0.trophy.id == "spread-out" }
    XCTAssertEqual(spread?.tier, 1, "3 companies at once = bronze")
    s.checkIn(today: Day.add(day, 8))
    let patient = Trophies.progress(s, content).first { $0.trophy.id == "patient-planter" }
    XCTAssertEqual(patient?.count, 8); XCTAssertEqual(patient?.tier, 1)
    // Harvesting keeps the record (badges never go backwards).
    s.harvest("DIS", points: 999, price: 100, today: Day.add(day, 9), id: eid(9))
    XCTAssertEqual(Trophies.progress(s, content).first { $0.trophy.id == "spread-out" }?.tier, 1)
  }

  func testBasketNudgeAndWisdom() {
    var s = rich(1000); s.setGardenLimit(100, nowMillis: 1)
    s.plant("DIS", points: 100, price: 100, today: day, id: eid(1), content)
    XCTAssertNotNil(Garden.basketNudge(s.gardenBook))
    s.plant("KO", points: 100, price: 100, today: day, id: eid(2), content)
    XCTAssertNil(Garden.basketNudge(s.gardenBook))
    XCTAssertFalse(Garden.wisdom(today: day).isEmpty)
  }

  /// Kid copy: no gambling or advice words, nothing about money, short sentences.
  func testCopyIsKidSafe() {
    var lines = Garden.wisdom + [Garden.marketNote(weekday: 1, hour: 9), Garden.marketNote(weekday: 3, hour: 10), Garden.marketNote(weekday: 3, hour: 18)]
    lines += [Garden.basketNudge({ var s = rich(); s.plant("DIS", points: 100, price: 100, today: day, id: eid(1), content); return s.gardenBook }()) ?? ""]
    for l in lines {
      for bad in ["bet", "gamble", "jackpot", "loot", "good buy", "you should", "cash", "money", "dollar", "win big"] {
        let words = " " + l.lowercased().map { $0.isLetter ? String($0) : " " }.joined() + " "
        XCTAssertFalse(words.contains(" \(bad) "), "\"\(bad)\" in: \(l)")
      }
      for sentence in l.split(whereSeparator: { ".!?".contains($0) }) { XCTAssertLessThanOrEqual(sentence.split(separator: " ").count, 20, l) }
    }
  }

  func testPricesAreDailyCloses() {
    let s = CandleSeries(s: "DIS", candles: [Candle(d: "2026-11-02", o: 1, h: 1, l: 1, c: 100), Candle(d: "2026-11-03", o: 1, h: 1, l: 1, c: 102), Candle(d: "2026-11-05", o: 1, h: 1, l: 1, c: 90)])
    XCTAssertEqual(Garden.close(s, onOrBefore: "2026-11-04")?.c, 102, "no price ticks between closes")
    XCTAssertEqual(Garden.dayMove(s, onOrBefore: "2026-11-04") ?? 0, 2, accuracy: 0.0001)
    XCTAssertEqual(Garden.spark(s, from: "2026-11-03", upTo: "2026-11-05"), [102, 90])
    XCTAssertEqual(Garden.marketNote(weekday: 7, hour: 12), "The market is sleeping for the weekend. Prices change on Monday.")
  }
}
