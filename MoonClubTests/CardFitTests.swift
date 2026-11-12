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
      // Moon Tower: every game at its debut, the same game high in the tower (more answers, longer charts,
      // bigger grids), and boss floors (every round's game in turn).
      var tower = TowerGame.allCases.flatMap { g in [Tower.level(g.debut)] + (g.debut...200).lazy.map(Tower.level).filter { $0.lead == g && $0.tier >= 4 && !$0.isBoss }.prefix(1) }
      tower += [Tower.level(10), Tower.level(100)]
      for l in tower {
        for i in 0..<(l.isBoss ? l.rounds : 1) {
          let h = minHeight(TowerRoundProbe(level: l, index: i), width: d.width, app: app); checked += 1
          if h > room { misfits.append("\(d.name) tower \(l.number) round \(i) (\(l.game(i))): \(Int(h)) > \(Int(room))") }
        }
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
      var screens: [(String, MoonLocker)] = [("badges", MoonLocker(tab: .badges)), ("stickers", MoonLocker(tab: .stickers)), ("points", MoonLocker(tab: .points))]
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

  /// Moon Garden (0.13): planting fits one sheet on iPhone SE and 17 at standard text, with nothing to
  /// scroll; the garden's cards and rows fit a phone's width; the locker's points page (with the ledger) still fits.
  func testMoonGardenFitsWithoutScrolling() throws {
    let c = try content(), app = model(c)
    app.mutate { $0.bank(.game, "fit", points: 900, today: "2026-10-31"); $0.setGardenLimit(100, nowMillis: 1) }
    for (i, sym) in ["DIS", "NKE", "AAPL", "KO"].enumerated() { XCTAssertTrue(app.plant(sym, points: 20 + i), "plant \(sym)") }
    app.harvest("KO", points: 5)
    var misfits: [String] = []
    for d in [Device(name: "iPhone SE", width: 375, height: 667, chrome: 40), Device(name: "iPhone 17", width: 402, height: 874, chrome: 62 + 34 + 10)] {
      let room = d.height - d.chrome
      for (name, v) in [("plant", AnyView(PlantSheet())), ("points", AnyView(MoonLocker(tab: .points)))] {
        let host = UIHostingController(rootView: v.environment(app).environment(\.dynamicTypeSize, .large))
        let h = host.sizeThatFits(in: CGSize(width: d.width, height: 1)).height
        if h > room { misfits.append("\(d.name) \(name): \(Int(h)) > \(Int(room))") }
      }
      for (name, v) in [("summary", AnyView(GardenSummary(book: app.derived.garden) {})), ("row", AnyView(PlotRow(plot: app.derived.garden.growing[0]) {}))] {
        let host = UIHostingController(rootView: v.environment(app).environment(\.dynamicTypeSize, .xxLarge))
        let w = host.sizeThatFits(in: CGSize(width: d.width - 40, height: .greatestFiniteMagnitude)).width
        if w > d.width - 40 + 0.5 { misfits.append("\(d.name) \(name) too wide: \(Int(w)) > \(Int(d.width - 40))") }
      }
    }
    XCTAssertTrue(misfits.isEmpty, "Garden screens that would need scrolling or clip:\n" + misfits.joined(separator: "\n"))
  }

  /// iPhone Duo screens (0.14) fit without scrolling: the atlas page at one inner-display page (~314 pt), Luna's
  /// pocket on the outer display, and the puppet show stacked on an iPhone SE (no fold: stage over controls).
  func testDuoScreensFitWithoutScrolling() throws {
    let c = try content(), app = model(c)
    let regions = World.regions(c)
    var misfits: [String] = []
    func measure(_ name: String, _ v: some View, width: CGFloat, room: CGFloat) {
      let host = UIHostingController(rootView: v.environment(app).environment(\.dynamicTypeSize, .large))
      let h = host.sizeThatFits(in: CGSize(width: width, height: 1)).height
      if h > room { misfits.append("\(name): \(Int(h)) > \(Int(room))") }
    }
    for i in regions.indices {
      measure("atlas \(regions[i].id)", AtlasPage(regions: regions, page: .constant(i), current: (0, 0), play: { _ in }), width: 314, room: 951 - 60)
    }
    measure("pocket (Duo outer)", LunaPocket {}, width: 384, room: 840 - 60)
    measure("pocket (SE)", LunaPocket {}, width: 375, room: 667 - 20)
    measure("puppet show (SE)", PuppetShow(), width: 375, room: 667 - 20)
    XCTAssertTrue(misfits.isEmpty, "Duo screens that would need scrolling:\n" + misfits.joined(separator: "\n"))
  }

  /// iPad, Split View and Stage Manager widths: the wide-window layouts never draw wider than the window
  /// (the old Story carousel ran off the right edge; the World header truncated in a narrow map column).
  func testIPadLayoutsStayInsideTheirWindow() throws {
    let c = try content(), app = model(c)
    let cards: [StoryView.Card] = [.weather(40), .word, .quiz, .next]
    var misfits: [String] = []
    for w in [320.0, 450, 600, 688, 900, 1032, 1376] as [CGFloat] {
      let views: [(String, AnyView)] = [
        ("story columns", AnyView(StoryColumns(cards: cards, width: w))),
        ("world header", AnyView(WorldHeader(regions: World.regions(c)))),
        ("story", AnyView(StoryView())),
        ("garden", AnyView(MoonGarden())),
      ]
      for (name, v) in views {
        let host = UIHostingController(rootView: NavigationStack { v }.environment(app).environment(\.horizontalSizeClass, w >= 680 ? .regular : .compact))
        let got = host.sizeThatFits(in: CGSize(width: w, height: 2000)).width
        if got > w + 0.5 { misfits.append("\(name) at \(Int(w)): \(Int(got)) wide") }
      }
      // The header's title row: every land name fits (unscaled or stacked), never cut to "Trend…".
      let header = UIHostingController(rootView: WorldHeader(regions: World.regions(c)).environment(app))
      let hs = header.sizeThatFits(in: CGSize(width: w, height: .greatestFiniteMagnitude))
      XCTAssertLessThanOrEqual(hs.width, w + 0.5, "world header at \(Int(w))")
    }
    XCTAssertTrue(misfits.isEmpty, misfits.joined(separator: "\n"))
  }

  /// World on iPad: the map never gets narrower than 360 pt beside the stop preview, landscape windows give
  /// the map most of the room, and narrow windows show the map alone (the preview opens as a sheet).
  func testWorldMapKeepsAReadableWidth() {
    let none = FoldInfo()
    for size in [CGSize(width: 712, height: 1376), CGSize(width: 1032, height: 1376), CGSize(width: 834, height: 1194), CGSize(width: 1056, height: 1032), CGSize(width: 1376, height: 1032), CGSize(width: 900, height: 700)] {
      guard let s = WorldView.panelSplit(size: size, fold: none) else { XCTFail("\(size) should show the preview beside the map"); continue }
      XCTAssertGreaterThanOrEqual(s.lead, 360, "map width at \(size)")
      XCTAssertGreaterThanOrEqual(s.trail, 280, "preview width at \(size)")
      XCTAssertEqual(s.lead + s.gap + s.trail, size.width, accuracy: 0.5)
      if size.width > size.height { XCTAssertGreaterThan(s.lead, s.trail, "landscape: the map gets most of the room") }
    }
    XCTAssertNil(WorldView.panelSplit(size: CGSize(width: 450, height: 1032), fold: none), "Slide Over width: map alone")
    XCTAssertNil(WorldView.panelSplit(size: CGSize(width: 402, height: 874), fold: none), "iPhone: map alone")
  }

  /// Read the Day: equal prices share one label and labels are pushed apart, so "Start" and "Low" never overlap.
  func testBigCandleLabelsNeverOverlap() {
    let flat = BigCandle.labels(o: 100, h: 104, l: 100, c: 102)
    XCTAssertEqual(flat.map(\.text), ["High $104", "End $102", "Start and low $100"])
    let doji = BigCandle.labels(o: 100, h: 101, l: 99, c: 100)
    XCTAssertEqual(doji.count, 3, "start and end on the same price share a row: \(doji.map(\.text))")
    let ys = BigCandle.spread([10, 12, 13, 200], gap: 20, in: 0...220)
    for (a, b) in zip(ys, ys.dropFirst()) { XCTAssertGreaterThanOrEqual(b - a, 20 - 0.001) }
    let tight = BigCandle.spread([200, 205, 210, 215], gap: 20, in: 0...220)
    XCTAssertLessThanOrEqual(tight.last ?? 0, 210 + 0.001, "pushed back inside the bottom edge")
    for (a, b) in zip(tight, tight.dropFirst()) { XCTAssertGreaterThanOrEqual(b - a, 20 - 0.001) }
  }

  /// Colour-blind safe candles: an up candle's body is hollow (its center isn't the solid green), a down
  /// candle's body is filled — readable even at a small size and in grayscale.
  func testCandlesShowDirectionWithoutColour() throws {
    func centerPixel(up: Bool, width: CGFloat) throws -> (r: CGFloat, g: CGFloat, b: CGFloat) {
      let c = up ? Candle(d: "a", o: 100, h: 112, l: 98, c: 110) : Candle(d: "a", o: 110, h: 112, l: 98, c: 100)
      let r = ImageRenderer(content: CandleChart(candles: [c, c, c], domain: 95...115).frame(width: width, height: 120).background(Color.white))
      r.scale = 2
      let img = try XCTUnwrap(r.uiImage?.cgImage)
      let data = try XCTUnwrap(img.dataProvider?.data as Data?)
      let bpr = img.bytesPerRow, x = Int(CGFloat(img.width) / 2), y = Int(CGFloat(img.height) * 0.42)
      let o = y * bpr + x * 4
      return (CGFloat(data[o]) / 255, CGFloat(data[o + 1]) / 255, CGFloat(data[o + 2]) / 255)
    }
    for w in [60.0, 120, 300] as [CGFloat] {
      let up = try centerPixel(up: true, width: w), down = try centerPixel(up: false, width: w)
      let lumUp = 0.3 * up.r + 0.59 * up.g + 0.11 * up.b, lumDown = 0.3 * down.r + 0.59 * down.g + 0.11 * down.b
      XCTAssertGreaterThan(lumUp - lumDown, 0.25, "at \(Int(w)) pt an up body (hollow) must read lighter than a down body (filled), even in grayscale")
    }
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
    for f in ["MoonClub/Features/School.swift", "MoonClub/Features/Story.swift", "MoonClub/Features/WorldGames.swift", "MoonClub/Features/WorldBosses.swift", "MoonClub/Features/WhatsNewModal.swift", "MoonClub/Features/Missions.swift", "MoonClub/Features/StartHere.swift", "MoonClub/Design/GameKit.swift", "MoonClub/Features/Rewards.swift"] {
      let src = try String(contentsOf: root.appendingPathComponent(f), encoding: .utf8)
      for marker in ["struct StepContent", "struct StoryCard", "struct ChartCard", "struct GameShell", "struct CheckView", "struct SortView", "struct MissionStrip", "struct StartHereHero", "struct RunResults", "struct GameHUD", "struct ArtPanel", "struct TimeMachineBoss", "struct MoonLocker", "struct TrophyShelf", "struct TrophyCell", "struct MoonShop", "struct ShopCell", "struct PointsBook", "struct RankCeremony", "struct RunEarnings"] {
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
      if case let .example(x) = s { keys.insert(x.emoji) }
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

/// A Moon Tower level laid out as `TowerPlayer` does, but showing round `index` first (GameShell always
/// opens on round 0, and a boss floor's rounds are each a different game).
struct TowerRoundProbe: View {
  let level: TowerLevel
  let index: Int
  @Environment(AppModel.self) private var app
  var body: some View {
    let node = WorldNode(id: level.id, title: "Level \(level.number)", art: "👑", kind: .game(.readDay))
    let g = level.game(index)
    GameShell(node: node, rounds: level.rounds, intro: g.how, boss: level.isBoss ? BossInfo(name: "Floor guard", art: "👑") : nil,
              hearts: level.hearts, roundTag: level.mixed ? { _ in "\(g.title): \(g.how)" } : nil, onFinish: { _ in }) { _, answer, answered in
      TowerRound(level: level, index: index, rounds: Rounds(series: Array(app.candles.values), seed: level.seed), answer: answer, answered: answered)
    }
  }
}

/// A Chart Academy level laid out as `AcademyPlayer` does, showing round `index` first.
struct AcademyRoundProbe: View {
  let level: AcademyLevel
  let index: Int
  var body: some View {
    let node = WorldNode(id: level.id, title: "Level \(level.number)", art: "👑", kind: .game(.readDay))
    let r = level.rounds[index % level.rounds.count]
    GameShell(node: node, rounds: level.rounds.count, intro: r.drill.how, boss: level.isBoss ? BossInfo(name: "Chapter boss", art: "👑") : nil,
              hearts: level.hearts, roundTag: level.mixed ? { _ in "\(r.drill.title): \(r.drill.how)" } : nil, onFinish: { _ in }) { _, answer, answered in
      if level.track == .candles { CandleDrill(level: level, round: r, answer: answer, answered: answered) }
      else { LineDrill(level: level, round: r, answer: answer, answered: answered) }
    }
  }
}

final class AcademyFitTests: XCTestCase {
  /// Every Chart Academy drill fits without scrolling on iPhone SE and 17, at its first level (tips on)
  /// and high up, plus every round of a chapter boss in each track.
  @MainActor func testEveryAcademyDrillFitsWithoutScrolling() throws {
    let c = try CardFitTests().content(), app = CardFitTests().model(c)
    var misfits: [String] = [], checked = 0
    var probes: [(AcademyLevel, Int)] = []
    for t in AcademyTrack.allCases {
      var seen = Set<String>()
      for n in 1...t.mainLevels {
        let l = Academy.level(t, n)
        for (i, r) in l.rounds.enumerated() {
          let key = "\(r.drill)-\(l.scaffold > 0)-\(l.tier >= 3)"
          if !seen.contains(key) { seen.insert(key); probes.append((l, i)) }
        }
      }
      let boss = Academy.level(t, 100)
      probes += boss.rounds.indices.map { (boss, $0) }
    }
    for d in CardFitTests.screens {
      let room = d.height - d.chrome
      for (l, i) in probes {
        let h = CardFitTests().minHeight(AcademyRoundProbe(level: l, index: i), width: d.width, app: app); checked += 1
        if h > room { misfits.append("\(d.name) \(l.id) round \(i) (\(l.rounds[i].drill)): \(Int(h)) > \(Int(room))") }
      }
    }
    XCTAssertGreaterThan(checked, 60)
    XCTAssertTrue(misfits.isEmpty, "Academy drills that would need scrolling:\n" + misfits.joined(separator: "\n"))
  }
}
