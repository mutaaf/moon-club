import SwiftUI
import MoonClubCore

enum Tab: String, CaseIterable, Identifiable {
  case story, guess, piggy, school, luna
  var id: String { rawValue }
  var title: String { ["Story", "Guess", "Piggy Bank", "World", "Ask Luna"][Tab.allCases.firstIndex(of: self)!] }
  var icon: String { ["book.pages.fill", "target", "banknote.fill", "map.fill", "moon.stars.fill"][Tab.allCases.firstIndex(of: self)!] }
  var surface: Surface { [.story, .guess, .piggy, .school, .luna][Tab.allCases.firstIndex(of: self)!] }
  /// The tab a deep link lands on. Links that change settings (`needsGrownUp`) have none: they go through the gate.
  init?(link: DeepLink) {
    switch link {
    case .home: self = .story
    case .world, .lesson: self = .school
    case .guess, .gameNight: self = .guess
    case .piggy, .garden: self = .piggy
    case .luna: self = .luna
    case .league, .pack: return nil
    }
  }
}

/// Compact width (iPhone, iPhone Duo closed): a TabView — on iPhone Duo its bar moves to the side.
/// Regular width (iPad, iPhone Duo open): a NavigationSplitView, whose columns the system keeps clear of
/// the fold. Chosen by size class, never by device. Each scene owns one hinge listener (`DuoModel`).
struct RootView: View {
  @Environment(AppModel.self) private var app
  @Environment(\.horizontalSizeClass) private var hSize
  @Environment(\.colorScheme) private var scheme
  @State private var duo = DuoModel()
  @State private var tab: Tab = {
    let a = ProcessInfo.processInfo.arguments
    return a.firstIndex(of: "-tab").flatMap { Tab(rawValue: a[$0 + 1]) } ?? .story
  }()
  @State private var gate = false
  @State private var grownUps = false
  /// A settings link (Family League code, lesson pack) waiting for the parental gate; shown in the grown-up corner.
  @State private var grownUpsLink: DeepLink?
  @State private var quest: String?
  @State private var whatsNew: ReleaseNews?
  @State private var locker: LockerTab?
  @State private var lockerSlot: ShopSlot = .rocket
  @State private var ceremony: Int?
  @State private var duoCoach = false
  @State private var sleepy = false
  /// iPhone Duo closed outside of play: Luna's pocket on the outer display (0.14).
  @State private var pocket = ProcessInfo.processInfo.arguments.contains("-pocket")
  @State private var bedtime = BedtimeClock.shared
  @State private var windowSafe = CGRect.zero
  /// iPad sidebar: shown or hidden (debug `-sidebar hidden` for screenshots).
  @State private var columns: NavigationSplitViewVisibility = {
    #if DEBUG
    let a = ProcessInfo.processInfo.arguments
    if let i = a.firstIndex(of: "-sidebar"), i + 1 < a.count { return a[i + 1] == "hidden" ? .detailOnly : .all }
    #endif
    return .automatic
  }()
  @Environment(\.scenePhase) private var phase

  var body: some View {
    let _ = Perf.body("RootView")
    Group {
      if hSize == .regular { split } else { tabs }
    }
    // The App colors pick repaints everything that reads Palette.accent (sheets above keep their state).
    .id(app.themeHex)
    .modifier(PartyShake())
    .overlay { FoldSeam() }
    .overlay { if pocket { LunaPocket { withAnimation(Motion.fade) { pocket = false } }.transition(.opacity) } }
    .onChange(of: duo.closedTick) { _, _ in if !PlayActivity.shared.playing, quest == nil { withAnimation(Motion.fade) { pocket = true } } }
    .onChange(of: duo.reading?.status) { _, s in if s != nil, s != .closed, duo.pinned == nil { withAnimation(Motion.fade) { pocket = false } } }        // iPhone Duo: the crease's soft shadow follows the hinge (0.14)
    .overlay { PartyOverlay() }
    .overlay(alignment: .bottom) { BadgeToast() }
    #if DEBUG
    .overlay { if ProcessInfo.processInfo.arguments.contains("-safearea") { SafeAreaDebug() } }
    #endif
    // iPhone Duo: "Fold me like a book!" once, the first time this device reports a hinge.
    .sheet(isPresented: $duoCoach) { DuoCoach { DuoCoachStore.markSeen(); duoCoach = false }.presentationDetents([.large]) }
    .onChange(of: duo.hasHinge, initial: true) { _, has in showDuoCoach(has) }
    // Healthy screen time: after ~20 minutes, between games, Luna gets sleepy (never mid-game).
    .sheet(isPresented: $sleepy) {
      GoodnightSheet(goodnight: { sleepy = false; bedtime.lastAsked = Date() }, oneMore: { sleepy = false; bedtime.lastAsked = Date() })
        .presentationDetents([.height(440)]).presentationCornerRadius(32)
    }
    .task {
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(30))
        if bedtime.sleepy(), !PlayActivity.shared.playing, !sleepy, ceremony == nil, whatsNew == nil { bedtime.lastAsked = Date(); sleepy = true }
      }
    }
    .onChange(of: phase) { old, new in if new == .active && old == .background { bedtime.newSession() } }
    .sheet(isPresented: $gate, onDismiss: { if !grownUps { grownUpsLink = nil } }) { ParentGate { gate = false; grownUps = true } }
    .fullScreenCover(isPresented: $grownUps, onDismiss: { grownUpsLink = nil; app.refreshBrain() }) { GrownUpsView(link: grownUpsLink).modifier(DebugWindow()) }
    .fullScreenCover(item: Binding(get: { quest.map(QuestRoute.init) }, set: { quest = $0?.id })) { r in QuestView(start: r.id) }
    .fullScreenCover(isPresented: Binding(get: { whatsNew != nil }, set: { if !$0 { whatsNew = nil } })) {
      if let n = whatsNew { WhatsNewModal(news: n) { whatsNew = nil }.readsCameraCorner() }
    }
    .sheet(item: $locker) { t in MoonLocker(tab: t, slot: lockerSlot).presentationCornerRadius(32) }
    .fullScreenCover(item: Binding(get: { ceremony.map(RankRoute.init) }, set: { ceremony = $0?.id })) { r in
      RankCeremony(index: r.id) { shop in
        app.mutate { $0.seeRank(r.id) }
        ceremony = nil
        if shop { Task { try? await Task.sleep(for: .milliseconds(450)); locker = .shop } }
      }
    }
    // A new rank gets its ceremony once play is over (never on top of a results screen).
    .onChange(of: app.pendingRank, initial: true) { _, r in showRank(r) }
    .onChange(of: PlayActivity.shared.playing) { _, _ in showRank(app.pendingRank) }
    .environment(\.openLocker, OpenLocker { t in locker = t })
    .environment(\.lunaLook, app.lunaLook)
    // The window's safe area, for sheets that are laid out taller than the screen (`ScrollsWhenShort`).
    .environment(\.windowSafeFrame, windowSafe)
    .background(GeometryReader { g in
      Color.clear
        .onAppear { windowSafe = g.frame(in: .global) }
        .onChange(of: g.frame(in: .global)) { _, f in windowSafe = f }
    })
    // Where the camera is (occlusion regions): iPhone Duo's outer display has it top-trailing, beside a
    // trailing Skip. Sheets inherit this; full-screen covers (What's New) read their own.
    .readsCameraCorner()
    .environment(\.openQuest, OpenQuest { quest = $0 })
    .environment(\.openTab, OpenTab { t in withAnimation(Motion.page) { tab = t } })
    .task { await app.loadMarket() }
    .task { app.checkIn(); celebrateStreak() }
    .task { await bench() }
    .task { try? await Task.sleep(for: .seconds(1.5)); Ready.mark("root") }
    .onAppear {
      let args = ProcessInfo.processInfo.arguments
      if let s = args.firstIndex(of: "-quest") { quest = args[s + 1] }
      if quest == nil { whatsNew = WhatsNewStore.pending() }
      #if DEBUG
      if args.contains("-demo") && args.contains("-grownups") { grownUps = true } // screenshots only; release builds always use the gate
      // Screenshots: -link <url> follows a deep link at launch; with -grownups a settings link shows its offer directly.
      if args.contains("-demo"), let i = args.firstIndex(of: "-link"), i + 1 < args.count, let u = URL(string: args[i + 1]) {
        if args.contains("-grownups") { let l = app.open(u); if l.needsGrownUp { grownUpsLink = l } } else { Task { try? await Task.sleep(for: .seconds(1)); follow(u) } }
      }
      if args.contains("-demo") && args.contains("-liveactivity") { LiveActivities.demo() } // simulator check of the real Live Activity
      // Screenshots: -locker badges|shop|points [-slot rocket|hat|…] opens the Moon Locker.
      if args.contains("-demo"), let i = args.firstIndex(of: "-locker"), i + 1 < args.count {
        Task { if args.contains("-orient") { try? await Task.sleep(for: .seconds(1.5)) }; locker = LockerTab(rawValue: args[i + 1]) } // after -orient turns the window
      }
      if args.contains("-demo"), let i = args.firstIndex(of: "-slot"), i + 1 < args.count { lockerSlot = ShopSlot(rawValue: args[i + 1]) ?? .rocket }
      // Party Moon screenshots: -sleepy (goodnight sheet), -duocoach (iPhone Duo coach), -party small|medium|large.
      if args.contains("-demo") && args.contains("-sleepy") { Task { try? await Task.sleep(for: .seconds(1)); sleepy = true } }
      if args.contains("-demo") && args.contains("-duocoach") { Task { if args.contains("-orient") { try? await Task.sleep(for: .seconds(1.5)) }; duoCoach = true } } // after -orient has turned the window
      // Screenshots: -orient landscape|landscapeLeft|portrait rotates the window scene (the simulator has no rotate command).
      if let i = args.firstIndex(of: "-orient"), i + 1 < args.count {
        // On the iPhone Duo's outer display this really rotates: `landscape` puts the camera top-left, `landscapeLeft` bottom-right.
        let mask: UIInterfaceOrientationMask = ["landscape": .landscapeRight, "landscapeLeft": .landscapeLeft][args[i + 1]] ?? .portrait
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { _ in }
      }
      if args.contains("-demo"), let i = args.firstIndex(of: "-party"), i + 1 < args.count {
        let m: PartyMoment = ["small": .right, "medium": .perfectRound, "large": .landWon][args[i + 1]] ?? .landWon
        Task { for _ in 0..<3 { try? await Task.sleep(for: .seconds(1.2)); PartyCenter.shared.fire(m, title: "Land won!") ; try? await Task.sleep(for: .seconds(3)) } }
      }
      #endif
    }
    // Universal links (mutaafaziz.com/metaphases/kids/…) and moonclub:// both arrive here (docs/LINKS.md).
    .onOpenURL { url in follow(url) }
    .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { a in if let url = a.webpageURL { follow(url) } }
    .tint(Palette.accent)
    .modifier(TracksHinge(duo: duo))
  }

  /// Follow a link from outside the app. Kid places switch the tab (closing the grown-up corner, a quest or the
  /// locker on the way). Settings never skip the gate: the gate opens, and only a grown-up who passes it sees the
  /// link's offer in the grown-up corner. Unknown links resolve to Home (MoonClubCore `DeepLink`).
  private func follow(_ url: URL) {
    let link = app.open(url)
    if link.needsGrownUp {
      grownUps = false; quest = nil; locker = nil
      grownUpsLink = link
      gate = true
      return
    }
    grownUps = false; gate = false; quest = nil; locker = nil
    if let t = Tab(link: link) { withAnimation(Motion.page) { tab = t } }
  }

  /// Debug `-bench`: one fixed script so performance can be compared before and after a change.
  /// Each phase prints body re-evaluations per view and frame/hitch stats (see Design/Perf.swift).
  private func bench() async {
    #if DEBUG
    guard Perf.on, Perf.mode != "school" else { return } // `-bench school` runs inside SchoolView (it scrolls the list)
    let mon = FrameMonitor()
    // `-bench world` / `-bench launch`: the first seconds of the World map, in 0.5 s windows.
    if Perf.mode == "world" || Perf.mode == "launch" {
      if Perf.mode == "world" { try? await Task.sleep(for: .seconds(6)) }
      Perf.reset(); mon.start()
      if Perf.mode == "world" { tab = .school }
      try? await Task.sleep(for: .seconds(Perf.mode == "world" ? 8 : 10)); mon.stop()
      for line in mon.buckets(0.5) { print("BENCH \(Perf.mode ?? "") \(line)") }
      print(Perf.report(Perf.mode ?? "") + " " + mon.summary)
      print("BENCH done"); fflush(stdout)
      return
    }
    // `-bench screen`: measure whatever screen the other launch args opened (`-play`, `-locker`, `-party`,
    // `-gamenight`…): 4 s to settle, then two windows — the first 3 s (effects running) and 3 s settled.
    if Perf.screen {
      try? await Task.sleep(for: .seconds(4))
      Perf.reset(); mon.start(); try? await Task.sleep(for: .seconds(3)); mon.stop()
      print(Perf.report("screen") + " " + mon.summary); fflush(stdout)
      try? await Task.sleep(for: .seconds(4))
      Perf.reset(); mon.start(); try? await Task.sleep(for: .seconds(3)); mon.stop()
      print(Perf.report("screenSettled") + " " + mon.summary); fflush(stdout)
      print("BENCH done"); fflush(stdout)
      return
    }
    try? await Task.sleep(for: .seconds(4))
    func phase(_ name: String, _ work: () async -> Void) async {
      Perf.reset(); mon.start()
      await work()
      mon.stop(); print(Perf.report(name) + " " + mon.summary); fflush(stdout)
    }
    await phase("idle3s") { try? await Task.sleep(for: .seconds(3)) }
    await phase("tabs") {
      for t in [Tab.guess, .piggy, .school, .luna, .story] { withAnimation(Motion.page) { tab = t }; try? await Task.sleep(for: .seconds(1.5)) }
    }
    await phase("bank10") {
      for i in 0..<10 { app.mutate { $0.bank(.game, "bench\(i)", points: 3, today: app.today) }; try? await Task.sleep(for: .milliseconds(250)) }
    }
    await phase("piggyIdle3s") { tab = .piggy; try? await Task.sleep(for: .seconds(3)) }
    await phase("worldIdle3s") { tab = .school; try? await Task.sleep(for: .seconds(3)) }
    try? await Task.sleep(for: .seconds(5))
    await phase("worldSettled3s") { try? await Task.sleep(for: .seconds(3)) }
    // Steady state: back on the Story after its aurora has settled (it drifts for 6 s after a screen appears).
    tab = .story; try? await Task.sleep(for: .seconds(7))
    await phase("storySettled3s") { try? await Task.sleep(for: .seconds(3)) }
    print("BENCH done"); fflush(stdout)
    #endif
  }

  private func showDuoCoach(_ has: Bool) {
    guard has, !DuoCoachStore.seen, !ProcessInfo.processInfo.arguments.contains("-demo") else { return }
    Task { try? await Task.sleep(for: .seconds(1.2)); if whatsNew == nil, quest == nil { duoCoach = true } }
  }

  /// A streak milestone (3, 7, 30 days…) gets its own party once on that day.
  private func celebrateStreak() {
    let n = Streak.days(Streak.activeDays(app.state), today: app.today)
    let key = "party.streakDay"
    guard StreakMilestone.isMilestone(n), UserDefaults.standard.string(forKey: key) != app.today else { return }
    UserDefaults.standard.set(app.today, forKey: key)
    Task { try? await Task.sleep(for: .seconds(1.5)); PartyCenter.shared.fire(.streak(n), title: StreakMilestone.title(n)) }
  }

  private func showRank(_ r: Int?) {
    guard let r, ceremony == nil, !PlayActivity.shared.playing, whatsNew == nil, quest == nil else { return }
    Task { try? await Task.sleep(for: .milliseconds(700)); if !PlayActivity.shared.playing, app.pendingRank == r { ceremony = r } }
  }

  /// The tab holding the Story's Start here step, when it isn't Story (it gets a small glowing dot).
  private var dotTab: Tab? {
    NextUp.dotTab(NextUp.step(app.today, app.state, app.content)).flatMap { Tab(rawValue: $0.rawValue) }
  }

  private var tabs: some View {
    let dot = dotTab
    return TabView(selection: $tab) {
      ForEach(Tab.allCases) { t in
        NavigationStack {
          screen(t).toolbar { topBar }
          #if DEBUG
            .overlay { if ProcessInfo.processInfo.arguments.contains("-safearea") { SafeAreaDebug(tag: "tab-\(t.rawValue)") } }
          #endif
        }
          .tabItem {
            // The tab holding the Start here step gets a small glowing dot drawn into its icon (TabIcon).
            if dot == t, tab != t {
              Label { Text(t.title) } icon: { Image(uiImage: TabIcon.dotted(t.icon, dark: scheme == .dark)) }
                .accessibilityHint("Your next step is here")
            } else {
              Label(t.title, systemImage: t.icon)
            }
          }
          .tag(t)
      }
    }
  }

  private var split: some View {
    NavigationSplitView(columnVisibility: $columns) {
      List(selection: Binding(get: { tab }, set: { if let v = $0 { tab = v } })) {
        Section { LevelRow().listRowBackground(Color.clear) }
        Section("Club") {
          let dot = dotTab
          ForEach(Tab.allCases) { t in
            HStack {
              Label(t.title, systemImage: t.icon)
              if dot == t, tab != t { Spacer(minLength: 4); GlowDot() }
            }
            .accessibilityElement(children: .combine)
            .accessibilityHint(dot == t && tab != t ? "Your next step is here" : "")
            .tag(t).font(.kHeadline).padding(.vertical, 6)
          }
        }
        Section("Quests") {
          ForEach(app.content.questChapters?.CHAPTERS ?? [], id: \.id) { ch in
            Button { quest = ch.id } label: { Label { Text(ch.title) } icon: { Glyph(ch.emoji, size: 24) } }
              .badge(app.chaptersDone.contains(ch.id) ? Text("✓") : nil)
          }
        }
        Section { Button { gate = true } label: { Label("For grown-ups", systemImage: "lock.shield") } }
      }
      .navigationTitle("Moon Club")
      .listStyle(.sidebar)
    } detail: {
      NavigationStack { screen(tab) }
    }
  }

  @ViewBuilder private func screen(_ t: Tab) -> some View {
    switch t {
    case .story: StoryView()
    case .guess: GuessView()
    case .piggy: PiggyView()
    case .school: WorldView()
    case .luna: AskLunaView()
    }
  }

  /// On iPhone Duo these bars go vertical. The grown-ups gate is pinned (it never overflows) and both
  /// items carry a title + symbol so the system can pick the form that fits the bar (Apple's HIG).
  @ToolbarContentBuilder private var topBar: some ToolbarContent {
    if #available(iOS 27.1, *) {
      ToolbarItem(placement: .topBarLeading) { LevelPill() }
        .visibilityPriority(.high)
      ToolbarItem(placement: .topBarPinnedTrailing) { GrownUpsButton { gate = true } }
    } else {
      ToolbarItem(placement: .topBarLeading) { LevelPill() }
      ToolbarItem(placement: .topBarTrailing) { GrownUpsButton { gate = true } }
    }
  }
}

struct QuestRoute: Identifiable { let id: String }
struct RankRoute: Identifiable { let id: Int }
struct OpenQuest { let open: (String) -> Void; func callAsFunction(_ id: String) { open(id) } }
private struct OpenQuestKey: EnvironmentKey { static let defaultValue = OpenQuest { _ in } }
extension EnvironmentValues { var openQuest: OpenQuest { get { self[OpenQuestKey.self] } set { self[OpenQuestKey.self] = newValue } } }

/// The grown-ups gate button: text in a horizontal bar, a lock symbol in a vertical one.
struct GrownUpsButton: View {
  let action: () -> Void
  @Environment(\.toolbarVertical) private var vertical
  var body: some View {
    if vertical {
      // A plain system Label in a vertical bar, sized and drawn by the bar like its own items. The old fixed
      // 44 pt frame + tinted image drew an empty capsule on iPhone Duo's outer display in landscape.
      Button(action: action) { Label("For grown-ups", systemImage: "lock.shield") }
        .labelStyle(.iconOnly)
        .accessibilityLabel("For grown-ups")
    } else {
      Button(action: action) { Text("For grown-ups").font(.footnote.weight(.semibold)) }
        .foregroundStyle(Palette.ink2)
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityLabel("For grown-ups")
    }
  }
}

/// The header pill: rank (with a ring filling toward the next one) and Moon points to spend. Tap opens
/// the Moon Locker (badges, the Moon Shop, where points came from).
struct LevelPill: View {
  @Environment(AppModel.self) private var app
  @Environment(\.toolbarVertical) private var vertical
  @Environment(\.openLocker) private var openLocker
  var body: some View {
    let _ = Perf.body("LevelPill")
    let l = app.level
    Button { openLocker(.badges) } label: {
      HStack(spacing: 8) {
        RankBadge(index: l.index, progress: l.progress, size: 28)
        if !vertical {
          VStack(alignment: .leading, spacing: 0) {
            Text(l.name).font(.caption.weight(.bold)).foregroundStyle(Palette.ink)
            HStack(spacing: 3) {
              PointsMark(size: 11)
              Text("\(app.wallet)").font(.caption2.weight(.bold)).monospacedDigit().foregroundStyle(Palette.ink2).contentTransition(.numericText(value: Double(app.wallet)))
              Text("· \(app.earnedCount)").font(.caption2.weight(.bold)).foregroundStyle(Palette.ink2)
              Image(systemName: "rosette").font(.system(size: 9, weight: .bold)).foregroundStyle(Palette.ink2)
            }
          }
        }
      }
      .padding(.horizontal, 10).padding(.vertical, 4)
      .fixedSize()
    }
    .buttonStyle(PressStyle())
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(l.name). \(app.wallet) Moon points to spend, \(app.earnedCount) badges. Opens your badges and the Moon Shop.")
  }
}

struct LevelRow: View {
  @Environment(AppModel.self) private var app
  var body: some View {
    let _ = Perf.body("LevelRow")
    let l = app.level
    HStack(spacing: 14) {
      Luna(size: 48, wave: true)
      VStack(alignment: .leading, spacing: 6) {
        Text(l.name).font(.kHeadline)
        ProgressView(value: l.progress).tint(Palette.accent)
        Text(l.next.map { "\($0 - app.points) points to \(app.nextRankName ?? "the next moon")" } ?? "The biggest moon of all!").font(.caption).foregroundStyle(.secondary)
      }
    }.padding(.vertical, 6)
  }
}
