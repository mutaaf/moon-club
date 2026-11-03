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
  // Card space = screen height − status bar − Game On HUD (~96) − pinned buttons (~76) − home indicator.
  // Play is full screen (no tab bar, no navigation bar) since 0.10.
  static let devices = [
    Device(name: "iPhone SE", width: 375, height: 667, chrome: 204),   // no notch, no home indicator (measured on the SE sim: status 20 + HUD ~99 + buttons ~83, plus 2 to spare)
    Device(name: "iPhone 17", width: 402, height: 874, chrome: 270),
    Device(name: "iPhone Duo outer", width: 384, height: 840, chrome: 270),
    Device(name: "iPad", width: 720, height: 1100, chrome: 270),
  ]
  /// Whole play screens (HUD + card/chart + buttons) at their smallest: this is what must fit the screen.
  static let screens = [
    Device(name: "iPhone SE", width: 375, height: 667, chrome: 20),    // status bar
    Device(name: "iPhone 17", width: 402, height: 874, chrome: 62 + 34),
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
    let host = UIHostingController(rootView: v.padding(20).environment(app).environment(\.dynamicTypeSize, type))
    return host.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude)).height
  }

  func testEveryLessonStepFitsItsCardWithoutScrolling() throws {
    let base = try content(), c = base.with(packs: base.bundledPacks), app = model(c)  // Core + every bundled pack
    var misfits: [String] = []
    for d in Self.devices {
      let cardWidth = min(d.width, 720) - 40
      let room = d.height - d.chrome
      for l in c.lessons {
        for (i, s) in l.steps.enumerated() {
          // The art stage grows into spare room; what must fit is the card at its smallest art.
          // Quiz steps' picture stage is spare-room only (it collapses to nothing), so it's left out here.
          let v = StepContent(step: s, art: true, seed: i, picked: .constant(nil), picks: .constant([:]), artMax: 150, quizArtMax: 0)
          let h = height(v, width: cardWidth, type: d.name == "iPhone SE" ? .xxLarge : .xxxLarge, app: app)
          if h > room { misfits.append("\(d.name) \(l.id)#\(i): \(Int(h)) > \(Int(room))") }
        }
      }
    }
    XCTAssertTrue(misfits.isEmpty, "Cards that would need scrolling:\n" + misfits.joined(separator: "\n"))
  }

  /// The smallest height a whole screen can be laid out at (flexible parts — charts, art, spacers — at
  /// their minimum; text at full size). If it's taller than the screen, something would be cut off.
  func minHeight(_ v: some View, width: CGFloat, app: AppModel) -> CGFloat {
    let host = UIHostingController(rootView: NavigationStack { v }.environment(app).environment(\.dynamicTypeSize, .large))
    return host.sizeThatFits(in: CGSize(width: width, height: 1)).height
  }

  func testEveryPlayScreenFitsWithoutScrolling() throws {
    let base = try content(), c = base.with(packs: base.bundledPacks), app = model(c)  // Core + every bundled pack
    let regions = World.regions(c)
    var misfits: [String] = [], checked = 0
    for d in Self.screens {
      let room = d.height - d.chrome
      for n in regions.flatMap(\.nodes) {
        switch n.kind { case .game, .review, .timeMachine: break; default: continue }
        let h = minHeight(NodePlayer(node: n, regions: regions), width: d.width, app: app); checked += 1
        if h > room { misfits.append("\(d.name) \(n.id): \(Int(h)) > \(Int(room))") }
      }
      for l in c.lessons {
        let h = minHeight(LessonPlayer(lesson: l), width: d.width, app: app); checked += 1
        if h > room { misfits.append("\(d.name) lesson \(l.id): \(Int(h)) > \(Int(room))") }
      }
    }
    XCTAssertGreaterThan(checked, 40)
    XCTAssertTrue(misfits.isEmpty, "Play screens that would need scrolling:\n" + misfits.joined(separator: "\n"))
  }

  /// Every quest stage (intro, each stage of every chapter, done) fits the screen at standard text on
  /// iPhone SE and iPhone 17 — HUD, title, stepper and stage card — with no page scroll.
  func testEveryQuestStageFitsWithoutScrolling() throws {
    let c = try content(), app = model(c)
    var starts = ["lemonade"] + QuestView.lemonade + ["lemonade:done"]
    for (ch, stages) in c.questChapters?.CH_STAGES ?? [:] { starts += [ch] + stages.map { "\(ch):\($0)" } + ["\(ch):done"] }
    var misfits: [String] = []
    for d in Self.screens {
      let room = d.height - d.chrome
      for s in starts {
        let host = UIHostingController(rootView: QuestView(start: s, scrolls: false).environment(app).environment(\.dynamicTypeSize, .large))
        let h = host.sizeThatFits(in: CGSize(width: d.width, height: 1)).height
        if h > room { misfits.append("\(d.name) quest \(s): \(Int(h)) > \(Int(room))") }
      }
    }
    XCTAssertGreaterThan(starts.count, 10)
    XCTAssertTrue(misfits.isEmpty, "Quest stages that would need scrolling:\n" + misfits.joined(separator: "\n"))
  }

  /// The Moon Locker (a sheet): every tab and every shop shelf fits on iPhone SE and iPhone 17 at
  /// standard text, with nothing to scroll (the trophy shelf pages; the shop shows one shelf at a time).
  func testMoonShopAndBadgeCabinetFitWithoutScrolling() throws {
    let c = try content(), app = model(c)
    app.mutate { $0.bank(.game, "fit", points: 2000, today: "2026-10-31"); $0.finishLesson("company", today: "2026-10-31") }
    var misfits: [String] = [], checked = 0
    // A large sheet starts ~10 pt below the status bar and ends at the screen bottom.
    for d in [Device(name: "iPhone SE", width: 375, height: 667, chrome: 40), Device(name: "iPhone 17", width: 402, height: 874, chrome: 62 + 34 + 10)] {
      let room = d.height - d.chrome
      var screens: [(String, MoonLocker)] = [("badges", MoonLocker(tab: .badges)), ("points", MoonLocker(tab: .points))]
      for s in ShopSlot.allCases { screens.append(("shop \(s.rawValue)", MoonLocker(tab: .shop, slot: s))) }
      for (name, v) in screens {
        let host = UIHostingController(rootView: v.environment(app).environment(\.dynamicTypeSize, .large))
        let h = host.sizeThatFits(in: CGSize(width: d.width, height: 1)).height; checked += 1
        if h > room { misfits.append("\(d.name) \(name): \(Int(h)) > \(Int(room))") }
      }
    }
    XCTAssertGreaterThan(checked, 15)
    XCTAssertTrue(misfits.isEmpty, "Locker screens that would need scrolling:\n" + misfits.joined(separator: "\n"))
    for s in ShopSlot.allCases { XCTAssertLessThanOrEqual(Shop.all.filter { $0.slot == s }.count, 8, "a shelf is at most two rows of four") }
    for it in Shop.all { XCTAssertNotNil(UIImage(systemName: it.symbol), "shop symbol \(it.symbol)") }
    for t in Trophies.all { XCTAssertNotNil(UIImage(systemName: t.symbol), "trophy symbol \(t.symbol)") }
    for s in ShopSlot.allCases { XCTAssertNotNil(UIImage(systemName: MoonShop.icon(s)), "slot icon \(s)") }
    for p in PointSource.allCases { XCTAssertNotNil(UIImage(systemName: p.symbol), "source symbol \(p.symbol)") }
  }

  func testArtReviewListAndNoMisleadingPictures() {
    // The whole emoji → picture map, for a human to skim (printed in the test log).
    print("ART REVIEW\n" + Art.reviewList.joined(separator: "\n"))
    for (k, bad) in Art.neverAgain { XCTAssertFalse(bad.contains(Art.spec(k).symbol), "\(k) must not be drawn as \(Art.spec(k).symbol)") }
    XCTAssertEqual(Art.spec("🐄").symbol, "arrow.left.arrow.right.circle.fill") // barter = a trade
    XCTAssertEqual(Art.spec("💰").symbol, "dollarsign.circle.fill")
    XCTAssertEqual(Art.spec("🍋").symbol, "custom.lemon")
  }

  func testNoCardHasAScrollViewInside() throws {
    // Source check: the card-content views never contain a ScrollView (the page may scroll, a card may not).
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    for f in ["MoonClub/Features/School.swift", "MoonClub/Features/Story.swift", "MoonClub/Features/WorldGames.swift", "MoonClub/Features/WorldBosses.swift", "MoonClub/Features/WhatsNewModal.swift", "MoonClub/Features/Missions.swift", "MoonClub/Design/GameKit.swift", "MoonClub/Features/Rewards.swift"] {
      let src = try String(contentsOf: root.appendingPathComponent(f), encoding: .utf8)
      for marker in ["struct StepContent", "struct StoryCard", "struct ChartCard", "struct GameShell", "struct CheckView", "struct SortView", "struct TodaysMissions", "struct RunResults", "struct GameHUD", "struct ArtPanel", "struct TimeMachineBoss", "struct MoonLocker", "struct TrophyShelf", "struct TrophyCell", "struct MoonShop", "struct ShopCell", "struct PointsBook", "struct RankCeremony", "struct RunEarnings"] {
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
    // Lesson packs: every glyph Core and every bundled pack declares, and the why-card clue art.
    keys.formUnion(c.glyphs ?? []); for p in c.bundledPacks { keys.formUnion(p.glyphs) }
    keys.formUnion(WhyCard.art.values)
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
