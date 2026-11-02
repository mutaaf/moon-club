import Foundation
import MoonClubCore

// Fakes for SwiftUI previews, UI tests and demo mode (launch argument `-demo`): deterministic, offline.

struct FakeMarket: MarketDataSource {
  let today: String
  func calendar(from: String, to: String) async throws -> [EarningsEvent] {
    let plan: [(String, Int, Session, Double?, Double?)] = [
      ("AAPL", -2, .amc, 2.02, 2.10), ("NKE", -3, .amc, 0.52, 0.48), ("DIS", 3, .bmo, 1.70, nil), ("MCD", 4, .bmo, 3.42, nil),
      ("TTWO", 6, .amc, 0.96, nil), ("TGT", 8, .bmo, 2.07, nil), ("WMT", 9, .bmo, 0.64, nil), ("RBLX", 11, .bmo, -0.42, nil),
    ]
    return plan.map { EarningsEvent(s: $0.0, d: Day.add(today, $0.1), h: $0.2, eE: $0.3, eA: $0.4) }.filter { $0.d >= from && $0.d <= to }
  }
  func mood() async throws -> Double? { 40 }
  func quotes(_ symbols: [String]) async throws -> [String: Double] {
    Dictionary(uniqueKeysWithValues: symbols.enumerated().map { ($1, 100 * (1 + Double($0 % 3) * 0.012)) })
  }
  func lastMove(_ symbol: String) async throws -> TickerPayload {
    try JSONDecoder().decode(TickerPayload.self, from: Data(#"{"history":[{"date":"2026-07-30","move":4.8}]}"#.utf8))
  }
}

/// A scripted brain per kind (demo mode still routes through the real LunaRouter + guard).
struct FakeBrain: LunaBrain {
  let kind: BrainKind
  func stream(_ p: LunaPrompt) -> AsyncThrowingStream<String, Error> {
    let line = kind == .byok
      ? "Great question! A **share** is a tiny slice of a company, like one slice of a giant pizza. 🍕 If a company is cut into 100 slices and you own 1, you own a small piece of it. When the company does well, each slice can be worth more. Here it's all pretend practice money!"
      : "A **share** is a tiny slice of a company, like one slice of a pizza. If you own a share, you own a small piece of it! 🍕"
    return AsyncThrowingStream { c in
      Task {
        for w in line.split(separator: " ") { c.yield(w + " "); try? await Task.sleep(for: .milliseconds(25)) }
        c.finish()
      }
    }
  }
}
struct FakeVoice: VoiceService { func speak(_ source: SpeakSource) async {}; func stop() async {} }
final class MemoryStore: ProgressStore, @unchecked Sendable {
  var s: KidsState
  init(_ s: KidsState = KidsState()) { self.s = s }
  func load() -> KidsState { s }
  func save(_ x: KidsState) { s = x }
}

enum Demo {
  /// A lived-in week for screenshots: a few guesses, a lesson, a piggy bank, a League sibling.
  static func seeded(today: String) -> KidsState {
    var s = KidsState()
    s.guess(Guess(s: "AAPL", d: Day.add(today, -2), pick: .beat, price: .up, at: Day.add(today, -4), result: .right))
    s.guess(Guess(s: "DIS", d: Day.add(today, 3), pick: .miss, at: Day.add(today, -1)))
    s.finishLesson("money", today: Day.add(today, -2)); s.finishLesson("earn", today: Day.add(today, -1))
    s.startPiggy([PiggyHolding(s: "DIS", coins: 400, shares: 4, start: 100), PiggyHolding(s: "RBLX", coins: 300, shares: 3, start: 100), PiggyHolding(s: "HSY", coins: 300, shares: 3, start: 100)], today: Day.add(today, -6), value: 1000)
    s.recordValue(today: Day.add(today, -3), value: 1006); s.recordValue(today: Day.add(today, -1), value: 1011)
    for st in ["company", "shares", "price", "report"] { s.questStage(st) }
    s.finishLemonade()
    s.seenBadges = ["lemonade", "first-guess", "good-guess", "first-lesson", "piggy"]
    s.setMe(1); s.addPlayer(LeaguePlayer(emoji: 4, guesses: [LeagueGuess(s: "AAPL", d: Day.add(today, -2), pick: .miss), LeagueGuess(s: "DIS", d: Day.add(today, 3), pick: .beat)]))
    return s
  }
}
