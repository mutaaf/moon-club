import SwiftUI
import MoonClubCore

/// Tap-a-word: every tricky word opens a picture card with read-aloud and "Play it" into the quest.
struct WordSheet: View {
  let key: String
  @Environment(AppModel.self) private var app
  @Environment(\.dismiss) private var dismiss
  @Environment(\.openQuest) private var openQuest
  @Environment(\.supportsMultipleWindows) private var multiWindow
  @Environment(\.openWindow) private var openWindow
  @Environment(DuoModel.self) private var duo: DuoModel?
  var body: some View {
    if let t = app.content.terms[key] {
      VStack(spacing: 18) {
        Glyph(t.emoji, size: 104, style: .halo)
          .accessibilityHidden(true)
        Text(t.word).font(.kHero).lineLimit(1).minimumScaleFactor(0.5)
        Text(t.means).font(.kRead).multilineTextAlignment(.center)
        Text(t.example).font(.system(.title3, design: .serif).italic()).foregroundStyle(Palette.ink2).multilineTextAlignment(.center)
        HStack(spacing: 10) {
          ReadAloud(source: .appCopy("\(t.word). \(t.means) \(t.example)"))
          if let play = t.play { Button("Play it") { dismiss(); openQuest(play) }.buttonStyle(SoftButtonStyle()) }
        }
        Button("Got it!") { dismiss() }.buttonStyle(PrimaryButtonStyle())
        // iPhone Duo (and iPad) can show two windows side by side: keep the whole Word Book open next to
        // a quest or lesson. New windows can't open on iPhone Duo's outer display, so it hides there.
        if multiWindow && duo?.pose != .closed {
          Button { dismiss(); openWindow(id: WordBookView.windowID, value: key) } label: {
            Label("Keep the Word Book open beside me", systemImage: "rectangle.split.2x1")
          }
          .font(.subheadline.weight(.semibold)).frame(minHeight: 44)
        }
      }
      .padding(28)
      .readable(520)
      .presentationDetents([.medium, .large])
      .presentationDragIndicator(.visible)
      .presentationBackground(.regularMaterial)
    }
  }
}

/// "What's that word?" — a row of chips at the bottom of a card.
struct WordChips: View {
  let keys: [String]
  @Environment(AppModel.self) private var app
  @State private var open: String?
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("What's that word?").font(.caption).foregroundStyle(.secondary)
      FlowLayout(spacing: 8) {
        ForEach(keys, id: \.self) { k in
          if let t = app.content.terms[k] {
            Button { open = k } label: {
              HStack(spacing: 6) { Glyph(t.emoji, size: 22); Text(t.word).font(.subheadline.weight(.semibold)); Image(systemName: "questionmark.circle.fill").foregroundStyle(Palette.accent) }
                .padding(.horizontal, 12).frame(minHeight: 40)
                .moonGlass(Capsule(), interactive: true, weight: .thin)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(t.word): what does it mean?")
          }
        }
      }
    }
    .sheet(item: Binding(get: { open.map(Ident.init) }, set: { open = $0?.id })) { WordSheet(key: $0.id) }
  }
}
struct Ident: Identifiable { let id: String }

/// 📖 Luna's Word Book: every tap-a-word card in one place, in its own window, so it can sit beside a
/// quest or lesson in Split View (iPhone Duo open, iPad). Opens on the word the kid was reading.
struct WordBookView: View {
  static let windowID = "wordbook"
  var start: String?
  @Environment(AppModel.self) private var app
  @State private var open: String?
  var body: some View {
    let terms = app.content.terms.sorted { $0.value.word.localizedCaseInsensitiveCompare($1.value.word) == .orderedAscending }
    NavigationStack {
      ScrollViewReader { proxy in
        ScrollView {
          LazyVStack(alignment: .leading, spacing: 10) {
            ForEach(terms, id: \.key) { k, t in
              Button { withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { open = open == k ? nil : k } } label: {
                VStack(alignment: .leading, spacing: 8) {
                  HStack(spacing: 12) {
                    Glyph(t.emoji, size: 40).frame(width: 48)
                    Text(t.word).font(.kTitle).foregroundStyle(Palette.ink)
                    Spacer()
                    Image(systemName: open == k ? "chevron.up" : "chevron.down").foregroundStyle(.secondary)
                  }
                  if open == k {
                    Text(t.means).font(.kRead).foregroundStyle(Palette.ink)
                    Text(t.example).font(.system(.body, design: .serif).italic()).foregroundStyle(Palette.ink2)
                    ReadAloud(source: .appCopy("\(t.word). \(t.means) \(t.example)"))
                  }
                }
                .padding(14).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .moonGlass(radius: 20, weight: .thin)
              }
              .buttonStyle(.plain)
              .id(k)
            }
          }
          .padding(16)
        }
        .onAppear { if let start { open = start; proxy.scrollTo(start, anchor: .top) } }
      }
      .background(AuroraField(surface: .school))
      .navigationTitle("Luna's Word Book")
    }
  }
}

/// A simple wrapping layout for chips.
struct FlowLayout: Layout {
  var spacing: CGFloat = 8
  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let w = proposal.width ?? 360
    var x: CGFloat = 0, y: CGFloat = 0, row: CGFloat = 0
    for s in subviews { let z = s.sizeThatFits(ProposedViewSize(width: w, height: nil)); let zw = min(z.width, w); if x + zw > w, x > 0 { x = 0; y += row + spacing; row = 0 }; x += zw + spacing; row = max(row, z.height) }
    return CGSize(width: w, height: y + row)
  }
  func placeSubviews(in b: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    var x = b.minX, y = b.minY, row: CGFloat = 0
    // Items never exceed the row width: long chips wrap their text instead of running off-screen.
    for s in subviews {
      let z = s.sizeThatFits(ProposedViewSize(width: b.width, height: nil)); let zw = min(z.width, b.width)
      if x + zw > b.maxX, x > b.minX { x = b.minX; y += row + spacing; row = 0 }
      s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: zw, height: z.height)); x += zw + spacing; row = max(row, z.height)
    }
  }
}
