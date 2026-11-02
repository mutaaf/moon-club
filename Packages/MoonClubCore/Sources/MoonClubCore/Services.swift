// Every boundary to the outside world is a protocol, with live implementations in the app and fakes
// for previews/tests. The request builders are pure and live here, so the kids-safety rules are
// unit-tested where they're enforced:
//  • Luna (chat) ALWAYS uses the free kid-safe brain and NEVER carries a key.
//  • A voice key is only ever attached to app copy or Luna's answer — never to text a kid typed.
import Foundation

public let apiBase = URL(string: "https://mutaafaziz.com/metaphases")!

// MARK: Models from the worker (read-only)
public struct EarningsEvent: Codable, Hashable, Sendable, Identifiable {
  public let s: String; public let d: String; public let h: Session; public let eE: Double?; public let eA: Double?
  public var id: String { "\(s):\(d)" }
  public var report: Report { Report(eA: eA, eE: eE) }
  public init(s: String, d: String, h: Session, eE: Double?, eA: Double?) { self.s = s; self.d = d; self.h = h; self.eE = eE; self.eA = eA }
  private enum K: String, CodingKey { case s, d, h, eE, eA }
  public init(from dec: Decoder) throws {
    let c = try dec.container(keyedBy: K.self)
    s = try c.decode(String.self, forKey: .s); d = try c.decode(String.self, forKey: .d)
    h = (try? c.decode(Session.self, forKey: .h)) ?? .none
    eE = try c.decodeIfPresent(Double.self, forKey: .eE); eA = try c.decodeIfPresent(Double.self, forKey: .eA)
  }
}
public struct CalendarPayload: Codable, Sendable { public let events: [EarningsEvent] }
public struct MacroPayload: Codable, Sendable { public struct Mood: Codable, Sendable { public let score: Double }; public let mood: Mood? }
public struct QuotePayload: Codable, Sendable { public struct Q: Codable, Sendable { public let price: Double }; public let quotes: [String: Q] }
public struct TickerPayload: Codable, Sendable {
  public struct Reaction: Codable, Sendable { public let date: String; public let move: Double? }
  public let history: [Reaction]
}

// MARK: Boundaries
public protocol Clock: Sendable { func today() -> String }
public struct SystemClock: Clock { public init() {}; public func today() -> String { Day.today() } }
public struct FixedClock: Clock { public let day: String; public init(_ day: String) { self.day = day }; public func today() -> String { day } }

/// A friendly error a kid can read (errors are values with copy, never stack traces).
public struct KidError: Error, Equatable, Sendable { public let message: String; public init(_ m: String) { message = m }
  public static let offline = KidError("Hmm, we can't reach the market right now. We'll show what we saved last time!")
  public static let resting = KidError("Luna is resting right now. Try again in a little while! 🌙")
}

public protocol MarketDataSource: Sendable {
  func calendar(from: String, to: String) async throws -> [EarningsEvent]
  func mood() async throws -> Double?
  func quotes(_ symbols: [String]) async throws -> [String: Double]
  func lastMove(_ symbol: String) async throws -> TickerPayload
}
public protocol LunaService: Sendable {
  func ask(_ question: String, context: LunaContext) -> AsyncThrowingStream<String, Error>
}
public enum SpeakSource: Sendable, Equatable {
  /// Text that ships in the app (lessons, cards) — may use a grown-up's voice key.
  case appCopy(String)
  /// Luna's answer — may use the voice key unless it repeats what the kid typed.
  case luna(answer: String, kidTyped: String?)
  public var text: String { switch self { case let .appCopy(t): return t; case let .luna(a, _): return a } }
  /// The safety rule: kid-typed words never go to a voice provider.
  public var mayUseKey: Bool {
    switch self {
    case .appCopy: return true
    case let .luna(answer, typed):
      guard let typed = typed?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), typed.count >= 4 else { return true }
      return !answer.lowercased().contains(typed)
    }
  }
}
public protocol VoiceService: Sendable {
  func speak(_ source: SpeakSource) async
  func stop() async
}
public protocol ProgressStore: Sendable {
  func load() -> KidsState
  func save(_ s: KidsState)
}

// MARK: Pure request builders (the rules live here and are tested)
public struct LunaContext: Codable, Hashable, Sendable {
  public struct Co: Codable, Hashable, Sendable { public let s: String; public let nick: String; public let hook: String; public let when: String?
    public init(s: String, nick: String, hook: String, when: String?) { self.s = s; self.nick = nick; self.hook = hook; self.when = when } }
  public let weather: String?; public let companies: [Co]
  public init(weather: String?, companies: [Co]) { self.weather = weather; self.companies = companies }
}
public enum Requests {
  public static func luna(question: String, context: LunaContext, base: URL = apiBase) -> URLRequest {
    var r = URLRequest(url: base.appendingPathComponent("api/ai/stream"))
    r.httpMethod = "POST"
    r.setValue("application/json", forHTTPHeaderField: "content-type")
    r.setValue("text/event-stream", forHTTPHeaderField: "accept")
    struct Body: Encodable { let task = "kids"; let provider = "edge"; let context: LunaContext; let question: String }
    r.httpBody = try? JSONEncoder().encode(Body(context: context, question: String(question.prefix(200))))
    return r // deliberately NO x-mp-key: kids chat is the free kid-safe brain only
  }
  public enum VoiceProvider: String, Codable, Sendable, CaseIterable { case openai, gemini }
  public static let voices: [VoiceProvider: [String]] = [.openai: ["coral", "nova", "fable", "shimmer", "sage"], .gemini: ["Leda", "Puck", "Aoede", "Zephyr", "Kore"]]
  public static let maxSpeakChars = 600
  /// nil when the rules say no (kid-typed text, unknown voice, too long, no key).
  public static func speak(_ source: SpeakSource, provider: VoiceProvider, voice: String, key: String, base: URL = apiBase) -> URLRequest? {
    let text = source.text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard source.mayUseKey, !key.isEmpty, !text.isEmpty, text.count <= maxSpeakChars, voices[provider]?.contains(voice) == true else { return nil }
    var r = URLRequest(url: base.appendingPathComponent("api/ai/speak"))
    r.httpMethod = "POST"
    r.setValue("application/json", forHTTPHeaderField: "content-type")
    r.setValue(key, forHTTPHeaderField: "x-mp-key")
    r.httpBody = try? JSONSerialization.data(withJSONObject: ["provider": provider.rawValue, "voice": voice, "text": text])
    return r
  }
  public static func calendarChunks(from: String, to: String) -> [(String, String)] {
    var out: [(String, String)] = []
    var a = from
    while a <= to { let b = min(Day.add(a, 6), to); out.append((a, b)); a = Day.add(b, 1) }
    return out
  }
}

/// Parses the worker's SSE stream ("data: {...}\n\n"); returns events and the unparsed tail.
public enum SSE {
  public enum Event: Equatable, Sendable { case text(String), error(String), done }
  public static func parse(_ buf: String) -> ([Event], String) {
    var events: [Event] = []
    var rest = buf
    while let r = rest.range(of: "\n\n") {
      let chunk = String(rest[..<r.lowerBound]); rest = String(rest[r.upperBound...])
      for line in chunk.split(separator: "\n") where line.hasPrefix("data:") {
        let json = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
        guard let d = json.data(using: .utf8), let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { continue }
        if let t = o["t"] as? String { events.append(.text(t)) }
        else if let e = o["error"] as? String { events.append(.error(e)) }
        else if o["done"] != nil { events.append(.done) }
      }
    }
    return (events, rest)
  }
}
