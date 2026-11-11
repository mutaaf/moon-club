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
  /// The curriculum a kid sees: Core plus the lesson packs a grown-up turned on (see `setPack`).
  private(set) var content: KidsContent
  /// Core, as it shipped (packs compose on top of it).
  let baseContent: KidsContent
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
  /// Moon School (the lesson list) to open on the World map, from a What's-new card (`NewsPlace.moonSchool`).
  var pendingMoonSchool = false
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
    baseContent = content
    self.content = content.with(packs: content.bundledPacks.filter { PackPrefs.enabled.contains($0.id) })
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
  /// Never traps: a symbol from synced/league/transferred state may not be in this build's content.
  func company(_ s: String) -> KidCo { companies[s] ?? KidCo(s: s, nick: s, hook: "", emoji: "🏢") }

  // MARK: Derived
  /// Everything expensive that is derived from `state`, computed once per state change (not once per view
  /// per render: before 0.13 each body re-walked the map, every trophy and the garden on its own).
  /// Reading it still reads `state`, so views stay observed exactly as before.
  struct Derived {
    let points: Int, level: LevelInfo, wallet: Int, trophies: [TrophyProgress], earnedCount: Int, garden: GardenBook
  }
  @ObservationIgnored private var memo: (version: Int, value: Derived)?
  @ObservationIgnored private var version = 0
  var derived: Derived {
    _ = state  // register observation of state
    if let m = memo, m.version == version { return m.value }
    let book = state.gardenBook
    let pts = state.points(content)
    let d = Derived(points: pts, level: levelFor(pts, levels: Ranks.levels(content)),
                    wallet: Garden.balance(earned: pts, gains: book.gains, spent: Shop.spent(state), planted: book.principal),
                    trophies: Trophies.progress(state, content), earnedCount: Trophies.earnedCount(state, content), garden: book)
    memo = (version, d)
    return d
  }
  var points: Int { derived.points }
  var level: LevelInfo { derived.level }
  var freshBadges: [Badge] { state.freshBadges(content).compactMap { id in content.badges.first { $0.id == id } } }
  // Points that matter (0.11): see MoonClubCore/Rewards.swift.
  /// Moon points left to spend (earned minus the Moon Shop).
  var wallet: Int { derived.wallet }
  var trophies: [TrophyProgress] { derived.trophies }
  var earnedCount: Int { derived.earnedCount }
  var nextRankName: String? { let ls = Ranks.levels(content), i = level.index + 1; return i < ls.count ? ls[i].name : nil }
  /// Web badges, then trophy tiers, not celebrated yet.
  var freshRewards: [RewardNews] { freshBadges.map(RewardNews.badge) + Trophies.fresh(state, content).map { RewardNews.trophy($0.0, $0.1) } }
  /// A rank reached whose ceremony hasn't played (the first rank, New Moon, has none).
  var pendingRank: Int? { let i = level.index; return i > 0 && i > (state.rankSeen ?? 0) ? i : nil }
  var lunaLook: LunaLook { LunaLook(hat: Shop.equipped(.hat, state), frame: Shop.equipped(.frame, state)) }
  var themeHex: UInt32 { let h = Shop.equipped(.theme, state)?.color ?? 0x2346D8; ThemeColor.hex = h; return h }
  /// The app came to the front today: the visit counts for the streak and the daily bonus.
  func checkIn() { mutate { $0.checkIn(today: today) } }
  var badges: Set<String> { Set(state.badges(content)) }
  var recap: Recap? { state.recap(content, today: today) }
  var kidEvents: [EarningsEvent] { let cos = companies; return events.filter { cos[$0.s] != nil } }   // one table, not one per event
  var upcoming: [EarningsEvent] { kidEvents.filter { $0.d >= today }.sorted { ($0.d, $0.s) < ($1.d, $1.s) } }
  var chaptersDone: [String] { state.chapters(content) }

  // MARK: Lesson packs (grown-up corner, behind the gate). Device-only setting; Core is always on.
  var packs: [LessonPack] { baseContent.bundledPacks }
  func packOn(_ id: String) -> Bool { content.activePacks.contains(id) }
  func setPack(_ id: String, on: Bool) {
    var ids = PackPrefs.enabled
    if on { ids.insert(id) } else { ids.remove(id) }
    PackPrefs.enabled = ids
    content = baseContent.with(packs: baseContent.bundledPacks.filter { ids.contains($0.id) })
  }

  // MARK: Spaced review (MoonClubCore Review.swift): only misses and Review-stop answers, kept on this device.
  func answered(lesson: String, step: Int, right: Bool, review: Bool) {
    let retire = Review.config(content).retireAt
    mutate { $0.answer(Review.itemId(lesson, step), right: right, today: today, review: review, retireAt: retire) }
  }

  /// How many times the Piggy Bank was opened today (a count on this device only; feeds "don't peek every minute").
  func peekPiggy() -> Int {
    let d = UserDefaults.standard, key = "moonclub.piggy.peeks"
    let parts = (d.string(forKey: key) ?? "").split(separator: "|")
    let n = (parts.count == 2 && parts[0] == Substring(today) ? Int(parts[1]) ?? 0 : 0) + 1
    d.set("\(today)|\(n)", forKey: key)
    return n
  }

  // MARK: Intents
  func mutate(_ f: (inout KidsState) -> Void) {
    var s = state; f(&s)
    guard s != state else { return }
    commit(s, push: true)
  }

  /// The one place state is replaced: save locally, tell iCloud (if on), refresh anything derived.
  private func commit(_ s: KidsState, push: Bool) {
    version &+= 1
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

  /// Game Night to open from a deep link (GuessView consumes it).
  var pendingGameNight = false

  /// A link from outside the app: a universal link (mutaafaziz.com/metaphases/kids/…) or moonclub:// (widgets,
  /// Live Activities). Resolves it against this build's content (MoonClubCore `DeepLink`: unknown or malformed
  /// links are `.home`), sets what the screens consume, and returns it for RootView to pick the tab. Links that
  /// change settings (`needsGrownUp`) set nothing here: RootView shows the parental gate first.
  func open(_ url: URL) -> DeepLink {
    let l = DeepLink.resolve(url, in: content)
    switch l {
    case .lesson(let id): pendingLesson = id
    case .gameNight: pendingGameNight = true
    case .piggy: UserDefaults.standard.set(PiggySide.coins.rawValue, forKey: PiggySide.key)
    case .garden: UserDefaults.standard.set(PiggySide.garden.rawValue, forKey: PiggySide.key)
    default: break
    }
    return l
  }

  /// A What's-new card's place: sets up what the place needs (a lesson, Game Night, the Piggy side, Moon School)
  /// and returns the tab it lives on. Kid places only (`NewsPlace` refuses grown-up links).
  func open(_ place: NewsPlace) -> Tab? {
    switch place {
    case .moonSchool: pendingMoonSchool = true; return .school
    case .link(let l): return Tab(link: open(l.appURL))
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

/// Which optional lesson packs a grown-up turned on, on this device (UserDefaults; nothing about the child).
enum PackPrefs {
  static let key = "moonclub.packs.v1"
  static var enabled: Set<String> {
    get { Set(UserDefaults.standard.stringArray(forKey: key) ?? []) }
    set { UserDefaults.standard.set(newValue.sorted(), forKey: key) }
  }
}
