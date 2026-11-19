import SwiftUI
import StoreKit
import UIKit
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
  /// When the current pass year ends (renews or stops), from the verified transaction. nil when off or unknown.
  private(set) var expires: Date?
  /// A purchase is waiting for a family organizer's OK (Ask to Buy). Turns on by itself once approved.
  var pending = false
  /// Bumps when the pass turns on while the app is open (the kid-side "Moon Club Pass is on!" party).
  private(set) var turnedOn = 0
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
        switch u {
        case .verified(let t): await t.finish(); EventLog.shared.add("store.update", t.productID)
        case .unverified(_, let e): Log.store.error("unverified transaction: \(e.localizedDescription, privacy: .public)"); EventLog.shared.add("store.unverified")
        }
        await self?.refresh()
      }
    }
    Task { await refresh(); await loadProduct() }
  }

  /// Coalesced: a refresh already running is awaited instead of starting a second walk of the entitlements.
  @ObservationIgnored private var refreshing: Task<Void, Never>?
  func refresh() async {
    guard forced == nil else { return }
    if let r = refreshing { await r.value; return }
    let t = Task { await self.refreshNow() }
    refreshing = t
    await t.value
    refreshing = nil
  }
  private func refreshNow() async {
    var on = false, ends: Date?
    for await e in Transaction.currentEntitlements {
      if case .verified(let t) = e, t.productID == PlayPlan.productID, t.revocationDate == nil, (t.expirationDate ?? .distantFuture) > Date() {
        on = true; ends = max(ends ?? .distantPast, t.expirationDate ?? .distantPast)
      }
    }
    expires = on ? ends.flatMap { $0 == .distantPast ? nil : $0 } : nil
    if on { pending = false }
    setActive(on)
    Log.store.info("pass refresh: \(on ? "on" : "off", privacy: .public)")
  }

  func loadProduct() async {
    guard product == nil else { return }
    do { product = try await Product.products(for: [PlayPlan.productID]).first }
    catch { Log.store.error("product load failed: \(error.localizedDescription, privacy: .public)"); EventLog.shared.add("store.productError", error.localizedDescription) }
    if product == nil { EventLog.shared.add("store.noProduct") }
  }

  /// Restore: asks the App Store to sync this Apple Account's purchases (it may ask the grown-up to sign in).
  /// Returns a short line for the grown-up corner.
  @discardableResult
  func restore() async -> String {
    do { try await AppStore.sync() } catch { await refresh(); return active ? "Moon Club Pass is on." : "Couldn't reach the App Store. Try again in a moment." }
    await refresh()
    return active ? "Restored: Moon Club Pass is on." : "No Moon Club Pass found for this Apple Account."
  }

  private func setActive(_ on: Bool) {
    guard on != active else { return }
    active = on
    defaults.set(on, forKey: Self.activeKey)
    if on { turnedOn &+= 1 }
    EventLog.shared.add("pass.state", on ? "on" : "off")
  }

  // MARK: Plays

  func decision(_ c: Climb, number: Int, id: String, won: Bool, today: String) -> PlayPlan.Decision {
    PlayPlan.check(c, number: number, id: id, won: won, pass: active, ledger: ledger, today: today)
  }
  /// Asks to play: records a counted level and returns true, or returns false (show `PlayLimitSheet`).
  func request(_ c: Climb, number: Int, id: String, won: Bool, today: String) -> Bool {
    let d = decision(c, number: number, id: id, won: won, today: today)
    guard d.allowed else {
      EventLog.shared.add("level.limit", "\(id) \(d == .doneForToday ? "doneForToday" : "needsBreak")")
      return false
    }
    if case .counted(let left) = d { EventLog.shared.add("level.open", "\(id) counted, \(left) left") }
    else { EventLog.shared.add("level.open", "\(id) free") }
    save(PlayPlan.record(c, number: number, id: id, won: won, pass: active, ledger: ledger, today: today))
    return true
  }
  func left(today: String) -> Int { PlayPlan.left(ledger, today: today) }
  func plays(today: String) -> PlayPlan.Today { PlayPlan.today(ledger, pass: active, today: today) }
  func canBreak(today: String) -> Bool { PlayPlan.canBreak(ledger, today: today) }
  func finishBreak(today: String, source: String = "luna") {
    save(PlayPlan.finishBreak(ledger, today: today))
    EventLog.shared.add("break.done", source)
  }

  private func save(_ l: PlayLedger) {
    guard l != ledger else { return }
    ledger = l
    do { defaults.set(try JSONEncoder().encode(l), forKey: Self.ledgerKey) }
    catch { Log.pass.error("ledger save failed: \(error.localizedDescription, privacy: .public)") }
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
  /// Pictures bigger than this are skipped (Luna's break shows instead).
  static let maxImageBytes = 4 * 1024 * 1024
  /// 0.23 hardening: our own ephemeral session: no cookies, no disk cache, no credentials, short timeouts.
  static let session: URLSession = {
    let c = URLSessionConfiguration.ephemeral
    c.httpCookieAcceptPolicy = .never; c.httpShouldSetCookies = false; c.httpCookieStorage = nil
    c.urlCredentialStorage = nil; c.urlCache = nil
    c.timeoutIntervalForRequest = 4; c.timeoutIntervalForResource = 10
    c.waitsForConnectivity = false
    return URLSession(configuration: c)
  }()

  /// The slot is declared as gameplay, so Marquee resolves it to direct, kid-safe sponsors only (no ad network).
  static func next() async -> Sponsor? {
    #if DEBUG
    if ProcessInfo.processInfo.arguments.contains("-demo") { return nil }
    #endif
    let (s, secs) = await Signpost.measure("sponsor fetch") { await fetch() }
    EventLog.shared.add("sponsor.fetch", (s.map { "\($0.media.rawValue) \($0.id)" } ?? "none") + String(format: " %.0f ms", secs * 1000))
    return s
  }

  private static func fetch() async -> Sponsor? {
    var c = URLComponents(url: base.appending(path: "config"), resolvingAgainstBaseURL: false)
    c?.queryItems = [.init(name: "app", value: app), .init(name: "slots", value: "\(slot):rewarded:gameplay")]
    guard let u = c?.url else { return nil }
    let req = URLRequest(url: u, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 4)
    let d: Data
    do {
      let (data, resp) = try await session.data(for: req)
      guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
        Log.sponsor.notice("config status \((resp as? HTTPURLResponse)?.statusCode ?? -1)"); return nil
      }
      d = data
    } catch { Log.sponsor.notice("config failed: \(error.localizedDescription, privacy: .public)"); return nil }
    guard let cfg = try? JSONDecoder().decode(Config.self, from: d) else { Log.sponsor.error("config didn't decode"); return nil }
    guard cfg.enabled, cfg.slots[slot]?.source == "direct" else { return nil }
    // Only https pictures/videos we can show; anything else is ignored.
    let fits = cfg.campaigns.filter { $0.kinds.contains("rewarded") && ($0.media == "image" || $0.media == "video") && URL(string: $0.src)?.scheme == "https" }
    guard !fits.isEmpty else { return nil }
    var r = Int.random(in: 0..<fits.reduce(0) { $0 + max(1, min($1.weight, 1000)) })
    for f in fits {
      r -= max(1, min(f.weight, 1000))
      if r < 0, let url = URL(string: f.src), let m = Sponsor.Media(rawValue: f.media) { return Sponsor(id: f.id, media: m, url: url, label: String(f.label.prefix(40))) }
    }
    return nil
  }

  /// A sponsor's picture: https, an image content type, at most `maxImageBytes`, decoded off the main thread.
  static func image(_ s: Sponsor) async -> UIImage? {
    guard s.url.scheme == "https" else { return nil }
    do {
      let (d, resp) = try await session.data(from: s.url)
      guard let h = resp as? HTTPURLResponse, h.statusCode == 200, d.count <= maxImageBytes,
            (h.value(forHTTPHeaderField: "Content-Type") ?? "image/").hasPrefix("image/") else {
        EventLog.shared.add("sponsor.imageRejected", s.id); return nil
      }
      return await Task.detached(priority: .userInitiated) { UIImage(data: d)?.preparingForDisplay() }.value
    } catch {
      EventLog.shared.add("sponsor.imageFailed", s.id); return nil
    }
  }

  /// One aggregate count per finished break (what Marquee's web loader sends too). Fire and forget.
  static func counted(_ s: Sponsor) {
    var req = URLRequest(url: base.appending(path: "beacon"), timeoutInterval: 6)
    req.httpMethod = "POST"
    req.setValue("application/json", forHTTPHeaderField: "content-type")
    req.httpBody = try? JSONSerialization.data(withJSONObject: ["app": app, "counts": ["\(slot)|\(s.id)|direct": ["i": 1, "v": 1]]])
    Task.detached { _ = try? await session.data(for: req) }
  }

  struct Config: Decodable {
    struct Slot: Decodable { let source: String }
    struct Campaign: Decodable { let id: String; let media: String; let src: String; let weight: Int; let kinds: [String]; let label: String }
    let enabled: Bool
    let slots: [String: Slot]
    let campaigns: [Campaign]
  }
}
