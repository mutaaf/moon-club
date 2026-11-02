import XCTest
@testable import MoonClubCore

final class BrainTests: XCTestCase {
  let ctx = LunaContext(weather: "Partly cloudy: people feel a little careful", companies: [
    .init(s: "NKE", nick: "Nike", hook: "makes sneakers", when: "in 3 days"),
    .init(s: "DIS", nick: "Disney", hook: "makes movies and parks", when: nil),
  ])

  // MARK: Router
  func testRouterPicksOnDeviceWhenAvailable() {
    XCTAssertEqual(BrainRouter.resolve(BrainSettings(), onDevice: .available, hasKey: false), .onDevice)
    XCTAssertEqual(BrainRouter.resolve(BrainSettings(), onDevice: .turnedOff, hasKey: false), .free)
    XCTAssertEqual(BrainRouter.resolve(BrainSettings(choice: .onDevice), onDevice: .notEligible, hasKey: true), .free)
    XCTAssertEqual(BrainRouter.resolve(BrainSettings(choice: .free), onDevice: .available, hasKey: true), .free)
  }
  func testByokNeverWithoutConsentOrKey() {
    var s = BrainSettings(choice: .byok, provider: .openai)
    XCTAssertEqual(BrainRouter.resolve(s, onDevice: .available, hasKey: true), .onDevice, "no consent → falls back")
    XCTAssertEqual(BrainRouter.resolve(s, onDevice: .downloading, hasKey: true), .free)
    s.consentFor = .anthropic // consent for a different provider doesn't count
    XCTAssertEqual(BrainRouter.resolve(s, onDevice: .unsupportedOS, hasKey: true), .free)
    s.consentFor = .openai
    XCTAssertEqual(BrainRouter.resolve(s, onDevice: .available, hasKey: false), .onDevice, "no key → falls back")
    XCTAssertEqual(BrainRouter.resolve(s, onDevice: .available, hasKey: true), .byok)
  }
  func testByokRequestNeedsConsentForThatProvider() throws {
    let p = LunaPrompt(question: "What is a share?", context: ctx, history: [], kind: .byok)
    XCTAssertNil(Requests.byok(.openai, key: "sk-x", model: "gpt-5-mini", prompt: p, consent: nil))
    XCTAssertNil(Requests.byok(.openai, key: "sk-x", model: "gpt-5-mini", prompt: p, consent: .anthropic))
    XCTAssertNil(Requests.byok(.openai, key: "  ", model: "gpt-5-mini", prompt: p, consent: .openai))
    let o = try XCTUnwrap(Requests.byok(.openai, key: "sk-x", model: "gpt-5-mini", prompt: p, consent: .openai))
    XCTAssertEqual(o.url?.absoluteString, "https://api.openai.com/v1/chat/completions")
    XCTAssertEqual(o.value(forHTTPHeaderField: "authorization"), "Bearer sk-x")
    let ob = try XCTUnwrap(JSONSerialization.jsonObject(with: o.httpBody!) as? [String: Any])
    XCTAssertEqual((ob["messages"] as? [[String: String]])?.first?["role"], "system")
    XCTAssertEqual(ob["reasoning_effort"] as? String, "low")
    let a = try XCTUnwrap(Requests.byok(.anthropic, key: "sk-ant", model: "claude-haiku-5-5", prompt: p, consent: .anthropic))
    XCTAssertEqual(a.value(forHTTPHeaderField: "x-api-key"), "sk-ant")
    XCTAssertNil(a.value(forHTTPHeaderField: "authorization"))
    let ab = try XCTUnwrap(JSONSerialization.jsonObject(with: a.httpBody!) as? [String: Any])
    XCTAssertTrue((ab["system"] as? String ?? "").contains("Never tell anyone to buy or sell"))
    XCTAssertEqual(ab["max_tokens"] as? Int, BrainCapabilities.of(.byok).maxTokens)
  }
  func testFreeBrainNeverSendsAKey() {
    let r = Requests.luna(question: "What is a share?", context: ctx)
    for h in ["x-mp-key", "x-api-key", "authorization"] { XCTAssertNil(r.value(forHTTPHeaderField: h)) }
    XCTAssertEqual(r.url?.host, "mutaafaziz.com")
  }

  // MARK: Prompt + memory
  func testPromptKeepsMemoryOnlyWhereAllowed() {
    let h = (0..<30).map { LunaTurn($0 % 2 == 0 ? .kid : .luna, "turn \($0)") }
    XCTAssertEqual(LunaPrompt(question: "q", context: ctx, history: h, kind: .free).history.count, 0)
    XCTAssertEqual(LunaPrompt(question: "q", context: ctx, history: h, kind: .onDevice).history.count, 8)
    XCTAssertEqual(LunaPrompt(question: "q", context: ctx, history: h, kind: .byok).history.count, 16)
    XCTAssertEqual(LunaPrompt(question: "q", context: ctx, history: h, kind: .byok).history.last?.text, "turn 29")
  }
  func testPromptFactsAndCap() {
    let p = LunaPrompt(question: "Why does Disney " + String(repeating: "x", count: 400), context: ctx, history: [], kind: .onDevice)
    XCTAssertEqual(p.question.count, 200)
    XCTAssertTrue(p.user.contains("Disney (DIS): makes movies"), "named company included")
    XCTAssertTrue(p.user.contains("Nike (NKE): makes sneakers. Shares its report card in 3 days"), "upcoming included")
    XCTAssertTrue(p.user.contains("Market weather today"))
    for k in BrainKind.allCases { XCTAssertTrue(LunaPrompts.system(k).hasPrefix(LunaPrompts.kidsSystem)) }
  }

  // MARK: Guard
  func testGuardRedirectsUnsafeAndAdvice() {
    XCTAssertEqual(LunaGuard.check("You should buy Nike today!", maxChars: 600).text, LunaGuard.redirect)
    XCTAssertEqual(LunaGuard.check("Let's talk about beer.", maxChars: 600).text, LunaGuard.redirect)
    XCTAssertEqual(LunaGuard.check("So, where do you live?", maxChars: 600).text, LunaGuard.redirect)
    XCTAssertTrue(LunaGuard.check("You should buy", maxChars: 600).stop)
    let ok = "Investing is not gambling. People buy shares to own a slice."
    XCTAssertEqual(LunaGuard.check(ok, maxChars: 600).text, ok)
  }
  func testGuardTrimsAndStripsLinks() {
    let long = String(repeating: "A share is a slice. ", count: 60)
    let g = LunaGuard.check(long, maxChars: 650)
    XCTAssertTrue(g.stop); XCTAssertLessThanOrEqual(g.text.count, 650); XCTAssertTrue(g.text.hasSuffix("."))
    XCTAssertEqual(LunaGuard.check("See https://evil.example now", maxChars: 600).text, "See  now")
    XCTAssertEqual(LunaGuard.check("Read [this](https://x.y) page", maxChars: 600).text, "Read this page")
  }

  // MARK: Providers
  func testModelPickAndDeltas() {
    XCTAssertEqual(KeyProvider.anthropic.pickModel(["claude-opus-5-5", "claude-haiku-4-5", "claude-haiku-5-5"]), "claude-haiku-5-5")
    XCTAssertEqual(KeyProvider.openai.pickModel(["gpt-4o", "gpt-5-mini", "gpt-5.1-mini"]), "gpt-5.1-mini")
    XCTAssertEqual(KeyProvider.xai.pickModel([]), "grok-4-fast")
    XCTAssertEqual(SSE.delta(#"{"type":"content_block_delta","delta":{"type":"text_delta","text":"Hi"}}"#), "Hi")
    XCTAssertEqual(SSE.delta(#"{"choices":[{"delta":{"content":"Yo"}}]}"#), "Yo")
    XCTAssertEqual(SSE.delta("[DONE]"), "")
    XCTAssertEqual(Requests.modelIds(Data(#"{"data":[{"id":"gpt-5-mini"}]}"#.utf8)), ["gpt-5-mini"])
    XCTAssertEqual(Requests.modelIds(Data(#"{"models":[{"name":"models/gemini-2.5-flash"}]}"#.utf8)), ["gemini-2.5-flash"])
    for p in KeyProvider.allCases { XCTAssertNil(Requests.models(p, key: "k").httpBody) }
  }

  // MARK: Router streams guarded snapshots
  struct Scripted: LunaBrain {
    let kind: BrainKind; let words: [String]
    func stream(_ p: LunaPrompt) -> AsyncThrowingStream<String, Error> { AsyncThrowingStream { c in for w in words { c.yield(w) }; c.finish() } }
  }
  func testRouterGuardsMidStream() async throws {
    let r = LunaRouter(brains: [Scripted(kind: .free, words: ["A share ", "is a slice. "]), Scripted(kind: .byok, words: ["Great! ", "You should buy ", "Nike."])], resolve: { .byok })
    var last = ""
    for try await s in r.ask("hi", context: ctx, history: []) { last = s }
    XCTAssertEqual(last, LunaGuard.redirect)
    let f = LunaRouter(brains: [Scripted(kind: .free, words: ["A share ", "is a slice."])], resolve: { .onDevice })
    XCTAssertEqual(f.activeBrain(), .free, "missing brain falls back to free")
    var snaps: [String] = []
    for try await s in f.ask("hi", context: ctx, history: []) { snaps.append(s) }
    XCTAssertEqual(snaps, ["A share ", "A share is a slice."])
  }
}
