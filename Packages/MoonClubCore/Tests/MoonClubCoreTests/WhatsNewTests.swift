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

  func testParsesOnlyLunasNews() {
    let n = WhatsNew.parse(version: "0.7.0", markdown: md)
    XCTAssertEqual(n.title, "Moon Club 0.7.0: \"Bat-Signal\"")
    XCTAssertEqual(n.items, [.init(symbol: "rectangle.stack", text: "I live on your Home Screen now!"), .init(symbol: "lock.fill", text: "Peek at me on the Lock Screen.")])
  }

  func testSemverOrder() {
    XCTAssertTrue(WhatsNew.less("0.9.0", "0.10.0"))
    XCTAssertFalse(WhatsNew.less("0.10.0", "0.9.0"))
    XCTAssertFalse(WhatsNew.less("1.0", "1.0.0"))
  }

  func news(_ v: String, _ n: Int) -> ReleaseNews { .init(version: v, title: v, items: (0..<n).map { .init(symbol: "star", text: "\(v)-\($0)") }) }

  func testPendingRules() {
    let all = [news("0.5.0", 2), news("0.6.0", 2), news("0.7.0", 3), news("0.8.0", 1)]
    XCTAssertEqual(WhatsNew.pending(lastSeen: nil, current: "0.7.0", all: all), [], "fresh install sees nothing")
    XCTAssertEqual(WhatsNew.pending(lastSeen: "0.7.0", current: "0.7.0", all: all), [], "already seen")
    let p = WhatsNew.pending(lastSeen: "0.5.0", current: "0.7.0", all: all)
    XCTAssertEqual(p.map(\.version), ["0.7.0", "0.6.0"], "newest first, nothing from the future")
    XCTAssertEqual(p.flatMap(\.items).count, WhatsNew.maxCards, "capped at maxCards lines")
    XCTAssertEqual(p.last?.items.count, 2)
  }

  /// Every bundled release note must carry 1–4 Luna's news lines (the app shows them after updates).
  func testEveryReleaseNoteHasLunasNews() throws {
    let dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../../../release-notes").standardized
    let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil).filter { $0.pathExtension == "md" && $0.lastPathComponent != "README.md" }
    XCTAssertFalse(files.isEmpty)
    for f in files {
      let n = WhatsNew.parse(version: f.deletingPathExtension().lastPathComponent, markdown: try String(contentsOf: f, encoding: .utf8))
      XCTAssert((1...4).contains(n.items.count), "\(f.lastPathComponent): Luna's news needs 1–4 lines")
      for i in n.items { XCTAssertLessThanOrEqual(i.text.count, 90, "\(f.lastPathComponent): keep each line short — \(i.text)") }
    }
  }
}
