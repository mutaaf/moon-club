import SwiftUI
import MoonClubCore

/// After an update, Luna shows what's new ONCE: a hero headline and 2–4 bright cards from the current version's
/// `## Luna's news` (release-notes/<version>.md, bundled; the same file feeds TestFlight, the GitHub release and
/// the App Store "What's New", so they can't drift). No links, nothing to type, one "Let's go". The full notes
/// stay behind the grown-up gate (For grown-ups → What's new). The rule itself is pure: `WhatsNew.launch`.
/// A card whose line ends in `→ <place>` is a callout: tapping it closes the modal and opens that place
/// (`NewsPlace`, routed by RootView through `AppModel.open(_:)`, the same switch a link makes).
@MainActor
enum WhatsNewStore {
  static let key = "whatsNew.lastSeen"
  nonisolated static var current: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0" }

  static func allNews(bundle: Bundle = .main) -> [ReleaseNews] {
    guard let dir = bundle.url(forResource: "release-notes", withExtension: nil),
          let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return [] }
    return files.filter { $0.pathExtension == "md" && $0.lastPathComponent != "README.md" }.compactMap { f in
      (try? String(contentsOf: f, encoding: .utf8)).map { WhatsNew.parse(version: f.deletingPathExtension().lastPathComponent, markdown: $0) }
    }
  }

  /// DEBUG only: `-whatsNew` shows the current version's card as if just updated; `-whatsnewFrom 0.15.0` picks
  /// the version updated from. Neither records anything, and both win over `-demo` (so a screenshot run can
  /// show it). Release builds ignore both. Phone: `xcrun simctl launch <sim> com.mutaafaziz.moonclub -whatsNew`,
  /// or in Xcode, Edit Scheme → Run → Arguments. Documented in release-notes/README.md.
  static func forceFrom(_ args: [String]) -> String? {
    #if DEBUG
    if let i = args.firstIndex(of: "-whatsnewFrom"), i + 1 < args.count { return args[i + 1] }
    if args.contains("-whatsNew") { return "0" }
    #endif
    return nil
  }

  /// What to show now, and the bookkeeping: a fresh install records the current version and shows nothing;
  /// an update records the new version as it shows (so it never repeats); tests, `-demo` and `-uitest` stay quiet.
  static func pending(defaults: UserDefaults = .standard, args: [String] = ProcessInfo.processInfo.arguments,
                      env: [String: String] = ProcessInfo.processInfo.environment, version: String = current,
                      all: [ReleaseNews]? = nil) -> ReleaseNews? {
    let l = WhatsNew.launch(lastSeen: defaults.string(forKey: key), current: version, all: all ?? allNews(),
                            args: args, env: env, forceFrom: forceFrom(args))
    if let r = l.record { defaults.set(r, forKey: key) }
    return l.news
  }
}

struct WhatsNewModal: View {
  let news: ReleaseNews
  var onDone: () -> Void
  /// A callout card was tapped: close and open its place.
  var onGo: (NewsPlace) -> Void = { _ in }
  @State private var shown = false
  @State private var burst = 0
  @State private var tour = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.horizontalSizeClass) private var hSize
  @Environment(\.dynamicTypeSize) private var typeSize
  @Environment(DuoModel.self) private var duo: DuoModel?

  static let fallbackHeadline = "Moon Club got an upgrade!"
  /// iPhone Duo news shows only on a device with a hinge; everyone else never sees features they can't use.
  static func isDuo(_ i: ReleaseNews.Item) -> Bool { i.text.contains("iPhone Duo") || (i.title ?? "").contains("iPhone Duo") }
  static func cards(_ n: ReleaseNews, hinge: Bool) -> [ReleaseNews.Item] { n.items.filter { hinge || !isDuo($0) } }
  private var cards: [ReleaseNews.Item] { Self.cards(news, hinge: duo?.hasHinge ?? false) }
  private let hues: [Hue] = [.berry, .teal, .orange, .grape]
  /// iPad / iPhone Duo open: cards side by side (2×2 for four). Big accessibility text: always one column.
  private var wide: Bool { hSize == .regular && !typeSize.isAccessibilitySize }

  var body: some View {
    GeometryReader { g in
      ScrollView {
        VStack(spacing: wide ? 26 : 20) {
          hero
          cardStack
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .frame(maxWidth: wide ? 780 : 520)
        .frame(maxWidth: .infinity, minHeight: g.size.height)
      }
      .scrollBounceBehavior(.basedOnSize)
    }
    .safeAreaInset(edge: .bottom) { letsGo }
    .background(AuroraField(surface: .story).ignoresSafeArea())
    .overlay { Celebrate(trigger: burst).allowsHitTesting(false) }
    .sensoryFeedback(.success, trigger: burst)
    .accessibilityAction(.escape) { onDone() }
    .onAppear {
      burst += 1
      withAnimation(reduceMotion ? Motion.fade : Motion.card) { shown = true }
    }
    .sheet(isPresented: $tour) { DuoCoach { tour = false }.presentationDetents([.large]) }
  }

  private var hero: some View {
    VStack(spacing: 12) {
      Text("New in \(news.version)")
        .font(.kEyebrow).foregroundStyle(Palette.accentInk)
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .padding(.horizontal, 12).padding(.vertical, 6).background(Palette.accent.opacity(0.12), in: Capsule())
        .accessibilityLabel("New in version \(news.version)")
      Luna(size: wide ? 112 : 92, wave: true, mood: .cheering)
        .scaleEffect(shown || reduceMotion ? 1 : 0.6)
        .accessibilityHidden(true)
      Text(news.headline ?? Self.fallbackHeadline)
        .font(.kHero).foregroundStyle(Palette.ink)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("whatsnew-headline")
    }
  }

  @ViewBuilder private var cardStack: some View {
    let items = Array(cards.enumerated())
    if wide {
      let perRow = cards.count == 4 ? 2 : max(cards.count, 1)
      Grid(horizontalSpacing: 16, verticalSpacing: 16) {
        ForEach(Array(stride(from: 0, to: items.count, by: perRow)), id: \.self) { start in
          GridRow {
            ForEach(items[start..<min(start + perRow, items.count)], id: \.offset) { i, item in card(item, index: i, vertical: true) }
          }
        }
      }
      .fixedSize(horizontal: false, vertical: true) // rows hug their tallest card instead of filling the screen
    } else {
      VStack(spacing: 12) {
        // Accessibility text sizes: art above the words, so the words get the card's full width.
        ForEach(items, id: \.offset) { i, item in card(item, index: i, vertical: typeSize.isAccessibilitySize) }
      }
    }
  }

  private func card(_ item: ReleaseNews.Item, index i: Int, vertical: Bool) -> some View {
    WhatsNewCard(item: item, hue: hues[i % hues.count], vertical: vertical, tour: Self.isDuo(item) ? { tour = true } : nil,
                 go: item.go.map { p in { onGo(p) } }, index: i)
      .opacity(shown ? 1 : 0)
      .offset(y: shown || reduceMotion ? 0 : 28)
      .animation(reduceMotion ? Motion.fade : Motion.card.delay(0.15 + Double(i) * 0.09), value: shown)
  }

  private var letsGo: some View {
    Button { onDone() } label: { Label("Let's go!", systemImage: "arrow.right").labelStyle(.titleOnly) }
      .buttonStyle(PrimaryButtonStyle())
      .frame(maxWidth: 420)
      .padding(.horizontal, 24)
      .padding(.top, 10)
      .padding(.bottom, 12)
      .frame(maxWidth: .infinity)
      // Cards that scroll under the button fade out instead of colliding with it.
      .background(alignment: .top) {
        LinearGradient(colors: [Palette.paper.opacity(0), Palette.paper.opacity(0.85)], startPoint: .top, endPoint: .init(x: 0.5, y: 0.35))
          .padding(.top, -24).ignoresSafeArea()
          .allowsHitTesting(false)
      }
      .accessibilityIdentifier("whatsnew-done")
      .accessibilityHint("Closes what's new")
  }
}

/// One callout: the release note's art drawn in Moon Club's tile style (an SF Symbol, a `custom.*` mark or an
/// `Art` emoji key, the same art as the map and lessons), a title of a few words and one short line.
/// Fixed content, no scrolling inside: the copy is linted (`WhatsNew.lint`).
struct WhatsNewCard: View {
  let item: ReleaseNews.Item
  let hue: Hue
  var vertical = false
  var tour: (() -> Void)? = nil
  /// Callout: the whole card is one button to the feature (nil = a plain card).
  var go: (() -> Void)? = nil
  var index = 0
  @ScaledMetric(relativeTo: .title) private var art: CGFloat = 60

  /// Where a place lives, for the button's VoiceOver hint.
  static func placeName(_ p: NewsPlace) -> String {
    switch p {
    case .moonSchool: return "Moon School"
    case .link(.lesson): return "a lesson"
    case .link(.gameNight): return "Game Night"
    case .link(.garden): return "the garden"
    case .link(let l): return Tab(link: l)?.title ?? "Moon Club"
    }
  }

  @ViewBuilder var body: some View {
    if let go, tour == nil {
      Button(action: go) { content }
        .buttonStyle(PressStyle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(item.go.map { "Opens \(Self.placeName($0))" } ?? "")
        .accessibilityIdentifier("whatsnew-go-\(index)")
    } else {
      content.accessibilityElement(children: .combine)
    }
  }

  /// "Show me" on a callout: says the card goes somewhere (the card itself is the tap target).
  private var showMe: some View {
    HStack(spacing: 6) {
      Text("Show me").font(.subheadline.weight(.heavy))
      Image(systemName: "arrow.right").font(.caption.weight(.heavy))
    }
    .foregroundStyle(.white)
    .padding(.horizontal, 14).padding(.vertical, 8)
    .background(hue.color, in: Capsule())
    .padding(.top, 6)
    .accessibilityHidden(true)
  }

  @ViewBuilder private var content: some View {
    let layout = vertical ? AnyLayout(VStackLayout(spacing: 14)) : AnyLayout(HStackLayout(alignment: .center, spacing: 16))
    layout {
      glyph
      VStack(alignment: vertical ? .center : .leading, spacing: 4) {
        if let t = item.title {
          Text(t).font(.kTitle).foregroundStyle(Palette.ink)
        }
        Text(item.text).font(item.title == nil ? .kRead : .kBody).foregroundStyle(item.title == nil ? Palette.ink : Palette.ink2)
        if let tour {
          Button(action: tour) { DuoCallout(text: "Take the iPhone Duo tour", symbol: "play.circle.fill") }
            .buttonStyle(PressStyle()).padding(.top, 6)
        } else if go != nil {
          showMe
        }
      }
      .multilineTextAlignment(vertical ? .center : .leading)
      .fixedSize(horizontal: false, vertical: true)
      .frame(maxWidth: .infinity, alignment: vertical ? .center : .leading)
    }
    .padding(vertical ? 22 : 16)
    .frame(maxWidth: .infinity, maxHeight: vertical ? .infinity : nil)
    .moonGlass(radius: 26)
    .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(hue.color.opacity(go == nil ? 0.35 : 0.7), lineWidth: go == nil ? 1 : 2))
    .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
  }

  @ViewBuilder private var glyph: some View {
    let size = vertical ? art * 1.25 : art
    if Art.spec(item.symbol) != Art.fallback { Glyph(item.symbol, size: size) } else { Glyph(symbol: item.symbol, hue: hue, size: size) }
  }
}
