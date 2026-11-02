import XCTest
@testable import MoonClubCore

/// Caching, request rules, state reducers and content quality.
final class CoreTests: XCTestCase {
  var content: KidsContent { VectorTests.content }
  func tmp() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString) }

  // MARK: Kids-safety rules, enforced in the request builders
  func testLunaNeverCarriesAKeyAndAlwaysUsesTheFreeKidBrain() throws {
    let r = Requests.luna(question: "What is a share?", context: LunaContext(weather: nil, companies: []))
    XCTAssertNil(r.value(forHTTPHeaderField: "x-mp-key"))
    let body = try JSONSerialization.jsonObject(with: r.httpBody!) as! [String: Any]
    XCTAssertEqual(body["task"] as? String, "kids"); XCTAssertEqual(body["provider"] as? String, "edge")
    XCTAssertNil(body["model"])
    XCTAssertEqual(r.url?.absoluteString, "https://mutaafaziz.com/metaphases/api/ai/stream")
  }
  func testLunaQuestionIsCappedAt200Chars() throws {
    let r = Requests.luna(question: String(repeating: "a", count: 500), context: LunaContext(weather: nil, companies: []))
    let body = try JSONSerialization.jsonObject(with: r.httpBody!) as! [String: Any]
    XCTAssertEqual((body["question"] as! String).count, 200)
  }
  func testVoiceKeyOnlyForAppCopyOrLunaNeverKidTypedText() {
    XCTAssertNotNil(Requests.speak(.appCopy("A share is a tiny slice."), provider: .openai, voice: "coral", key: "sk-test"))
    XCTAssertNotNil(Requests.speak(.luna(answer: "A share is a tiny slice!", kidTyped: "why do prices move"), provider: .gemini, voice: "Leda", key: "k"))
    XCTAssertNil(Requests.speak(.luna(answer: "You asked: my name is Sam. A share is…", kidTyped: "my name is Sam"), provider: .openai, voice: "coral", key: "sk"))
    XCTAssertNil(Requests.speak(.appCopy("hi there"), provider: .openai, voice: "not-a-voice", key: "sk"))
    XCTAssertNil(Requests.speak(.appCopy("hi"), provider: .openai, voice: "coral", key: ""))
    XCTAssertNil(Requests.speak(.appCopy(String(repeating: "a", count: 601)), provider: .openai, voice: "coral", key: "sk"))
    let r = Requests.speak(.appCopy("Hello"), provider: .openai, voice: "nova", key: "sk-x")!
    XCTAssertEqual(r.value(forHTTPHeaderField: "x-mp-key"), "sk-x")
    XCTAssertFalse(String(data: r.httpBody!, encoding: .utf8)!.contains("sk-x"), "the key travels only as the header")
  }
  func testCalendarFetchedInWeekChunks() {
    let ch = Requests.calendarChunks(from: "2026-10-01", to: "2026-10-22")
    XCTAssertEqual(ch.map(\.0), ["2026-10-01", "2026-10-08", "2026-10-15", "2026-10-22"])
    XCTAssertEqual(ch.last?.1, "2026-10-22")
    XCTAssertTrue(ch.allSatisfy { Day.between($0.0, $0.1) <= 6 })
  }
  func testSSEParsing() {
    let (ev, rest) = SSE.parse("data: {\"t\":\"Hi\"}\n\ndata: {\"t\":\" there\"}\n\ndata: {\"done\":true}\n\ndata: {\"t\":\"par")
    XCTAssertEqual(ev, [.text("Hi"), .text(" there"), .done]); XCTAssertEqual(rest, "data: {\"t\":\"par")
    XCTAssertEqual(SSE.parse("data: {\"error\":\"busy\"}\n\n").0, [.error("busy")])
  }

  // MARK: Caching
  func testDiskLRUEvictsLeastRecentlyUsed() {
    let lru = DiskLRU(dir: tmp(), capacity: 300)
    let t0 = Date(timeIntervalSince1970: 1_000_000)
    lru.set("a", Data(count: 100), now: t0); lru.set("b", Data(count: 100), now: t0.addingTimeInterval(1))
    _ = lru.get("a", now: t0.addingTimeInterval(2)) // a is now more recent than b
    lru.set("c", Data(count: 100), now: t0.addingTimeInterval(3)) // 3 × 108 bytes > 300 → evict b
    XCTAssertNotNil(lru.get("a")); XCTAssertNil(lru.get("b")); XCTAssertNotNil(lru.get("c"))
    XCTAssertLessThanOrEqual(lru.totalBytes, 300)
  }
  func testLayeredCacheFreshStaleAndOffline() async throws {
    final class Box: @unchecked Sendable { var now = Date(timeIntervalSince1970: 2_000_000); var calls = 0; var fail = false }
    let box = Box()
    let cache = LayeredCache(disk: DiskLRU(dir: tmp(), capacity: 1 << 20), now: { box.now })
    let policy = CachePolicy(ttl: 60, maxStale: 3600)
    let load: @Sendable () async throws -> Data = { box.calls += 1; if box.fail { throw KidError.offline }; return Data("v\(box.calls)".utf8) }
    var d = try await cache.data("k", policy: policy, load: load); XCTAssertEqual(String(data: d, encoding: .utf8), "v1")
    d = try await cache.data("k", policy: policy, load: load); XCTAssertEqual(box.calls, 1, "fresh hit from memory")
    box.now = box.now.addingTimeInterval(120); box.fail = true
    d = try await cache.data("k", policy: policy, load: load)
    XCTAssertEqual(String(data: d, encoding: .utf8), "v1", "stale served while revalidating; offline keeps last good copy")
    box.now = box.now.addingTimeInterval(7200)
    do { _ = try await cache.data("k", policy: policy, load: load); XCTFail("too stale and offline should throw") } catch {}
  }
  func testCoalescerSharesOneInFlightLoad() async throws {
    final class Count: @unchecked Sendable { var n = 0; let lock = NSLock() }
    let c = Coalescer(), count = Count()
    let work: @Sendable () async throws -> Data = { count.lock.withLock { count.n += 1 }; try await Task.sleep(nanoseconds: 50_000_000); return Data([1]) }
    async let a = c.run("x", work); async let b = c.run("x", work); async let e = c.run("x", work)
    _ = try await (a, b, e)
    XCTAssertEqual(count.n, 1)
  }
  func testLunaCacheKeyNormalizes() {
    XCTAssertEqual(lunaCacheKey("What's a share?", contentVersion: "1"), lunaCacheKey("  what is   a SHARE ", contentVersion: "1"))
    XCTAssertNotEqual(lunaCacheKey("What is a share?", contentVersion: "1"), lunaCacheKey("What is a share?", contentVersion: "2"))
  }

  // MARK: State reducers
  func testReducers() {
    var s = KidsState()
    s.guess(Guess(s: "AAPL", d: "2026-11-02", pick: .beat, at: "2026-10-31"))
    s.guess(Guess(s: "AAPL", d: "2026-11-02", pick: .miss, at: "2026-10-31"))
    XCTAssertEqual(s.guesses.count, 1); XCTAssertEqual(s.guesses[0].pick, .miss)
    s.resolve(s: "AAPL", d: "2026-11-02", result: .right, priceResult: nil)
    XCTAssertEqual(s.guesses[0].result, .right)
    s.finishLesson("share", today: "2026-10-31"); s.finishLesson("share", today: "2026-11-01")
    XCTAssertEqual(s.lessons, ["share"]); XCTAssertEqual(s.lessonDates["share"], "2026-10-31")
    s.setMe(1); s.addPlayer(LeaguePlayer(emoji: 4, guesses: [])); s.addPlayer(LeaguePlayer(emoji: 4, guesses: [LeagueGuess(s: "DIS", d: "2026-11-12", pick: .beat)]))
    XCTAssertEqual(s.league.count, 1); XCTAssertEqual(s.league[0].guesses.count, 1)
    for st in ["company", "shares", "price", "report"] { s.questStage(st) }
    XCTAssertEqual(s.chapters(content), ["lemonade"])
    XCTAssertTrue(s.badges(content).contains("lemonade"))
    let data = try! JSONEncoder().encode(s); XCTAssertEqual(try! JSONDecoder().decode(KidsState.self, from: data), s)
  }
  func testPiggyHistoryCapped() {
    var s = KidsState(); s.startPiggy([], today: "2026-01-01", value: 1000)
    for i in 1...200 { s.recordValue(today: Day.add("2026-01-01", i), value: 1000 + Double(i)) }
    XCTAssertEqual(s.piggy?.history.count, 120)
  }

  // MARK: Content quality (the same rules the web enforces)
  func testEveryLessonReadsAtGrade5OrBelow() {
    for l in content.lessons {
      let says = l.steps.compactMap { if case let .say(_, t) = $0 { return t } else { return nil } }.joined(separator: " ")
      XCTAssertLessThanOrEqual(fkGrade(says), 5.0, l.id)
    }
  }
  func testNothingIsAdvice() {
    let all = (content.lessons.flatMap { $0.steps.map { "\($0)" } } + content.terms.values.map { $0.means + $0.example }).joined(separator: " ")
    XCTAssertNil(all.range(of: #"\byou should (buy|sell)\b|buy now|sign up|download"#, options: [.regularExpression, .caseInsensitive]))
  }
  func testChapterMathIsFixed() throws {
    let q = try XCTUnwrap(content.questChapters)
    let jar = Chapters.jarPath(10, start: q.START, rate: q.JAR_RATE), tree = Chapters.treePath(10, start: q.START, path: q.TREE_YEARS)
    XCTAssertTrue(zip(jar, jar.dropFirst()).allSatisfy { $0 < $1 }, "the jar never goes down")
    XCTAssertTrue(zip(tree, tree.dropFirst()).contains { $0 > $1 }, "the tree has down years")
    XCTAssertGreaterThan(tree.last!, jar.last!, "…but grows more over 10 years")
    let sb = Chapters.snowball(seasons: q.SEASONS, slices: q.SLICES, payPerSlice: q.PAY_PER_SLICE, slicePrice: q.SLICE_PRICE)
    XCTAssertGreaterThan(sb.replant.last!.slices, sb.spend.last!.slices)
  }
  func testContentRejectsBadInput() {
    XCTAssertThrowsError(try KidsContent.load(Data("{}".utf8)))
    var o = try! JSONSerialization.jsonObject(with: VectorTests.raw) as! [String: Any]; o["version"] = 99
    XCTAssertThrowsError(try KidsContent.load(try! JSONSerialization.data(withJSONObject: o))) { XCTAssertEqual($0 as? KidsContent.LoadError, .unsupportedVersion(99)) }
  }
}
