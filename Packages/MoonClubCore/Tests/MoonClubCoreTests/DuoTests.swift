import CoreGraphics
import XCTest
@testable import MoonClubCore

/// iPhone Duo: poses, hinge effects, the fold-aware spread and Game Night.
final class DuoTests: XCTestCase {
  let vFold = CGRect(x: 314, y: 0, width: 40, height: 951)   // inner display, book pose (division region incl. margins)
  let hFold = CGRect(x: 0, y: 314, width: 951, height: 40)   // inner display turned, tabletop pose

  func testPoseFromHingeAndFold() {
    XCTAssertEqual(Pose.of(nil, fold: nil), .noHinge, "nil hinge context = a device without a hinge")
    XCTAssertEqual(Pose.of(.init(.closed, degrees: 0), fold: nil), .closed)
    XCTAssertEqual(Pose.of(.init(.fullyOpen, degrees: 180), fold: vFold), .flat)
    XCTAssertEqual(Pose.of(.init(.partiallyOpen, degrees: 110), fold: vFold), .book)
    XCTAssertEqual(Pose.of(.init(.partiallyOpen, degrees: 100), fold: hFold), .tabletop)
    XCTAssertEqual(Pose.of(.init(.partiallyOpen, degrees: 100), fold: nil), .book, "no region reported yet: assume book")
  }

  func testLunasMoonWaxesAsThePhoneOpens() {
    XCTAssertEqual(HingeMoon.phase(.init(.closed, degrees: 0)), 0)
    XCTAssertEqual(HingeMoon.phase(.init(.partiallyOpen, degrees: 45)), 1)
    XCTAssertEqual(HingeMoon.phase(.init(.partiallyOpen, degrees: 90)), 2)
    XCTAssertEqual(HingeMoon.phase(.init(.partiallyOpen, degrees: 135)), 3)
    XCTAssertEqual(HingeMoon.phase(.init(.fullyOpen, degrees: 178)), 4, "fully open is a full moon even if the angle reads 178°")
    XCTAssertEqual(HingeMoon.phase(nil), 4, "no hinge: Luna stays full")
    XCTAssertEqual(HingeMoon.illumination(.init(.partiallyOpen, degrees: 400)), 1, "angles are clamped")
    XCTAssertEqual(HingeMoon.name(2), "Half moon")
    // Monotonic: opening never makes the moon smaller.
    let ph = stride(from: 0.0, through: 180, by: 5).map { HingeMoon.illumination(.init(.partiallyOpen, degrees: $0)) }
    XCTAssertEqual(ph, ph.sorted())
  }

  func testPiggyLidMovesOnlyWhileOpening() {
    XCTAssertEqual(PiggyLid.open(nil), 0)
    XCTAssertEqual(PiggyLid.open(.init(.closed, degrees: 0)), 0)
    XCTAssertEqual(PiggyLid.open(.init(.fullyOpen, degrees: 180)), 0, "flat = lid rests shut; the effect is for the act of opening")
    XCTAssertEqual(PiggyLid.open(.init(.partiallyOpen, degrees: 10)), 0)
    XCTAssertEqual(PiggyLid.open(.init(.partiallyOpen, degrees: 125)), 1, accuracy: 1e-9)
    let mid = PiggyLid.open(.init(.partiallyOpen, degrees: 70))
    XCTAssertGreaterThan(mid, 0.3); XCTAssertLessThan(mid, 0.7)
  }

  func testHingeMoments() {
    let open = HingeReading(.partiallyOpen, degrees: 90)
    XCTAssertEqual(HingeMoment.between(open, .init(.closed, degrees: 0)), .closed)
    XCTAssertEqual(HingeMoment.between(open, .init(.fullyOpen, degrees: 180)), .openedFlat)
    XCTAssertNil(HingeMoment.between(open, .init(.partiallyOpen, degrees: 100)), "angle jitter is not a moment")
    XCTAssertNil(HingeMoment.between(nil, .init(.closed, degrees: 0)), "the first reading is a state, not a change")
  }

  func testSpreadKeepsBothPagesOffTheFold() {
    let bounds = CGRect(x: 0, y: 0, width: 669, height: 951)
    let s = try! XCTUnwrap(Fold.spread(in: bounds, fold: vFold))
    XCTAssertTrue(s.sideBySide)
    XCTAssertFalse(s.first.intersects(vFold)); XCTAssertFalse(s.second.intersects(vFold))
    XCTAssertEqual(s.first.width, 314); XCTAssertEqual(s.second.minX, 354); XCTAssertEqual(s.second.maxX, 669)

    let t = try! XCTUnwrap(Fold.spread(in: CGRect(x: 0, y: 0, width: 951, height: 669), fold: hFold))
    XCTAssertFalse(t.sideBySide)
    XCTAssertEqual(t.first.maxY, 314); XCTAssertEqual(t.second.minY, 354)

    XCTAssertNil(Fold.spread(in: bounds, fold: nil), "no fold → one page")
    XCTAssertNil(Fold.spread(in: CGRect(x: 0, y: 0, width: 400, height: 900), fold: CGRect(x: 180, y: 0, width: 40, height: 900)), "pages too narrow → one page")
    XCTAssertNil(Fold.spread(in: CGRect(x: 0, y: 0, width: 300, height: 900), fold: vFold), "fold outside this view → one page")
  }

  func testEvenColumnsAcrossTheFold() {
    XCTAssertEqual(Fold.columns(width: 669, minimum: 200, spacing: 12, foldCrosses: false), 3)
    XCTAssertEqual(Fold.columns(width: 669, minimum: 200, spacing: 12, foldCrosses: true), 2)
    XCTAssertEqual(Fold.columns(width: 300, minimum: 200, spacing: 12, foldCrosses: true), 2, "never a single column split by the fold")
    XCTAssertEqual(Fold.columns(width: 300, minimum: 200, spacing: 12, foldCrosses: false), 1)
  }

  func testGameNightRevealsTogetherAndScores() {
    let ev: [(s: String, d: String, report: Report)] = [
      ("AAPL", "2026-10-30", Report(eA: 1.85, eE: 1.77)),   // beat
      ("NKE", "2026-10-01", Report(eA: 0.49, eE: 0.52)),    // miss
      ("DIS", "2026-11-12", Report(eA: nil, eE: 1.1)),      // future: excluded
      ("KO", "2026-10-21", Report(eA: 0.8, eE: nil)),       // no estimate: excluded
    ]
    var g = GameNight(events: ev, today: "2026-10-31")
    XCTAssertEqual(g.rounds.map(\.s), ["AAPL", "NKE"], "newest past report cards with a known result")
    XCTAssertEqual(g.answer, .beat)
    g.pick(0, .beat)
    XCTAssertFalse(g.revealed, "nothing is revealed until both players pick")
    g.next(); XCTAssertEqual(g.index, 0, "can't skip an unrevealed round")
    g.pick(1, .miss)
    XCTAssertTrue(g.revealed); XCTAssertEqual(g.scores, [1, 0])
    g.pick(1, .beat); XCTAssertEqual(g.scores, [1, 0], "picks lock once revealed")
    g.next()
    XCTAssertEqual(g.round?.s, "NKE"); XCTAssertEqual(g.answer, .miss)
    g.pick(0, .miss); g.pick(1, .miss)
    XCTAssertEqual(g.scores, [2, 1])
    g.next()
    XCTAssertTrue(g.isOver); XCTAssertEqual(g.winner, 0)
    XCTAssertTrue(GameNight(events: [], today: "2026-10-31").isOver)
  }
}
