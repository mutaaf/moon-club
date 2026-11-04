// Market World rules, chart reading and the "no card needs scrolling" content lint.
import XCTest
@testable import MoonClubCore

final class WorldTests: XCTestCase {
  lazy var content: KidsContent = {
    let url = Bundle.module.url(forResource: "kids-content", withExtension: "json")!
    return try! KidsContent.load(Data(contentsOf: url))
  }()

  func testSevenRegionsEachWithABossAndNoBrokenNodes() {
    let rs = World.regions(content)
    XCTAssertEqual(rs.map(\.id), ["coast", "isle", "canyon", "trails", "peaks", "sea", "castle"])
    for r in rs {
      XCTAssertTrue(r.boss.isBoss, r.id)
      XCTAssertTrue((3...12).contains(r.nodes.count), "\(r.id) has \(r.nodes.count) nodes")
      XCTAssertEqual(r.nodes.filter(\.isBoss).count, 1, r.id)
    }
    let ids = rs.flatMap(\.nodes).map(\.id)
    XCTAssertEqual(Set(ids).count, ids.count, "node ids are unique (they key the synced stars)")
    // Every chart lesson the web exported lands on the map.
    for l in ["candle", "wicks", "tug-of-war", "trend", "sideways", "zoom-out", "floor-ceiling", "breakout", "clues", "volume", "moving-average", "report-jump"] {
      XCTAssertTrue(rs.flatMap(\.nodes).contains { $0.kind == .lesson(l) }, l)
    }
  }

  func testUnlockingWalksTheMapInOrder() {
    let rs = World.regions(content)
    var s = KidsState()
    XCTAssertTrue(World.regionOpen(0, rs, s, content))
    XCTAssertFalse(World.regionOpen(1, rs, s, content))
    XCTAssertEqual(World.current(rs, s, content).region, 0)
    XCTAssertTrue(World.nodeOpen(rs[0].nodes[0], in: rs[0], regionOpen: true, s, content))
    XCTAssertFalse(World.nodeOpen(rs[0].nodes[1], in: rs[0], regionOpen: true, s, content))
    s.finishLemonade()
    XCTAssertTrue(World.nodeOpen(rs[0].nodes[1], in: rs[0], regionOpen: true, s, content))
    XCTAssertFalse(World.nodeOpen(rs[0].boss, in: rs[0], regionOpen: true, s, content), "boss waits for every node")
    // One lesson in a unit earns a star; the whole unit earns three.
    s.finishLesson("money", today: "2026-11-02")
    XCTAssertEqual(World.stars(rs[0].nodes[1], s, content), 1)
    for l in content.lessons where l.unit == "money" { s.finishLesson(l.id, today: "2026-11-02") }
    XCTAssertEqual(World.stars(rs[0].nodes[1], s, content), 3)
    for l in content.lessons where ["earning", "goals", "spending", "safety", "companies", "shares", "piggy"].contains(l.unit) { s.finishLesson(l.id, today: "2026-11-02") }
    XCTAssertTrue(World.nodeOpen(rs[0].boss, in: rs[0], regionOpen: true, s, content))
    s.earn("coast-boss", stars: 2)
    XCTAssertTrue(World.conquered(rs[0], s, content))
    XCTAssertTrue(World.regionOpen(1, rs, s, content))
    XCTAssertEqual(World.current(rs, s, content).region, 1)
  }

  func testStarsNeverGoDownAndScorePoints() {
    var s = KidsState()
    let before = s.points(content)
    s.earn("canyon-build", stars: 3); s.earn("canyon-build", stars: 1); s.earn("canyon-read", stars: 9)
    XCTAssertEqual(s.stars?["canyon-build"], 3)
    XCTAssertEqual(s.stars?["canyon-read"], 3, "clamped to 3")
    XCTAssertEqual(s.points(content) - before, 30)
    XCTAssertEqual(World.starsFor(right: 3, of: 3), 3)
    XCTAssertEqual(World.starsFor(right: 2, of: 3), 2)
    XCTAssertEqual(World.starsFor(right: 0, of: 3), 1, "playing always earns one star")
  }

  func testStarsMergeAcrossDevicesAsTheBestOfEach() {
    var a = KidsState(), b = KidsState()
    a.earn("trails-spot", stars: 1); a.earn("canyon-build", stars: 3)
    b.earn("trails-spot", stars: 3)
    let m = a.merged(with: b)
    XCTAssertEqual(m.stars, ["trails-spot": 3, "canyon-build": 3])
    XCTAssertEqual(m, b.merged(with: a))
    // Older saves (no stars field) still decode.
    let old = try! JSONDecoder().decode(KidsState.self, from: Data(#"{"schema":1,"guesses":[],"lessons":["company"],"lessonDates":{},"seenBadges":[],"league":[],"quest":[],"questDone":false}"#.utf8))
    XCTAssertNil(old.stars)
  }

  // MARK: Charts

  func testTrendFloorCeilingAndSmoothLine() {
    XCTAssertEqual(ChartMath.trend((0..<20).map { 100 + Double($0) }), .up)
    XCTAssertEqual(ChartMath.trend((0..<20).map { 120 - Double($0) }), .down)
    XCTAssertEqual(ChartMath.trend((0..<20).map { 100 + ($0 % 2 == 0 ? 1.5 : -1.5) }), .sideways)
    let cs = (0..<30).map { i in Candle(d: "\(i)", o: 100, h: 105 + Double(i % 3), l: i % 6 == 0 ? 90 : 96, c: 101) }
    XCTAssertEqual(ChartMath.floor(cs), 90, accuracy: 3)
    XCTAssertGreaterThan(ChartMath.ceiling(cs), 106)
    let sma = ChartMath.sma([1, 2, 3, 4, 5], window: 3)
    XCTAssertNil(sma[1]); XCTAssertEqual(sma[2]!, 2, accuracy: 1e-9); XCTAssertEqual(sma[4]!, 4, accuracy: 1e-9)
  }

  func testDayStoriesAndScoring() {
    XCTAssertEqual(ChartMath.story(Candle(d: "", o: 100, h: 104, l: 99.5, c: 103.5)), .bigUp)
    XCTAssertEqual(ChartMath.story(Candle(d: "", o: 100, h: 100.6, l: 99.6, c: 100.5)), .smallUp)
    XCTAssertEqual(ChartMath.story(Candle(d: "", o: 100, h: 100.5, l: 96, c: 96.4)), .bigDown)
    XCTAssertEqual(ChartMath.story(Candle(d: "", o: 100, h: 108, l: 92, c: 100.4)), .tugOfWar)
    XCTAssertEqual(ChartMath.levelStars(guess: 101, target: 100, chartRange: 40), 3)
    XCTAssertEqual(ChartMath.levelStars(guess: 120, target: 100, chartRange: 40), 1)
    let closes = (0..<20).map { 100 + Double($0) }
    XCTAssertEqual(ChartMath.trendlineStars(start: 100, end: 119, closes: closes), 3)
    XCTAssertEqual(ChartMath.trendlineStars(start: 119, end: 100, closes: closes), 1, "the wrong way is one star")
  }

  func testPracticePatternsLookLikeTheirNames() {
    for seed in 0..<20 {
      let b = Practice.chart(.breakout, seed: seed)
      XCTAssertGreaterThan(b.last!.c, ChartMath.ceiling(Array(b.prefix(20))), "breakout ends above the old ceiling, seed \(seed)")
      let t = Practice.chart(.doubleTop, seed: seed)
      XCTAssertLessThan(t.last!.c, t.map(\.c).max()! - 4, "double top slides down, seed \(seed)")
      XCTAssertEqual(Practice.chart(.bounce, seed: seed), Practice.chart(.bounce, seed: seed), "deterministic")
    }
  }

  func testBundledRealCandlesHaveEveryTrendForSpotTheTrend() throws {
    let url = try XCTUnwrap(Bundle.module.url(forResource: "candles", withExtension: "json"))
    let bundle = try JSONDecoder().decode(CandleBundle.self, from: Data(contentsOf: url))
    let series = bundle.all
    XCTAssertGreaterThanOrEqual(series.count, 5)
    for s in series { XCTAssertGreaterThan(s.candles.count, 120, s.s); XCTAssertTrue(s.candles.allSatisfy { $0.h >= $0.bodyTop && $0.l <= $0.bodyBottom }) }
    for t in Trend.allCases { XCTAssertFalse(series.flatMap { ChartMath.windows($0, length: 30, trend: t) }.isEmpty, "\(t) windows exist") }
    for sym in ["AAPL", "DIS", "NKE", "KO", "MCD"] { XCTAssertTrue(series.contains { $0.s == sym }, "Time Machine boss \(sym) has a chart") }
  }

  // MARK: Content lint — short enough to fit one card without scrolling

  func testEveryCardStepFitsOneCard() {
    for l in content.lessons {
      XCTAssertLessThanOrEqual(l.title.count, 40, "title \(l.id)")
      for s in l.steps {
        switch s {
        case let .say(_, text): XCTAssertLessThanOrEqual(text.count, 110, "\(l.id): \(text)")
        case let .check(c):
          XCTAssertLessThanOrEqual(c.q.count, 90, "\(l.id): \(c.q)")
          XCTAssertLessThanOrEqual(c.options.count, 3, l.id)
          for o in c.options { XCTAssertLessThanOrEqual(o.count, 42, "\(l.id): \(o)") }
          XCTAssertLessThanOrEqual(c.why.count, 100, "\(l.id): \(c.why)")
        case let .sort(q, b, items, why):
          XCTAssertLessThanOrEqual(q.count, 60, l.id); XCTAssertLessThanOrEqual(items.count, 6, l.id)
          for i in items { XCTAssertLessThanOrEqual(i.text.count, 42, "\(l.id): \(i.text)") }
          for x in b { XCTAssertLessThanOrEqual(x.count, 14, l.id) }
          XCTAssertLessThanOrEqual(why.count, 100, l.id)
        case let .example(x):
          XCTAssertLessThanOrEqual(x.text.count, 110, "\(l.id): \(x.text)")
          XCTAssertTrue((2...4).contains(x.lines.count), l.id)
          for line in x.lines { XCTAssertLessThanOrEqual(line.count, 42, "\(l.id): \(line)") }
        case let .grow(g):
          XCTAssertLessThanOrEqual(g.text.count, 110, "\(l.id): \(g.text)")
          XCTAssertLessThanOrEqual(g.label.count, 20, l.id); XCTAssertLessThanOrEqual(g.vs?.label.count ?? 0, 20, l.id)
          XCTAssertTrue((2...10).contains(g.years), l.id)
        }
      }
    }
  }
}
