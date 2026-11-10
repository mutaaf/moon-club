import XCTest
import MoonClubCore
@testable import MoonClub

/// The update modal in the app: once per version through real UserDefaults, quiet under tests and screenshot
/// flags, and the bundled notes for the version this build ships carry a headline and 2–4 cards.
@MainActor
final class WhatsNewAppTests: XCTestCase {
  var defaults: UserDefaults!
  let suite = "whatsnew-tests"
  override func setUp() { UserDefaults().removePersistentDomain(forName: suite); defaults = UserDefaults(suiteName: suite) }
  override func tearDown() { UserDefaults().removePersistentDomain(forName: suite) }

  var bundled: [ReleaseNews] { WhatsNewStore.allNews(bundle: Bundle(for: AppModel.self)) }
  func pending(args: [String] = [], env: [String: String] = [:]) -> ReleaseNews? {
    WhatsNewStore.pending(defaults: defaults, args: args, env: env, version: WhatsNewStore.current, all: bundled)
  }

  func testBundledNotesForThisVersion() throws {
    let v = WhatsNewStore.current
    let n = try XCTUnwrap(bundled.first { $0.version == v }, "release-notes/\(v).md is bundled")
    XCTAssertNotNil(n.headline)
    XCTAssert((2...WhatsNew.maxCards).contains(n.items.count))
    XCTAssertEqual(WhatsNew.lint(n), [])
    XCTAssertGreaterThanOrEqual(WhatsNewModal.cards(n, hinge: false).count, 2, "devices without a hinge still get 2+ cards")
    for i in n.items { XCTAssert(UIImage(systemName: i.symbol) != nil || Art.spec(i.symbol) != Art.fallback || i.symbol.hasPrefix("custom."), "art \(i.symbol)") }
  }

  func model() throws -> AppModel {
    let url = try XCTUnwrap(Bundle(for: AppModel.self).url(forResource: "kids-content", withExtension: "json"))
    let c = try KidsContent.load(try Data(contentsOf: url))
    return AppModel(content: c, services: Services(market: FakeMarket(today: "2026-10-31"), luna: LunaRouter(brains: [FakeBrain(kind: .free)], resolve: { .free }), voice: FakeVoice(), store: MemoryStore(), clock: FixedClock("2026-10-31")))
  }

  /// Every callout in this version's notes lands on a real kid place in this build (a lesson it names exists).
  func testBundledCalloutsLandOnRealPlaces() throws {
    let n = try XCTUnwrap(bundled.first { $0.version == WhatsNewStore.current })
    XCTAssertEqual(n.badPlaces, [])
    let app = try model()
    for i in n.items { if let p = i.go {
      XCTAssertNotNil(app.open(p), "\(i.title ?? i.text) → \(p) has a tab")
      if case .link(.lesson(let id)) = p { XCTAssert(app.content.lessons.contains { $0.id == id }, "lesson \(id) is in this build") }
      app.pendingLesson = nil; app.pendingMoonSchool = false
    } }
  }

  /// A callout closes the modal and opens its place: the tab it lives on, plus what that place needs.
  func testCalloutRouting() throws {
    let app = try model()
    XCTAssertEqual(app.open(.link(.home)), .story)
    XCTAssertEqual(app.open(.link(.world)), .school)
    XCTAssertEqual(app.open(.link(.guess)), .guess)
    XCTAssertEqual(app.open(.link(.luna)), .luna)
    XCTAssertFalse(app.pendingMoonSchool)
    XCTAssertEqual(app.open(.moonSchool), .school)
    XCTAssertTrue(app.pendingMoonSchool, "the World map pushes Moon School")
    app.pendingMoonSchool = false
    XCTAssertEqual(app.open(.link(.gameNight)), .guess)
    XCTAssertTrue(app.pendingGameNight)
    app.pendingGameNight = false
    let lesson = try XCTUnwrap(app.content.lessons.first)
    XCTAssertEqual(app.open(.link(.lesson(lesson.id))), .school)
    XCTAssertEqual(app.pendingLesson, lesson.id)
    app.pendingLesson = nil
    XCTAssertEqual(app.open(.link(.lesson("not-a-lesson"))), .school, "a missing lesson still lands on the map")
    XCTAssertNil(app.pendingLesson)
    // Notes can't name a grown-up place, so a card never leads toward the gate.
    XCTAssertNil(NewsPlace("league/ABCDEFGH12"))
    XCTAssertNil(NewsPlace("pack/space"))
  }

  /// The callout cards are buttons; plain cards and the Duo card aren't.
  func testCardsWithAPlaceGetTheButton() {
    let v = WhatsNewStore.current
    guard let n = bundled.first(where: { $0.version == v }) else { return XCTFail("notes") }
    let callouts = WhatsNewModal.cards(n, hinge: false).filter { $0.go != nil }
    XCTAssertGreaterThanOrEqual(callouts.count, 1)
    XCTAssertEqual(WhatsNewCard.placeName(.moonSchool), "Moon School")
    XCTAssertEqual(WhatsNewCard.placeName(.link(.home)), "Story")
    XCTAssertEqual(WhatsNewCard.placeName(.link(.world)), "World")
  }

  func testFreshInstallShowsNothingAndRecords() {
    XCTAssertNil(pending())
    XCTAssertEqual(defaults.string(forKey: WhatsNewStore.key), WhatsNewStore.current)
    XCTAssertNil(pending(), "and stays quiet")
  }

  func testUpgradeShowsOnce() {
    defaults.set("0.15.0", forKey: WhatsNewStore.key)
    XCTAssertEqual(pending()?.version, WhatsNewStore.current)
    XCTAssertEqual(defaults.string(forKey: WhatsNewStore.key), WhatsNewStore.current)
    XCTAssertNil(pending(), "same version again: nothing")
  }

  func testQuietUnderFlags() {
    defaults.set("0.15.0", forKey: WhatsNewStore.key)
    XCTAssertNil(pending(args: ["-demo", "-tab", "school"]))
    XCTAssertNil(pending(args: ["-uitest"]))
    XCTAssertNil(pending(env: ProcessInfo.processInfo.environment), "hosting this test bundle counts as a test run")
    XCTAssertEqual(defaults.string(forKey: WhatsNewStore.key), "0.15.0", "quiet runs never touch the record")
    #if DEBUG
    XCTAssertEqual(pending(args: ["-demo", "-whatsNew"])?.version, WhatsNewStore.current, "DEBUG -whatsNew forces it")
    XCTAssertEqual(defaults.string(forKey: WhatsNewStore.key), "0.15.0", "forcing records nothing")
    #endif
  }

  /// The phone/simulator force flag: DEBUG `-whatsNew` / `-whatsnewFrom <v>` show the modal (even on a fresh
  /// install or under a test host) and never record the version. Release builds ignore both.
  func testForceFlag() {
    #if DEBUG
    XCTAssertEqual(WhatsNewStore.forceFrom(["-whatsNew"]), "0")
    XCTAssertEqual(WhatsNewStore.forceFrom(["-whatsnewFrom", "0.15.0"]), "0.15.0")
    XCTAssertNil(WhatsNewStore.forceFrom(["-whatsnewFrom"]), "a missing version is ignored")
    XCTAssertNil(WhatsNewStore.forceFrom(["-demo"]))
    XCTAssertEqual(pending(args: ["-whatsNew"], env: ProcessInfo.processInfo.environment)?.version, WhatsNewStore.current)
    XCTAssertNil(defaults.string(forKey: WhatsNewStore.key), "a forced fresh install records nothing")
    XCTAssertEqual(pending(args: ["-whatsnewFrom", "0.15.0"])?.version, WhatsNewStore.current)
    XCTAssertNil(defaults.string(forKey: WhatsNewStore.key))
    #else
    XCTAssertNil(WhatsNewStore.forceFrom(["-whatsNew"]), "Release ignores the force flag")
    #endif
  }
}
