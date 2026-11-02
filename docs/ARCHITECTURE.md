# Architecture

```
            ┌──────────────────────── MoonClubApp (composition root) ───────────────────────┐
            │  live:  LiveMarketData · LunaRouter · LiveVoice · FileProgressStore · SystemClock│
            │  -demo: FakeMarket     · LunaRouter · FakeVoice · MemoryStore       · FixedClock│
            └───────────────────────────────┬───────────────────────────────────────────────┘
                                            │ Services (protocols)
                                   ┌────────▼────────┐   intents    ┌──────────────────────┐
   SwiftUI Features  ──reads────▶  │    AppModel     │ ───────────▶ │ KidsState reducers   │
   (Story, Guess, Piggy,  ◀─────── │  @Observable    │ ◀──new state │ (pure, MoonClubCore) │
    School, Quests, Luna, ...)     └────────┬────────┘              └──────────────────────┘
                                            │ derived: points, level, badges, recap, chapters
                                   ┌────────▼────────────────────────────────────────────┐
                                   │ MoonClubCore: content model + validation, logic,     │
                                   │ League codec, quest math, LayeredCache, requests     │
                                   └──────────────────────────────────────────────────────┘
        kids-content.json  ◀── metaphases `npm run export:kids` (content + test vectors)
```

| Principle | Where |
|---|---|
| **Single source of truth** | Content comes only from `kids-content.json`, exported from the web repo. `VectorTests` proves the Swift logic matches the web's for every exported vector. |
| **Separation of concerns / decoupling** | `MoonClubCore` imports Foundation only (no UIKit/SwiftUI) and builds and tests on macOS. Every outside boundary is a protocol in `Services.swift`: `MarketDataSource`, `LunaService`, `VoiceService`, `ProgressStore`, `Clock`. |
| **Dependency injection** | `MoonClubApp.boot()` is the only place that picks live or fake implementations. Views get the one `AppModel` from the environment; there are no singletons beyond the composition root (plus the debug-only `FrameProbe`). |
| **Unidirectional data flow** | Views send intents (`app.mutate { $0.guess(...) }`). Pure reducers on `KidsState` return the new state. `AppModel` persists it atomically and views re-render from derived values. |
| **Pure functions, testability** | All logic is a pure function of its inputs: dates are ISO strings, and `Clock` is injected so tests use a fixed day. |
| **Errors as values** | `KidError` carries friendly copy. Content loading returns a typed `LoadError` (unsupported version, invalid), shown by `ContentErrorView` instead of a crash. |
| **Versioned, schema-validated content** | `KidsContent.load` checks `version` and then `validate()`: unique ids, units exist, answers in range, sorts have 2 buckets, ≤ 32 companies (5-bit League codes), levels ascending. |
| **Caching** | `LayeredCache`, layered memory → disk (LRU, byte cap) → network, with per-endpoint TTLs and stale-while-revalidate. If the network fails, it serves the last good copy (up to `maxStale`). A `Coalescer` keeps one load in flight per key. Luna answers are cached for 7 days, keyed by the normalized question plus the content version. Voice clips are cached on disk by text and voice (24 MB LRU). |
| **Luna's brains** | `LunaService` is a `LunaRouter` (MoonClubCore `Brain.swift`) over three `LunaBrain`s: `OnDeviceBrain` (FoundationModels, iOS 26+, nothing leaves the device), `FreeBrain` (the Metaphases free model, no key), `ByokBrain` (a grown-up's own Anthropic/OpenAI/Gemini/xAI key, sent straight to the provider). `BrainRouter.resolve` is pure: automatic = on-device when available, else free; BYOK needs a key **and** consent for that provider, or it falls back. The router re-resolves on every question, builds one `LunaPrompt` (same kid-safe system prompt, mirrored from the web's `KIDS_SYSTEM`), and streams **guarded cumulative snapshots** through `LunaGuard` (link stripping, a length cap per brain, and a blocklist → gentle redirect, applied mid-stream). `BrainCapabilities` says what each brain unlocks: memory turns, "Explain more", length. Settings live in UserDefaults (`moonclub.brain.v1`); the key lives only in the Keychain (`…lunakey`). |
| **Safety rules as code** | `Requests.luna` has no key parameter at all. `Requests.byok` returns nil unless the saved consent is for that provider. `Requests.speak` returns nil for kid-typed text (`SpeakSource.mayUseKey`). `scripts/check-rules.sh` allows a key header only inside `Requests.byok` / `models` / `speak`, forbids hard-coded consent, and forbids links out and `openURL` outside `GrownUps.swift`, remote packages and analytics SDK imports. Unit tests cover the request builders. |
| **Performance** | `AuroraField` is one full-screen Metal `colorEffect` layer at ≤ 30 fps (`TimelineView(.animation(minimumInterval:))`), with no textures and no per-frame allocations. It pauses off-screen, in the background and in Low Power Mode, and shows a still frame under Reduce Motion. A debug `FrameProbe` logs the average frame interval every 120 frames (Console, category "aurora"). Celebrations are drawn in a single `Canvas`. |
| **Accessibility** | Dynamic Type throughout (system text styles); VoiceOver labels on every custom control; 44pt targets; Reduce Motion respected by aurora, particles, transitions and Luna's bob/blink. |
