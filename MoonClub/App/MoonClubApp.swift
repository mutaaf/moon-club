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
  @Environment(\.scenePhase) private var phase

  init() {}

  var body: some Scene {
    WindowGroup {
      Group {
        if let app { RootView().environment(app) }
        else if let loadError { ContentErrorView(message: loadError) }
        else { Color(Palette.paper).ignoresSafeArea() }
      }
      .task { boot() }
      .onChange(of: phase) { _, p in if p == .active { app?.reloadFromStore(); app?.checkIn() } }
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
        var seeded = args.contains("-fresh") ? KidsState() : Demo.seeded(today: clock.today())
        // Screenshots: -world mid|all seeds Market World progress (mid = three lands won; all = everything).
        if let i = args.firstIndex(of: "-world"), i + 1 < args.count { seeded = Demo.world(seeded, content: content, lands: args[i + 1] == "all" ? 99 : 3) }
        // Screenshots never carry a stale badge toast: demo badges start seen (-toast keeps them fresh to film the toast).
        if !args.contains("-toast") {
          seeded.seeBadges(seeded.badges(content))
          seeded.seeBadges(Trophies.progress(seeded, content).flatMap { p in (0...p.tier).dropFirst().map { Trophies.key(p, tier: $0) } })
        }
        // Screenshots: -points <n> banks spendable points; -rank shows the ceremony for the current rank.
        if let i = args.firstIndex(of: "-points"), i + 1 < args.count, let n = Int(args[i + 1]) { seeded.bank(.game, "demo", points: n, today: clock.today()) }
        if !args.contains("-rank") { seeded.seeRank(seeded.level(content).index) }
        if let i = args.firstIndex(of: "-equip"), i + 1 < args.count {
          for id in args[i + 1].split(separator: ",").map(String.init) { var o = Set(seeded.owned ?? []); o.insert(id); seeded.owned = o.sorted(); seeded.equip(id, nowMillis: 1) }
        }
        #if DEBUG
        // Screenshots: -brain onDevice|free|byok presets Luna's brain choice (demo only).
        if let i = args.firstIndex(of: "-brain"), let k = BrainKind(rawValue: args[i + 1]) { var b = BrainStore.load(); b.choice = k; BrainStore.save(b) }
        #endif
        services = Services(market: FakeMarket(today: clock.today()), luna: LunaRouter(brains: BrainKind.allCases.map(FakeBrain.init), resolve: { BrainStore.resolve() }), voice: FakeVoice(), store: MemoryStore(seeded), clock: clock, sync: DemoSync(on: args.contains("-syncOn")))
      } else {
        services = Services(market: LiveMarketData(), luna: LunaRouter(brains: [OnDeviceBrain(), FreeBrain(contentVersion: content.generated), ByokBrain()], resolve: { BrainStore.resolve() }), voice: LiveVoice(), store: SharedProgressStore(), clock: SystemClock(), sync: ICloudSync())
      }
      let model = AppModel(content: content, services: services)
      if !args.contains("-demo") {
        model.candleLoader = { await LiveMarketData.kidsCandles(Array(AppModel.bundledCandles.keys)) }
        Task { await model.refreshCandles() }
      }
      app = model
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
