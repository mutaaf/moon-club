import XCTest
import SwiftUI
@testable import MoonClub

/// The World's sea is a full-screen Metal shader under Liquid Glass. It must start still and move only when
/// the kid scrolls. The map's own animated scrolls (open on Luna's stop, follow the rocket, atlas page turns)
/// report `.animating`; on iPad the open scroll animates, and waking on it ran the sea at 20 fps for the
/// World's first ~3.5 s every time it opened (~33 ms frames on iPad, 0.14.0).
final class SeaWakeTests: XCTestCase {
  func testOnlyTheKidsOwnScrollWakesTheSea() throws {
    guard #available(iOS 18.0, *) else { throw XCTSkip("scroll phases are iOS 18+") }
    // Programmatic scrolls never wake it.
    XCTAssertFalse(MapScroll.wakes(from: .idle, to: .animating))
    XCTAssertFalse(MapScroll.wakes(from: .animating, to: .idle))
    XCTAssertFalse(MapScroll.wakes(from: .idle, to: .decelerating))
    // A finger on the map does, once per gesture.
    XCTAssertTrue(MapScroll.wakes(from: .idle, to: .tracking))
    XCTAssertTrue(MapScroll.wakes(from: .idle, to: .interacting))
    XCTAssertTrue(MapScroll.wakes(from: .animating, to: .interacting), "grabbing the map mid-animation counts")
    XCTAssertFalse(MapScroll.wakes(from: .tracking, to: .interacting))
    XCTAssertFalse(MapScroll.wakes(from: .interacting, to: .decelerating))
  }
}
