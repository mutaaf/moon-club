// The URL router: every route, both URL forms, and malformed input that must land safely on Home.
import XCTest
@testable import MoonClubCore

final class DeepLinkTests: XCTestCase {
  lazy var content: KidsContent = {
    let url = Bundle.module.url(forResource: "kids-content", withExtension: "json")!
    return try! KidsContent.load(Data(contentsOf: url))
  }()

  func p(_ s: String) -> DeepLink { DeepLink.parse(URL(string: s)!) }

  func testEveryRouteOnTheWeb() {
    let w = "https://mutaafaziz.com/metaphases/kids"
    XCTAssertEqual(p(w), .home)
    XCTAssertEqual(p(w + "/"), .home)
    XCTAssertEqual(p(w + "/school"), .world)
    XCTAssertEqual(p(w + "/school/"), .world)
    XCTAssertEqual(p(w + "/school/money"), .lesson("money"))
    XCTAssertEqual(p(w + "/school/tug-of-war?ref=share"), .lesson("tug-of-war"))
    XCTAssertEqual(p(w + "/guess"), .guess)
    XCTAssertEqual(p(w + "/gamenight"), .gameNight)
    XCTAssertEqual(p(w + "/piggy"), .piggy)
    XCTAssertEqual(p(w + "/garden"), .garden)
    XCTAssertEqual(p(w + "/ask"), .luna)
    XCTAssertEqual(p(w + "/league/MOON-1A2B-C3D4"), .league("MOON-1A2B-C3D4"))
    XCTAssertEqual(p(w + "/league/moon-1a2b-c3d4"), .league("MOON-1A2B-C3D4"))
    XCTAssertEqual(p(w + "/pack/guest-coach-nova"), .pack("guest-coach-nova"))
    XCTAssertEqual(p("https://www.mutaafaziz.com/metaphases/kids/guess"), .guess)
    XCTAssertEqual(p("https://MUTAAFAZIZ.COM/metaphases/kids/piggy"), .piggy)
  }

  func testEveryRouteOnTheScheme() {
    XCTAssertEqual(p("moonclub://home"), .home)
    XCTAssertEqual(p("moonclub://"), .home)
    XCTAssertEqual(p("moonclub://school"), .world)
    XCTAssertEqual(p("moonclub://world"), .world)
    XCTAssertEqual(p("moonclub://school/money"), .lesson("money"))
    XCTAssertEqual(p("moonclub://lesson/money"), .lesson("money"))
    XCTAssertEqual(p("moonclub://guess"), .guess)
    XCTAssertEqual(p("moonclub://gamenight"), .gameNight)
    XCTAssertEqual(p("moonclub://piggy"), .piggy)
    XCTAssertEqual(p("moonclub://garden"), .garden)
    XCTAssertEqual(p("moonclub://ask"), .luna)
    XCTAssertEqual(p("moonclub://league/MOON-1A2B-C3D4"), .league("MOON-1A2B-C3D4"))
    XCTAssertEqual(p("moonclub://pack/guest-coach-nova"), .pack("guest-coach-nova"))
  }

  /// Widgets and Live Activities have shipped moonclub://tab/<name> and moonclub://lesson/<id> since 0.7.
  func testWidgetLinksStillWork() {
    XCTAssertEqual(p("moonclub://tab/story"), .home)
    XCTAssertEqual(p("moonclub://tab/guess"), .guess)
    XCTAssertEqual(p("moonclub://tab/piggy"), .piggy)
    XCTAssertEqual(p("moonclub://tab/school"), .world)
    XCTAssertEqual(p("moonclub://tab/luna"), .luna)
    XCTAssertEqual(p("moonclub://tab/nope"), .home)
  }

  func testMalformedLinksLandOnHome() {
    for s in [
      "https://evil.com/metaphases/kids/guess",
      "https://mutaafaziz.com.evil.com/metaphases/kids/guess",
      "http://mutaafaziz.com/metaphases/kids/guess",
      "https://mutaafaziz.com/metaphases/guess",
      "https://mutaafaziz.com/metaphases/kidsx/guess",
      "https://mutaafaziz.com/",
      "https://user:pw@mutaafaziz.com/metaphases/kids/guess",
      "https://mutaafaziz.com:8443/metaphases/kids/guess",
      "https://mutaafaziz.com/metaphases/kids/grownups",
      "https://mutaafaziz.com/metaphases/kids/privacy",
      "https://mutaafaziz.com/metaphases/kids/school/money/print",
      "https://mutaafaziz.com/metaphases/kids/school/Money",
      "https://mutaafaziz.com/metaphases/kids/school/-x",
      "https://mutaafaziz.com/metaphases/kids/school/%F0%9F%8C%99",
      "https://mutaafaziz.com/metaphases/kids/school/" + String(repeating: "a", count: 49),
      "https://mutaafaziz.com/metaphases/kids/league/short",
      "https://mutaafaziz.com/metaphases/kids/league/MOON_1A2B_C3D4",
      "https://mutaafaziz.com/metaphases/kids/league",
      "https://mutaafaziz.com/metaphases/kids/pack",
      "https://mutaafaziz.com/metaphases/kids/pack/Nova!",
      "https://mutaafaziz.com/metaphases/kids/guess/extra",
      "https://mutaafaziz.com/metaphases/kids/" + String(repeating: "x/", count: 300),
      "moonclub://grownups",
      "moonclub://settings/reset",
      "moonclub://lesson",
      "moonclub://lesson/a/b",
      "javascript:alert(1)",
      "file:///etc/passwd",
      "mailto:a@b.co",
      "otherapp://guess",
    ] {
      XCTAssertEqual(URL(string: s).map(DeepLink.parse), .home, s)
    }
  }

  func testResolveChecksThisBuildsContent() {
    let r = { (s: String) in DeepLink.resolve(URL(string: s)!, in: self.content) }
    XCTAssertEqual(r("moonclub://school/money"), .lesson("money"))
    XCTAssertEqual(r("moonclub://school/no-such-lesson"), .world, "a lesson this build doesn't have opens the map")
    XCTAssertEqual(r("moonclub://pack/no-such-pack"), .home, "only bundled packs; the remote channel stays off")
    XCTAssertEqual(r("moonclub://league/MOON-1A2B-C3D4"), .home, "a code that doesn't decode goes home")
    let pack = try! XCTUnwrap(content.bundledPacks.first)
    XCTAssertEqual(r("moonclub://pack/\(pack.id)"), .pack(pack.id))
    let code = League.encode(LeaguePlayer(emoji: 2, guesses: [LeagueGuess(s: content.companies[0].s, d: "2026-11-02", pick: .beat, price: .up)]), companies: content.companies)
    XCTAssertEqual(r(DeepLink.web + "/league/" + code), .league(code))
    XCTAssertEqual(r("https://mutaafaziz.com/metaphases/kids/garden"), .garden)
  }

  func testOnlySettingsWaitForTheGate() {
    let all: [DeepLink] = [.home, .world, .lesson("money"), .guess, .gameNight, .piggy, .garden, .luna, .league("MOON-1A2B-C3D4"), .pack("x")]
    XCTAssertEqual(all.filter(\.needsGrownUp), [.league("MOON-1A2B-C3D4"), .pack("x")])
  }

  func testShareURLsRoundTrip() {
    let all: [DeepLink] = [.home, .world, .lesson("money"), .guess, .gameNight, .piggy, .garden, .luna, .league("MOON-1A2B-C3D4"), .pack("guest-coach-nova")]
    for l in all {
      XCTAssertEqual(DeepLink.parse(l.webURL()), l, "\(l) web")
      XCTAssertEqual(DeepLink.parse(l.webURL(ref: Campaign.share)), l, "\(l) web+ref")
      XCTAssertEqual(DeepLink.parse(l.appURL), l, "\(l) scheme")
    }
    XCTAssertEqual(DeepLink.lesson("money").webURL(ref: "share").absoluteString, "https://mutaafaziz.com/metaphases/kids/school/money?ref=share")
    XCTAssertEqual(DeepLink.guess.webURL(ref: "Not A Slug").absoluteString, "https://mutaafaziz.com/metaphases/kids/guess", "bad refs are dropped")
    XCTAssertEqual(Campaign.pack("guest-coach-nova"), "pack-guest-coach-nova")
    XCTAssertTrue(Campaign.isSlug(Campaign.pack(String(repeating: "a", count: 48))))
    XCTAssertFalse(Campaign.isSlug(""))
    XCTAssertFalse(Campaign.isSlug("kid@example.com"))
  }

  func testPartnerSlotShipsEmptyAndOnlyDrawsSafeLinks() {
    XCTAssertTrue(Partners.list.isEmpty, "affiliate partners are the owner's call (docs/LINKS.md)")
    XCTAssertTrue(Partners.disclosure.contains("we may earn a fee"))
    let ok = Partner(id: "book", title: "A picture book about saving", blurb: "A bedtime story about a jar and a goal.", url: "https://example.com/book?tag=moonclub-20")
    XCTAssertTrue(Partners.valid(ok))
    XCTAssertFalse(Partners.valid(Partner(id: "a", title: "x", blurb: "y", url: "http://example.com")))
    XCTAssertFalse(Partners.valid(Partner(id: "a", title: "x", blurb: "y", url: "moonclub://guess")))
    XCTAssertFalse(Partners.valid(Partner(id: "a", title: "Get rich", blurb: "y", url: "https://example.com")))
    XCTAssertFalse(Partners.valid(Partner(id: "a", title: "x", blurb: "see www.x.com", url: "https://example.com")))
  }
}
