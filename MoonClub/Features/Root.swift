import SwiftUI
import MoonClubCore

enum Tab: String, CaseIterable, Identifiable {
  case story, guess, piggy, school, luna
  var id: String { rawValue }
  var title: String { ["Story", "Guess", "Piggy Bank", "Moon School", "Ask Luna"][Tab.allCases.firstIndex(of: self)!] }
  var icon: String { ["book.pages.fill", "target", "banknote.fill", "graduationcap.fill", "moon.stars.fill"][Tab.allCases.firstIndex(of: self)!] }
  var surface: Surface { [.story, .guess, .piggy, .school, .luna][Tab.allCases.firstIndex(of: self)!] }
}

/// Phone: a TabView. iPad: a NavigationSplitView with a sidebar — never a stretched phone layout.
struct RootView: View {
  @Environment(AppModel.self) private var app
  @Environment(\.horizontalSizeClass) private var hSize
  @State private var tab: Tab = {
    let a = ProcessInfo.processInfo.arguments
    return a.firstIndex(of: "-tab").flatMap { Tab(rawValue: a[$0 + 1]) } ?? .story
  }()
  @State private var gate = false
  @State private var grownUps = false
  @State private var quest: String?

  var body: some View {
    Group {
      if hSize == .regular { split } else { tabs }
    }
    .overlay(alignment: .top) { BadgeToast() }
    .sheet(isPresented: $gate) { ParentGate { gate = false; grownUps = true } }
    .fullScreenCover(isPresented: $grownUps) { GrownUpsView() }
    .fullScreenCover(item: Binding(get: { quest.map(QuestRoute.init) }, set: { quest = $0?.id })) { r in QuestView(start: r.id) }
    .environment(\.openQuest, OpenQuest { quest = $0 })
    .task { await app.loadMarket() }
    .onAppear {
      let args = ProcessInfo.processInfo.arguments
      if let s = args.firstIndex(of: "-quest") { quest = args[s + 1] }
      #if DEBUG
      if args.contains("-demo") && args.contains("-grownups") { grownUps = true } // screenshots only; release builds always use the gate
      #endif
    }
    .tint(Palette.accent)
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
            Button { quest = ch.id } label: { Label { Text(ch.title) } icon: { Text(ch.emoji) } }
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
    case .school: SchoolView()
    case .luna: AskLunaView()
    }
  }

  @ToolbarContentBuilder private var topBar: some ToolbarContent {
    ToolbarItem(placement: .topBarLeading) { LevelPill() }
    ToolbarItem(placement: .topBarTrailing) {
      Button("For grown-ups") { gate = true }.font(.footnote.weight(.semibold)).foregroundStyle(Palette.ink2)
    }
  }
}

struct QuestRoute: Identifiable { let id: String }
struct OpenQuest { let open: (String) -> Void; func callAsFunction(_ id: String) { open(id) } }
private struct OpenQuestKey: EnvironmentKey { static let defaultValue = OpenQuest { _ in } }
extension EnvironmentValues { var openQuest: OpenQuest { get { self[OpenQuestKey.self] } set { self[OpenQuestKey.self] = newValue } } }

struct LevelPill: View {
  @Environment(AppModel.self) private var app
  var body: some View {
    let l = app.level
    HStack(spacing: 8) {
      MoonPhase(phase: l.index, size: 22)
      VStack(alignment: .leading, spacing: 0) {
        Text(l.name).font(.caption.weight(.bold))
        Text("\(app.points) pts").font(.caption2).monospacedDigit().foregroundStyle(.secondary).contentTransition(.numericText(value: Double(app.points)))
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

/// New-badge celebration: compact, auto-dismissing, with a particle burst and a success haptic.
struct BadgeToast: View {
  @Environment(AppModel.self) private var app
  @State private var burst = 0
  var body: some View {
    ZStack(alignment: .top) {
      Celebrate(trigger: burst).frame(height: 420)
      if let b = app.freshBadges.first {
        HStack(spacing: 12) {
          MoonPhase(phase: b.phase, size: 34)
          VStack(alignment: .leading, spacing: 2) {
            Text("New badge: \(b.name)!").font(.subheadline.weight(.bold))
            Text(b.why).font(.caption).foregroundStyle(.secondary).lineLimit(2)
          }
          Spacer(minLength: 0)
          Button("Yay!") { see() }.buttonStyle(.borderedProminent).buttonBorderShape(.capsule)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 20, y: 8)
        .padding(.horizontal, 16).padding(.top, 6)
        .readable(520)
        .transition(.move(edge: .top).combined(with: .opacity))
        .sensoryFeedback(.success, trigger: b.id)
        .task(id: b.id) { burst += 1; try? await Task.sleep(for: .seconds(6)); see() }
        .accessibilityElement(children: .combine)
      }
    }
    .animation(.spring(response: 0.45, dampingFraction: 0.8), value: app.freshBadges.first?.id)
  }
  private func see() { let ids = app.freshBadges.map(\.id); withAnimation { app.mutate { $0.seeBadges(ids) } } }
}
