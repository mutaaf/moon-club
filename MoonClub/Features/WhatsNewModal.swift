import SwiftUI
import MoonClubCore

/// After an update, Luna presents what's new: kid-sized cards from each release note's "## Luna's news",
/// paged (no scrolling inside a card), once per version per device. Grown-ups keep the full notes in their corner.
@MainActor
enum WhatsNewStore {
  static let key = "whatsNew.lastSeen"
  static var current: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0" }

  static func allNews() -> [ReleaseNews] {
    guard let dir = Bundle.main.url(forResource: "release-notes", withExtension: nil),
          let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return [] }
    return files.filter { $0.pathExtension == "md" && $0.lastPathComponent != "README.md" }.compactMap { f in
      (try? String(contentsOf: f, encoding: .utf8)).map { WhatsNew.parse(version: f.deletingPathExtension().lastPathComponent, markdown: $0) }
    }
  }

  /// What to show now. A fresh install records the current version and shows nothing.
  static func pending(defaults: UserDefaults = .standard, args: [String] = ProcessInfo.processInfo.arguments) -> [ReleaseNews] {
    #if DEBUG
    if let i = args.firstIndex(of: "-whatsnewFrom"), i + 1 < args.count { return WhatsNew.pending(lastSeen: args[i + 1], current: current, all: allNews()) }
    if args.contains("-demo") { return [] } // screenshots stay clean unless asked
    #endif
    let seen = defaults.string(forKey: key)
    if seen == nil { defaults.set(current, forKey: key); return [] }
    return WhatsNew.pending(lastSeen: seen, current: current, all: allNews())
  }

  static func markSeen(defaults: UserDefaults = .standard) { defaults.set(current, forKey: key) }
}

struct WhatsNewModal: View {
  let news: [ReleaseNews]
  var onDone: () -> Void
  @State private var page = 0
  @State private var burst = 0
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  private var cards: [(version: String, item: ReleaseNews.Item)] { news.flatMap { n in n.items.map { (n.version, $0) } } }
  private let tints: [Color] = [Palette.accent, Color(hex: 0x1F7A55), Color(hex: 0xB4691F), Color(hex: 0x7B5CE0), Color(hex: 0xC2456B)]

  var body: some View {
    VStack(spacing: 18) {
      HStack {
        Text(news.count > 1 ? "Updates \(news.last!.version)–\(news.first!.version)" : "Version \(news.first?.version ?? "")")
          .font(.kEyebrow).foregroundStyle(Palette.accent)
          .padding(.horizontal, 12).padding(.vertical, 6).background(Palette.accent.opacity(0.1), in: Capsule())
        Spacer()
        Button("Skip") { finish() }.font(.kHeadline).foregroundStyle(Palette.ink2).accessibilityIdentifier("whatsnew-skip")
      }
      Luna(size: 92, wave: true).padding(.top, 4)
      Text("Moon Club got an upgrade!").font(.kHero).multilineTextAlignment(.center).minimumScaleFactor(0.7).lineLimit(2)
      TabView(selection: $page) {
        ForEach(Array(cards.enumerated()), id: \.offset) { i, c in card(c.item, tint: tints[i % tints.count]).tag(i).padding(.horizontal, 4) }
      }
      .tabViewStyle(.page(indexDisplayMode: .never))
      .frame(maxHeight: 300)
      HStack(spacing: 8) {
        ForEach(cards.indices, id: \.self) { i in Capsule().fill(i == page ? Palette.accent : Palette.ink2.opacity(0.28)).frame(width: i == page ? 22 : 8, height: 8) }
      }
      .animation(.spring(response: 0.3, dampingFraction: 0.8), value: page)
      .accessibilityHidden(true)
      Button(page < cards.count - 1 ? "Next" : "Let's go!") {
        if page < cards.count - 1 { withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { page += 1 } } else { finish() }
      }
      .buttonStyle(PrimaryButtonStyle())
      .accessibilityIdentifier("whatsnew-next")
    }
    .padding(24)
    .frame(maxWidth: 520)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(AuroraField(surface: .story).ignoresSafeArea())
    .overlay { Celebrate(trigger: burst).allowsHitTesting(false) }
    .sensoryFeedback(.success, trigger: burst)
    .sensoryFeedback(.selection, trigger: page)
    .onAppear { burst += 1 }
  }

  private func card(_ item: ReleaseNews.Item, tint: Color) -> some View {
    VStack(spacing: 18) {
      Image(systemName: item.symbol)
        .font(.system(size: 44, weight: .semibold))
        .symbolRenderingMode(.hierarchical)
        .foregroundStyle(tint)
        .frame(width: 96, height: 96)
        .background(tint.opacity(0.12), in: Circle())
        .symbolEffect(.bounce, value: page)
      Text(item.text).font(.kRead).foregroundStyle(Palette.ink).multilineTextAlignment(.center)
        .minimumScaleFactor(0.8).fixedSize(horizontal: false, vertical: true)
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    .accessibilityElement(children: .combine)
  }

  private func finish() { WhatsNewStore.markSeen(); onDone() }
}
