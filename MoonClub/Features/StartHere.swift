import SwiftUI
import MoonClubCore

// The Story's one primary action (CLAUDE.md "Story: one thing to tap"). Kids said they didn't know where
// to start: now Luna says hi and ONE bright button plays the next step (MoonClubCore `NextUp`).

/// Start here: Luna's one-line hello and ONE big, bright button for the next step.
/// It's the only primary-colored, glowing thing on the Story. It pulses a few times when it appears, then
/// rests (still under Reduce Motion). VoiceOver lands on it first and reads "Start here: Play: Candle match".
struct StartHereHero: View {
  let step: NextStep
  let greeting: String
  let go: () -> Void
  /// A page to itself (iPhone Duo book pose): a tall card, the art and play button above the words,
  /// so the title reads in full on a narrow page instead of breaking word by word.
  var tall = false
  @Environment(\.accessibilityReduceMotion) private var rm
  @Environment(\.dynamicTypeSize) private var type
  @State private var pulse = false
  @AccessibilityFocusState private var focused: Bool
  @ScaledMetric(relativeTo: .title2) private var art: CGFloat = 52

  var body: some View {
    let _ = Perf.body("StartHereHero")
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 12) {
        Luna(size: type.isAccessibilitySize ? 40 : 54, wave: true)
        Text(greeting).font(.kTitle).foregroundStyle(Palette.ink)
          .lineLimit(2).minimumScaleFactor(0.7).fixedSize(horizontal: false, vertical: true)
      }
      .accessibilityHidden(true)
      Button(action: go) { face }
        .buttonStyle(PressStyle())
        .accessibilityLabel("Start here: \(step.label)")
        .accessibilityValue(step.minutes.map { "About \($0) minute\($0 == 1 ? "" : "s")" } ?? "")
        .accessibilityFocused($focused)
    }
    .accessibilityElement(children: .contain)
    .accessibilitySortPriority(10)
    // The hero still fits on screen at the biggest text sizes.
    .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    .onAppear {
      if UIAccessibility.isVoiceOverRunning { Task { try? await Task.sleep(for: .milliseconds(700)); focused = true } }
      guard !rm else { return }
      pulse = false
      withAnimation(.easeOut(duration: 1.7).repeatCount(4, autoreverses: false).delay(0.5)) { pulse = true }
    }
  }

  private var face: some View {
    let shape = RoundedRectangle(cornerRadius: 30, style: .continuous)
    return Group {
      if tall {
        VStack(alignment: .leading, spacing: 14) {
          HStack {
            if !type.isAccessibilitySize { Glyph(step.art, size: min(art * 1.3, 84)) }
            Spacer(minLength: 0)
            playDisc
          }
          words
        }
      } else {
        HStack(spacing: 14) {
          if !type.isAccessibilitySize {
            Glyph(step.art, size: min(art, 72))
          }
          words
          Spacer(minLength: 0)
          playDisc
        }
      }
    }
    .padding(.horizontal, 18).padding(.vertical, 20)
    .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
    .background(AuroraSwatch(colors: [Hue.sky.color, Hue.grape.color, Hue.berry.color], seed: 3,
                             base: Palette.accent.blend(with: .black, by: 0.12)))
    .clipShape(shape)
    .overlay(shape.strokeBorder(.white.opacity(0.35), lineWidth: 1.5))
    // The glow, and a ring that ripples out a few times, then rests.
    .shadow(color: Palette.accent.opacity(0.45), radius: 22, y: 10)
    .overlay {
      shape.stroke(Palette.accent.opacity(pulse ? 0 : 0.6), lineWidth: 4)
        .scaleEffect(pulse ? 1.06 : 1)
        .allowsHitTesting(false)
    }
    .contentShape(shape)
  }

  private var words: some View {
      VStack(alignment: .leading, spacing: 4) {
        Text(step.verb).font(.system(.headline, design: .rounded).weight(.heavy)).foregroundStyle(.white.opacity(0.9))
          .textCase(.uppercase).tracking(0.6)
        Text(step.title).font(.system(.title, design: .rounded).weight(.heavy)).foregroundStyle(.white)
          .lineLimit(3).minimumScaleFactor(0.6).fixedSize(horizontal: false, vertical: true)
        if let m = step.minutes {
          Label("\(m) min", systemImage: "clock.fill").font(.subheadline.weight(.bold)).foregroundStyle(.white)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(.white.opacity(0.22), in: Capsule())
            .padding(.top, 2)
        }
      }
  }

  private var playDisc: some View {
      Image(systemName: step.target == .chest ? "gift.fill" : "play.fill")
        .font(.system(size: 24, weight: .black))
        .foregroundStyle(Palette.accent)
        .frame(width: 58, height: 58)
        .background(.white, in: Circle())
        .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
  }
}

/// The header that opens "Today's story" (the day's cards). Closed by default; the date lives here now.
struct MoreHeader: View {
  let open: Bool
  let date: String
  let count: Int
  let toggle: () -> Void
  var body: some View {
    Button(action: toggle) {
      HStack(spacing: 12) {
        Glyph(symbol: "book.pages.fill", hue: .grape, size: 34)
        VStack(alignment: .leading, spacing: 2) {
          Text("Today's story").font(.kHeadline).foregroundStyle(Palette.ink)
          Text("\(date) · \(count) cards").font(.caption).foregroundStyle(Palette.ink2)
        }
        .fixedSize(horizontal: false, vertical: true)
        Spacer(minLength: 0)
        Image(systemName: "chevron.down").font(.subheadline.weight(.bold)).foregroundStyle(Palette.ink2)
          .rotationEffect(.degrees(open ? 180 : 0))
      }
      .padding(14)
      .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
      .background(Palette.card.opacity(0.55), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
      .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Palette.line.opacity(0.8), lineWidth: 0.5))
      .contentShape(Rectangle())
    }
    .buttonStyle(PressStyle())
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Today's story. \(date). \(count) cards")
    .accessibilityValue(open ? "Open" : "Closed")
    .accessibilityAddTraits(.isButton)
  }
}

/// Luna's quests, small: the next chapter not done yet (inside Today's story; the map has them too).
struct QuestRow: View {
  @Environment(AppModel.self) private var app
  @Environment(\.openQuest) private var openQuest
  var body: some View {
    let chapters = app.content.questChapters?.CHAPTERS ?? []
    if let next = chapters.first(where: { !app.chaptersDone.contains($0.id) }) {
      Button { openQuest(next.id) } label: {
        HStack(spacing: 12) {
          Glyph(next.emoji, size: 40)
          VStack(alignment: .leading, spacing: 2) {
            Text("Luna's quest").font(.caption.weight(.bold)).foregroundStyle(Palette.ink2)
            Text(next.title).font(.kHeadline).foregroundStyle(Palette.ink)
          }
          Spacer(minLength: 0)
          Image(systemName: "chevron.right").font(.subheadline.weight(.bold)).foregroundStyle(Palette.ink2)
        }
        .padding(12)
        .background(Palette.card.opacity(0.7), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
      }
      .buttonStyle(PressStyle())
      .accessibilityLabel("Luna's quest: \(next.title)")
    }
  }
}

/// A tab icon with a small glowing dot drawn in (the tab that holds the Start here step). A tab badge would
/// be the system's big red "something's wrong" dot, and iOS 26's tab bar ignores a badge color, so the dot
/// is part of the picture: the symbol in the bar's ink (light and dark) plus the app's color.
enum TabIcon {
  @MainActor private static var cache: [String: UIImage] = [:]
  /// One picture per color scheme (the caller passes its `colorScheme`), at an explicit 3x scale.
  @MainActor static func dotted(_ symbol: String, dark: Bool) -> UIImage {
    let accent = UIColor(Palette.accent)
    let key = "\(symbol)|\(ThemeColor.hex)|\(dark)"
    if let c = cache[key] { return c }
    let config = UIImage.SymbolConfiguration(pointSize: 23, weight: .semibold)
    guard let base = UIImage(systemName: symbol, withConfiguration: config) else { return UIImage() }
    let pad: CGFloat = 5, dot: CGFloat = 9, scale: CGFloat = 3
    let size = CGSize(width: base.size.width + pad * 2, height: base.size.height + pad)
    let fmt = UIGraphicsImageRendererFormat.preferred()
    fmt.scale = scale
    let ink = UIColor.label.resolvedColor(with: UITraitCollection(userInterfaceStyle: dark ? .dark : .light))
    let drawn = UIGraphicsImageRenderer(size: size, format: fmt).image { ctx in
      base.withTintColor(ink, renderingMode: .alwaysOriginal).draw(at: CGPoint(x: pad, y: pad))
      let r = CGRect(x: size.width - dot - 1, y: 1, width: dot, height: dot)
      ctx.cgContext.setShadow(offset: .zero, blur: 4, color: accent.withAlphaComponent(0.9).cgColor)
      accent.setFill()
      ctx.cgContext.fillEllipse(in: r)
    }
    guard let cg = drawn.cgImage else { return drawn }
    let out = UIImage(cgImage: cg, scale: scale, orientation: .up).withRenderingMode(.alwaysOriginal)
    cache[key] = out
    return out
  }
}

/// The small glowing dot on the tab (iPad sidebar row) that holds the Start here step, when it isn't Story.
struct GlowDot: View {
  var body: some View {
    Circle().fill(Palette.accent).frame(width: 9, height: 9)
      .shadow(color: Palette.accent.opacity(0.8), radius: 5)
      .accessibilityHidden(true)
  }
}
