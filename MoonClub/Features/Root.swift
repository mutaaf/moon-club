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

  var body: some View {
    Group {
      if hSize == .regular { split } else { tabs }
    }
    .overlay(alignment: .bottom) { BadgeToast() }
    .sheet(isPresented: $gate) { ParentGate { gate = false; grownUps = true } }
    .fullScreenCover(isPresented: $grownUps, onDismiss: { app.refreshBrain() }) { GrownUpsView() }
    .fullScreenCover(item: Binding(get: { quest.map(QuestRoute.init) }, set: { quest = $0?.id })) { r in QuestView(start: r.id) }
    .fullScreenCover(isPresented: Binding(get: { !whatsNew.isEmpty }, set: { if !$0 { whatsNew = [] } })) {
      WhatsNewModal(news: whatsNew) { whatsNew = [] }
    }
    .environment(\.openQuest, OpenQuest { quest = $0 })
    .environment(\.openTab, OpenTab { t in withAnimation(Motion.page) { tab = t } })
    .task { await app.loadMarket() }
    .onAppear {
      let args = ProcessInfo.processInfo.arguments
      if let s = args.firstIndex(of: "-quest") { quest = args[s + 1] }
      if quest == nil { whatsNew = WhatsNewStore.pending() }
      #if DEBUG
      if args.contains("-demo") && args.contains("-grownups") { grownUps = true } // screenshots only; release builds always use the gate
      if args.contains("-demo") && args.contains("-liveactivity") { LiveActivities.demo() } // simulator check of the real Live Activity
      #endif
    }
    .onOpenURL { url in if let t = app.open(url) { tab = t } }
    .tint(Palette.accent)
    .modifier(TracksHinge(duo: duo))
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

struct LevelPill: View {
  @Environment(AppModel.self) private var app
  @Environment(\.toolbarVertical) private var vertical
  var body: some View {
    let l = app.level
    HStack(spacing: 8) {
      MoonPhase(phase: l.index, size: 22)
      if !vertical {
        VStack(alignment: .leading, spacing: 0) {
          Text(l.name).font(.caption.weight(.bold))
          Text("\(app.points) pts").font(.caption2).monospacedDigit().foregroundStyle(.secondary).contentTransition(.numericText(value: Double(app.points)))
        }
      }
    }
    .padding(.horizontal, 10).padding(.vertical, 4)
    .fixedSize()
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Level: \(l.name), \(app.points) points")
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
        Text(l.next.map { "\($0 - app.points) points to \(app.content.levels[l.index + 1].name)" } ?? "Full Moon! You did it all.").font(.caption).foregroundStyle(.secondary)
      }
    }.padding(.vertical, 6)
  }
}

/// New-badge celebration: a compact pill that rises from the bottom, just above the tab bar, so it never
/// covers a title, a navigation bar or a prompt. Each badge is marked seen the moment it appears (so it
/// shows exactly once, even if the app is killed mid-toast), and the pill leaves by itself after 4 s.
struct BadgeToast: View {
  @Environment(AppModel.self) private var app
  @Environment(\.accessibilityReduceMotion) private var rm
  @State private var burst = 0
  @State private var showing: Badge?
  /// Space for the tab bar (or the bottom of the sidebar layout) under the pill.
  static let tabBarClearance: CGFloat = 92

  var body: some View {
    ZStack(alignment: .bottom) {
      Celebrate(trigger: burst).frame(height: 420)
      if let b = showing {
        HStack(spacing: 10) {
          MoonPhase(phase: b.phase, size: 28)
          Text("New badge: **\(b.name)**").font(.subheadline).lineLimit(1).minimumScaleFactor(0.8)
        }
        .padding(.leading, 10).padding(.trailing, 16).padding(.vertical, 8)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Hue.gold.color.opacity(0.6), lineWidth: 1))
        .shadow(color: .black.opacity(0.14), radius: 14, y: 6)
        .padding(.bottom, Self.tabBarClearance)
        .onTapGesture { withAnimation(Motion.safe(Motion.card, rm)) { showing = nil } }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .sensoryFeedback(.success, trigger: b.id)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("New badge: \(b.name). \(b.why)")
        .accessibilityAddTraits(.isButton)
      }
    }
    .allowsHitTesting(showing != nil)
    // Not `.task(id:)`: marking the badge seen changes that id, which would cancel the 4 s wait at once.
    .onChange(of: app.freshBadges.first?.id, initial: true) { _, id in
      guard id != nil, !busy else { return }
      busy = true
      Task { await present(); busy = false }
    }
  }
  @State private var busy = false

  /// Takes the next fresh badge, marks it seen at once, shows it for ~4 s, then looks for the next.
  private func present() async {
    guard showing == nil, let b = app.freshBadges.first else { return }
    app.mutate { $0.seeBadges([b.id]) }
    withAnimation(Motion.safe(Motion.celebrate, rm)) { showing = b }
    burst += 1
    try? await Task.sleep(for: .seconds(4))
    withAnimation(Motion.safe(Motion.card, rm)) { showing = nil }
    try? await Task.sleep(for: .milliseconds(400))
    if app.freshBadges.first != nil { await present() }
  }
}
