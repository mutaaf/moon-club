import XCTest
@testable import MoonClubCore

final class WhatsNewTests: XCTestCase {
  let md = """
  # Moon Club 0.7.0: "Bat-Signal"

  ## What to test
  - **Widget.** grown-up words
  ## Luna's news
  - [rectangle.stack] I live on your Home Screen now!
  - [lock.fill]   Peek at me on the Lock Screen.
  - not an item
  ## Our promises
  - [x] ignored, wrong section
  """

  let cards = """
  # Moon Club 0.17.0: "Super Suit"

  ## Luna's news
  > **Moon Club got a super suit!**
  - [hand.point.up.left.fill] **Super button!** Tap it. I pick your next step!
  - [🍋] **Lights, camera, lessons!** Every lesson card is a little show.
  ## What to test
  > not the headline
  """

  func testParsesOnlyLunasNews() {
    let n = WhatsNew.parse(version: "0.7.0", markdown: md)
    XCTAssertEqual(n.title, "Moon Club 0.7.0: \"Bat-Signal\"")
    XCTAssertNil(n.headline)
    XCTAssertEqual(n.items, [.init(symbol: "rectangle.stack", text: "I live on your Home Screen now!"), .init(symbol: "lock.fill", text: "Peek at me on the Lock Screen.")])
  }

  func testParsesHeadlineAndTitledCards() {
    let n = WhatsNew.parse(version: "0.17.0", markdown: cards)
    XCTAssertEqual(n.headline, "Moon Club got a super suit!")
    XCTAssertEqual(n.items, [
      .init(symbol: "hand.point.up.left.fill", title: "Super button!", text: "Tap it. I pick your next step!"),
      .init(symbol: "🍋", title: "Lights, camera, lessons!", text: "Every lesson card is a little show."),
    ])
    XCTAssertEqual(WhatsNew.lint(n), [])
    XCTAssertFalse(WhatsNew.lint(WhatsNew.parse(version: "0.17.0", markdown: md)).isEmpty, "new versions need a headline and titles")
    XCTAssertEqual(WhatsNew.lint(WhatsNew.parse(version: "0.7.0", markdown: md)), [], "old notes are grandfathered")
  }

  func testCardPlaces() {
    let md = """
    # Moon Club 0.17.1
    ## Luna's news
    > Big news!
    - [hand.point.up.left.fill] **Super button!** Tap it. I pick for you! → story
    - [sparkles] **Lights, camera!** Every lesson card is a show. → moon-school
    - [map.fill] **Train on my map** Real teams want astronauts.  →  world
    - [target] **One lesson** Try it. → school/what-is-money
    - [moon.stars.fill] **Plain card** Arrows like A → B in the middle stay put, no place.
    """
    let n = WhatsNew.parse(version: "0.17.1", markdown: md)
    XCTAssertEqual(n.items.map(\.go), [.link(.home), .moonSchool, .link(.world), .link(.lesson("what-is-money")), nil])
    XCTAssertEqual(n.items[0].text, "Tap it. I pick for you!", "the place is not part of the line")
    XCTAssertEqual(n.items[2].text, "Real teams want astronauts.")
    XCTAssertEqual(n.items[4].text, "Arrows like A → B in the middle stay put, no place.")
    XCTAssertEqual(n.badPlaces, [])
  }

  func testPlacesAreKidPlacesOnly() {
    for (t, p) in [("story", NewsPlace.link(.home)), ("home", .link(.home)), ("world", .link(.world)), ("school", .link(.world)),
                   ("guess", .link(.guess)), ("gamenight", .link(.gameNight)), ("piggy", .link(.piggy)), ("garden", .link(.garden)),
                   ("luna", .link(.luna)), ("ask", .link(.luna)), ("Moon-School", .moonSchool)] {
      XCTAssertEqual(NewsPlace(t), p, t)
    }
    // Grown-up places (they change settings), unknown and malformed tokens: no place.
    for t in ["league/ABCDEFGH12", "pack/space", "settings", "", "moon school", "a/b/c", "https://mutaafaziz.com"] { XCTAssertNil(NewsPlace(t), t) }
  }

  func testUnknownPlaceFailsLint() {
    let n = WhatsNew.parse(version: "0.17.1", markdown: "## Luna's news\n> Hi!\n- [sparkles] **One** Line. → nowhere\n- [sparkles] **Two** Line. → piggy\n")
    XCTAssertEqual(n.items.map(\.go), [nil, .link(.piggy)])
    XCTAssertEqual(WhatsNew.lint(n), ["unknown card place → nowhere (see release-notes/README.md)"])
  }

  func testSemverOrder() {
    XCTAssertTrue(WhatsNew.less("0.9.0", "0.10.0"))
    XCTAssertFalse(WhatsNew.less("0.10.0", "0.9.0"))
    XCTAssertFalse(WhatsNew.less("1.0", "1.0.0"))
  }

  func news(_ v: String, _ n: Int) -> ReleaseNews { .init(version: v, title: v, headline: "Hi \(v)", items: (0..<n).map { .init(symbol: "star", title: "T\($0)", text: "\(v)-\($0)") }) }
  lazy var all = [news("0.15.0", 2), news("0.16.0", 2), news("0.17.0", 5), news("0.18.0", 1)]

  func testNewsIsTheNewestVersionUpToCurrent() {
    XCTAssertNil(WhatsNew.news(lastSeen: nil, current: "0.17.0", all: all), "fresh install sees nothing")
    XCTAssertNil(WhatsNew.news(lastSeen: "0.17.0", current: "0.17.0", all: all), "already seen")
    let n = WhatsNew.news(lastSeen: "0.15.0", current: "0.17.0", all: all)
    XCTAssertEqual(n?.version, "0.17.0", "the current version's notes, never one from the future")
    XCTAssertEqual(n?.items.count, WhatsNew.maxCards, "capped at maxCards")
    XCTAssertEqual(WhatsNew.news(lastSeen: "0.15.0", current: "0.16.5", all: all)?.version, "0.16.0", "newest notes not past current")
  }

  // MARK: once per version

  func launch(_ seen: String?, _ current: String = "0.17.0", args: [String] = [], env: [String: String] = [:], force: String? = nil) -> WhatsNew.Launch {
    WhatsNew.launch(lastSeen: seen, current: current, all: all, args: args, env: env, forceFrom: force)
  }

  func testFreshInstallRecordsTheVersionAndShowsNothing() {
    XCTAssertEqual(launch(nil), .init(news: nil, record: "0.17.0"))
  }

  func testUpgradeShowsOnceThenNever() {
    var stored: String? = "0.15.0"
    let first = launch(stored)
    XCTAssertEqual(first.news?.version, "0.17.0")
    XCTAssertEqual(first.record, "0.17.0", "recorded as soon as it shows, so quitting mid-modal never repeats it")
    stored = first.record ?? stored
    XCTAssertEqual(launch(stored), .init(news: nil, record: nil), "second launch of the same version: nothing")
  }

  func testSameVersionAndDowngradeShowNothing() {
    XCTAssertEqual(launch("0.17.0"), .init(news: nil, record: nil))
    XCTAssertEqual(launch("0.18.0"), .init(news: nil, record: nil), "a downgrade never shows old news")
  }

  func testQuietUnderTestsScreenshotsAndStoreCapture() {
    for a in [["-demo"], ["-demo", "-tab", "school"], ["-uitest"]] {
      XCTAssertEqual(launch("0.15.0", args: a), .init(news: nil, record: nil), "\(a)")
      XCTAssertEqual(launch(nil, args: a), .init(news: nil, record: nil), "\(a) leaves a fresh install's record alone")
    }
    XCTAssertEqual(launch("0.15.0", env: [WhatsNew.testEnvKey: "/tmp/x.xctestconfiguration"]), .init(news: nil, record: nil))
  }

  func testDebugForceShowsWithoutRecording() {
    let f = launch("0.17.0", args: ["-demo"], force: "0")
    XCTAssertEqual(f.news?.version, "0.17.0")
    XCTAssertNil(f.record)
  }

  func testDebugForceWinsOverQuietAndNeverRecords() {
    XCTAssertNil(launch(nil, force: "0").record, "even a fresh install isn't recorded")
    XCTAssertEqual(launch(nil, force: "0").news?.version, "0.17.0")
    XCTAssertEqual(launch("0.17.0", env: [WhatsNew.testEnvKey: "x"], force: "0").news?.version, "0.17.0", "shows under a test host")
    XCTAssertNil(launch("0.17.0", force: "0.17.0").news, "forcing from the current version: nothing newer")
  }

  // MARK: the shipped notes

  static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../../..").standardized

  /// Every bundled release note must carry Luna's news (the app shows it after updates), in its era's format.
  func testEveryReleaseNotePassesLint() throws {
    let dir = Self.root.appendingPathComponent("release-notes")
    let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil).filter { $0.pathExtension == "md" && $0.lastPathComponent != "README.md" }
    XCTAssertFalse(files.isEmpty)
    for f in files {
      let n = WhatsNew.parse(version: f.deletingPathExtension().lastPathComponent, markdown: try String(contentsOf: f, encoding: .utf8))
      XCTAssertEqual(WhatsNew.lint(n), [], f.lastPathComponent)
    }
  }

  /// The current MARKETING_VERSION has a headline and 2–4 titled cards, and a kid updating from the live
  /// App Store version (or any older one) gets exactly those.
  func testCurrentVersionHasModalNotes() throws {
    let yml = try String(contentsOf: Self.root.appendingPathComponent("project.yml"), encoding: .utf8)
    let line = try XCTUnwrap(yml.components(separatedBy: "\n").first { $0.contains("MARKETING_VERSION:") })
    let v = line.components(separatedBy: "\"").dropFirst().first ?? ""
    let md = try String(contentsOf: Self.root.appendingPathComponent("release-notes/\(v).md"), encoding: .utf8)
    let n = WhatsNew.parse(version: v, markdown: md)
    XCTAssertNotNil(n.headline, "release-notes/\(v).md needs a > headline")
    XCTAssert((2...WhatsNew.maxCards).contains(n.items.count))
    XCTAssert(n.items.allSatisfy { $0.title != nil })
    XCTAssertEqual(WhatsNew.news(lastSeen: "0.15.0", current: v, all: [n])?.items, n.items)
    XCTAssertEqual(n.badPlaces, [])
    XCTAssert(n.items.contains { $0.go != nil }, "at least one card takes the kid to the feature")
    // Kids rules: no links, no web addresses in the kid copy.
    for s in [n.headline ?? ""] + n.items.flatMap({ [$0.title ?? "", $0.text] }) {
      XCTAssertNil(s.range(of: #"https?://|www\.|\.com"#, options: .regularExpression), s)
    }
  }
}
