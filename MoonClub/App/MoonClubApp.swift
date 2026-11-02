import SwiftUI
import MoonClubCore

/// Composition root: the only place that chooses live vs fake implementations.
///   default        → live services (read-only market data, free Luna, device voice / grown-up key)
///   -demo          → offline fakes + a seeded week (screenshots, App Review demo)
///   -fresh         → with -demo, start from an empty progress file
///   -tab <name>    → open on a tab (story, guess, piggy, school, luna) for screenshots
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
        services = Services(market: FakeMarket(today: clock.today()), luna: FakeLuna(), voice: FakeVoice(), store: MemoryStore(seeded), clock: clock)
      } else {
        services = Services(market: LiveMarketData(), luna: LiveLuna(contentVersion: content.generated), voice: LiveVoice(), store: FileProgressStore(), clock: SystemClock())
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
