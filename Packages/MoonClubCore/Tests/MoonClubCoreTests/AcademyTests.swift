import XCTest
import CoreGraphics
@testable import MoonClubCore

final class AcademyTests: XCTestCase {
  // MARK: Line Lab ground truth + graders

  func testTrendChartsHaveACleanLineAndTheIdealLinePasses() {
    for up in [true, false] {
      for seed in 0..<80 {
        let days = [18, 26, 36, 42][seed % 4]
        let (cs, t) = LineLab.trendChart(up: up, seed: seed, days: days)
        XCTAssertEqual(cs.count, days)
        XCTAssertGreaterThanOrEqual(t.touches.count, 2, "seed \(seed)")
        XCTAssertEqual(t.up, up)
        XCTAssertEqual(t.line.slope > 0, up, "seed \(seed) slope")
        let g = LineLab.grade(trend: t.line, ideal: t, candles: cs, tol: LineLab.tolerance(5))
        XCTAssertEqual(g.stars, 3, "the ideal line is spot on (seed \(seed))")
        // The same line the wrong way fails.
        let flipped = ChartLine(x1: t.line.x1, y1: t.line.y2, x2: t.line.x2, y2: t.line.y1)
        XCTAssertFalse(LineLab.grade(trend: flipped, ideal: t, candles: cs, tol: LineLab.tolerance(0)).right, "seed \(seed) flipped")
        // Shifted by a quarter of the span: far.
        XCTAssertFalse(LineLab.grade(trend: t.line.shifted(LineLab.span(cs) * 0.25), ideal: t, candles: cs, tol: LineLab.tolerance(0)).right)
      }
    }
  }

  func testTolerancesTightenWithTheTier() {
    for k in 1...5 { XCTAssertLessThan(LineLab.tolerance(k), LineLab.tolerance(k - 1)) }
    let (cs, t) = LineLab.trendChart(up: true, seed: 9, days: 30)
    let P = LineLab.span(cs)
    let nudged = t.line.shifted(P * 0.045)
    XCTAssertTrue(LineLab.grade(trend: nudged, ideal: t, candles: cs, tol: LineLab.tolerance(0)).right)
    XCTAssertFalse(LineLab.grade(trend: nudged, ideal: t, candles: cs, tol: LineLab.tolerance(5)).stars == 3)
  }

  func testLevelChartsHaveAFloorOrCeiling() {
    for floor in [true, false] {
      for seed in 0..<60 {
        let (cs, lv) = LineLab.levelChart(floor: floor, seed: seed, days: 30)
        XCTAssertEqual(LineLab.grade(level: lv, target: lv, candles: cs, tier: 5).stars, 3)
        XCTAssertFalse(LineLab.grade(level: lv + LineLab.span(cs) * 0.2, target: lv, candles: cs, tier: 0).right)
        if floor { XCTAssertLessThanOrEqual(lv, cs.map(\.l).min()! + LineLab.span(cs) * 0.03, "seed \(seed)") }
        else { XCTAssertGreaterThanOrEqual(lv, cs.map(\.h).max()! - LineLab.span(cs) * 0.03, "seed \(seed)") }
      }
    }
  }

  func testBreakoutsHoldOrSlipAndTheDayIsFound() {
    var bigWhenHeld = 0, held = 0
    for seed in 0..<80 {
      for ceiling in [true, false] {
        let h = seed % 2 == 0
        let b = LineLab.breakout(ceiling: ceiling, held: h, seed: seed, days: 30)
        let found = LineLab.breakoutDay(b.candles, level: b.level, ceiling: ceiling)
        XCTAssertNotNil(found, "seed \(seed)")
        if let f = found { XCTAssertLessThanOrEqual(abs(f - b.day), 1, "seed \(seed) ceiling \(ceiling)") }
        let after = b.candles[(b.day + 1)...].map(\.c)
        let stayed = after.allSatisfy { ceiling ? $0 > b.level : $0 < b.level }
        XCTAssertEqual(stayed, h, "seed \(seed) ceiling \(ceiling)")
        if h { held += 1; if b.bigCrowd { bigWhenHeld += 1 } } else { XCTAssertFalse(b.bigCrowd) }
      }
    }
    XCTAssertGreaterThan(Double(bigWhenHeld) / Double(held), 0.65)
    XCTAssertLessThan(Double(bigWhenHeld) / Double(held), 0.97)
  }

  func testAveragesAndCrosses() {
    let cs = LineLab.waveChart(seed: 4, days: 40, turns: 2)
    let f = LineLab.sma(cs, 5), s = LineLab.sma(cs, 20)
    XCTAssertNil(f[3]); XCTAssertNotNil(f[4]); XCTAssertNil(s[18])
    XCTAssertEqual(f[4]!, cs.prefix(5).map(\.c).reduce(0, +) / 5, accuracy: 1e-9)
    var found = 0
    for seed in 0..<50 {
      let w = LineLab.waveChart(seed: seed, days: 40, turns: 2)
      found += LineLab.crosses(fast: LineLab.sma(w, 5), slow: LineLab.sma(w, 20), closes: w.map(\.c)).isEmpty ? 0 : 1
    }
    XCTAssertGreaterThan(found, 45, "wave charts nearly always cross")
    XCTAssertEqual(LineLab.side(101, 100), .above)
    XCTAssertEqual(LineLab.side(100.1, 100), .touching)
  }

  func testBooksAndFills() {
    for seed in 0..<50 {
      let deep = LineLab.book(deep: true, seed: seed), thin = LineLab.book(deep: false, seed: seed)
      XCTAssertGreaterThan(thin.spreadShare, 5 * deep.spreadShare)
      XCTAssertGreaterThan(deep.topShares, 4 * thin.topShares)
      XCTAssertGreaterThan(deep.bestAsk, deep.bestBid)
      let q = 50
      if let a = deep.fill(q), let b = thin.fill(min(q, thin.asks.reduce(0) { $0 + $1.shares })) {
        XCTAssertGreaterThanOrEqual(a, deep.bestAsk); XCTAssertGreaterThanOrEqual(b, thin.bestAsk)
        XCTAssertLessThan(deep.slip(q)!, 0.0001 + deep.spread)
      }
    }
    let book = LineLab.Book(bids: [.init(price: 9, shares: 10)], asks: [.init(price: 10, shares: 10), .init(price: 12, shares: 10)])
    XCTAssertEqual(book.fill(20)!, 11, accuracy: 1e-9)
    XCTAssertNil(book.fill(21))
  }

  // MARK: PlotMap: what's drawn is what's graded, on every screen

  func testPlotMapRoundTripsOnEveryScreen() {
    let cs = LineLab.waveChart(seed: 2, days: 36)
    let range = PlotMap.range(cs)
    // SE, 17, 17 Pro Max, Duo outer, Duo inner, iPad portrait/landscape, the Duo atlas half page
    let sizes: [CGSize] = [CGSize(width: 288, height: 220), CGSize(width: 361, height: 300), CGSize(width: 398, height: 340), CGSize(width: 350, height: 260),
                           CGSize(width: 629, height: 480), CGSize(width: 780, height: 520), CGSize(width: 1100, height: 600), CGSize(width: 300, height: 600)]
    for size in sizes {
      for vol in [false, true] {
        let m = PlotMap(size: size, count: cs.count, range: range, volume: vol)
        for i in cs.indices {
          XCTAssertEqual(m.index(atX: m.x(i)), i)
          // A finger anywhere inside the column picks that day.
          XCTAssertEqual(m.index(atX: m.x(i) + m.step * 0.45), i)
          XCTAssertEqual(m.price(atY: m.y(cs[i].c)), cs[i].c, accuracy: 1e-9)
        }
        // One pixel of finger movement is less than a tenth of the strictest tolerance.
        let onePixel = 1 / 3 / Double(m.pointsPerPrice)
        XCTAssertLessThan(onePixel / m.span, LineLab.tolerance(5) / 10, "\(size)")
        XCTAssertLessThanOrEqual(m.plot.maxY, size.height - m.volumeHeight)
      }
    }
  }

  // MARK: levels

  func testHundredsOfLevels() {
    XCTAssertEqual(AcademyTrack.candles.mainLevels, 300)
    XCTAssertEqual(AcademyTrack.lines.mainLevels, 220)
    for t in AcademyTrack.allCases {
      var seen = Set<String>()
      for n in 1...(t.mainLevels + 60) {
        let l = Academy.level(t, n)
        XCTAssertEqual(l, Academy.level(t, n), "deterministic")
        XCTAssertFalse(l.rounds.isEmpty)
        XCTAssertLessThanOrEqual(l.rounds.count, 12)
        XCTAssert(l.rounds.allSatisfy { $0.drill.track == t }, "\(t) \(n)")
        XCTAssert((0...5).contains(l.tier))
        seen.insert(l.rounds.map { "\($0.drill)\($0.pattern)" }.joined())
        if n % 20 == 0 { XCTAssertTrue(l.isBoss) }
      }
      XCTAssertGreaterThan(seen.count, t.mainLevels / 2, "levels aren't copies")
    }
    // Every pattern gets taught, and the first levels of a chapter teach (worked example → alone).
    let taught = Set((1...300).flatMap { Academy.level(.candles, $0).rounds.map(\.pattern) })
    XCTAssertEqual(taught, Set(CandlePattern.allCases))
    XCTAssertEqual([1, 2, 3, 4].map { Academy.level(.candles, $0).scaffold }, [2, 1, 0, 0])
    // Tiers climb.
    XCTAssertLessThan(Academy.level(.candles, 5).tier, Academy.level(.candles, 290).tier)
    XCTAssertLessThan(Academy.level(.lines, 5).tier, Academy.level(.lines, 215).tier)
    // A round's pattern is one the kid has met.
    for n in 1...300 {
      let l = Academy.level(.candles, n)
      let met = Set(Academy.met(min(l.chapter, Academy.candleChapters.count - 1)))
      if !met.isEmpty { XCTAssert(l.rounds.allSatisfy { met.contains($0.pattern) }, "level \(n)") }
    }
  }

  func testProgressAndStars() {
    var s = KidsState()
    XCTAssertEqual(Academy.current(.candles, s), 1)
    XCTAssertTrue(Academy.open(.candles, 1, s)); XCTAssertFalse(Academy.open(.candles, 2, s))
    s.stars = ["candle-1": 2, "candle-2": 1, "lines-1": 3, "tower-1": 3]
    XCTAssertEqual(Academy.current(.candles, s), 3)
    XCTAssertEqual(Academy.current(.lines, s), 2)
    XCTAssertEqual(Academy.totalStars(.candles, s), 3)
    XCTAssertEqual(Academy.totalStars(.lines, s), 3)
    XCTAssertEqual(Tower.totalStars(s), 3, "tower stars stay their own")
    XCTAssertEqual(Academy.starsFor(right: 5, of: 5), 3)
    XCTAssertEqual(Academy.starsFor(right: 3, of: 5), 2)
    XCTAssertEqual(Academy.starsFor(right: 0, of: 5), 1, "finishing always earns a star")
  }

  func testDrillCopyIsKidSafe() {
    for d in Drill.allCases {
      for s in [d.title, d.how] {
        let l = " \(s.lowercased()) "
        for bad in [" buy ", " sell ", "should", "bet ", "hurry"] { XCTAssertFalse(l.contains(bad), s) }
        XCTAssertLessThanOrEqual(s.count, 60, s)
      }
    }
    for c in Academy.candleChapters + Academy.lineChapters { XCTAssertLessThanOrEqual(c.line.count, 44, c.line) }
  }
}
