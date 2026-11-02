import AVFoundation
import Foundation
import MoonClubCore
import Security

// Live implementations of the MoonClubCore boundaries. Network is read-only market data + Luna
// (free kid-safe brain, no key) + an optional grown-up voice key. Nothing about the kid is sent.

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

// MARK: Luna — free kid-safe brain only; answers cached on disk (normalized question + content version, 7 days).
final class LiveLuna: LunaService, @unchecked Sendable {
  private let disk = DiskLRU(dir: cacheDir("luna"), capacity: 1 << 20)
  private let version: String
  init(contentVersion: String) { version = contentVersion }

  func ask(_ question: String, context: LunaContext) -> AsyncThrowingStream<String, Error> {
    let key = lunaCacheKey(question, contentVersion: version)
    return AsyncThrowingStream { cont in
      let task = Task {
        if let (d, age) = disk.get(key), age < CachePolicy.luna.ttl, let s = String(data: d, encoding: .utf8) {
          for word in s.split(separator: " ", omittingEmptySubsequences: false) { cont.yield(word + " "); try? await Task.sleep(for: .milliseconds(18)) }
          cont.finish(); return
        }
        do {
          let (bytes, resp) = try await session.bytes(for: Requests.luna(question: question, context: context))
          guard (resp as? HTTPURLResponse)?.statusCode ?? 500 < 400 else { throw KidError.resting }
          var full = ""
          // Each SSE event from the worker is one `data:` line; parse line by line.
          for try await line in bytes.lines where line.hasPrefix("data:") {
            for e in SSE.parse(line + "\n\n").0 {
              switch e {
              case let .text(t): full += t; cont.yield(t)
              case .error: throw KidError.resting
              case .done: break
              }
            }
          }
          if !full.isEmpty { disk.set(key, Data(full.utf8)) }
          cont.finish()
        } catch { cont.finish(throwing: (error as? KidError) ?? .resting) }
      }
      cont.onTermination = { _ in task.cancel() }
    }
  }
}

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
  static func set(_ v: String?) {
    let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service]
    SecItemDelete(q as CFDictionary)
    guard let v, !v.isEmpty else { return }
    var add = q; add[kSecValueData as String] = Data(v.utf8); add[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    SecItemAdd(add as CFDictionary, nil)
  }
  static func get() -> String? {
    let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
    var out: AnyObject?
    guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let d = out as? Data else { return nil }
    return String(data: d, encoding: .utf8)
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
    if s.mode != .device, let key = Keychain.get(), let provider = Requests.VoiceProvider(rawValue: s.mode.rawValue),
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
  func stop() async { stopNow() }
  private func stopNow() { synth.stopSpeaking(at: .immediate); player?.stop(); player = nil; resume() }
  private func resume() { waiter?.resume(); waiter = nil }
  nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) { Task { @MainActor in self.resume() } }
  nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel u: AVSpeechUtterance) { Task { @MainActor in self.resume() } }
  nonisolated func audioPlayerDidFinishPlaying(_ p: AVAudioPlayer, successfully: Bool) { Task { @MainActor in self.resume() } }
}

// MARK: Progress — one JSON file in Application Support, written atomically. Never leaves the device.
final class FileProgressStore: ProgressStore, @unchecked Sendable {
  private let url: URL
  init(fileName: String = "progress.json") {
    let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("MoonClub")
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    url = dir.appendingPathComponent(fileName)
  }
  func load() -> KidsState { (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode(KidsState.self, from: $0) } ?? KidsState() }
  func save(_ s: KidsState) { if let d = try? JSONEncoder().encode(s) { try? d.write(to: url, options: [.atomic, .completeFileProtection]) } }
}
