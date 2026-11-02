// "Move my progress": the app must decode the website's code (vectors from metaphases `npm run export:kids`).
import XCTest
@testable import MoonClubCore

final class TransferTests: XCTestCase {
  var t: [String: Any] { VectorTests.v["transfer"] as! [String: Any] }
  var c: KidsContent { VectorTests.content }

  func testChecksumsMatchTheWeb() {
    for x in t["checksums"] as! [[String: String]] { XCTAssertEqual(Transfer.checksum(x["body"]!), x["out"]!, x["body"]!) }
  }

  func testDecodesTheWebsiteCode() throws {
    let s = try Transfer.decode(t["code"] as! String, companies: c.companies).get()
    let w = t["state"] as! [String: Any]
    XCTAssertEqual(Set(s.lessons), Set(w["lessons"] as! [String]))
    XCTAssertEqual(s.lessonDates, w["lessonDates"] as! [String: String])
    XCTAssertEqual(Set(s.quest), Set(w["quest"] as! [String])); XCTAssertTrue(s.questDone)
    XCTAssertEqual(Set(s.seenBadges), Set(w["seenBadges"] as! [String]))
    XCTAssertEqual(s.me, w["me"] as? Int)
    let wg = w["guesses"] as! [[String: Any]]
    XCTAssertEqual(s.guesses.count, wg.count)
    for g in wg {
      let m = try XCTUnwrap(s.guesses.first { $0.s == g["s"] as! String && $0.d == g["d"] as! String })
      XCTAssertEqual(m.pick.rawValue, g["pick"] as! String); XCTAssertEqual(m.price?.rawValue, g["price"] as? String)
      XCTAssertEqual(m.at, g["at"] as! String)
      XCTAssertEqual(m.result?.rawValue, g["result"] as? String); XCTAssertEqual(m.priceResult?.rawValue, g["priceResult"] as? String)
    }
    let wp = w["piggy"] as! [String: Any]
    XCTAssertEqual(s.piggy?.started, wp["started"] as? String)
    XCTAssertEqual(s.piggy?.history, (wp["history"] as! [String: NSNumber]).mapValues(\.doubleValue))
    XCTAssertEqual(s.piggy?.holdings.map(\.s).sorted(), (wp["holdings"] as! [[String: Any]]).map { $0["s"] as! String }.sorted())
    let wl = (w["league"] as! [[String: Any]]).first!
    XCTAssertEqual(s.league.first?.emoji, wl["emoji"] as? Int)
    XCTAssertEqual(s.league.first?.guesses.count, (wl["guesses"] as! [Any]).count)
  }

  func testFindsTheCodeInPastedText() {
    XCTAssertNoThrow(try Transfer.decode(t["pasted"] as! String, companies: c.companies).get())
  }

  func testRejectsBadCodes() {
    for x in t["bad"] as! [[String: String]] {
      guard case .failure(let f) = Transfer.decode(x["code"]!, companies: c.companies) else { return XCTFail("accepted \(x["code"]!)") }
      XCTAssertEqual(f == .notACode ? "notACode" : f == .damaged ? "damaged" : "tooBig", x["why"]!)
    }
  }

  func testImportMergesAndIsSafeToPasteTwice() throws {
    let s = try Transfer.decode(t["code"] as! String, companies: c.companies).get()
    var mine = KidsState(); mine.finishLesson("profit", today: "2026-11-01")
    let once = mine.merged(with: s), twice = once.merged(with: s)
    XCTAssertEqual(once, twice)
    XCTAssertTrue(once.lessons.contains("profit")); XCTAssertTrue(once.lessons.contains("share"))
  }
}
