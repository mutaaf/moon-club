import SwiftUI
import MoonClubCore

/// Everything the app talks to, behind protocols. Live in the app; fakes in previews, tests and demo mode.
struct Services {
  var market: MarketDataSource
  var luna: LunaService
  var voice: VoiceService
  var store: ProgressStore
  var clock: Clock
  /// Cross-device progress (iCloud, opt-in). Defaults to none so tests and previews need no change.
  var sync: SyncService = NoSync()
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
  let sync: SyncService
  /// Mirrors `sync.isOn` / `sync.lastSynced` so SwiftUI updates when they change.
  private(set) var syncOn = false
  private(set) var lastSynced: Date?

  // Market data the screens share (loaded once, cached by the service layer).
  var events: [EarningsEvent] = []
  var mood: Double?
  var marketError: KidError?
  var loadingMarket = false
  /// Which Luna brain answers right now (the grown-up corner can change it; refreshed on the way out).
  private(set) var brain: BrainKind = .free
  var brainCaps: BrainCapabilities { .of(brain) }
  /// A lesson to open from a widget or Live Activity deep link (Moon School consumes it).
  var pendingLesson: String?
  /// Market World charts: a year of real daily candles, bundled (works offline, deterministic in demo
  /// mode) and refreshed from /api/kids/candles when the live app has a connection.
  var candles: [String: CandleSeries] = AppModel.bundledCandles
  static let bundledCandles: [String: CandleSeries] = {
    guard let url = Bundle.main.url(forResource: "candles", withExtension: "json"),
          let d = try? Data(contentsOf: url), let b = try? JSONDecoder().decode(CandleBundle.self, from: d) else { return [:] }
    return Dictionary(b.all.map { ($0.s, $0) }, uniquingKeysWith: { a, _ in a })
  }()
  /// Set by the composition root for the live app only.
  var candleLoader: (@Sendable () async -> CandleBundle?)?
  func refreshCandles() async {
    guard let b = await candleLoader?() else { return }
    for s in b.all where s.candles.count >= 60 { candles[s.s] = s }
  }

  init(content: KidsContent, services s: Services) {
    self.content = content
    market = s.market; luna = s.luna; voice = s.voice; store = s.store; clock = s.clock; sync = s.sync
    state = s.store.load()
    brain = s.luna.activeBrain()
    syncOn = sync.isOn; lastSynced = sync.lastSynced
    sync.observe { [weak self] remote in self?.absorb(remote) }
    if sync.isOn { syncNow() }
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
    commit(s, push: true)
  }

  /// The one place state is replaced: save locally, tell iCloud (if on), refresh anything derived.
  private func commit(_ s: KidsState, push: Bool) {
    state = s
    store.save(s)
    if push, sync.isOn { sync.push(s) }
    stateDidChange()
  }

  /// Hook for things outside the app that mirror progress. Widgets: republish the shared snapshot here
  /// (after local edits AND after merges from other devices).
  private func stateDidChange() { WidgetPublisher.publish(self) }

  // MARK: Sync (iCloud, opt-in behind the grown-up gate)
  /// Another device changed the synced copy: merge it in (merge is order-independent, so this is safe
  /// however often it runs) and push back only if our side added something.
  private func absorb(_ remote: KidsState) {
    let merged = state.merged(with: remote)
    lastSynced = sync.lastSynced
    if merged != state { commit(merged, push: merged != remote.normalized()) }
  }

  /// Pull, merge, push. Turning sync on never loses progress on either side.
  func syncNow() {
    guard sync.isOn else { return }
    let merged = sync.pull().map { state.merged(with: $0) } ?? state.normalized()
    if merged != state { commit(merged, push: false) }
    sync.push(merged)
    lastSynced = sync.lastSynced ?? Date()
  }

  func setSync(_ on: Bool) {
    sync.isOn = on && sync.isAvailable
    syncOn = sync.isOn
    if syncOn { syncNow() }
  }

  enum ResetScope { case thisDevice, everywhere }
  /// "This device only" also turns sync off here; otherwise the next sync would bring the progress back.
  /// "All devices" bumps the reset epoch, which beats every older copy (see MoonClubCore/Sync.swift).
  func resetProgress(_ scope: ResetScope) {
    switch scope {
    case .everywhere:
      commit(KidsState.resetEverywhere(from: state, nowMillis: Int(Date().timeIntervalSince1970 * 1000)), push: true)
    case .thisDevice:
      setSync(false)
      var fresh = KidsState(); fresh.resetEpoch = state.resetEpoch
      commit(fresh, push: false)
    }
  }

  /// "Move my progress" from the website: decode the pasted code and merge it in. Safe to repeat.
  func importProgress(_ text: String) -> Result<Int, Transfer.Failure> {
    switch Transfer.decode(text, companies: content.companies) {
    case .failure(let f): return .failure(f)
    case .success(let incoming):
      let before = state.lessons.count + state.guesses.count + state.quest.count
      let merged = state.merged(with: incoming)
      commit(merged, push: true)
      return .success(merged.lessons.count + merged.guesses.count + merged.quest.count - before)
    }
  }

  /// Widgets can change progress while the app sleeps (a guess, "I read it"): pick that up on return.
  func reloadFromStore() {
    let s = store.load()
    if s != state { commit(s, push: true) } else { WidgetPublisher.publish(self) } // a widget guess syncs like any other
  }

  /// moonclub://tab/<name> and moonclub://lesson/<id> (widgets, Live Activities). In-app only.
  func open(_ url: URL) -> Tab? {
    guard url.scheme == MoonLink.scheme else { return nil }
    switch url.host {
    case "tab": return Tab(rawValue: url.lastPathComponent)
    case "lesson": pendingLesson = url.lastPathComponent; return .school
    default: return nil
    }
  }

  func loadMarket() async {
    guard !loadingMarket else { return }
    loadingMarket = true; defer { loadingMarket = false }
    async let cal = market.calendar(from: Day.add(today, -30), to: Day.add(today, 21))
    async let m = market.mood()
    do { events = try await cal; marketError = nil } catch { marketError = (error as? KidError) ?? .offline }
    mood = try? await m
    WidgetPublisher.publish(self)
  }
}
