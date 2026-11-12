import XCTest
@testable import MoonClubCore

final class CandlePatternTests: XCTestCase {
  func testThirtyNinePatternsInTheBook() {
    XCTAssertEqual(CandlePattern.allCases.count, 39)
    for p in CandlePattern.allCases {
      XCTAssertEqual(p.twin.twin, p, "\(p) twin")
      XCTAssertNotEqual(p.lookalike, p)
      XCTAssert((1...5).contains(p.difficulty))
    }
  }

  /// The generator and the checker test each other: every generated pattern passes its own rule, shows up
  /// only once, and its look-alike's rule fails on it.
  func testEveryGeneratedPatternPassesItsOwnRuleAndOnlyItsOwn() {
    for p in CandlePattern.allCases {
      var misses = 0
      for seed in 0..<120 {
        let ch = CandleLab.make(p, seed: seed * 977 + 13, lead: 8, after: seed % 3)
        if !CandleLab.matches(p, in: ch.candles, at: ch.start) { misses += 1; continue }
        XCTAssertEqual(CandleLab.find(p, in: ch.candles), [ch.start], "\(p) seed \(seed) shows up elsewhere")
        XCTAssertFalse(CandleLab.matches(p.lookalike, in: ch.candles, at: ch.start), "\(p) seed \(seed) also reads as \(p.lookalike)")
        for k in ch.candles { XCTAssert(k.l <= min(k.o, k.c) && k.h >= max(k.o, k.c) && k.l > 0, "\(p) bad candle") }
      }
      XCTAssertEqual(misses, 0, "\(p) failed its own rule \(misses) times")
    }
  }

  func testHiddenPatternsHaveOneAnswer() {
    for (i, p) in CandlePattern.allCases.enumerated() {
      for seed in 0..<15 {
        let ch = CandleLab.hide(p, seed: seed * 31 + i, days: 22)
        XCTAssertEqual(CandleLab.find(p, in: ch.candles), [ch.start], "\(p) seed \(seed)")
      }
    }
  }

  func testTheDaysAfterAreAClueNotAPromise() {
    var went = 0, total = 0
    for seed in 0..<400 {
      let ch = CandleLab.make(.hammer, seed: seed, after: 4)
      guard let f = ch.followed else { continue }
      total += 1; if f { went += 1 }
      let after = ch.candles[(ch.end + 1)...].map(\.c)
      let up = (after.last ?? 0) > ch.candles[ch.end].c
      XCTAssertEqual(up, f, "seed \(seed): followed flag matches the drawing")
    }
    XCTAssertGreaterThan(total, 300)
    let share = Double(went) / Double(total)
    XCTAssert(share > 0.5 && share < 0.72, "share \(share)")
  }

  func testTwinsMirror() {
    XCTAssertEqual(CandlePattern.hammer.twin, .shootingStar)
    XCTAssertEqual(CandlePattern.hangingMan.twin, .invertedHammer)
    XCTAssertEqual(CandlePattern.morningStar.twin, .eveningStar)
    XCTAssertEqual(CandlePattern.hammer.lead, .down)
    XCTAssertEqual(CandlePattern.shootingStar.lead, .up)
    XCTAssertEqual(CandlePattern.invertedHammer.lead, .down)
    XCTAssertEqual(CandlePattern.hangingMan.lead, .up)
  }

  func testWordsAreKidSafe() {
    for p in CandlePattern.allCases {
      for s in [p.name, p.says, p.lookFor] {
        let l = s.lowercased()
        for bad in [" buy ", "sell ", "will ", "guarantee", "should", "bet ", "rich"] { XCTAssertFalse(" \(l) ".contains(bad), "\(p): \(s)") }
        XCTAssertLessThanOrEqual(s.count, 64, s)
      }
    }
  }
}

final class CandleBuildTests: XCTestCase {
  func testTemplatesBuildAndNearMissesAreOneHandleOff() {
    for p in CandleLab.buildable {
      guard let t = CandleLab.template(p) else { return XCTFail("\(p) has no template") }
      XCTAssertTrue(CandleLab.shapeOK(p, t), "\(p) template")
      if p == .marubozuUp || p == .bigUpCandle { XCTAssertFalse(CandleLab.shapeOK(p.lookalike, t), "\(p) also builds \(p.lookalike)") }
      for seed in 0..<20 {
        guard let (miss, k) = CandleLab.nearMiss(p, seed: seed) else { return XCTFail("\(p) no near miss") }
        XCTAssertFalse(CandleLab.shapeOK(p, miss))
        var fixed = miss
        switch k { case 0: fixed.o = t.o; case 1: fixed.c = t.c; case 2: fixed.h = t.h; default: fixed.l = t.l }
        XCTAssertTrue(CandleLab.shapeOK(p, fixed), "\(p) seed \(seed): putting handle \(k) back fixes it")
      }
    }
  }

  func testStoriesHaveOneRightCandle() {
    for seed in 0..<200 {
      let s = CandleLab.story(seed: seed, choices: 4)
      XCTAssertTrue(s.target.valid)
      XCTAssertEqual(s.options.filter { $0 == s.target }.count, 1, "seed \(seed)")
      XCTAssertGreaterThanOrEqual(s.options.count, 2)
      XCTAssert(s.options.allSatisfy(\.valid))
    }
  }
}
