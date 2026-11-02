import XCTest
import MoonClubCore
@testable import MoonClub

/// App-level checks: the bundled content loads and validates, and the demo seed is coherent.
@MainActor
final class AppTests: XCTestCase {
  func testBundledContentLoads() throws {
    let url = try XCTUnwrap(Bundle(for: AppModel.self).url(forResource: "kids-content", withExtension: "json"))
    let c = try KidsContent.load(try Data(contentsOf: url))
    XCTAssertGreaterThanOrEqual(c.lessons.count, 24)
    XCTAssertNotNil(c.questChapters, "chapters 2 and 3 ship in the app")
  }
  func testDemoModelDerivesProgress() throws {
    let url = try XCTUnwrap(Bundle(for: AppModel.self).url(forResource: "kids-content", withExtension: "json"))
    let c = try KidsContent.load(try Data(contentsOf: url))
    let today = "2026-10-31"
    let m = AppModel(content: c, services: Services(market: FakeMarket(today: today), luna: FakeLuna(), voice: FakeVoice(), store: MemoryStore(Demo.seeded(today: today)), clock: FixedClock(today)))
    XCTAssertTrue(m.chaptersDone.contains("lemonade"))
    XCTAssertGreaterThan(m.points, 0)
    XCTAssertEqual(m.recap?.label, "This week")
  }
}
