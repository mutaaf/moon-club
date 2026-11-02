// Luna's brain: a grown-up choice between three brains behind one protocol.
//   • onDevice — Apple Intelligence (FoundationModels). Nothing leaves the device. Default when available.
//   • free     — the Metaphases free kid-safe brain (Workers AI). No key, ever. The fallback.
//   • byok     — a grown-up's own Anthropic / OpenAI / Gemini / xAI key, called directly from the device.
//                Only with an explicit consent for THAT provider ("your child's questions will be sent to …").
// Every brain gets the same kid-safe system prompt, and every answer passes through LunaGuard.
// The rules live in this file as pure functions and are unit-tested.
import Foundation

public enum BrainKind: String, Codable, CaseIterable, Sendable { case onDevice, free, byok }

/// Why Apple Intelligence can or can't run here (mirrors SystemLanguageModel.Availability).
public enum OnDeviceStatus: String, Codable, Sendable {
  case available, notEligible, turnedOff, downloading, unsupportedOS

  /// Plain-language explanation plus the fix, for the grown-up picker.
  public var explanation: String {
    switch self {
    case .available: return "Ready. Luna thinks right here on this device, and nothing is sent anywhere."
    case .notEligible: return "This device can't run Apple Intelligence (it needs an iPhone 15 Pro or newer, or an iPad with an M-series or A17 Pro chip)."
    case .turnedOff: return "Apple Intelligence is turned off. Turn it on in Settings → Apple Intelligence & Siri, then come back."
    case .downloading: return "Apple Intelligence is still downloading its model. Keep the device on Wi-Fi and charging; it will be ready soon."
    case .unsupportedOS: return "Needs iOS 26 or later. Update in Settings → General → Software Update."
    }
  }
}

public enum KeyProvider: String, Codable, CaseIterable, Sendable, Identifiable {
  case anthropic, openai, gemini, xai
  public var id: String { rawValue }
  public var label: String { ["anthropic": "Anthropic", "openai": "OpenAI", "gemini": "Google", "xai": "xAI"][rawValue]! }
  public var vendor: String { ["anthropic": "Claude", "openai": "ChatGPT", "gemini": "Gemini", "xai": "Grok"][rawValue]! }
  public var keyHint: String { ["anthropic": "sk-ant-…", "openai": "sk-…", "gemini": "AIza…", "xai": "xai-…"][rawValue]! }
  public var base: URL {
    URL(string: ["anthropic": "https://api.anthropic.com/v1", "openai": "https://api.openai.com/v1",
                 "gemini": "https://generativelanguage.googleapis.com/v1beta/openai", "xai": "https://api.x.ai/v1"][rawValue]!)!
  }
  /// Used when the model list can't be read (same as the web's PROVIDERS.fallbackModel).
  public var fallbackModel: String { ["anthropic": "claude-haiku-5-5", "openai": "gpt-5-mini", "gemini": "gemini-2.5-flash", "xai": "grok-4-fast"][rawValue]! }
  /// Cheap, current chat models first (ported from metaphases worker/ai/providers.ts PREFS).
  var preferences: [String] {
    switch self {
    case .anthropic: return [#"^claude-haiku-\d"#, #"^claude-sonnet-\d"#]
    case .openai: return [#"^gpt-\d+(\.\d+)?-mini$"#, #"^gpt-\d+(\.\d+)?-nano$"#, #"^gpt-\d+(\.\d+)?-mini"#, #"^gpt-\d"#]
    case .xai: return [#"^grok-[\d.]+-fast(?!.*(image|vision))"#, "fast", "mini", #"^grok-[\d.]+$"#, "^grok"]
    case .gemini: return [#"^gemini-[\d.]+-flash$"#, #"^gemini-[\d.]+-flash"#, #"^gemini-[\d.]+-flash-lite"#, "^gemini"]
    }
  }
  /// The voice providers this key can also power (read-aloud).
  public var voice: Requests.VoiceProvider? { self == .openai ? .openai : self == .gemini ? .gemini : nil }

  /// Pick the best chat model from a provider's live list (newest-looking id within the first matching preference).
  public func pickModel(_ ids: [String]) -> String {
    for p in preferences {
      let hits = ids.filter { $0.range(of: p, options: .regularExpression) != nil }
      if let best = hits.sorted(by: { $0.compare($1, options: .numeric) == .orderedDescending }).first { return best }
    }
    return fallbackModel
  }
}

/// Saved in UserDefaults by the app. The key itself lives only in the Keychain.
public struct BrainSettings: Codable, Equatable, Sendable {
  /// nil = automatic (on-device when available, else free).
  public var choice: BrainKind?
  public var provider: KeyProvider = .anthropic
  public var model: String?
  /// The provider the grown-up agreed to send questions to. Consent is per provider: switching resets it.
  public var consentFor: KeyProvider?
  public init(choice: BrainKind? = nil, provider: KeyProvider = .anthropic, model: String? = nil, consentFor: KeyProvider? = nil) {
    self.choice = choice; self.provider = provider; self.model = model; self.consentFor = consentFor
  }
  public var consented: Bool { consentFor == provider }
}

public enum BrainRouter {
  /// Which brain answers. BYOK needs a choice + a key + consent for that provider; anything missing falls back.
  public static func resolve(_ s: BrainSettings, onDevice: OnDeviceStatus, hasKey: Bool) -> BrainKind {
    let device: BrainKind = onDevice == .available ? .onDevice : .free
    switch s.choice {
    case .byok?: return hasKey && s.consented ? .byok : device
    case .free?: return .free
    case .onDevice?, nil: return device
    }
  }
}

/// What each brain unlocks. "Full capabilities" = BYOK.
public struct BrainCapabilities: Equatable, Sendable {
  public let maxChars: Int
  /// Earlier turns of this chat sent along (0 = every question stands alone).
  public let memoryTurns: Int
  /// "Explain more" on story and report cards.
  public let deepExplain: Bool
  public let maxTokens: Int
  public static func of(_ k: BrainKind) -> BrainCapabilities {
    switch k {
    case .free: return .init(maxChars: 650, memoryTurns: 0, deepExplain: false, maxTokens: 300)
    case .onDevice: return .init(maxChars: 750, memoryTurns: 4, deepExplain: true, maxTokens: 350)
    case .byok: return .init(maxChars: 1400, memoryTurns: 8, deepExplain: true, maxTokens: 700)
    }
  }
}

public extension BrainKind {
  var badge: String { ["onDevice": "On-device Luna", "free": "Free Luna", "byok": "Super Luna"][rawValue]! }
  /// SF Symbol: a moon with sparkles for on-device, a key for BYOK.
  var symbol: String { ["onDevice": "moon.stars.fill", "free": "moon.fill", "byok": "key.fill"][rawValue]! }
}

public struct LunaTurn: Codable, Hashable, Sendable {
  public enum Role: String, Codable, Sendable { case kid, luna }
  public let role: Role; public let text: String
  public init(_ role: Role, _ text: String) { self.role = role; self.text = text }
}

/// Everything one brain needs for one answer. Built purely, so every brain gets the same rules.
public struct LunaPrompt: Sendable, Equatable {
  public let system: String
  public let user: String
  public let history: [LunaTurn]
  public let question: String
  public let context: LunaContext
  public let caps: BrainCapabilities

  public init(question: String, context: LunaContext, history: [LunaTurn], kind: BrainKind) {
    let c = BrainCapabilities.of(kind)
    caps = c
    let q = String(question.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200))
    self.question = q; self.context = context
    self.history = Array(history.suffix(c.memoryTurns * 2)).map { LunaTurn($0.role, String($0.text.prefix(c.maxChars))) }
    system = LunaPrompts.system(kind)
    user = LunaPrompts.user(q, context: context)
  }
}

public enum LunaPrompts {
  /// Mirrors metaphases worker/ai/prompts.ts KIDS_SYSTEM: keep the two in sync.
  public static let kidsSystem = """
  You are Luna, a friendly moon who helps kids (about 8 to 12 years old) learn how money, companies and the stock market work. You live inside Metaphases Kids, where everything is pretend practice money.

  Rules you never break:
  - Use short sentences and simple words a 9-year-old can read. Be warm and encouraging.
  - Only talk about money, saving, companies, shares, earnings report cards and the stock market. If a kid asks about anything else, say: "That's a great question for a grown-up! I'm best at money and markets." Then suggest a money question they could ask you.
  - Never tell anyone to buy or sell anything, and never tell them to use real money. Say it's pretend practice here, and that real money decisions are for grown-ups.
  - Never ask for, guess or repeat personal information: no names, ages, schools, addresses, locations, photos or contact details. If a kid shares personal information, kindly say they shouldn't share that online, and don't repeat it.
  - No scary, violent, adult or unkind content. If something feels unsafe, say: "Let's ask a grown-up about that!"
  - Use only the facts provided. If you don't know, say "I'm not sure!" Don't make up numbers.
  - No links. At most one emoji.
  """
  public static func system(_ k: BrainKind) -> String {
    switch k {
    case .free: return kidsSystem + "\n- Answer in 2 to 5 sentences."
    case .onDevice: return kidsSystem + "\n- Answer in 2 to 6 sentences. You may use what was said earlier in this chat."
    case .byok: return kidsSystem + "\n- Answer in 2 to 5 sentences, or up to 9 short sentences when the kid asks you to explain more. Use a fun everyday example (pizza slices, lemonade stands, trading cards). You may use what was said earlier in this chat."
    }
  }
  /// The facts block + question. Only companies the question mentions, plus the next few report cards (keeps
  /// the on-device context window small).
  public static func user(_ q: String, context: LunaContext) -> String {
    let lq = q.lowercased()
    let named = context.companies.filter { lq.contains($0.nick.lowercased()) || lq.range(of: "\\b\($0.s.lowercased())\\b", options: .regularExpression) != nil }
    let soon = context.companies.filter { $0.when != nil }.prefix(5)
    var seen = Set<String>()
    let cos = (named + soon).filter { seen.insert($0.s).inserted }
    var facts: [String] = []
    if let w = context.weather { facts.append("Market weather today: \(w)") }
    for c in cos { facts.append("\(c.nick) (\(c.s)): \(c.hook)" + (c.when.map { ". Shares its report card \($0)" } ?? "")) }
    return (facts.isEmpty ? "" : "Facts you can use:\n- " + facts.joined(separator: "\n- ") + "\n\n") + "Kid's question: \(q)"
  }
  /// Tap-generated (never kid-typed) deep-explain questions for story and report cards.
  public static func explain(reportFor nick: String, when: String) -> String { "Explain more about \(nick)'s report card \(when). What will grown-ups look at, and what do beat and miss mean for it?" }
  public static func explain(weather title: String) -> String { "Explain more about today's market weather: \(title). Why do people feel that way, and what does it mean for prices?" }
  public static func explain(word: String) -> String { "Explain the word \"\(word)\" in more depth with a fun example." }
}

/// The output guard every answer passes through: link-free, length-capped, and anything off-limits becomes a
/// gentle redirect.
public enum LunaGuard {
  public static let redirect = "That's a great question for a grown-up! I'm best at money and markets. Want to ask me what a share is? 🌙"
  static let blocked: [String] = [
    // advice / real money
    #"\byou should (buy|sell|invest)"#, #"\b(buy|sell) (it|them|this|that) (now|today)\b"#, #"\bguaranteed (profits?|returns?|money)\b"#,
    #"\bopen (a|an) (brokerage|trading) account\b"#, #"\b(credit card|bank account|social security) numbers?\b"#, #"\bcrypto ?casino\b"#,
    // unsafe / adult
    #"\b(kill|killing|suicide|murder|guns?|weapons?|drugs?|alcohol|beer|vodka|cigarettes?|vape|sex|sexy|porn|nude|naked|casino)\b"#,
    // asking for personal info
    #"\bwhat('s| is) your (name|address|school|phone)"#, #"\bwhere do you live\b"#, #"\bhow old are you\b"#, #"\bsend (me )?(a )?(photo|picture|selfie)"#,
  ]
  public static func isBlocked(_ text: String) -> Bool {
    blocked.contains { text.range(of: $0, options: [.regularExpression, .caseInsensitive]) != nil }
  }
  /// The guarded version of a (possibly partial) answer. `done` = the stream has ended.
  public static func check(_ text: String, maxChars: Int) -> (text: String, stop: Bool) {
    if isBlocked(text) { return (redirect, true) }
    var t = text.replacingOccurrences(of: #"\[([^\]]+)\]\([^)]*\)"#, with: "$1", options: .regularExpression)
    t = t.replacingOccurrences(of: #"(https?://|www\.)\S+"#, with: "", options: .regularExpression)
    guard t.count > maxChars else { return (t, false) }
    let cut = String(t.prefix(maxChars))
    if let end = cut.lastIndex(where: { ".!?".contains($0) }), cut.distance(from: cut.startIndex, to: end) > maxChars * 2 / 5 {
      return (String(cut[...end]), true)
    }
    return (cut.trimmingCharacters(in: .whitespaces) + "…", true)
  }
}

/// One brain. Streams text deltas for a prompt; the router applies the guard.
public protocol LunaBrain: Sendable {
  var kind: BrainKind { get }
  func stream(_ prompt: LunaPrompt) -> AsyncThrowingStream<String, Error>
}

/// The LunaService the app uses: resolves the brain per question (settings can change any time) and streams
/// guarded, cumulative snapshots of the answer.
public final class LunaRouter: LunaService, @unchecked Sendable {
  private let brains: [BrainKind: LunaBrain]
  private let resolveKind: @Sendable () -> BrainKind
  public init(brains: [LunaBrain], resolve: @escaping @Sendable () -> BrainKind) {
    self.brains = Dictionary(uniqueKeysWithValues: brains.map { ($0.kind, $0) })
    resolveKind = resolve
  }
  public func activeBrain() -> BrainKind { let k = resolveKind(); return brains[k] == nil ? .free : k }

  public func ask(_ question: String, context: LunaContext, history: [LunaTurn]) -> AsyncThrowingStream<String, Error> {
    let kind = activeBrain()
    let prompt = LunaPrompt(question: question, context: context, history: history, kind: kind)
    guard let brain = brains[kind] ?? brains[.free] else { return AsyncThrowingStream { $0.finish(throwing: KidError.resting) } }
    return AsyncThrowingStream { cont in
      let task = Task {
        var raw = ""
        do {
          for try await d in brain.stream(prompt) {
            raw += d
            let g = LunaGuard.check(raw, maxChars: prompt.caps.maxChars)
            cont.yield(g.text)
            if g.stop { break }
          }
          if raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { throw KidError.resting }
          cont.finish()
        } catch is CancellationError { cont.finish() }
        catch let e as KidError { cont.finish(throwing: e) }
        catch { cont.finish(throwing: KidError.resting) }
      }
      cont.onTermination = { _ in task.cancel() }
    }
  }
}

public extension Requests {
  /// A grown-up's own key, sent straight to the provider (never through our server). nil unless the grown-up
  /// consented to THIS provider — kid-typed questions only ever reach a third party through here.
  static func byok(_ p: KeyProvider, key: String, model: String, prompt: LunaPrompt, consent: KeyProvider?) -> URLRequest? {
    guard consent == p else { return nil }
    let key = key.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !key.isEmpty, !model.isEmpty, !prompt.question.isEmpty else { return nil }
    let turns = prompt.history.map { ["role": $0.role == .kid ? "user" : "assistant", "content": $0.text] } + [["role": "user", "content": prompt.user]]
    var body: [String: Any] = ["model": model, "stream": true]
    var r: URLRequest
    if p == .anthropic {
      r = URLRequest(url: p.base.appendingPathComponent("messages"))
      r.setValue(key, forHTTPHeaderField: "x-api-key")
      r.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
      body["system"] = prompt.system; body["messages"] = turns; body["max_tokens"] = prompt.caps.maxTokens
    } else {
      r = URLRequest(url: p.base.appendingPathComponent("chat/completions"))
      r.setValue("Bearer \(key)", forHTTPHeaderField: "authorization")
      body["messages"] = [["role": "system", "content": prompt.system]] + turns
      let reasoning = (p == .openai && model.range(of: #"^(gpt-5|o\d)"#, options: .regularExpression) != nil) || (p == .gemini && model.range(of: #"^gemini-(2\.5|[3-9])"#, options: .regularExpression) != nil)
      if reasoning { body["reasoning_effort"] = "low" } else { body["max_tokens"] = prompt.caps.maxTokens }
    }
    r.httpMethod = "POST"
    r.timeoutInterval = 30
    r.setValue("application/json", forHTTPHeaderField: "content-type")
    r.httpBody = try? JSONSerialization.data(withJSONObject: body)
    return r
  }
  /// The one-tap key check: list the provider's models. Sends no kid text.
  static func models(_ p: KeyProvider, key: String) -> URLRequest {
    var r = URLRequest(url: p == .anthropic ? URL(string: p.base.absoluteString + "/models?limit=100")! : p.base.appendingPathComponent("models"))
    r.timeoutInterval = 12
    if p == .anthropic { r.setValue(key, forHTTPHeaderField: "x-api-key"); r.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version") }
    else { r.setValue("Bearer \(key)", forHTTPHeaderField: "authorization") }
    return r
  }
  static func modelIds(_ data: Data) -> [String] {
    guard let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
    let rows = (o["data"] as? [[String: Any]]) ?? (o["models"] as? [[String: Any]]) ?? []
    return rows.compactMap { ($0["id"] as? String) ?? ($0["name"] as? String) }.map { $0.replacingOccurrences(of: "models/", with: "") }
  }
}

public extension SSE {
  /// Text delta from one provider SSE `data:` payload (Anthropic or OpenAI-compatible). Port of the web's deltaFrom.
  static func delta(_ data: String) -> String {
    guard !data.isEmpty, data != "[DONE]", let d = data.data(using: .utf8), let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return "" }
    if j["type"] as? String == "content_block_delta", let dl = j["delta"] as? [String: Any], dl["type"] as? String == "text_delta" { return dl["text"] as? String ?? "" }
    if let ch = (j["choices"] as? [[String: Any]])?.first, let dl = ch["delta"] as? [String: Any], let c = dl["content"] as? String { return c }
    return ""
  }
  /// Friendly copy for a provider HTTP status (for the grown-up key check).
  static func keyProblem(_ status: Int, _ p: KeyProvider) -> String {
    switch status {
    case 401, 403: return "\(p.label) didn't accept that key. Check you copied all of it."
    case 402, 429: return "\(p.label) says this key is out of credit or busy. Check billing, then try again."
    case 404: return "\(p.label) doesn't offer that model to this key."
    default: return "Couldn't reach \(p.label) (\(status)). Try again in a moment."
    }
  }
}
