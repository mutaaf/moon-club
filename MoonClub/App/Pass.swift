import SwiftUI
import StoreKit
import MoonClubCore

/// Moon Club Pass (0.20) on this device: the yearly subscription (StoreKit 2, no server, no account) and today's
/// new-level ledger. The rules are pure in MoonClubCore `Pass.swift` (`PlayPlan`); this only stores and asks.
/// Buying happens only in the grown-up corner, behind the gate (`PassOffer` in GrownUps.swift).
@MainActor @Observable
final class PassModel {
  /// The pass is on (a verified, unrevoked, unexpired transaction). Cached so it's right offline at launch.
  private(set) var active: Bool
  private(set) var ledger: PlayLedger
  private(set) var product: Product?
  @ObservationIgnored private var updates: Task<Void, Never>?
  @ObservationIgnored private let defaults: UserDefaults
  @ObservationIgnored private var forced: Bool?

  private static let activeKey = "pass.active", ledgerKey = "pass.ledger"

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    active = defaults.bool(forKey: Self.activeKey)
    ledger = (defaults.data(forKey: Self.ledgerKey)).flatMap { try? JSONDecoder().decode(PlayLedger.self, from: $0) } ?? PlayLedger()
    #if DEBUG
    // Screenshots / testing: -pass on|off, -playsUsed N (today's new levels used), -breaks N.
    let a = ProcessInfo.processInfo.arguments
    if let i = a.firstIndex(of: "-pass"), i + 1 < a.count { forced = a[i + 1] == "on"; active = a[i + 1] == "on" }
    if let i = a.firstIndex(of: "-playsUsed"), i + 1 < a.count, let n = Int(a[i + 1]) {
      let day = a.firstIndex(of: "-today").map { a[$0 + 1] } ?? (a.contains("-demo") ? "2026-10-31" : SystemClock().today())
      ledger = PlayLedger(day: day, opened: (0..<n).map { "used-\($0)" }, breaks: a.firstIndex(of: "-breaks").flatMap { Int(a[$0 + 1]) } ?? 0)
    }
    #endif
  }

  /// Live app only: listen for purchases (also ones finished on another device or in Settings) and refresh.
  func start() {
    guard updates == nil, forced == nil else { return }
    updates = Task { [weak self] in
      for await u in Transaction.updates {
        if case .verified(let t) = u { await t.finish() }
        await self?.refresh()
      }
    }
    Task { await refresh(); await loadProduct() }
  }

  func refresh() async {
    guard forced == nil else { return }
    var on = false
    for await e in Transaction.currentEntitlements {
      if case .verified(let t) = e, t.productID == PlayPlan.productID, t.revocationDate == nil, (t.expirationDate ?? .distantFuture) > Date() { on = true }
    }
    setActive(on)
  }

  func loadProduct() async {
    if product == nil { product = try? await Product.products(for: [PlayPlan.productID]).first }
  }

  /// Restore: asks the App Store to sync this Apple Account's purchases (it may ask the grown-up to sign in).
  func restore() async { try? await AppStore.sync(); await refresh() }

  private func setActive(_ on: Bool) {
    guard on != active else { return }
    active = on
    defaults.set(on, forKey: Self.activeKey)
  }

  // MARK: Plays

  func decision(_ c: Climb, number: Int, id: String, won: Bool, today: String) -> PlayPlan.Decision {
    PlayPlan.check(c, number: number, id: id, won: won, pass: active, ledger: ledger, today: today)
  }
  /// Asks to play: records a counted level and returns true, or returns false (show `PlayLimitSheet`).
  func request(_ c: Climb, number: Int, id: String, won: Bool, today: String) -> Bool {
    guard decision(c, number: number, id: id, won: won, today: today).allowed else { return false }
    save(PlayPlan.record(c, number: number, id: id, won: won, pass: active, ledger: ledger, today: today))
    return true
  }
  func left(today: String) -> Int { PlayPlan.left(ledger, today: today) }
  func canBreak(today: String) -> Bool { PlayPlan.canBreak(ledger, today: today) }
  func finishBreak(today: String) { save(PlayPlan.finishBreak(ledger, today: today)) }

  private func save(_ l: PlayLedger) {
    guard l != ledger else { return }
    ledger = l
    if let d = try? JSONEncoder().encode(l) { defaults.set(d, forKey: Self.ledgerKey) }
  }
}

/// Sponsor breaks come from our own ad server (Marquee, mutaafaziz.com/ads) and only ever show a kid-safe direct
/// sponsor's picture or short video: no ad SDK, no identifiers, no cookies, nothing to tap out to. The request
/// names only the app and the slot; the beacon sends one aggregate count. With no sponsor (or no network) the
/// break is Luna's own ("A short break with Luna").
struct Sponsor: Equatable, Sendable {
  enum Media: String, Sendable { case image, video }
  let id: String
  let media: Media
  let url: URL
  let label: String
}

enum SponsorFeed {
  static let base = URL(string: "https://mutaafaziz.com/ads/api")!
  static let app = "moonclub", slot = "level-break"

  /// The slot is declared as gameplay, so Marquee resolves it to direct, kid-safe sponsors only (no ad network).
  static func next() async -> Sponsor? {
    #if DEBUG
    if ProcessInfo.processInfo.arguments.contains("-demo") { return nil }
    #endif
    var c = URLComponents(url: base.appending(path: "config"), resolvingAgainstBaseURL: false)
    c?.queryItems = [.init(name: "app", value: app), .init(name: "slots", value: "\(slot):rewarded:gameplay")]
    guard let u = c?.url else { return nil }
    var req = URLRequest(url: u, cachePolicy: .reloadRevalidatingCacheData, timeoutInterval: 4)
    req.httpShouldHandleCookies = false
    guard let (d, _) = try? await URLSession.shared.data(for: req), let cfg = try? JSONDecoder().decode(Config.self, from: d),
          cfg.enabled, cfg.slots[slot]?.source == "direct" else { return nil }
    let fits = cfg.campaigns.filter { $0.kinds.contains("rewarded") && ($0.media == "image" || $0.media == "video") }
    guard !fits.isEmpty else { return nil }
    var r = Int.random(in: 0..<fits.reduce(0) { $0 + max(1, $1.weight) })
    for f in fits {
      r -= max(1, f.weight)
      if r < 0, let url = URL(string: f.src), let m = Sponsor.Media(rawValue: f.media) { return Sponsor(id: f.id, media: m, url: url, label: f.label) }
    }
    return nil
  }

  /// One aggregate count per finished break (what Marquee's web loader sends too). Fire and forget.
  static func counted(_ s: Sponsor) {
    var req = URLRequest(url: base.appending(path: "beacon"), timeoutInterval: 6)
    req.httpMethod = "POST"; req.httpShouldHandleCookies = false
    req.setValue("application/json", forHTTPHeaderField: "content-type")
    req.httpBody = try? JSONSerialization.data(withJSONObject: ["app": app, "counts": ["\(slot)|\(s.id)|direct": ["i": 1, "v": 1]]])
    Task.detached { _ = try? await URLSession.shared.data(for: req) }
  }

  struct Config: Decodable {
    struct Slot: Decodable { let source: String }
    struct Campaign: Decodable { let id: String; let media: String; let src: String; let weight: Int; let kinds: [String]; let label: String }
    let enabled: Bool
    let slots: [String: Slot]
    let campaigns: [Campaign]
  }
}
