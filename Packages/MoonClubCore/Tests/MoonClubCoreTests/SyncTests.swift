// Sync must converge no matter the order: merge is commutative, associative and idempotent (checked
// over generated states), and the real-life cases (offline on two devices, clock skew, resets) behave.
import XCTest
@testable import MoonClubCore

/// Deterministic generator (SplitMix64) so a failing property prints a reproducible seed.
struct Gen {
  var x: UInt64
  mutating func next() -> UInt64 { x &+= 0x9E3779B97F4A7C15; var z = x; z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9; z = (z ^ (z >> 27)) &* 0x94D049BB133111EB; return z ^ (z >> 31) }
  mutating func int(_ n: Int) -> Int { Int(next() % UInt64(n)) }
  mutating func bool() -> Bool { int(2) == 1 }
  mutating func pick<T>(_ a: [T]) -> T { a[int(a.count)] }
}

final class SyncTests: XCTestCase {
  static let syms = ["AAPL", "DIS", "KO", "NKE"], days = ["2026-10-21", "2026-10-29", "2026-11-05", "2026-11-12"]
  static let lessons = ["company", "share", "profit", "save", "grow"], at = ["2026-10-01", "2026-10-15", "2026-10-30"]

  func randomState(_ g: inout Gen, epoch: Int? = nil) -> KidsState {
    var s = KidsState()
    s.resetEpoch = epoch ?? (g.int(4) == 0 ? g.pick([0, 5, 9]) : nil)
    for l in Self.lessons where g.bool() { s.lessons.append(l); s.lessonDates[l] = g.pick(Self.at) }
    s.seenBadges = ["first-guess", "lemonade", "saver"].filter { _ in g.bool() }
    s.quest = ["company", "shares", "price"].filter { _ in g.bool() }
    s.questDone = g.bool()
    for sym in Self.syms where g.bool() {
      let o: [Outcome?] = [nil, .right, .wrong]
      s.guesses.append(Guess(s: sym, d: g.pick(Self.days), pick: g.pick([.beat, .miss]), price: g.pick([nil, .up, .down]), at: g.pick(Self.at), result: g.pick(o), priceResult: g.pick(o)))
    }
    if g.bool() {
      var h: [String: Double] = [:]; for d in Self.at where g.bool() { h[d] = Double(1000 + g.int(50)) }
      s.piggy = Piggy(started: g.pick(["2026-10-01", "2026-10-15"]), holdings: [PiggyHolding(s: g.pick(Self.syms), coins: Double(100 * (1 + g.int(5))), shares: 1, start: 50)], history: h)
    }
    s.me = g.bool() ? g.int(8) : nil
    for e in [1, 3, 5] where g.bool() { s.league.append(LeaguePlayer(emoji: e, guesses: [LeagueGuess(s: g.pick(Self.syms), d: g.pick(Self.days), pick: g.pick([.beat, .miss]))])) }
    s.recapSeen = g.bool() ? g.pick(["2026-10-19", "2026-10-26"]) : nil
    return s
  }

  func testAlgebraicPropertiesOverGeneratedStates() {
    for seed in 0..<400 {
      var g = Gen(x: UInt64(seed))
      let sameEpoch = g.bool()
      let e: Int? = sameEpoch ? 0 : nil
      let a = randomState(&g, epoch: e), b = randomState(&g, epoch: e), c = randomState(&g, epoch: e)
      XCTAssertEqual(a.merged(with: b), b.merged(with: a), "commutative, seed \(seed)")
      XCTAssertEqual(a.merged(with: b).merged(with: c), a.merged(with: b.merged(with: c)), "associative, seed \(seed)")
      XCTAssertEqual(a.merged(with: a), a.normalized(), "idempotent, seed \(seed)")
      XCTAssertEqual(a.merged(with: b).merged(with: b), a.merged(with: b), "re-merge is a no-op, seed \(seed)")
    }
  }

  func testMergeWithSelfAndEmpty() {
    var g = Gen(x: 42); let a = randomState(&g, epoch: 0)
    XCTAssertEqual(a.merged(with: a), a.normalized())
    XCTAssertEqual(a.merged(with: KidsState()), a.normalized())
  }

  /// iPad and iPhone both offline: each finishes different lessons and guesses; after sync both have everything.
  func testOfflineEditsOnTwoDevices() {
    var ipad = KidsState(), phone = KidsState()
    ipad.finishLesson("company", today: "2026-10-28"); ipad.guess(Guess(s: "DIS", d: "2026-11-12", pick: .beat, at: "2026-10-28"))
    phone.finishLesson("share", today: "2026-10-29"); phone.finishLesson("company", today: "2026-10-30")
    phone.guess(Guess(s: "KO", d: "2026-10-21", pick: .miss, at: "2026-10-20")); phone.finishLemonade()
    let m = ipad.merged(with: phone)
    XCTAssertEqual(Set(m.lessons), ["company", "share"])
    XCTAssertEqual(m.lessonDates["company"], "2026-10-28", "a lesson keeps the earliest day it was finished")
    XCTAssertEqual(Set(m.guesses.map(\.s)), ["DIS", "KO"])
    XCTAssertTrue(m.questDone)
    XCTAssertEqual(m, phone.merged(with: ipad))
  }

  /// Points come from the merged progress, never from adding the two devices' points.
  func testPointsAreRecomputedNotSummed() {
    var a = KidsState(); a.finishLesson("company", today: "2026-10-28")
    let b = a
    XCTAssertEqual(a.merged(with: b).lessons, ["company"])
  }

  /// A device with a wrong clock can't make the devices disagree: they still converge on one answer.
  func testClockSkewStillConverges() {
    let early = Guess(s: "DIS", d: "2026-11-12", pick: .beat, at: "2026-10-28")
    let skewed = Guess(s: "DIS", d: "2026-11-12", pick: .miss, at: "2027-03-01") // this device's clock is months ahead
    var a = KidsState(), b = KidsState(); a.guess(early); b.guess(skewed)
    XCTAssertEqual(a.merged(with: b), b.merged(with: a))
    XCTAssertEqual(a.merged(with: b).guesses.first?.pick, .miss, "later edit by its own clock wins, the same way everywhere")
    // …but a resolved guess beats an unresolved one whatever the clocks say.
    var resolved = early; resolved.result = .right
    var c = KidsState(); c.guess(resolved)
    XCTAssertEqual(c.merged(with: b).guesses.first?.result, .right)
  }

  func testResultsFillInFromEitherDevice() {
    let g = Guess(s: "AAPL", d: "2026-10-29", pick: .beat, at: "2026-10-27")
    var a = KidsState(), b = KidsState(); a.guess(g); b.guess(g); b.resolve(s: "AAPL", d: "2026-10-29", result: .right, priceResult: nil)
    XCTAssertEqual(a.merged(with: b).guesses.first?.result, .right)
  }

  func testResetEverywhereWinsOverOlderData() {
    var old = KidsState(); old.finishLesson("company", today: "2026-10-28"); old.finishLemonade()
    let reset = KidsState.resetEverywhere(from: old, nowMillis: 1_790_000_000_000)
    XCTAssertTrue(reset.merged(with: old).lessons.isEmpty, "a device that hasn't heard about the reset can't bring progress back")
    XCTAssertFalse(old.merged(with: reset).questDone)
    // New progress after the reset syncs normally.
    var after = reset; after.finishLesson("share", today: "2026-11-02")
    XCTAssertEqual(after.merged(with: reset).merged(with: old).lessons, ["share"])
    // A second reset beats the first even if the clock went backwards.
    let again = KidsState.resetEverywhere(from: after, nowMillis: 5)
    XCTAssertGreaterThan(again.epoch, after.epoch)
  }

  /// "This device only" keeps the epoch, so it doesn't propagate (the app turns sync off for that device).
  func testDeviceOnlyResetDoesNotPropagate() {
    var a = KidsState(); a.finishLesson("company", today: "2026-10-28")
    var local = KidsState(); local.resetEpoch = a.resetEpoch
    XCTAssertEqual(local.merged(with: a).lessons, ["company"], "merging would bring it back, which is why sync turns off with it")
  }

  func testPiggyLaterStartReplacesOldPiggy() {
    var a = KidsState(), b = KidsState()
    a.startPiggy([PiggyHolding(s: "DIS", coins: 1000, shares: 10, start: 100)], today: "2026-10-01", value: 1000)
    a.recordValue(today: "2026-10-02", value: 1010)
    b.startPiggy([PiggyHolding(s: "KO", coins: 1000, shares: 16, start: 60)], today: "2026-10-15", value: 1000)
    let m = a.merged(with: b)
    XCTAssertEqual(m.piggy?.started, "2026-10-15"); XCTAssertEqual(m.piggy?.holdings.first?.s, "KO"); XCTAssertNil(m.piggy?.history["2026-10-02"])
    var c = a; c.recordValue(today: "2026-10-03", value: 1020)
    XCTAssertEqual(Set(a.merged(with: c).piggy!.history.keys), ["2026-10-01", "2026-10-02", "2026-10-03"])
  }

  func testLeagueUnionAndMeNeverListedTwice() {
    var a = KidsState(), b = KidsState()
    a.addPlayer(LeaguePlayer(emoji: 3, guesses: [LeagueGuess(s: "DIS", d: "2026-11-12", pick: .beat)]))
    b.addPlayer(LeaguePlayer(emoji: 3, guesses: [LeagueGuess(s: "KO", d: "2026-10-21", pick: .miss)]))
    b.setMe(5); a.addPlayer(LeaguePlayer(emoji: 5, guesses: []))
    let m = a.merged(with: b)
    XCTAssertEqual(m.leaguePlayers.map(\.emoji), [3])
    XCTAssertEqual(m.leaguePlayers.first?.guesses.count, 2)
    XCTAssertEqual(m.me, 5)
  }

  func testOlderSavesWithoutEpochStillDecode() throws {
    let old = #"{"schema":1,"guesses":[],"lessons":["company"],"lessonDates":{"company":"2026-10-28"},"seenBadges":[],"league":[],"quest":[],"questDone":false}"#
    let s = try JSONDecoder().decode(KidsState.self, from: Data(old.utf8))
    XCTAssertEqual(s.lessons, ["company"]); XCTAssertEqual(s.epoch, 0)
  }

  func testPayloadStaysSmallAndDropsDeviceOnlyFields() {
    var s = KidsState(); s.recapSeen = "2026-10-26"
    for i in 0..<2000 { s.guesses.append(Guess(s: "DIS", d: String(format: "2026-%02d-%02d", 1 + i % 12, 1 + i % 28) + "-\(i)", pick: .beat, price: .up, at: "2026-10-01", result: .right, priceResult: .wrong)) }
    let d = Sync.payload(s)
    XCTAssertLessThan(d.count, Sync.maxPayloadBytes)
    let back = try! XCTUnwrap(Sync.decode(d))
    XCTAssertNil(back.recapSeen)
    XCTAssertLessThanOrEqual(back.guesses.count, Sync.maxSyncedGuesses)
    XCTAssertEqual(back.guesses.last?.d, s.guesses.map(\.d).max(), "the newest guesses are the ones kept")
  }
}
