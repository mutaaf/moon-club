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
}
