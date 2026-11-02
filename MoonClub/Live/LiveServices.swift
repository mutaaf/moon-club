import AVFoundation
import Foundation
import MoonClubCore
import Security

// Live implementations of the MoonClubCore boundaries. Network is read-only market data + Luna (Brains.swift:
// on-device, free, or a grown-up's own key after consent) + an optional grown-up voice key.

private func cacheDir(_ name: String) -> URL {
  FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("MoonClub/\(name)")
}
private let session: URLSession = {
  let c = URLSessionConfiguration.default
  c.timeoutIntervalForRequest = 15
  c.urlCache = nil // our LayeredCache is the cache
  c.httpAdditionalHeaders = ["user-agent": "MoonClub-iOS/1"]
  return URLSession(configuration: c)
}()

private func get(_ path: String, _ query: [String: String] = [:]) async throws -> Data {
  var u = URLComponents(url: apiBase.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
  if !query.isEmpty { u.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) } }
  let (d, r) = try await session.data(from: u.url!)
  guard (r as? HTTPURLResponse)?.statusCode ?? 500 < 400 else { throw KidError.offline }
  return d
}

// MARK: Market data — memory → disk → network, stale-while-revalidate, one in-flight per key.
final class LiveMarketData: MarketDataSource, @unchecked Sendable {
  private let cache = LayeredCache(disk: DiskLRU(dir: cacheDir("market"), capacity: 6 << 20))
  private let dec = JSONDecoder()

  func calendar(from: String, to: String) async throws -> [EarningsEvent] {
    let chunks = Requests.calendarChunks(from: from, to: to)
    var all: [EarningsEvent] = [], failures = 0
    try await withThrowingTaskGroup(of: [EarningsEvent]?.self) { g in
      for (a, b) in chunks {
        g.addTask { [cache, dec] in
          let d = try? await cache.data("cal:\(a):\(b)", policy: .calendar) { try await get("api/calendar", ["from": a, "to": b]) }
          return d.flatMap { try? dec.decode(CalendarPayload.self, from: $0).events }
        }
      }
      for try await r in g { if let r { all += r } else { failures += 1 } }
    }
    if all.isEmpty && failures > 0 { throw KidError.offline }
    var seen = Set<String>()
    return all.filter { seen.insert($0.id).inserted }
  }
  func mood() async throws -> Double? {
    let d = try await cache.data("macro", policy: .mood) { try await get("api/macro") }
    return try dec.decode(MacroPayload.self, from: d).mood?.score
  }
  func quotes(_ symbols: [String]) async throws -> [String: Double] {
    let syms = symbols.sorted().joined(separator: ",")
    let d = try await cache.data("quotes:\(syms)", policy: .quotes) { try await get("api/quotes", ["s": syms]) }
    return try dec.decode(QuotePayload.self, from: d).quotes.mapValues(\.price)
  }
  func lastMove(_ symbol: String) async throws -> TickerPayload {
    let d = try await cache.data("ticker:\(symbol)", policy: .ticker) { try await get("api/ticker/\(symbol)") }
    return try dec.decode(TickerPayload.self, from: d)
  }
}

// MARK: Luna — see Brains.swift (free / on-device / your own key, chosen in the grown-up corner).

// MARK: Voice — iOS's best installed voice, or a grown-up's own OpenAI/Gemini key (clips cached on disk).
struct VoiceSettings: Codable, Equatable {
  enum Mode: String, Codable, CaseIterable { case device, openai, gemini }
  var mode: Mode = .device
  var voice: String = "coral"
  static let key = "moonclub.voice.v1"
  static func load() -> VoiceSettings { (UserDefaults.standard.data(forKey: key)).flatMap { try? JSONDecoder().decode(VoiceSettings.self, from: $0) } ?? VoiceSettings() }
  func save() { UserDefaults.standard.set(try? JSONEncoder().encode(self), forKey: Self.key) }
}

enum Keychain {
  static let service = "com.mutaafaziz.moonclub.voicekey"
  static let lunaService = "com.mutaafaziz.moonclub.lunakey"
  static let lunaMetaService = "com.mutaafaziz.moonclub.lunakey.meta"
  /// Saves (or with nil deletes) a secret. `synced` puts it in iCloud Keychain (end-to-end encrypted by
  /// Apple, only on the family's own devices); otherwise it never leaves this device. Deleting removes
  /// both kinds, so "Remove" on one device removes a synced key everywhere.
  static func set(_ v: String?, service: String = Keychain.service, synced: Bool = false) {
    let any: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrSynchronizable as String: kSecAttrSynchronizableAny]
    SecItemDelete(any as CFDictionary)
    if v == nil, service == lunaService { set(nil, service: lunaMetaService) } // the key's settings go with it
    guard let v, !v.isEmpty else { return }
    let add: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecValueData as String: Data(v.utf8),
                              kSecAttrSynchronizable as String: synced,
                              kSecAttrAccessible as String: synced ? kSecAttrAccessibleWhenUnlocked : kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
    SecItemAdd(add as CFDictionary, nil)
  }
  static func get(service: String = Keychain.service) -> String? {
    let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
                            kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
    var out: AnyObject?
    guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let d = out as? Data else { return nil }
    return String(data: d, encoding: .utf8)
  }
  /// Whether the stored secret is the iCloud Keychain (synced) kind.
  static func isSynced(service: String) -> Bool {
    let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrSynchronizable as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
    return SecItemCopyMatching(q as CFDictionary, nil) == errSecSuccess
  }
}

/// "Use on my other devices" for Luna's own-key brain. Off by default. When on, the key AND its settings
/// (provider, the grown-up's consent for that provider, model) travel through iCloud Keychain, never
/// through iCloud key-value sync and never to us. Consent stays tied to one provider: changing provider
/// deletes the key (everywhere) and the consent with it.
enum KeyTravel {
  struct Meta: Codable, Equatable { var provider: KeyProvider; var consentFor: KeyProvider?; var model: String? }
  static var isOn: Bool { Keychain.isSynced(service: Keychain.lunaService) }

  static func setOn(_ on: Bool, settings s: BrainSettings) {
    guard let key = Keychain.get(service: Keychain.lunaService) else { return }
    Keychain.set(key, service: Keychain.lunaService, synced: on)
    if on { publish(s) } // (set() above already removed the meta when turning off? no: only on delete)
    else { Keychain.set(nil, service: Keychain.lunaMetaService) }
  }
  /// Keep the travelling settings in step with this device's (called whenever they're saved).
  static func publish(_ s: BrainSettings) {
    guard isOn else { return }
    let m = Meta(provider: s.provider, consentFor: s.consentFor, model: s.model)
    if let d = try? JSONEncoder().encode(m), let str = String(data: d, encoding: .utf8) { Keychain.set(str, service: Keychain.lunaMetaService, synced: true) }
  }
  /// On a device that got a travelling key: take its provider + consent, unless a grown-up here already
  /// picked a different provider (then the key isn't for this setup and stays unused until they choose).
  static func adopt(into s: BrainSettings) -> BrainSettings {
    guard let str = Keychain.get(service: Keychain.lunaMetaService), let m = try? JSONDecoder().decode(Meta.self, from: Data(str.utf8)) else { return s }
    var r = s
    if s.choice == nil || s.provider == m.provider {
      r.provider = m.provider; r.consentFor = m.consentFor == m.provider ? m.consentFor : nil; r.model = r.model ?? m.model
      if s.choice == nil, r.consentFor != nil { r.choice = .byok }
    }
    return r
  }
}

@MainActor
final class LiveVoice: NSObject, VoiceService, @unchecked Sendable, AVSpeechSynthesizerDelegate, AVAudioPlayerDelegate {
  private let synth = AVSpeechSynthesizer()
  private var player: AVAudioPlayer?
  private var waiter: CheckedContinuation<Void, Never>?
  private let clips = DiskLRU(dir: cacheDir("voice"), capacity: 24 << 20)

  override init() { super.init(); synth.delegate = self }

  /// The friendliest installed en-US voice: premium > enhanced > default, preferring warm names.
  static let bestVoice: AVSpeechSynthesisVoice? = {
    let en = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == "en-US" }
    let warm = ["Ava", "Zoe", "Samantha", "Allison", "Susan", "Evan", "Nathan"]
    return en.sorted { a, b in
      if a.quality != b.quality { return a.quality.rawValue > b.quality.rawValue }
      return (warm.firstIndex(of: a.name) ?? 99) < (warm.firstIndex(of: b.name) ?? 99)
    }.first ?? AVSpeechSynthesisVoice(language: "en-US")
  }()

  func speak(_ source: SpeakSource) async {
    stopNow()
    try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
    try? AVAudioSession.sharedInstance().setActive(true)
    let s = VoiceSettings.load()
    if s.mode != .device, let provider = Requests.VoiceProvider(rawValue: s.mode.rawValue), let key = Self.voiceKey(provider),
       let req = Requests.speak(source, provider: provider, voice: s.voice, key: key) {
      let cacheKey = "tts:\(provider.rawValue):\(s.voice):\(source.text)"
      var audio = clips.get(cacheKey)?.data
      if audio == nil, let (d, r) = try? await session.data(for: req), (r as? HTTPURLResponse)?.statusCode == 200 {
        audio = d; clips.set(cacheKey, d)
      }
      if let audio, let p = try? AVAudioPlayer(data: audio) {
        player = p; p.delegate = self; p.play()
        await withCheckedContinuation { waiter = $0 }
        return
      }
      // any failure falls back to the free device voice below
    }
    let u = AVSpeechUtterance(string: source.text.replacingOccurrences(of: "*", with: ""))
    u.voice = Self.bestVoice; u.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92; u.pitchMultiplier = 1.05
    synth.speak(u)
    await withCheckedContinuation { waiter = $0 }
  }
  /// The voice key, or Luna's own key when it's for the same provider (one key unlocks both).
  static func voiceKey(_ p: Requests.VoiceProvider) -> String? {
    if let k = Keychain.get(), !k.isEmpty { return k }
    let b = BrainStore.load()
    return b.provider.voice == p ? BrainStore.lunaKey : nil
  }
  func stop() async { stopNow() }
  private func stopNow() { synth.stopSpeaking(at: .immediate); player?.stop(); player = nil; resume() }
  private func resume() { waiter?.resume(); waiter = nil }
  nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) { Task { @MainActor in self.resume() } }
  nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel u: AVSpeechUtterance) { Task { @MainActor in self.resume() } }
  nonisolated func audioPlayerDidFinishPlaying(_ p: AVAudioPlayer, successfully: Bool) { Task { @MainActor in self.resume() } }
}

// Progress lives in the shared keychain group now: see Shared/MoonShare.swift (SharedProgressStore, with a one-time move
// from the old Application Support file).
