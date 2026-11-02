import XCTest
import SwiftUI
import MoonClubCore
@testable import MoonClub

/// "We shouldn't have to scroll inside the cards." Every lesson step is measured as it's laid out in its
/// card, at iPhone SE, iPhone 17, iPhone Duo (outer) and iPad widths, up to the largest standard text size
/// (xxxLarge). Each must fit the card space that device leaves after the bars and buttons. (Accessibility
/// text sizes may scroll the *page*; a card never scrolls inside itself — there is no inner ScrollView.)
/// Also: every illustration resolves to a real SF Symbol, and every emoji in the content has designed art.
@MainActor
final class CardFitTests: XCTestCase {
  struct Device { let name: String; let width: CGFloat; let height: CGFloat; var chrome: CGFloat = 250 }
  // Card space = screen height − status/nav bar − lesson progress − pinned buttons − tab bar/home indicator.
  static let devices = [
    Device(name: "iPhone SE", width: 375, height: 667, chrome: 225),   // no notch, no home indicator
    Device(name: "iPhone 17", width: 402, height: 874),
    Device(name: "iPhone Duo outer", width: 384, height: 840),
    Device(name: "iPad", width: 720, height: 1100),
  ]
  static let chrome: CGFloat = 250

  func content() throws -> KidsContent {
    let url = try XCTUnwrap(Bundle(for: AppModel.self).url(forResource: "kids-content", withExtension: "json"))
    return try KidsContent.load(try Data(contentsOf: url))
  }
  func model(_ c: KidsContent) -> AppModel {
    AppModel(content: c, services: Services(market: FakeMarket(today: "2026-10-31"), luna: LunaRouter(brains: [FakeBrain(kind: .free)], resolve: { .free }), voice: FakeVoice(), store: MemoryStore(), clock: FixedClock("2026-10-31")))
  }

  func height(_ v: some View, width: CGFloat, type: DynamicTypeSize, app: AppModel) -> CGFloat {
    let host = UIHostingController(rootView: v.padding(24).environment(app).environment(\.dynamicTypeSize, type))
    return host.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude)).height
  }

  func testEveryLessonStepFitsItsCardWithoutScrolling() throws {
    let c = try content(), app = model(c)
    var misfits: [String] = []
    for d in Self.devices {
      let cardWidth = min(d.width, 720) - 40
      let room = d.height - d.chrome
      for l in c.lessons {
        for (i, s) in l.steps.enumerated() {
          let v = StepContent(step: s, art: true, seed: i, picked: .constant(nil), picks: .constant([:]))
          let h = height(v, width: cardWidth, type: .xxxLarge, app: app)
          if h > room { misfits.append("\(d.name) \(l.id)#\(i): \(Int(h)) > \(Int(room))") }
        }
      }
    }
    XCTAssertTrue(misfits.isEmpty, "Cards that would need scrolling:\n" + misfits.joined(separator: "\n"))
  }

  func testNoCardHasAScrollViewInside() throws {
    // Source check: the card-content views never contain a ScrollView (the page may scroll, a card may not).
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    for f in ["MoonClub/Features/School.swift", "MoonClub/Features/Story.swift", "MoonClub/Features/WorldGames.swift", "MoonClub/Features/WorldBosses.swift", "MoonClub/Features/WhatsNewModal.swift"] {
      let src = try String(contentsOf: root.appendingPathComponent(f), encoding: .utf8)
      for marker in ["struct StepContent", "struct StoryCard", "struct ChartCard", "struct GameShell", "struct CheckView", "struct SortView"] {
        guard let r = src.range(of: marker) else { continue }
        let body = src[r.lowerBound...].prefix(4000)
        let end = body.range(of: "\n}\n").map { body[..<$0.lowerBound] } ?? body
        XCTAssertFalse(end.contains("ScrollView"), "\(marker) in \(f) contains a ScrollView")
      }
    }
  }

  func testEverySymbolExistsAndEveryContentEmojiHasArt() throws {
    for s in Art.allSymbols { XCTAssertNotNil(UIImage(systemName: s), "SF Symbol \(s)") }
    for r in World.regions(try content()) { for n in r.nodes { XCTAssertNotEqual(Art.spec(n.art), Art.fallback, "map art \(n.art)") } }
    let c = try content()
    var keys = Set<String>()
    keys.formUnion(c.lessons.map(\.emoji)); keys.formUnion(c.units.map(\.emoji)); keys.formUnion(c.companies.map(\.emoji))
    keys.formUnion(c.terms.values.map(\.emoji)); keys.formUnion(c.players)
    keys.formUnion(c.questChapters?.CHAPTERS.map(\.emoji) ?? [])
    for l in c.lessons { for s in l.steps {
      if case let .say(e, _) = s { keys.insert(e) }
      if case let .sort(_, _, items, _) = s { keys.formUnion(items.map(\.emoji)) }
    } }
    let missing = keys.filter { Art.spec($0) == Art.fallback }
    XCTAssertTrue(missing.isEmpty, "emoji without designed art: \(missing.sorted())")
    for s in ["moon.zzz.fill", "map.fill", "books.vertical.fill", "character.book.closed.fill", "hand.thumbsup.fill", "hand.thumbsdown.fill", "flag.checkered", "signpost.right.fill", "figure.hiking", "sailboat.fill", "beach.umbrella.fill", "flame.fill", "flag.2.crossed.fill"] {
      XCTAssertNotNil(UIImage(systemName: s), "SF Symbol \(s)")
    }
  }

  func testMarketWorldGamesHaveRealChartsOffline() {
    let s = AppModel.bundledCandles
    XCTAssertGreaterThanOrEqual(s.count, 5, "bundled candles load")
    let r = Rounds(series: Array(s.values), seed: 7)
    for t in Trend.allCases { XCTAssertNotEqual(r.window(0, length: 30, trend: t).0, "Practice", "a real \(t) window exists") }
  }
}
