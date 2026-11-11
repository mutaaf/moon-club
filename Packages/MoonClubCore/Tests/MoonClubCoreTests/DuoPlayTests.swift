import CoreGraphics
import XCTest
@testable import MoonClubCore

/// iPhone Duo play (0.14): hinge light, tent mode, page flicks, fold to save, the pocket, Market Race,
/// the atlas, the graphics budget, and the new Duo-only rewards.
final class DuoPlayTests: XCTestCase {
  let vFold = CGRect(x: 314, y: 0, width: 40, height: 951)
  let hFold = CGRect(x: 0, y: 314, width: 951, height: 40)
  func open(_ d: Double) -> HingeReading { .init(.partiallyOpen, degrees: d) }

  lazy var content: KidsContent = {
    let url = Bundle.module.url(forResource: "kids-content", withExtension: "json")!
    return try! KidsContent.load(Data(contentsOf: url))
  }()
  lazy var series: [CandleSeries] = {
    let url = Bundle.module.url(forResource: "candles", withExtension: "json")!
    return try! JSONDecoder().decode(CandleBundle.self, from: Data(contentsOf: url)).all
  }()

  func testTheSunRisesAsThePhoneOpens() {
    XCTAssertEqual(HingeLight.sun(nil), 1, "no hinge: always full day")
    XCTAssertEqual(HingeLight.sun(.init(.closed, degrees: 0)), 0)
    XCTAssertEqual(HingeLight.sun(.init(.fullyOpen, degrees: 178)), 1)
    let suns = stride(from: 0.0, through: 180, by: 5).map { HingeLight.sun(open($0)) }
    XCTAssertEqual(suns, suns.sorted(), "opening never sets the sun")
    XCTAssertEqual(HingeLight.lunaLight(nil), -2.2, accuracy: 1e-9)
    XCTAssertLessThan(HingeLight.lunaLight(open(20)), HingeLight.lunaLight(open(160)), "Luna's light swings round as it opens")
    XCTAssertEqual(HingeLight.seam(nil), 0); XCTAssertEqual(HingeLight.seam(.init(.closed, degrees: 0)), 0)
    XCTAssertGreaterThan(HingeLight.seam(open(60)), HingeLight.seam(.init(.fullyOpen, degrees: 180)), "deeper seam when half open")
    XCTAssertEqual(HingeLight.fogPart(.init(.fullyOpen, degrees: 180)), 0, "fog parts only while unfolding")
    XCTAssertLessThanOrEqual(HingeLight.fogPart(open(170)), 0.35, "a peek, never a clear view of a locked land")
  }

  func testTentIsANarrowSteadyStandWithAVerticalFold() {
    XCTAssertTrue(Stance.isTentAngle(open(70), fold: vFold))
    XCTAssertTrue(Stance.isTentAngle(open(70), fold: nil))
    XCTAssertFalse(Stance.isTentAngle(open(70), fold: hFold), "a horizontal fold is tabletop")
    XCTAssertFalse(Stance.isTentAngle(open(130), fold: vFold), "wide is a book")
    XCTAssertFalse(Stance.isTentAngle(.init(.closed, degrees: 0), fold: nil))
    XCTAssertFalse(Stance.isTentAngle(nil, fold: nil))
    var t = Stance.Tracker()
    XCTAssertFalse(t.feed(open(70), at: 0))
    XCTAssertFalse(t.feed(open(72), at: 1.0), "not steady long enough yet")
    XCTAssertTrue(t.feed(open(75), at: 1.3))
    XCTAssertFalse(t.feed(open(140), at: 1.4), "leaving the window ends it at once")
    XCTAssertFalse(t.feed(open(70), at: 1.5), "and the clock starts again")
  }

  func testAQuickFoldFlickTurnsThePageButASlowMoveDoesNot() {
    var f = PageFlick()
    XCTAssertFalse(f.feed(open(130), at: 0))
    XCTAssertFalse(f.feed(open(100), at: 0.2))
    XCTAssertTrue(f.feed(open(126), at: 0.5), "dip 30°, back within 10°")
    var slow = PageFlick()
    XCTAssertFalse(slow.feed(open(130), at: 0))
    XCTAssertFalse(slow.feed(open(100), at: 1.0))
    XCTAssertFalse(slow.feed(open(128), at: 2.0), "too slow")
    var shallow = PageFlick()
    _ = shallow.feed(open(130), at: 0); _ = shallow.feed(open(115), at: 0.2)
    XCTAssertFalse(shallow.feed(open(129), at: 0.4), "a 15° wobble isn't a flick")
    var closed = PageFlick()
    XCTAssertFalse(closed.feed(.init(.closed, degrees: 0), at: 0))
  }

  func testFoldToSaveLidFollowsTheHingeAndCommitsOnClose() {
    XCTAssertEqual(FoldSave.lid(nil), 0)
    XCTAssertEqual(FoldSave.lid(open(120)), 0)
    XCTAssertEqual(FoldSave.lid(.init(.closed, degrees: 0)), 1)
    XCTAssertGreaterThan(FoldSave.lid(open(30)), FoldSave.lid(open(60)))
    XCTAssertTrue(FoldSave.commits(from: open(20), to: .init(.closed, degrees: 0), ready: true))
    XCTAssertFalse(FoldSave.commits(from: open(20), to: .init(.closed, degrees: 0), ready: false), "nothing valid to plant")
    XCTAssertFalse(FoldSave.commits(from: .init(.closed, degrees: 0), to: .init(.closed, degrees: 0), ready: true))
    XCTAssertFalse(FoldSave.commits(from: nil, to: .init(.closed, degrees: 0), ready: true), "first reading is not a close")
  }

  func testPocketGlanceAndWake() {
    let g = PocketGlance.make(KidsState(), content, candles: [:], today: "2026-11-03")
    XCTAssertEqual(g.missionsDone, 0)
    XCTAssertGreaterThan(g.missionsTotal, 0)
    XCTAssertEqual(g.gardenValue, 0)
    XCTAssertTrue(g.line.contains("missions"))
    XCTAssertEqual(PocketGlance(missionsDone: 3, missionsTotal: 3, gardenValue: 0, gardenPlanted: 0, chestReady: false).line, "All missions done. Great job!")
    XCTAssertEqual(PocketGlance(missionsDone: 2, missionsTotal: 3, gardenValue: 0, gardenPlanted: 0, chestReady: false).line, "1 more mission to go!")
    for l in [g.line, PocketGlance(missionsDone: 3, missionsTotal: 3, gardenValue: 1, gardenPlanted: 0, chestReady: true).line] {
      XCTAssertFalse(l.lowercased().contains("buy") || l.lowercased().contains("hurry"))
    }
    XCTAssertFalse(PocketWake.wakes(x: 0.01, y: 0.02, z: 0.01), "lying still on a table")
    XCTAssertTrue(PocketWake.wakes(x: 0.05, y: 0.1, z: 0.02), "picked up")
  }

  func testMarketRaceIsFairAndEnds() {
    let a = MarketRace(series: series, seed: 42), b = MarketRace(series: series, seed: 42)
    XCTAssertEqual(a.asks, b.asks, "seeded: a rematch and both halves agree")
    XCTAssertGreaterThanOrEqual(a.asks.count, 20)
    XCTAssertTrue(a.asks.contains { if case .trend = $0 { return true }; return false })
    var r = a
    // Player 0 always right and first; player 1 always wrong.
    while !r.isOver, let q = r.ask {
      r.pick(0, up: q.answerUp); XCTAssertFalse(r.revealed, "picks stay hidden until both are in")
      r.pick(1, up: !q.answerUp); XCTAssertTrue(r.revealed)
      XCTAssertEqual(r.gained, [2, 0], "first right answer gets the boost")
      r.next()
    }
    XCTAssertEqual(r.winner, 0)
    XCTAssertEqual(r.spots[0], MarketRace.finish)
    // Both right: the first gets 2, the second 1.
    var s = a
    if let q = s.ask { s.pick(1, up: q.answerUp); s.pick(0, up: q.answerUp) }
    XCTAssertEqual(s.gained, [1, 2])
    s.pick(0, up: true); XCTAssertEqual(s.spots, [1, 2], "no picks after the reveal")
    XCTAssertTrue(MarketRace(series: [], seed: 1).asks.isEmpty)
    XCTAssertNil(MarketRace(series: [], seed: 1).ask)
  }

  func testAtlasHasAKidSafeStoryForEveryLand() {
    let rs = World.regions(content)
    XCTAssertGreaterThanOrEqual(rs.count, 7)
    for r in rs {
      let p = Atlas.page(r)
      XCTAssertEqual(p.title, r.name)
      XCTAssertGreaterThanOrEqual(p.story.count, 2, r.id)
      for line in p.story + [p.fact] {
        XCTAssertLessThanOrEqual(line.count, 110, "fits a page: \(line)")
        for w in ["buy", "sell now", "should", "hurry", "bet"] { XCTAssertFalse(line.lowercased().contains(w), "\(r.id): \(w)") }
      }
    }
    XCTAssertEqual(Atlas.turn(0, by: -1, count: 7), 0)
    XCTAssertEqual(Atlas.turn(6, by: 1, count: 7), 6)
    XCTAssertEqual(Atlas.turn(2, by: 1, count: 7), 3)
  }

  func testGraphicsBudget() {
    XCTAssertEqual(FXLevel.of(visible: false, active: true, reduceMotion: false, lowPower: false, thermal: 0), .paused)
    XCTAssertEqual(FXLevel.of(visible: true, active: false, reduceMotion: false, lowPower: false, thermal: 0), .paused)
    XCTAssertEqual(FXLevel.of(visible: true, active: true, reduceMotion: true, lowPower: false, thermal: 0), .still)
    XCTAssertEqual(FXLevel.of(visible: true, active: true, reduceMotion: false, lowPower: true, thermal: 0), .still)
    XCTAssertEqual(FXLevel.of(visible: true, active: true, reduceMotion: false, lowPower: false, thermal: 2), .still, "serious heat")
    XCTAssertEqual(FXLevel.of(visible: true, active: true, reduceMotion: false, lowPower: false, thermal: 1), .full)
  }

  func testDuoRewardsAreEarnedOnDuoAndHiddenElsewhere() {
    var s = KidsState()
    for id in ["rocket.twin", "hat.twin"] {
      XCTAssertTrue(Shop.duoOnly.contains(id))
      XCTAssertFalse(Shop.visible(hinge: false, s).contains { $0.id == id }, "no Duo items without a hinge")
      XCTAssertTrue(Shop.visible(hinge: true, s).contains { $0.id == id })
    }
    for id in ["duo-puppet", "duo-race", "duo-atlas", "duo-fold"] {
      XCTAssertFalse(Trophies.visible(hinge: false, s).contains { $0.id == id })
    }
    let twin = Shop.item("rocket.twin")
    XCTAssertEqual(twin.flatMap { Shop.lock($0, s, content) }, .trophy("Market Racer"))
    s.useDuo(.race)
    XCTAssertEqual(Trophies.progress(s, content).first { $0.trophy.id == "duo-race" }?.tier, 1)
    XCTAssertFalse(Skins.all.contains { $0.id == "twin" }, "never granted as a legacy chest skin")
    // Old chests can't hand out the Duo rocket.
    var old = KidsState(); old.chests = (0..<20).map { "2025-01-\(String(format: "%02d", $0 + 1))" }
    XCTAssertFalse(Shop.owned(old).contains("rocket.twin"))
  }

  func testFoldSealArmsOnlyWhenOpen() {
    XCTAssertFalse(FoldSeal.armed(nil))
    XCTAssertFalse(FoldSeal.armed(.init(.closed, degrees: 0)))
    XCTAssertTrue(FoldSeal.armed(.init(.partiallyOpen, degrees: 110)))
    XCTAssertTrue(FoldSeal.armed(.init(.fullyOpen, degrees: 180)))
    XCTAssertEqual(FoldSeal.flap(.init(.fullyOpen, degrees: 180)), 0)
    XCTAssertEqual(FoldSeal.flap(.init(.closed, degrees: 0)), 1)
    XCTAssertGreaterThan(FoldSeal.flap(.init(.partiallyOpen, degrees: 20)), FoldSeal.flap(.init(.partiallyOpen, degrees: 60)))
  }
}
