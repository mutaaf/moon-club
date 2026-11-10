import XCTest
import SwiftUI
@testable import MoonClub

/// iPhone Duo's outer display, closed (466×678 pt): the camera and a vertical status bar take an 84 pt column
/// on one side (occlusion regions: the camera 37×37 at (400, 29), and the column 84×174 upright / 84×82
/// sideways). Upright, everything fits. Sideways the window's safe area is only 432 pt tall, play screens
/// overflowed (the HUD's close button was pushed into the top edge beside the camera) and `.large` sheets
/// were laid out ~636 pt tall, so their bottom sat off screen. `ScrollsWhenShort` scrolls those rooms and
/// pins sheets to what's on screen; these numbers are the ones the simulator reported (`-safearea`).
final class ShortRoomTests: XCTestCase {
  // Global frames, as the root and the screens measure them.
  let outerUpright = CGRect(x: 0, y: 0, width: 382, height: 644)        // window safe area, camera column trailing
  let outerSideways = CGRect(x: 84, y: 0, width: 594, height: 432)      // camera column leading (or trailing)

  func testUprightRoomsNeverChange() {
    // Lesson stage areas (window minus the HUD-free bottom actions) and full play screens on upright devices.
    let rooms: [(String, CGRect, CGRect)] = [
      ("Duo outer upright, lesson stage", CGRect(x: 0, y: 0, width: 382, height: 568), outerUpright),
      ("Duo outer upright, game", outerUpright, outerUpright),
      ("Duo outer upright, large sheet", CGRect(x: 0, y: 8, width: 466, height: 636), CGRect(x: 0, y: 0, width: 382, height: 644)),
      ("iPhone SE, lesson stage", CGRect(x: 0, y: 20, width: 375, height: 571), CGRect(x: 0, y: 20, width: 375, height: 647)),
      ("iPhone 17, lesson stage", CGRect(x: 0, y: 62, width: 402, height: 700), CGRect(x: 0, y: 62, width: 402, height: 778)),
      ("iPad 11, game", CGRect(x: 0, y: 24, width: 834, height: 1166), CGRect(x: 0, y: 24, width: 834, height: 1166)),
      ("Duo inner (book), lesson stage", CGRect(x: 0, y: 24, width: 669, height: 840), CGRect(x: 0, y: 24, width: 669, height: 913)),
    ]
    for (name, room, window) in rooms {
      XCTAssertEqual(ShortRoom.fit(room: room, window: window), .init(scrolls: false, height: nil), name)
    }
  }

  func testSidewaysOuterDisplayScrolls() {
    // The lesson stage above its buttons, and a full-screen game.
    XCTAssertEqual(ShortRoom.fit(room: CGRect(x: 84, y: 0, width: 594, height: 356), window: outerSideways), .init(scrolls: true, height: nil))
    XCTAssertEqual(ShortRoom.fit(room: outerSideways, window: outerSideways), .init(scrolls: true, height: nil))
  }

  func testSheetsTallerThanTheScreenArePinnedToWhatShows() {
    // Sideways, the Moon Locker / Duo tour sheet is laid out 636 pt tall from y = 8 on a 432 pt safe area.
    let fit = ShortRoom.fit(room: CGRect(x: 84, y: 8, width: 594, height: 636), window: outerSideways)
    XCTAssertTrue(fit.scrolls)
    XCTAssertEqual(fit.height ?? 0, 424, accuracy: 0.5, "content is pinned to the 424 pt that are on screen")
  }

  /// Occlusion regions as the simulator reported them (global, physical points).
  func testCameraCornerIsTheOuterDisplaysOnly() {
    let camera = CGRect(x: 399.7, y: 29.3, width: 37, height: 37)
    let column = CGRect(x: 382, y: 0, width: 84, height: 174)
    XCTAssertTrue(CameraCorner.topTrailing([camera, column], window: outerUpright), "Duo outer, upright: top-trailing")
    // Sideways: top-left (landscape) and bottom-right (landscapeLeft) never count as top-trailing.
    XCTAssertFalse(CameraCorner.topTrailing([CGRect(x: 29.3, y: 29.3, width: 37, height: 37), CGRect(x: 0, y: 0, width: 84, height: 82)], window: outerSideways))
    XCTAssertFalse(CameraCorner.topTrailing([CGRect(x: 611.7, y: 399.7, width: 37, height: 37), CGRect(x: 594, y: 384, width: 84, height: 82)],
                                            window: CGRect(x: 0, y: 0, width: 594, height: 432)))
    // iPhone 17: the Dynamic Island is top-center (and above the bars); sideways it's on a side, mid-height.
    XCTAssertFalse(CameraCorner.topTrailing([CGRect(x: 138, y: 11, width: 126, height: 37)], window: CGRect(x: 0, y: 62, width: 402, height: 778)))
    XCTAssertFalse(CameraCorner.topTrailing([CGRect(x: 11, y: 138, width: 37, height: 126)], window: CGRect(x: 62, y: 0, width: 750, height: 381)))
    // No regions (iPad, iOS before 27.1): nothing moves.
    XCTAssertFalse(CameraCorner.topTrailing([], window: outerUpright))
    // Right-to-left: trailing is the left end of the bar.
    XCTAssertTrue(CameraCorner.topTrailing([CGRect(x: 29.3, y: 29.3, width: 37, height: 37)], window: CGRect(x: 84, y: 0, width: 382, height: 644), rtl: true))
  }

  func testNotMeasuredYetIsLeftAlone() {
    XCTAssertEqual(ShortRoom.fit(room: .zero, window: outerSideways), .init(scrolls: false, height: nil))
    XCTAssertEqual(ShortRoom.fit(room: outerUpright, window: .zero), .init(scrolls: false, height: nil))
  }

  /// The whole fallback, laid out: in a sideways outer-display room a lesson-sized layout scrolls and its top
  /// row (where the HUD's close button lives) starts inside the room, never above it.
  func testTopRowStaysInsideAShortRoom() {
    let topRow = "top"
    struct Probe: View {
      var body: some View {
        VStack(spacing: 0) {
          Color.red.frame(height: 44).accessibilityIdentifier("top")
          Color.blue.frame(minHeight: 500)
        }
        .scrollsWhenShort()
      }
    }
    let host = UIHostingController(rootView: Probe().environment(\.windowSafeFrame, outerSideways))
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 594, height: 356))
    window.rootViewController = host
    window.makeKeyAndVisible()
    host.view.frame = window.bounds
    host.view.setNeedsLayout(); host.view.layoutIfNeeded()
    RunLoop.main.run(until: Date().addingTimeInterval(0.3))
    host.view.layoutIfNeeded()
    let scroll = host.view.firstSubview(of: UIScrollView.self)
    XCTAssertNotNil(scroll, "a 356 pt room scrolls")
    if let scroll {
      XCTAssertGreaterThanOrEqual(scroll.contentSize.height, ShortRoom.minHeight - 1, "laid out at its designed height")
      XCTAssertEqual(scroll.contentOffset.y + scroll.adjustedContentInset.top, 0, accuracy: 0.5, "starts at the top row (\(topRow))")
    }
  }
}

private extension UIView {
  func firstSubview<T: UIView>(of type: T.Type) -> T? {
    for v in subviews {
      if let t = v as? T { return t }
      if let t = v.firstSubview(of: type) { return t }
    }
    return nil
  }
}
