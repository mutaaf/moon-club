import XCTest
import MoonClubCore
@testable import MoonClub

/// The app ↔ widget handoff, in the real host app (real entitlements, real keychain group).
@MainActor
final class WidgetShareTests: XCTestCase {
  var savedSnapshot: Data?, savedProgress: Data?
  override func setUp() { savedSnapshot = MoonShare.read("snapshot"); savedProgress = MoonShare.read("progress") }
  override func tearDown() {
    if let d = savedSnapshot { MoonShare.write("snapshot", d) } else { MoonShare.remove("snapshot") }
    if let d = savedProgress { MoonShare.write("progress", d) } else { MoonShare.remove("progress") }
  }

  func testAccessGroupIsTheTeamSharedGroup() {
    XCTAssertEqual(MoonShare.accessGroup?.hasSuffix(".com.mutaafaziz.moonclub.shared"), true)
    XCTAssertFalse(MoonShare.accessGroup?.hasPrefix("$(") ?? true, "build setting expanded")
  }

  func testSnapshotWritesOnlyWhenChanged() {
    MoonShare.remove("snapshot")
    XCTAssertTrue(MoonShare.writeSnapshot(.placeholder))
    XCTAssertFalse(MoonShare.writeSnapshot(.placeholder), "same bytes: no write, no timeline reload")
    XCTAssertEqual(MoonShare.readSnapshot(), .placeholder)
  }

  /// A widget tap goes through the same store the app reads on return.
  func testWidgetGuessLandsInProgress() async throws {
    MoonShare.remove("progress")
    var snap = WidgetSnapshot.placeholder
    snap.reports[1].d = Day.add(Day.today(), 1)
    MoonShare.writeSnapshot(snap)
    _ = try await GuessReportIntent(symbol: "NKE", day: snap.reports[1].d, pick: .miss).perform()
    XCTAssertEqual(MoonShare.readSnapshot()?.reports[1].pick, .miss, "optimistic snapshot first")
    let g = SharedProgressStore().load().guesses.first { $0.s == "NKE" }
    XCTAssertEqual(g?.pick, .miss)
    XCTAssertEqual(g?.at, Day.today())
  }

  func testTooLateToGuessIsIgnored() async throws {
    MoonShare.remove("progress")
    _ = try await GuessReportIntent(symbol: "NKE", day: Day.add(Day.today(), -1), pick: .beat).perform()
    XCTAssertTrue(SharedProgressStore().load().guesses.isEmpty)
  }

  func testReadStoryIntent() async throws {
    MoonShare.remove("progress")
    _ = try await ReadStoryIntent().perform()
    XCTAssertEqual(SharedProgressStore().load().storyRead, Day.today())
  }

  func testDeepLinks() throws {
    let url = try XCTUnwrap(Bundle(for: AppModel.self).url(forResource: "kids-content", withExtension: "json"))
    let app = AppModel(content: try KidsContent.load(try Data(contentsOf: url)), services: Services(market: FakeMarket(today: "2026-10-31"), luna: LunaRouter(brains: [FakeBrain(kind: .free)], resolve: { .free }), voice: FakeVoice(), store: MemoryStore(KidsState()), clock: FixedClock("2026-10-31")))
    XCTAssertEqual(app.open(MoonLink.tab("piggy")), .piggy)
    XCTAssertEqual(UserDefaults.standard.string(forKey: PiggySide.key), "coins")
    XCTAssertEqual(app.open(MoonLink.lesson("share")), .lesson("share"))
    XCTAssertEqual(app.pendingLesson, "share")
    app.pendingLesson = nil
    XCTAssertEqual(app.open(URL(string: "https://mutaafaziz.com/metaphases/kids/school/money?ref=share")!), .lesson("money"))
    XCTAssertEqual(app.pendingLesson, "money")
    XCTAssertEqual(app.open(URL(string: "https://mutaafaziz.com/metaphases/kids/garden")!), .garden)
    XCTAssertEqual(UserDefaults.standard.string(forKey: PiggySide.key), "garden")
    XCTAssertEqual(app.open(URL(string: "moonclub://gamenight")!), .gameNight)
    XCTAssertTrue(app.pendingGameNight)
    app.pendingLesson = nil
    XCTAssertEqual(app.open(URL(string: "https://example.com/metaphases/kids/guess")!), .home, "only our own site and scheme")
    // Settings links set nothing until the grown-up gate (RootView) has been passed.
    let pack = try XCTUnwrap(app.packs.first)
    XCTAssertEqual(app.open(URL(string: "moonclub://pack/\(pack.id)")!), .pack(pack.id))
    XCTAssertFalse(app.packOn(pack.id), "a pack link never turns a pack on by itself")
    XCTAssertNil(app.pendingLesson)
    XCTAssertEqual(Tab(link: .garden), .piggy); XCTAssertEqual(Tab(link: .lesson("x")), .school); XCTAssertEqual(Tab(link: .home), .story)
    XCTAssertNil(Tab(link: .league("MOON-1")), "gated links don't switch tabs")
  }
}
