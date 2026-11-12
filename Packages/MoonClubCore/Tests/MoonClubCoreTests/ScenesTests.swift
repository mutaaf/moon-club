// Lesson scenes (Moon School cards): every lesson resolves to a scene, the table never goes stale, and Luna's
// hook lines stay short and kid-safe.
import XCTest
@testable import MoonClubCore

final class ScenesTests: XCTestCase {
  var c: KidsContent { VectorTests.content }

  func testEveryLessonResolvesToAScene() {
    XCTAssertFalse(c.lessons.isEmpty)
    for l in c.lessons {
      let s = Scenes.scene(for: l)
      XCTAssertFalse(s.hook.isEmpty, l.id)
      XCTAssertLessThanOrEqual(s.hook.count, Scenes.hookLimit, "\(l.id): \(s.hook)")
      XCTAssertTrue((0..<1).contains(s.seed), l.id)
    }
    // Bundled packs too (a guest coach's island gets scenes without anyone touching the table).
    let all = c.with(packs: c.bundledPacks)
    XCTAssertGreaterThan(all.lessons.count, c.lessons.count)
    for l in all.lessons { XCTAssertLessThanOrEqual(Scenes.scene(for: l).hook.count, Scenes.hookLimit, l.id) }
  }

  func testEveryCoreUnitHasItsOwnPaletteAndAct() {
    for u in c.units { XCTAssertNotNil(Scenes.units[u.id], "add unit \(u.id) to Scenes.units") }
  }

  func testTableHasNoStaleIds() {
    let lessons = Set(c.lessons.map(\.id)), units = Set(c.units.map(\.id))
    for id in Scenes.lessons.keys { XCTAssertTrue(lessons.contains(id), "Scenes.lessons names a lesson that doesn't exist: \(id)") }
    for id in Scenes.units.keys { XCTAssertTrue(units.contains(id), "Scenes.units names a unit that doesn't exist: \(id)") }
  }

  func testUnknownLessonGetsASensibleDefault() {
    let l = Lesson(id: "brand-new", unit: "some-new-unit", title: "Something new", emoji: "✨",
                   steps: [.say(emoji: "✨", text: "This first sentence is much too long to fit inside the bubble. Then more.")])
    let s = Scenes.scene(for: l)
    XCTAssertEqual(s.act, .pop)
    XCTAssertEqual(s.palette, Scenes.fallbackPalette("some-new-unit"))
    XCTAssertEqual(s.hook, Scenes.hooks[.pop])
    XCTAssertNil(s.prop)
    // A known unit's default act applies to a new lesson in it.
    let m = Lesson(id: "new-in-candles", unit: "candles", title: "x", emoji: "🕯️", steps: [.say(emoji: "🕯️", text: "Candles are fun.")])
    XCTAssertEqual(Scenes.scene(for: m).act, .candles)
    XCTAssertEqual(Scenes.scene(for: m).hook, "Candles are fun.")
  }

  func testEveryActHasAHookAndHooksAreKidSafe() {
    for a in SceneAct.allCases { XCTAssertNotNil(Scenes.hooks[a], "\(a)") }
    let banned = ["buy", "hurry", "lose", "bet", "gamble", "cash", "rich"]
    for h in Scenes.hooks.values {
      XCTAssertLessThanOrEqual(h.count, Scenes.hookLimit, h)
      let words = h.lowercased().split(whereSeparator: { !$0.isLetter && $0 != "'" })
      for w in words { XCTAssertFalse(banned.contains(String(w)), "\(h) uses \(w)") }
      // Grade ≤ 5: short sentences of short words.
      XCTAssertLessThanOrEqual(words.count, 8, h)
      XCTAssertLessThanOrEqual(words.map(\.count).max() ?? 0, 9, h)
    }
  }

  func testSeedsAreStableAcrossLaunches() {
    XCTAssertEqual(Scenes.stableHash("money"), Scenes.stableHash("money"))
    XCTAssertNotEqual(Scenes.seed("money"), Scenes.seed("earn"))
  }

  /// Every picture after a lesson's first step (later say steps, worked examples, quiz stages) gets a living scene
  /// whose act draws that picture as its prop, in the lesson's unit palette.
  func testEveryStepPictureGetsAPropAct() {
    let all = c.with(packs: c.bundledPacks)
    var count = 0
    for l in all.lessons {
      for (i, pic, quiz) in Scenes.pictures(l) {
        let s = Scenes.step(l, at: i, picture: pic, quiz: quiz)
        XCTAssertTrue(Scenes.propActs.contains(s.act), "\(l.id)#\(i) \(pic): \(s.act) doesn't draw the picture")
        if quiz { XCTAssertEqual(s.act, .think, "\(l.id)#\(i)") }
        if let u = Scenes.units[l.unit] { XCTAssertEqual(s.palette, u.0, "\(l.id)#\(i)") }
        XCTAssertTrue((0..<1).contains(s.seed))
        // Stable: the same step always gets the same scene.
        XCTAssertEqual(Scenes.step(l, at: i, picture: pic, quiz: quiz).act, s.act)
        count += 1
      }
    }
    XCTAssertGreaterThan(count, 200)
    for a in Scenes.pictureActs.values { XCTAssertTrue(Scenes.propActs.contains(a), "\(a)") }
    for a in Scenes.gentleActs { XCTAssertTrue(Scenes.propActs.contains(a), "\(a)") }
  }

  func testStepScenesWithoutALessonStillResolve() {
    let s = Scenes.step(nil, at: 3, picture: "🦄")
    XCTAssertTrue(Scenes.gentleActs.contains(s.act))
    XCTAssertEqual(s.palette, Scenes.fallbackPalette("🦄"))
    XCTAssertEqual(Scenes.step(nil, at: 0, picture: "🏦").act, .drop)
    XCTAssertEqual(Scenes.step(nil, at: 0, picture: "🏦", quiz: true).act, .think)
  }
}
