import SwiftUI
import MoonClubCore

enum Tab: String, CaseIterable, Identifiable {
  case story, guess, piggy, school, luna
  var id: String { rawValue }
  var title: String { ["Story", "Guess", "Piggy Bank", "World", "Ask Luna"][Tab.allCases.firstIndex(of: self)!] }
  var icon: String { ["book.pages.fill", "target", "banknote.fill", "map.fill", "moon.stars.fill"][Tab.allCases.firstIndex(of: self)!] }
  var surface: Surface { [.story, .guess, .piggy, .school, .luna][Tab.allCases.firstIndex(of: self)!] }
}

/// Compact width (iPhone, iPhone Duo closed): a TabView — on iPhone Duo its bar moves to the side.
/// Regular width (iPad, iPhone Duo open): a NavigationSplitView, whose columns the system keeps clear of
/// the fold. Chosen by size class, never by device. Each scene owns one hinge listener (`DuoModel`).
struct RootView: View {
  @Environment(AppModel.self) private var app
  @Environment(\.horizontalSizeClass) private var hSize
  @State private var duo = DuoModel()
  @State private var tab: Tab = {
    let a = ProcessInfo.processInfo.arguments
    return a.firstIndex(of: "-tab").flatMap { Tab(rawValue: a[$0 + 1]) } ?? .story
  }()
  @State private var gate = false
  @State private var grownUps = false
  @State private var quest: String?
  @State private var whatsNew: [ReleaseNews] = []
  @State private var locker: LockerTab?
  @State private var lockerSlot: ShopSlot = .rocket
  @State private var ceremony: Int?

  var body: some View {
    Group {
      if hSize == .regular { split } else { tabs }
    }
    // The App colors pick repaints everything that reads Palette.accent (sheets above keep their state).
    .id(app.themeHex)
    .overlay(alignment: .bottom) { BadgeToast() }
    .sheet(isPresented: $gate) { ParentGate { gate = false; grownUps = true } }
    .fullScreenCover(isPresented: $grownUps, onDismiss: { app.refreshBrain() }) { GrownUpsView() }
    .fullScreenCover(item: Binding(get: { quest.map(QuestRoute.init) }, set: { quest = $0?.id })) { r in QuestView(start: r.id) }
    .fullScreenCover(isPresented: Binding(get: { !whatsNew.isEmpty }, set: { if !$0 { whatsNew = [] } })) {
      WhatsNewModal(news: whatsNew) { whatsNew = [] }
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
    .environment(\.openQuest, OpenQuest { quest = $0 })
    .environment(\.openTab, OpenTab { t in withAnimation(Motion.page) { tab = t } })
    .task { await app.loadMarket() }
    .task { app.checkIn() }
    .onAppear {
      let args = ProcessInfo.processInfo.arguments
      if let s = args.firstIndex(of: "-quest") { quest = args[s + 1] }
      if quest == nil { whatsNew = WhatsNewStore.pending() }
      #if DEBUG
      if args.contains("-demo") && args.contains("-grownups") { grownUps = true } // screenshots only; release builds always use the gate
      if args.contains("-demo") && args.contains("-liveactivity") { LiveActivities.demo() } // simulator check of the real Live Activity
      // Screenshots: -locker badges|shop|points [-slot rocket|hat|…] opens the Moon Locker.
      if args.contains("-demo"), let i = args.firstIndex(of: "-locker"), i + 1 < args.count { locker = LockerTab(rawValue: args[i + 1]) }
      if args.contains("-demo"), let i = args.firstIndex(of: "-slot"), i + 1 < args.count { lockerSlot = ShopSlot(rawValue: args[i + 1]) ?? .rocket }
      #endif
    }
    .onOpenURL { url in if let t = app.open(url) { tab = t } }
    .tint(Palette.accent)
    .modifier(TracksHinge(duo: duo))
  }

  private func showRank(_ r: Int?) {
    guard let r, ceremony == nil, !PlayActivity.shared.playing, whatsNew.isEmpty, quest == nil else { return }
    Task { try? await Task.sleep(for: .milliseconds(700)); if !PlayActivity.shared.playing, app.pendingRank == r { ceremony = r } }
  }

  private var tabs: some View {
    TabView(selection: $tab) {
      ForEach(Tab.allCases) { t in
        NavigationStack { screen(t).toolbar { topBar } }
          .tabItem { Label(t.title, systemImage: t.icon) }
          .tag(t)
      }
    }
  }

  private var split: some View {
    NavigationSplitView {
      List(selection: Binding(get: { tab }, set: { if let v = $0 { tab = v } })) {
        Section { LevelRow().listRowBackground(Color.clear) }
        Section("Club") { ForEach(Tab.allCases) { t in Label(t.title, systemImage: t.icon).tag(t).font(.kHeadline).padding(.vertical, 6) } }
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
    Button(action: action) {
      if vertical { Image(systemName: "lock.shield").font(.title3) }
      else { Text("For grown-ups").font(.footnote.weight(.semibold)) }
    }
    .foregroundStyle(Palette.ink2)
    .frame(minWidth: 44, minHeight: 44)
    .accessibilityLabel("For grown-ups")
  }
}

/// The header pill: rank (with a ring filling toward the next one) and Moon points to spend. Tap opens
/// the Moon Locker (badges, the Moon Shop, where points came from).
struct LevelPill: View {
  @Environment(AppModel.self) private var app
  @Environment(\.toolbarVertical) private var vertical
  @Environment(\.openLocker) private var openLocker
  var body: some View {
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
