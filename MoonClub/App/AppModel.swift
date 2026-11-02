import SwiftUI
import MoonClubCore

/// Everything the app talks to, behind protocols. Live in the app; fakes in previews, tests and demo mode.
struct Services {
  var market: MarketDataSource
  var luna: LunaService
  var voice: VoiceService
  var store: ProgressStore
  var clock: Clock
}

/// The single app-wide model (the composition root owns exactly one). Views read derived values and
/// send intents; intents run the pure reducers in MoonClubCore and persist atomically.
@MainActor @Observable
final class AppModel {
  let content: KidsContent
  private(set) var state: KidsState
  let market: MarketDataSource
  let luna: LunaService
  let voice: VoiceService
  private let store: ProgressStore
  private let clock: Clock

  // Market data the screens share (loaded once, cached by the service layer).
  var events: [EarningsEvent] = []
  var mood: Double?
  var marketError: KidError?
  var loadingMarket = false
  /// Which Luna brain answers right now (the grown-up corner can change it; refreshed on the way out).
  private(set) var brain: BrainKind = .free
  var brainCaps: BrainCapabilities { .of(brain) }

  init(content: KidsContent, services s: Services) {
    self.content = content
    market = s.market; luna = s.luna; voice = s.voice; store = s.store; clock = s.clock
    state = s.store.load()
    brain = s.luna.activeBrain()
  }

  func refreshBrain() { let b = luna.activeBrain(); if b != brain { brain = b } }

  var today: String { clock.today() }
  var companies: [String: KidCo] { content.companyBySymbol }

  // MARK: Derived
  var points: Int { state.points(content) }
  var level: LevelInfo { state.level(content) }
  var freshBadges: [Badge] { state.freshBadges(content).compactMap { id in content.badges.first { $0.id == id } } }
  var badges: Set<String> { Set(state.badges(content)) }
  var recap: Recap? { state.recap(content, today: today) }
  var kidEvents: [EarningsEvent] { events.filter { companies[$0.s] != nil } }
  var upcoming: [EarningsEvent] { kidEvents.filter { $0.d >= today }.sorted { ($0.d, $0.s) < ($1.d, $1.s) } }
  var chaptersDone: [String] { state.chapters(content) }

  // MARK: Intents
  func mutate(_ f: (inout KidsState) -> Void) {
    var s = state; f(&s)
    guard s != state else { return }
    state = s
    store.save(s)
  }

  func loadMarket() async {
    guard !loadingMarket else { return }
    loadingMarket = true; defer { loadingMarket = false }
    async let cal = market.calendar(from: Day.add(today, -30), to: Day.add(today, 21))
    async let m = market.mood()
    do { events = try await cal; marketError = nil } catch { marketError = (error as? KidError) ?? .offline }
    mood = try? await m
  }
}
