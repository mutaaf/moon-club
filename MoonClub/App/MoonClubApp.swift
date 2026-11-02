import SwiftUI
import MoonClubCore

/// Composition root: the only place that chooses live vs fake implementations.
///   default        → live services (read-only market data, Luna router: on-device / free / grown-up key, voice)
///   -demo          → offline fakes + a seeded week (screenshots, App Review demo)
///   -fresh         → with -demo, start from an empty progress file
///   -tab <name>    → open on a tab (story, guess, piggy, school, luna) for screenshots
///   -grownups      → (debug, with -demo) open the grown-up corner; -brain <kind> presets Luna's brain
///   -syncOn        → (with -demo) iCloud sync shown as on; -scrollSync scrolls the grown-up corner to it
@main
struct MoonClubApp: App {
  @State private var app: AppModel?
  @State private var loadError: String?

  init() {}

  var body: some Scene {
    WindowGroup {
      Group {
        if let app { RootView().environment(app) }
        else if let loadError { ContentErrorView(message: loadError) }
        else { Color(Palette.paper).ignoresSafeArea() }
      }
      .task { boot() }
    }
    // A second window for Luna's Word Book (iPhone Duo open, iPad): same model, same process.
    WindowGroup("Word Book", id: WordBookView.windowID, for: String.self) { $word in
      Group {
        if let app { WordBookView(start: word).environment(app) }
        else { Color(Palette.paper).ignoresSafeArea() }
      }
      .task { boot() }
    }
  }

  @MainActor private func boot() {
    guard app == nil else { return }
    do {
      let url = Bundle.main.url(forResource: "kids-content", withExtension: "json")!
      let content = try KidsContent.load(try Data(contentsOf: url))
      let args = ProcessInfo.processInfo.arguments
      let services: Services
      if args.contains("-demo") {
        let clock = FixedClock(args.firstIndex(of: "-today").map { args[$0 + 1] } ?? "2026-10-31")
        let seeded = args.contains("-fresh") ? KidsState() : Demo.seeded(today: clock.today())
        #if DEBUG
        // Screenshots: -brain onDevice|free|byok presets Luna's brain choice (demo only).
        if let i = args.firstIndex(of: "-brain"), let k = BrainKind(rawValue: args[i + 1]) { var b = BrainStore.load(); b.choice = k; BrainStore.save(b) }
        #endif
        services = Services(market: FakeMarket(today: clock.today()), luna: LunaRouter(brains: BrainKind.allCases.map(FakeBrain.init), resolve: { BrainStore.resolve() }), voice: FakeVoice(), store: MemoryStore(seeded), clock: clock, sync: DemoSync(on: args.contains("-syncOn")))
      } else {
        services = Services(market: LiveMarketData(), luna: LunaRouter(brains: [OnDeviceBrain(), FreeBrain(contentVersion: content.generated), ByokBrain()], resolve: { BrainStore.resolve() }), voice: LiveVoice(), store: FileProgressStore(), clock: SystemClock(), sync: ICloudSync())
      }
      app = AppModel(content: content, services: services)
    } catch {
      loadError = String(describing: error)
    }
  }
}

struct ContentErrorView: View {
  let message: String
  var body: some View {
    VStack(spacing: 16) {
      Luna(size: 80)
      Text("Luna lost her lesson book").font(.kTitle)
      Text("Please update Moon Club. (\(message))").font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
    }.padding(32)
  }
}
