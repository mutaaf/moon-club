import SwiftUI
import MoonClubCore

/// Tap-a-word: every tricky word opens a picture card with read-aloud and "Play it" into the quest.
struct WordSheet: View {
  let key: String
  @Environment(AppModel.self) private var app
  @Environment(\.dismiss) private var dismiss
  @Environment(\.openQuest) private var openQuest
  var body: some View {
    if let t = app.content.terms[key] {
      VStack(spacing: 18) {
        Text(t.emoji).font(.system(size: 88)).phaseAnimator([0, 1]) { v, p in v.offset(y: p == 1 ? -6 : 0).rotationEffect(.degrees(p == 1 ? -4 : 0)) } animation: { _ in .easeInOut(duration: 1.4) }
          .accessibilityHidden(true)
        Text(t.word).font(.kHero)
        Text(t.means).font(.kRead).multilineTextAlignment(.center)
        Text(t.example).font(.system(.title3, design: .serif).italic()).foregroundStyle(Palette.ink2).multilineTextAlignment(.center)
        HStack(spacing: 10) {
          ReadAloud(source: .appCopy("\(t.word). \(t.means) \(t.example)"))
          if let play = t.play { Button("Play it 🍋") { dismiss(); openQuest(play) }.buttonStyle(SoftButtonStyle()) }
        }
        Button("Got it!") { dismiss() }.buttonStyle(PrimaryButtonStyle())
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
              HStack(spacing: 6) { Text(t.emoji); Text(t.word).font(.subheadline.weight(.semibold)); Image(systemName: "questionmark.circle.fill").foregroundStyle(Palette.accent) }
                .padding(.horizontal, 12).frame(minHeight: 40)
                .background(.thinMaterial, in: Capsule())
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
