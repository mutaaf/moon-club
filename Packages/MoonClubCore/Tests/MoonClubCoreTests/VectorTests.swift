// The Swift port must reproduce every vector exported from the web (metaphases
// `npm run export:kids`). If a vector fails, web and app disagree — fix the port, not the vector.
import XCTest
@testable import MoonClubCore

final class VectorTests: XCTestCase {
  static let raw: Data = try! Data(contentsOf: Bundle.module.url(forResource: "kids-content", withExtension: "json")!)
  static let content = try! KidsContent.load(raw)
  static let v = (try! JSONSerialization.jsonObject(with: raw) as! [String: Any])["vectors"] as! [String: Any]
  var c: KidsContent { Self.content }
  func list(_ k: String) -> [[String: Any]] { Self.v[k] as! [[String: Any]] }
  func dbl(_ x: Any?) -> Double? { (x as? NSNumber)?.doubleValue }

  func testContentLoadsAndValidates() {
    XCTAssertGreaterThanOrEqual(c.lessons.count, 9)
    XCTAssertEqual(c.players.count, 8)
    XCTAssertNoThrow(try c.validate())
  }

  func testWeather() {
    for x in list("weatherFor") {
      let out = x["out"] as! [String: String], w = weatherFor(dbl(x["score"])!)
      XCTAssertEqual([w.icon, w.emoji, w.title, w.line], [out["icon"]!, out["emoji"]!, out["title"]!, out["line"]!], "score \(x["score"]!)")
    }
  }
  func testKidWhen() {
    for x in list("kidWhen") {
      XCTAssertEqual(kidWhen(x["date"] as! String, Session(rawValue: x["session"] as! String)!, today: x["today"] as! String), x["out"] as! String)
    }
  }
  func testLines() {
    for x in list("expectLine") { XCTAssertEqual(expectLine(dbl(x["epsE"])), x["out"] as! String) }
    for x in list("lastTimeLine") { XCTAssertEqual(lastTimeLine(dbl(x["move"])), x["out"] as! String) }
    for x in list("whyLine") { let e = x["e"] as! [String: Any]; XCTAssertEqual(whyLine("Apple", Report(eA: dbl(e["eA"]), eE: dbl(e["eE"]))), x["out"] as! String) }
  }
  func testResolve() {
    for x in list("resolveGuess") {
      let e = x["e"] as? [String: Any]
      XCTAssertEqual(resolveGuess(Pick(rawValue: x["pick"] as! String)!, e.map { Report(eA: dbl($0["eA"]), eE: dbl($0["eE"])) }).rawValue, x["out"] as! String)
    }
    for x in list("resolvePrice") {
      XCTAssertEqual(resolvePrice((x["pick"] as? String).flatMap(Direction.init), dbl(x["move"])).rawValue, x["out"] as! String)
    }
  }
  func testPiggyMath() {
    for x in list("evenSplit") {
      XCTAssertEqual(evenSplit(x["syms"] as! [String]), (x["out"] as! [String: NSNumber]).mapValues(\.intValue))
    }
    let bp = list("buyPretend")[0]
    let coins: [(String, Double)] = [("DIS", 400), ("RBLX", 300), ("KO", 300), ("HSY", 0)]
    let prices = (bp["prices"] as! [String: NSNumber]).mapValues(\.doubleValue)
    let h = buyPretend(coins, prices: prices)
    let want = (bp["out"] as! [[String: Any]])
    XCTAssertEqual(h.map(\.s), want.map { $0["s"] as! String })
    for (a, b) in zip(h, want) { XCTAssertEqual(a.shares, dbl(b["shares"])!, accuracy: 1e-12); XCTAssertEqual(a.start, dbl(b["start"])!) }
    let pv = list("piggyValue")[0], pvPrices = (pv["prices"] as! [String: Any]).compactMapValues { dbl($0) }
    XCTAssertEqual(piggyValue(h, prices: pvPrices), dbl(pv["out"])!, accuracy: 1e-9)
    for x in list("holdingChange") {
      let hh = x["holding"] as! [String: Any]
      let ph = PiggyHolding(s: hh["s"] as! String, coins: dbl(hh["coins"])!, shares: dbl(hh["shares"])!, start: dbl(hh["start"])!)
      XCTAssertEqual(holdingChange(ph, price: dbl(x["price"])), dbl(x["out"])!, accuracy: 1e-9)
    }
    let bm = list("biggestMover")[0]["out"] as! [String: Any]
    let m = biggestMover(h, prices: pvPrices)!
    XCTAssertEqual(m.s, bm["s"] as! String); XCTAssertEqual(m.change, dbl(bm["change"])!, accuracy: 1e-9)
    for x in list("basketTip") { XCTAssertEqual(basketTip((x["n"] as! NSNumber).intValue), x["out"] as! String) }
  }
  func progress(_ o: [String: Any]) -> KidsProgress {
    KidsProgress(guesses: (o["guesses"] as! [[String: Any]]).map(guess), lessons: o["lessons"] as! [String], piggy: o["piggy"] as! Bool,
                 piggyCount: (o["piggyCount"] as! NSNumber).intValue, quest: (o["quest"] as? Bool) ?? false, chapters: (o["chapters"] as? [String]) ?? [])
  }
  func guess(_ g: [String: Any]) -> Guess {
    Guess(s: g["s"] as! String, d: g["d"] as! String, pick: Pick(rawValue: g["pick"] as! String)!, price: (g["price"] as? String).flatMap(Direction.init),
          at: g["at"] as! String, result: (g["result"] as? String).flatMap(Outcome.init), priceResult: (g["priceResult"] as? String).flatMap(Outcome.init))
  }
  func testLevelsPointsBadges() {
    for x in list("levelFor") {
      let out = x["out"] as! [String: Any], l = levelFor((x["points"] as! NSNumber).intValue, levels: c.levels)
      XCTAssertEqual(l.index, (out["index"] as! NSNumber).intValue); XCTAssertEqual(l.name, out["name"] as! String)
      XCTAssertEqual(l.next, (out["next"] as? NSNumber)?.intValue); XCTAssertEqual(l.progress, dbl(out["progress"])!, accuracy: 1e-12)
    }
    for x in list("pointsFor") { XCTAssertEqual(pointsFor(progress(x["progress"] as! [String: Any])), (x["out"] as! NSNumber).intValue) }
    for x in list("badgesFor") { XCTAssertEqual(badgesFor(progress(x["progress"] as! [String: Any]), totalLessons: (x["totalLessons"] as! NSNumber).intValue), x["out"] as! [String]) }
  }
  func testReadingLevel() {
    for x in list("syllables") { XCTAssertEqual(syllables(x["word"] as! String), (x["out"] as! NSNumber).intValue, x["word"] as! String) }
    for x in list("fkGrade") { XCTAssertEqual(fkGrade(x["text"] as! String), dbl(x["out"])!, accuracy: 1e-9, x["text"] as! String) }
  }
  func testOfTheDay() {
    for x in list("ofTheDay") {
      XCTAssertEqual(ofTheDayIndex(count: (x["n"] as! NSNumber).intValue, today: x["today"] as! String, salt: (x["salt"] as! NSNumber).intValue), (x["index"] as! NSNumber).intValue)
    }
  }
  func testRecap() {
    for x in list("recapWeek") {
      let w = recapWeek(x["today"] as! String), out = x["out"] as? [String: String]
      XCTAssertEqual(w?.from, out?["from"]); XCTAssertEqual(w?.to, out?["to"]); XCTAssertEqual(w?.label, out?["label"])
    }
    for x in list("recap") {
      let i = x["input"] as! [String: Any]
      let pg = (i["piggy"] as? [String: Any]).map { RecapPiggy(started: $0["started"] as! String, history: ($0["history"] as! [String: NSNumber]).mapValues(\.doubleValue)) }
      let input = RecapInput(guesses: (i["guesses"] as! [[String: Any]]).map(guess), lessonDates: (i["lessonDates"] as? [String: String]) ?? [:], piggy: pg,
                             points: (i["points"] as! NSNumber).intValue, level: (i["level"] as! NSNumber).intValue)
      let r = buildRecap(input, today: x["today"] as! String, levels: c.levels.count)
      guard let out = x["out"] as? [String: Any] else { XCTAssertNil(r); continue }
      XCTAssertEqual(r?.guesses, (out["guesses"] as! NSNumber).intValue); XCTAssertEqual(r?.right, (out["right"] as! NSNumber).intValue)
      XCTAssertEqual(r?.lessons, (out["lessons"] as! NSNumber).intValue); XCTAssertEqual(r?.active, out["active"] as? Bool)
      XCTAssertEqual(r?.piggyPct, dbl(out["piggyPct"]))
      XCTAssertEqual(recapLines(r!, levels: c.levels), x["lines"] as! [String])
      XCTAssertEqual(recapQuery(r!), x["query"] as! String)
    }
  }
  func leaguePlayer(_ o: [String: Any]) -> LeaguePlayer {
    LeaguePlayer(emoji: (o["emoji"] as! NSNumber).intValue, guesses: (o["guesses"] as! [[String: Any]]).map {
      LeagueGuess(s: $0["s"] as! String, d: $0["d"] as! String, pick: Pick(rawValue: $0["pick"] as! String)!, price: ($0["price"] as? String).flatMap(Direction.init)) })
  }
  func testLeagueCodecIsWebCompatible() {
    for x in list("leagueEncode") { XCTAssertEqual(League.encode(leaguePlayer(x["player"] as! [String: Any]), companies: c.companies), x["code"] as! String) }
    for x in list("leagueDecode") {
      let r = League.decode(x["code"] as! String, companies: c.companies), out = x["out"] as! [String: Any]
      if out["ok"] as! Bool {
        guard case let .success(p) = r else { return XCTFail("should decode \(x["code"]!)") }
        XCTAssertEqual(p, leaguePlayer(out["player"] as! [String: Any]))
      } else {
        guard case let .failure(e) = r else { return XCTFail("should reject \(x["code"]!)") }
        XCTAssertEqual(e.message, out["why"] as! String)
      }
    }
    let lr = list("leagueRows")[0]
    let rows = League.rows((lr["players"] as! [[String: Any]]).map(leaguePlayer), limit: 10)
    XCTAssertEqual(rows.map(\.key), (lr["out"] as! [[String: Any]]).map { $0["key"] as! String })
  }
}
