import SwiftUI

// Bright "at a glance" tiles and accordions for reading screens (the grown-up corner's How to play and
// For grown-ups). Lead with a few bright tiles; the long words live in accordions, closed by default.

/// One still frame of the app's aurora shader (`Shaders.metal` `aurora`), tuned bright for a small tile.
/// It never animates (one draw), so a grid of them costs nothing per frame. Reduce Transparency and
/// high-contrast users get a flat tint instead.
struct AuroraSwatch: View {
  /// Three light colors, drawn as soft glowing blobs.
  let colors: [Color]
  /// Picks where the blobs sit, so neighbouring tiles don't look the same.
  var seed: Float = 0
  /// A deep base (the Story's Start here button): the field stays saturated in light and dark, and Reduce
  /// Transparency gets this color flat, so white words on it keep their contrast.
  var base: Color? = nil
  @Environment(\.colorScheme) private var scheme
  @Environment(\.accessibilityReduceTransparency) private var solid
  var body: some View {
    let c = colors.count >= 3 ? colors : [Hue.sky.light, Hue.grape.light, Hue.mint.light]
    Group {
      if solid {
        if let base { base } else { c[0].opacity(scheme == .dark ? 0.35 : 0.6) }
      } else if let base {
        GeometryReader { geo in
          Rectangle().colorEffect(ShaderLibrary.aurora(
            .float2(geo.size), .float(seed * 37), .color(c[0]), .color(c[1]), .color(c[2]), .color(base), .float(0.85)))
        }
      } else {
        GeometryReader { geo in
          Rectangle().colorEffect(ShaderLibrary.aurora(
            .float2(geo.size), .float(seed * 37),
            .color(c[0]), .color(c[1]), .color(c[2]),
            // The base is the first color washed toward the card, so the whole tile glows, not just its blobs.
            .color(scheme == .dark ? c[0].blend(with: Color(hex: 0x1D1C3D), by: 0.78) : c[0].blend(with: .white, by: 0.55)),
            .float(scheme == .dark ? 0.55 : 1)))
        }
      }
    }
    .accessibilityHidden(true)
  }
}

/// A bright highlight: a symbol on a glowing aurora field, one bold line, and an optional short second line.
struct GlanceTile: View {
  let symbol: String
  let hue: Hue
  let title: String
  var detail: String? = nil
  /// The other two colors in the field (defaults to the hue's neighbours).
  var glow: [Hue] = []
  var seed: Float = 0
  @ScaledMetric(relativeTo: .headline) private var icon: CGFloat = 40

  var body: some View {
    let others = glow.count >= 2 ? glow : [.sky, .berry]
    HStack(alignment: .center, spacing: 14) {
      Glyph(symbol: symbol, hue: hue, size: min(icon, 64))
      VStack(alignment: .leading, spacing: 3) {
        Text(title).font(.kHeadline).foregroundStyle(Palette.ink).fixedSize(horizontal: false, vertical: true)
        if let detail { Text(detail).font(.subheadline).foregroundStyle(Palette.ink2).fixedSize(horizontal: false, vertical: true) }
      }
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 16).padding(.vertical, 12)
    .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
    .background(AuroraSwatch(colors: [hue.light, others[0].color.blend(with: .white, by: 0.25), others[1].color.blend(with: .white, by: 0.25)], seed: seed))
    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.white.opacity(0.5), lineWidth: 1))
    .shadow(color: hue.color.opacity(0.18), radius: 10, y: 4)
    .accessibilityElement(children: .combine)
  }
}

/// Lays tiles out in one column on a phone and 2–3 balanced columns on wider windows (iPad, Duo open).
/// It follows the room it's given, never the device.
struct TileGrid<Content: View>: View {
  var minimum: CGFloat = 270
  @ViewBuilder var content: Content
  var body: some View {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: minimum), spacing: 12, alignment: .top)], alignment: .leading, spacing: 12) { content }
  }
}

/// An accordion: a clear header (symbol, title, one-line summary, chevron) that opens to the details.
/// Closed by default. VoiceOver reads it as one button with its state.
struct Accordion<Content: View>: View {
  let symbol: String
  let hue: Hue
  let title: String
  var summary: String? = nil
  @ViewBuilder var content: Content
  @Environment(\.accessibilityReduceMotion) private var rm
  @State private var open = Accordion.startOpen

  /// Debug `-expand` opens every accordion (screenshots, review).
  static var startOpen: Bool {
    #if DEBUG
    return ProcessInfo.processInfo.arguments.contains("-expand")
    #else
    return false
    #endif
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Button { withAnimation(Motion.safe(Motion.card, rm)) { open.toggle() } } label: {
        HStack(spacing: 12) {
          Glyph(symbol: symbol, hue: hue, size: 34)
          VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.kHeadline).foregroundStyle(Palette.ink)
            if let summary { Text(summary).font(.caption).foregroundStyle(Palette.ink2) }
          }
          .fixedSize(horizontal: false, vertical: true)
          Spacer(minLength: 0)
          Image(systemName: "chevron.down").font(.subheadline.weight(.bold)).foregroundStyle(Palette.ink2)
            .rotationEffect(.degrees(open ? 180 : 0))
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
      }
      .buttonStyle(PressStyle())
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(summary.map { "\(title). \($0)" } ?? title)
      .accessibilityValue(open ? "Open" : "Closed")
      .accessibilityHint(open ? "Hides the details" : "Shows the details")
      .accessibilityAddTraits(.isButton)

      if open {
        VStack(alignment: .leading, spacing: 10) { content }
          .font(.callout).foregroundStyle(Palette.ink)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 16).padding(.bottom, 16)
          .transition(rm ? .opacity : .opacity.combined(with: .move(edge: .top)))
      }
    }
    .background(Palette.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(open ? hue.color.opacity(0.45) : Palette.line, lineWidth: open ? 1.5 : 1))
    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
  }
}

/// A short point inside an accordion: a small colored dot and the words (markdown allowed).
struct Point: View {
  let text: LocalizedStringKey
  var hue: Hue = .sky
  init(_ text: LocalizedStringKey, hue: Hue = .sky) { self.text = text; self.hue = hue }
  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 10) {
      Circle().fill(hue.color).frame(width: 7, height: 7).alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1 }
      Text(text).fixedSize(horizontal: false, vertical: true)
    }
  }
}
