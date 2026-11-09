import XCTest
import SwiftUI
import MoonClubCore
@testable import MoonClub

/// Moon School's lesson scenes: every lesson's prop is a real symbol (or one of our drawn marks), every act
/// draws in every state without trapping, and the Up Next hero fits narrow windows at big text sizes.
@MainActor
final class SceneTests: XCTestCase {
  func content() throws -> KidsContent {
    let url = try XCTUnwrap(Bundle(for: AppModel.self).url(forResource: "kids-content", withExtension: "json"))
    return try JSONDecoder().decode(KidsContent.self, from: Data(contentsOf: url))
  }

  func testEveryLessonPropIsARealSymbol() throws {
    let c = try content()
    let all = c.with(packs: c.bundledPacks)
    for l in all.lessons {
      let s = Scenes.scene(for: l).symbol(for: l)
      if s.hasPrefix("custom.") { XCTAssertTrue(["custom.piggy", "custom.lemon", "custom.candle"].contains(s), "\(l.id): \(s)"); continue }
      XCTAssertNotNil(UIImage(systemName: s), "\(l.id): \(s)")
    }
    for s in ["sparkle", "arrow.up", "flag.fill", "basket.fill", "leaf.fill", "magnifyingglass", "star.fill", "checkmark", "checkmark.shield.fill"] {
      XCTAssertNotNil(UIImage(systemName: s), s)
    }
  }

  /// Renders one frame of every act, live and settled, and checks pixels came out (the shader and Canvas ran).
  func testEveryActRenders() throws {
    let c = try content()
    XCTAssertFalse(c.lessons.isEmpty)
    for (k, act) in SceneAct.allCases.enumerated() {
      for (i, status) in [SceneStatus.open, .done].enumerated() {
        let scene = LessonScene(act: act, palette: ScenePalette.allCases[k % ScenePalette.allCases.count], prop: "tag.fill", hook: "Hi!", seed: 0.1 * Double(i))
        let r = ImageRenderer(content: SceneFrame(scene: scene, symbol: "tag.fill", side: 64, status: status, luna: 24))
        r.scale = 2
        XCTAssertNotNil(r.uiImage, "\(act) \(status)")
      }
    }
  }

  func testUpNextHeroFitsNarrowWindows() throws {
    let c = try content()
    let lesson = try XCTUnwrap(c.lessons.max { $0.title.count < $1.title.count })
    for (width, type) in [(320.0, DynamicTypeSize.xxxLarge), (320, .accessibility3), (375, .large), (1000, .xxLarge)] {
      let v = UpNextHero(lesson: lesson, unitTitle: "Baskets of companies").environment(\.dynamicTypeSize, type)
      let size = UIHostingController(rootView: v).sizeThatFits(in: CGSize(width: width, height: .infinity))
      XCTAssertLessThanOrEqual(size.width, width + 0.5, "hero overflows \(width) pt at \(type)")
      XCTAssertGreaterThan(size.height, 100)
    }
  }
}
