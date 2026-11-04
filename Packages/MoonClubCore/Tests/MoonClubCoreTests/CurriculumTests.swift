// Lesson packs, "Why did it move?", Luna's coach and spaced review. The web exports the vectors
// (metaphases `npm run export:kids`); if one fails, web and app disagree: fix the port, not the vector.
import XCTest
@testable import MoonClubCore

final class CurriculumTests: XCTestCase {
  var c: KidsContent { VectorTests.content }
  var v: [String: Any] { VectorTests.v }
  func dbl(_ x: Any?) -> Double? { (x as? NSNumber)?.doubleValue }
  func decode<T: Decodable>(_ t: T.Type, _ any: Any) throws -> T { try JSONDecoder().decode(T.self, from: JSONSerialization.data(withJSONObject: any)) }

  // MARK: Packs
  func testCoreManifestAndCourses() throws {
    let meta = try XCTUnwrap(c.pack)
    XCTAssertEqual(meta.id, "core")
    XCTAssertTrue(meta.reviewers.contains { $0.role == "teacher" && $0.signedOff != nil })
    XCTAssertTrue(meta.reviewers.contains { $0.role == "markets" && $0.signedOff != nil })
    XCTAssertEqual(c.guessCourse?.ladder.first, "report-card")
    XCTAssertEqual(c.piggyCourse?.ladder.first, "piggy-start")
    XCTAssertEqual(Set(c.lessons.compactMap(\.track)), ["6-8", "9-11", "challenge"])
    XCTAssertEqual(c.optionalTracks, ["challenge"], "Full Moons is the only optional track")
    XCTAssertTrue(PackRules.validate(c.corePack).isEmpty, "\(PackRules.validate(c.corePack))")
  }
  func testValidatorAgreesWithTheWeb() throws {
    let core = c.corePack
    for x in v["packValidate"] as! [[String: Any]] {
      let p = try decode(LessonPack.self, x["pack"]!)
      let withCore = x["withCore"] as! Bool
      let codes = Set(PackRules.validate(p, base: withCore && p.kind != "core" ? core : nil).map(\.code)).sorted()
      XCTAssertEqual(codes, (x["codes"] as! [String]), x["name"] as! String)
    }
  }
  func testBundledPacksValidateAgainstCore() {
    XCTAssertFalse(c.bundledPacks.isEmpty)
    for p in c.bundledPacks {
      XCTAssertEqual(PackRules.validate(p, base: c.corePack), [], p.id)
      XCTAssertNotNil(p.hostBadge, "a guest pack always discloses its host on screen")
    }
  }
  func testComposeMatchesTheWeb() throws {
    let x = v["compose"] as! [String: Any]
    let ids = x["packs"] as! [String]
    let composed = c.with(packs: c.bundledPacks.filter { ids.contains($0.id) })
    XCTAssertEqual(composed.units.map(\.id), x["units"] as! [String])
    XCTAssertEqual(composed.lessons.map(\.id), x["lessons"] as! [String])
    XCTAssertEqual(composed.regions?.map(\.id), x["regions"] as? [String])
    XCTAssertEqual(composed.terms.keys.sorted(), x["glossary"] as! [String])
    XCTAssertEqual(composed.activePacks, ids)
    // The composed map shows the guest island, and the core map is unchanged without packs.
    XCTAssertTrue(World.regions(composed).contains { $0.id == "nova-cove" })
    XCTAssertFalse(World.regions(c).contains { $0.id == "nova-cove" })
    XCTAssertNoThrow(try composed.validate())
  }
  func testAnInvalidPackIsNeverComposed() {
    guard var bad = c.bundledPacks.first else { return XCTFail() }
    bad.units[0] = PackUnit(id: "money", title: "x", emoji: "🚀", blurb: "x", track: nil, objectives: nil, lessons: bad.units[0].lessons)
    XCTAssertEqual(c.with(packs: [bad]).units.count, c.units.count)
  }
  func testSignedChannel() throws {
    let x = try XCTUnwrap(v["packSig"] as? [String: Any])
    let body = Data(base64Encoded: x["body"] as! String)!, sig = x["sig"] as! String, key = x["publicKey"] as! String
    XCTAssertEqual(c.channel?.publicKey, key, "the app trusts the key that ships with its content")
    XCTAssertTrue(PackChannel.verify(body: body, signature: sig, publicKey: key), "Node's Ed25519 signature verifies in CryptoKit")
    XCTAssertFalse(PackChannel.verify(body: Data(base64Encoded: x["tampered"] as! String)!, signature: sig, publicKey: key))
    // A correctly signed pack is still refused until a human signs it off.
    XCTAssertEqual(PackChannel.accept(body: body, signature: sig, trustedKey: key, core: c.corePack), .failure(.notReady))
    XCTAssertEqual(PackChannel.accept(body: body, signature: sig, trustedKey: "Rr1jkmN/61muHIPrXAana7n5tNlxQwX7Ys8fdeDQMSA=", core: c.corePack), .failure(.badSignature))
    XCTAssertFalse(PackChannel.remoteEnabled, "remote packs stay off until a human-signed pack is ready")
  }

  // MARK: Why did it move?
  func testWhyMatchesTheWeb() throws {
    for x in v["why"] as! [[String: Any]] {
      let input = try decode(WhyInput.self, x["input"]!)
      let want = try decode(WhyResult.self, x["out"]!)
      XCTAssertEqual(Why.explain(input, today: x["today"] as? String), want, want.headline)
    }
  }
  func testWhyInputBuilderMatchesTheWeb() throws {
    for x in v["whyBuild"] as! [[String: Any]] {
      let a = x["args"] as! [String: Any]
      func series(_ k: String) throws -> Why.Series? { (a[k] is NSNull || a[k] == nil) ? nil : try decode(Why.Series.self, a[k]!) }
      let got = Why.buildInput(s: a["s"] as! String, nick: a["nick"] as! String, range: WhyRange(rawValue: a["range"] as! String)!,
                               stock: try series("stock"), spy: try series("spy"), sector: try series("sector"),
                               reports: try decode([Why.ReportRow].self, a["reports"]!), dividends: try decode([Why.DividendRow].self, a["dividends"]!))
      XCTAssertEqual(got, try decode(WhyInput.self, x["input"]!), a["s"] as! String)
    }
  }
  func testReportResultMatchesTheWeb() {
    for x in v["reportResult"] as! [[String: Any]] { XCTAssertEqual(Why.reportResult(eA: dbl(x["eA"])!, eE: dbl(x["eE"])!).rawValue, x["out"] as! String) }
  }
  func testWhyNeverInventsACause() {
    let big = Why.explain(WhyInput(s: "DIS", nick: "Disney", range: .day, move: 9, market: nil, sector: nil, report: nil, dividend: nil, normal: 1.4, asOf: "2026-10-30"), today: "2026-10-30")
    XCTAssertEqual(big.causes.map(\.id), ["unknown"])
    XCTAssertEqual(Why.when(.day, asOf: "2026-10-30", today: "2026-11-01"), "on Friday")
    for (s, _) in Why.sectorOf { XCTAssertNotNil(c.companyBySymbol[s], s) }
  }

  // MARK: Coach
  func testCoachMatchesTheWeb() throws {
    let x = v["coach"] as! [String: Any]
    let g = try XCTUnwrap(c.guessCourse), p = try XCTUnwrap(c.piggyCourse)
    for n in x["next"] as! [[String: Any]] {
      let got = Coach.next(g.ladder, done: n["done"] as! [String])
      if let o = n["out"] as? [String: Any] { XCTAssertEqual(got, Coach.Next(id: o["id"] as! String, index: o["index"] as! Int, of: o["of"] as! Int)) } else { XCTAssertNil(got) }
    }
    for r in x["reveal"] as! [[String: Any]] {
      let i = r["r"] as! [String: Any]
      XCTAssertEqual(Coach.reveal(g, eA: dbl(i["eA"]), eE: dbl(i["eE"]), move: dbl(i["move"])), r["out"] as! String)
      XCTAssertEqual(Coach.revealKey(eA: dbl(i["eA"]), eE: dbl(i["eE"]), move: dbl(i["move"])), r["key"] as! String)
      XCTAssertEqual(Coach.learn(g, eA: dbl(i["eA"]), eE: dbl(i["eE"]), move: dbl(i["move"])), r["learn"] as? String)
    }
    for t in x["piggy"] as! [[String: Any]] {
      let i = t["x"] as! [String: Any], o = t["out"] as! [String: String]
      let got = Coach.piggyTip(p, .init(holdings: i["holdings"] as! Int, started: i["started"] as! String, today: i["today"] as! String, value: dbl(i["value"])!, start: dbl(i["start"])!, peeks: i["peeks"] as! Int, groups: i["groups"] as? Int))
      XCTAssertEqual([got.key, got.text], [o["key"]!, o["text"]!])
    }
  }

  // MARK: Spaced review and mastery
  func testAMissComesBackAndClimbsTheBoxes() throws {
    var s = KidsState()
    s.finishLesson("share", today: "2026-11-01")
    let item = Review.itemId("share", 3)
    s.answer(item, right: false, today: "2026-11-01", review: false)
    XCTAssertEqual(Review.due(s, c, today: "2026-11-01").first?.id, item, "a miss comes back at the very next Review stop")
    s.answer(item, right: true, today: "2026-11-01", review: true)          // box 1: back in a day
    XCTAssertFalse(Review.due(s, c, today: "2026-11-01").contains { $0.id == item })
    XCTAssertTrue(Review.due(s, c, today: "2026-11-02").contains { $0.id == item })
    s.answer(item, right: true, today: "2026-11-02", review: true)          // box 2: back in 3 days
    XCTAssertFalse(Review.due(s, c, today: "2026-11-04").contains { $0.id == item })
    XCTAssertTrue(Review.due(s, c, today: "2026-11-05").contains { $0.id == item })
    s.answer(item, right: false, today: "2026-11-05", review: true)         // a miss starts it over
    XCTAssertEqual(Review.entry(s, item)?.box, 0)
  }
  func testALessonReplayDoesNotSkipTheSpacing() {
    var s = KidsState(); let item = Review.itemId("share", 3)
    s.answer(item, right: false, today: "2026-11-01", review: false)
    s.answer(item, right: true, today: "2026-11-01", review: false)
    XCTAssertEqual(Review.entry(s, item)?.box, 0)
    var t = KidsState(); t.answer(item, right: true, today: "2026-11-01", review: false)
    XCTAssertNil(t.review, "right answers in a lesson record nothing about the child")
  }
  func testFinishedLessonsComeBackOnceSpacedAndInterleaved() {
    var s = KidsState()
    for l in ["money", "share", "candle"] { s.finishLesson(l, today: "2026-10-28") }
    XCTAssertTrue(Review.due(s, c, today: "2026-10-28").isEmpty, "not on the same day")
    let due = Review.due(s, c, today: "2026-10-30")
    XCTAssertEqual(due.count, min(5, Review.items(c).filter { ["money", "share", "candle"].contains($0.lesson) }.count))
    XCTAssertEqual(Set(due.prefix(3).map(\.unit)).count, 3, "a Review stop mixes units")
    for it in due { s.answer(it.id, right: true, today: "2026-10-30", review: true) }
    XCTAssertFalse(Review.due(s, c, today: "2026-10-31").contains { due.map(\.id).contains($0.id) })
  }
  func testMasteryByUnit() {
    var s = KidsState()
    XCTAssertEqual(Review.mastery("money", s, c), .notStarted)
    s.finishLesson("money", today: "2026-11-01")
    XCTAssertEqual(Review.mastery("money", s, c), .learning)
    for l in c.lessons where l.unit == "money" { s.finishLesson(l.id, today: "2026-11-01") }
    XCTAssertEqual(Review.mastery("money", s, c), .mastered)
    for it in Review.items(c) where it.unit == "money" { s.answer(it.id, right: false, today: "2026-11-01", review: false) }
    XCTAssertEqual(Review.mastery("money", s, c), .practicing)
  }
  func testReviewMergeIsAJoin() {
    var a = KidsState(), b = KidsState()
    a.review = ["share#3": "2026-11-01|0", "money#3": "2026-11-02|2"]
    b.review = ["share#3": "2026-11-03|1"]
    let m = a.merged(with: b)
    XCTAssertEqual(m.review, ["share#3": "2026-11-03|1", "money#3": "2026-11-02|2"])
    XCTAssertEqual(m, b.merged(with: a))
  }

  // MARK: 0.15: worked examples, growth pictures, refresh, the challenge track and a growing map
  func testGrowMatchesTheWeb() throws {
    for x in v["grow"] as! [[String: Any]] {
      let kind = Growth.Kind(rawValue: x["kind"] as! String)!
      XCTAssertEqual(Growth.series(start: dbl(x["start"])!, rate: dbl(x["rate"])!, years: x["years"] as! Int, kind: kind), x["out"] as! [Int], "\(x)")
    }
    let steps = v["growSteps"] as! [[String: Any]]
    XCTAssertGreaterThanOrEqual(steps.count, 5)
    for x in steps {
      let at = (x["at"] as! String).split(separator: "#"), rows = x["rows"] as! [String: Any]
      let l = try XCTUnwrap(c.lessons.first { $0.id == at[0] })
      guard case let .grow(g) = l.steps[Int(at[1])!] else { return XCTFail("\(at) is not a grow step") }
      let got = Growth.rows(g)
      XCTAssertEqual(got.main, rows["main"] as! [Int], "\(at)")
      XCTAssertEqual(got.vs, rows["vs"] as? [Int], "\(at)")
    }
    // The money snowball in numbers: growth on growth beats the same extra each year, and both start equal.
    XCTAssertEqual(Growth.series(start: 100, rate: 10, years: 2), [100, 110, 121])
    XCTAssertEqual(Growth.series(start: 100, rate: 10, years: 2, kind: .simple), [100, 110, 120])
  }
  func testEveryLessonHasRetrievalAndNewStepsAreRevealedOneTapAtATime() {
    for l in c.lessons { XCTAssertTrue(l.steps.contains(where: \.isQuiz), "\(l.id) needs a check or a sort") }
    let examples = c.lessons.flatMap(\.steps).filter { if case .example = $0 { return true }; return false }
    XCTAssertGreaterThanOrEqual(examples.count, 10)
    for s in examples { XCTAssertTrue((2...4).contains(s.reveals)) }
    for u in c.units { XCTAssertFalse(u.talk?.isEmpty ?? true, "\(u.id) has dinner-table talk for grown-ups") }
  }
  func testAMissAtAReviewStopBringsTheLessonBackUntilItIsReplayed() {
    var s = KidsState()
    s.finishLesson("share", today: "2026-11-01"); s.play("lesson", "share", today: "2026-11-01")
    XCTAssertTrue(Review.refresh(s, c).isEmpty)
    s.answer(Review.itemId("share", 3), right: false, today: "2026-11-03", review: true)   // forgot it later
    XCTAssertEqual(Review.refresh(s, c).map(\.id), ["share"])
    s.play("lesson", "share", today: "2026-11-04")                                           // replayed: refreshed
    XCTAssertTrue(Review.refresh(s, c).isEmpty)
    // Missing most of a lesson the day it was played also asks for a refresh.
    var t = KidsState()
    t.finishLesson("share", today: "2026-11-01"); t.play("lesson", "share", today: "2026-11-01")
    for i in [3, 4] { t.answer(Review.itemId("share", i), right: false, today: "2026-11-01", review: false) }
    XCTAssertEqual(Review.refresh(t, c).map(\.id), ["share"])
  }
  func testChallengeLessonsNeverGateStarsMasteryOrBossQuizzes() throws {
    let growing = try XCTUnwrap(World.regions(c).flatMap(\.nodes).first { $0.kind == .unit("growing") })
    var s = KidsState()
    let challenge = c.lessons.filter { $0.unit == "growing" && c.isOptional($0) }
    XCTAssertFalse(challenge.isEmpty, "growing has a Full Moons lesson")
    for l in c.requiredLessons("growing") { s.finishLesson(l.id, today: "2026-11-01") }
    XCTAssertEqual(World.stars(growing, s, c), 3)
    XCTAssertEqual(Review.mastery("growing", s, c), .mastered)
  }
  func testAUnitThatGrowsKeepsTheStarsAChildAlreadyHad() throws {
    let report = try XCTUnwrap(World.regions(c).flatMap(\.nodes).first { $0.kind == .unit("report") })
    XCTAssertTrue(c.lessons.contains { $0.unit == "report" && $0.since != nil }, "report gained lessons in 0.15")
    var s = KidsState()
    for l in c.lessons where l.unit == "report" && l.since == nil { s.finishLesson(l.id, today: "2026-10-01") }
    XCTAssertEqual(World.stars(report, s, c), 3, "new lessons are a bonus, never a lost star")
  }
  func testStarredStopsNeverLockAndTheRocketStaysInTheFirstUnconqueredLand() throws {
    let rs = World.regions(c)
    var s = KidsState()
    s.finishLemonade()
    // An older save: the whole old Lemonade Coast and Saver's Isle done, the new stops not yet.
    for l in c.lessons where ["money", "companies", "shares", "piggy", "growing", "dividends", "smart"].contains(l.unit) && l.since == nil { s.finishLesson(l.id, today: "2026-10-01") }
    s.earn("coast-boss", stars: 3); s.earn("isle-boss", stars: 3)
    let coast = rs[0]
    let companies = try XCTUnwrap(coast.nodes.first { $0.id == "coast-companies" })
    let earning = try XCTUnwrap(coast.nodes.firstIndex { $0.id == "coast-earning" })
    XCTAssertLessThan(earning, coast.nodes.firstIndex(of: companies)!, "the new stops come before Companies")
    XCTAssertTrue(World.nodeOpen(companies, in: coast, regionOpen: true, s, c), "a stop with stars never locks again")
    XCTAssertEqual(World.current(rs, s, c).region, 2, "the rocket waits in Candle Canyon, not back on the coast")
  }

  // MARK: The map
  func testEveryRegionHasAnOptionalReviewStop() {
    let rs = World.regions(c)
    XCTAssertEqual(rs.count, 7)
    var s = KidsState()
    for r in rs {
      let stop = r.nodes.first { if case .practice = $0.kind { return true }; return false }
      XCTAssertNotNil(stop, r.id)
      XCTAssertTrue(stop!.isOptional)
    }
    // The boss opens without a Review stop star; the Review stop is open as soon as its land is.
    let coast = rs[0]
    for n in coast.nodes where !n.isOptional && !n.isBoss { s.earn(n.id, stars: 1) }
    for l in c.lessons { s.finishLesson(l.id, today: "2026-11-01") }
    s.finishLemonade()
    XCTAssertTrue(World.nodeOpen(coast.boss, in: coast, regionOpen: true, s, c))
    XCTAssertTrue(World.nodeOpen(coast.nodes.first { $0.isOptional }!, in: coast, regionOpen: true, KidsState(), c))
    XCTAssertFalse(World.reviewScope(rs[1], rs, c).isDisjoint(with: World.reviewScope(rs[0], rs, c)), "later Review stops include earlier lands")
  }
}
