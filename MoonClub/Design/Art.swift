import SwiftUI

// Moon Club's one illustration language. Content (exported from the web) still names things with emoji
// — that's the web's art — but the native app never draws an emoji as a picture: every emoji key maps to
// an SF Symbol + a hue from one small palette, drawn in the same tile / halo style everywhere (app,
// widgets, Live Activities). Unknown keys fall back to sparkles, and a test checks every content emoji
// and every symbol name resolves (MoonClubTests/ArtTests).

enum Hue: CaseIterable {
  case lemon, orange, coral, berry, grape, sky, teal, mint, gold, slate, choco, ink
  var color: Color {
    switch self {
    case .lemon: return Color(hex: 0xF2BE2E)
    case .orange: return Color(hex: 0xF0893E)
    case .coral: return Color(hex: 0xEC6461)
    case .berry: return Color(hex: 0xD2508F)
    case .grape: return Color(hex: 0x7E62EE)
    case .sky: return Color(hex: 0x3F82EE)
    case .teal: return Color(hex: 0x1FA99A)
    case .mint: return Color(hex: 0x3DB97F)
    case .gold: return Color(hex: 0xD99A1E)
    case .slate: return Color(hex: 0x66708C)
    case .choco: return Color(hex: 0x8A5636)
    case .ink: return Color(hex: 0x2346D8)
    }
  }
  /// Lighter partner for gradients.
  var light: Color { color.blend(with: .white, by: 0.45) }
}

struct ArtSpec: Hashable { let symbol: String; let hue: Hue }

enum Art {
  /// emoji (as used in kids-content.json and the web) → symbol + hue.
  static let map: [String: ArtSpec] = [
    // weather & sky
    "☀️": .init(symbol: "sun.max.fill", hue: .lemon), "🌞": .init(symbol: "sun.max.fill", hue: .gold),
    "☁️": .init(symbol: "cloud.fill", hue: .slate), "⛅": .init(symbol: "cloud.sun.fill", hue: .lemon),
    "⛈️": .init(symbol: "cloud.bolt.rain.fill", hue: .grape), "🌦️": .init(symbol: "cloud.sun.rain.fill", hue: .sky),
    "⛄": .init(symbol: "snowflake", hue: .sky), "🌙": .init(symbol: "moon.fill", hue: .gold), "⭐": .init(symbol: "star.fill", hue: .lemon),
    "✨": .init(symbol: "sparkles", hue: .gold), "🔭": .init(symbol: "binoculars.fill", hue: .grape),
    // money
    "💰": .init(symbol: "dollarsign.circle.fill", hue: .mint), "💵": .init(symbol: "banknote.fill", hue: .mint),
    "🪙": .init(symbol: "centsign.circle.fill", hue: .gold), "🫙": .init(symbol: "archivebox.fill", hue: .teal),
    "🐷": .init(symbol: "gift.fill", hue: .berry), "🏦": .init(symbol: "building.columns.fill", hue: .slate),
    "🧾": .init(symbol: "doc.plaintext.fill", hue: .slate), "🏷️": .init(symbol: "tag.fill", hue: .coral),
    "➕": .init(symbol: "plus.circle.fill", hue: .mint), "🎁": .init(symbol: "gift.fill", hue: .coral),
    // growing
    "🌱": .init(symbol: "leaf.fill", hue: .mint), "🌳": .init(symbol: "tree.fill", hue: .mint), "🌻": .init(symbol: "sun.min.fill", hue: .lemon),
    "🥚": .init(symbol: "oval.portrait.fill", hue: .lemon), "🐄": .init(symbol: "drop.fill", hue: .sky), "🐢": .init(symbol: "tortoise.fill", hue: .teal),
    // companies & work
    "🏪": .init(symbol: "storefront.fill", hue: .coral), "🏠": .init(symbol: "house.fill", hue: .orange), "🏡": .init(symbol: "house.fill", hue: .mint),
    "🧑‍🍳": .init(symbol: "frying.pan.fill", hue: .orange), "🧑‍💼": .init(symbol: "briefcase.fill", hue: .slate), "🔧": .init(symbol: "wrench.and.screwdriver.fill", hue: .slate),
    "🤝": .init(symbol: "hands.clap.fill", hue: .orange), "🏟️": .init(symbol: "sportscourt.fill", hue: .teal), "👑": .init(symbol: "crown.fill", hue: .gold),
    "🍕": .init(symbol: "chart.pie.fill", hue: .orange), "🍰": .init(symbol: "birthday.cake.fill", hue: .berry), "🎂": .init(symbol: "birthday.cake.fill", hue: .coral),
    "🍋": .init(symbol: "drop.circle.fill", hue: .lemon), "🍎": .init(symbol: "apple.logo", hue: .coral), "🍭": .init(symbol: "sparkles", hue: .berry),
    // charts & reports
    "📈": .init(symbol: "chart.line.uptrend.xyaxis", hue: .mint), "📊": .init(symbol: "chart.bar.fill", hue: .sky), "📝": .init(symbol: "doc.text.fill", hue: .sky),
    "📋": .init(symbol: "list.clipboard.fill", hue: .sky), "📅": .init(symbol: "calendar", hue: .coral), "🗓️": .init(symbol: "calendar", hue: .coral),
    "🔮": .init(symbol: "sparkle.magnifyingglass", hue: .grape), "🔍": .init(symbol: "magnifyingglass", hue: .sky), "🕵️": .init(symbol: "magnifyingglass.circle.fill", hue: .grape),
    "👍": .init(symbol: "hand.thumbsup.fill", hue: .mint), "👎": .init(symbol: "hand.thumbsdown.fill", hue: .coral), "✅": .init(symbol: "checkmark.circle.fill", hue: .mint),
    "❓": .init(symbol: "questionmark.circle.fill", hue: .grape), "🎢": .init(symbol: "chart.line.uptrend.xyaxis", hue: .berry), "🚩": .init(symbol: "flag.fill", hue: .coral),
    "🗳️": .init(symbol: "checkmark.rectangle.stack.fill", hue: .sky), "📣": .init(symbol: "megaphone.fill", hue: .orange), "🔔": .init(symbol: "bell.fill", hue: .gold),
    "🔤": .init(symbol: "textformat.abc", hue: .sky),
    // feelings & people
    "🧠": .init(symbol: "brain.head.profile", hue: .berry), "🤔": .init(symbol: "questionmark.bubble.fill", hue: .grape), "😮": .init(symbol: "exclamationmark.bubble.fill", hue: .orange),
    "🤷": .init(symbol: "questionmark.circle.fill", hue: .slate), "🤞": .init(symbol: "hands.sparkles.fill", hue: .grape), "🙋": .init(symbol: "hand.raised.fill", hue: .orange),
    "👀": .init(symbol: "eye.fill", hue: .sky), "🎉": .init(symbol: "party.popper.fill", hue: .berry), "🎭": .init(symbol: "theatermasks.fill", hue: .grape),
    "🃏": .init(symbol: "suit.club.fill", hue: .slate),
    // things kids know
    "🎒": .init(symbol: "backpack.fill", hue: .coral), "🎓": .init(symbol: "graduationcap.fill", hue: .ink), "🧥": .init(symbol: "tshirt.fill", hue: .sky),
    "👟": .init(symbol: "shoeprints.fill", hue: .coral), "🚲": .init(symbol: "bicycle", hue: .teal), "🚗": .init(symbol: "car.fill", hue: .coral),
    "🚀": .init(symbol: "paperplane.fill", hue: .coral), "🧸": .init(symbol: "teddybear.fill", hue: .choco), "🧩": .init(symbol: "puzzlepiece.fill", hue: .grape),
    "🧱": .init(symbol: "cube.fill", hue: .coral), "🧺": .init(symbol: "basket.fill", hue: .choco), "📦": .init(symbol: "shippingbox.fill", hue: .choco),
    "🛒": .init(symbol: "cart.fill", hue: .sky), "📱": .init(symbol: "iphone", hue: .slate), "💻": .init(symbol: "laptopcomputer", hue: .slate),
    "🎮": .init(symbol: "gamecontroller.fill", hue: .grape), "🕹️": .init(symbol: "gamecontroller.fill", hue: .ink), "🎲": .init(symbol: "dice.fill", hue: .coral),
    "🎧": .init(symbol: "headphones", hue: .mint), "🏀": .init(symbol: "basketball.fill", hue: .orange), "🎯": .init(symbol: "target", hue: .coral),
    "🏰": .init(symbol: "wand.and.stars", hue: .grape), "🍟": .init(symbol: "takeoutbag.and.cup.and.straw.fill", hue: .coral), "🥤": .init(symbol: "bubbles.and.sparkles.fill", hue: .coral),
    "🥨": .init(symbol: "fork.knife", hue: .choco), "🍿": .init(symbol: "popcorn.fill", hue: .coral), "▶️": .init(symbol: "play.rectangle.fill", hue: .coral),
    "☕": .init(symbol: "cup.and.saucer.fill", hue: .teal), "🌯": .init(symbol: "fork.knife", hue: .orange), "🍫": .init(symbol: "rectangle.split.3x3.fill", hue: .choco),
    // League players
    "🦊": .init(symbol: "pawprint.fill", hue: .orange), "🦄": .init(symbol: "wand.and.stars", hue: .berry), "🐼": .init(symbol: "teddybear.fill", hue: .slate),
    "🐙": .init(symbol: "fish.fill", hue: .berry),
    // the map & market world
    "🕯️": .init(symbol: "chart.bar.xaxis", hue: .coral), "🧭": .init(symbol: "safari.fill", hue: .teal), "🌊": .init(symbol: "water.waves", hue: .sky),
    "⛰️": .init(symbol: "mountain.2.fill", hue: .slate), "🛤️": .init(symbol: "point.topleft.down.to.point.bottomright.curvepath.fill", hue: .orange),
    "🏝️": .init(symbol: "beach.umbrella.fill", hue: .teal), "📡": .init(symbol: "antenna.radiowaves.left.and.right", hue: .sky),
    "〰️": .init(symbol: "waveform.path", hue: .grape), "🔊": .init(symbol: "speaker.wave.3.fill", hue: .sky), "🪜": .init(symbol: "stairs", hue: .orange),
    "⏳": .init(symbol: "hourglass", hue: .grape), "⏰": .init(symbol: "alarm.fill", hue: .orange),
    "📉": .init(symbol: "chart.line.downtrend.xyaxis", hue: .coral), "⬆️": .init(symbol: "arrow.up.circle.fill", hue: .mint),
    "⬇️": .init(symbol: "arrow.down.circle.fill", hue: .coral), "💤": .init(symbol: "moon.zzz.fill", hue: .grape), "🌕": .init(symbol: "circle.fill", hue: .gold),
  ]
  static let fallback = ArtSpec(symbol: "sparkles", hue: .grape)
  static func spec(_ key: String) -> ArtSpec {
    if let s = map[key] { return s }
    let trimmed = key.replacingOccurrences(of: "\u{FE0F}", with: "")
    return map[trimmed] ?? map.first { $0.key.replacingOccurrences(of: "\u{FE0F}", with: "") == trimmed }?.value ?? fallback
  }
  /// For tests: every key whose symbol must exist.
  static var allSymbols: [String] { Array(Set(map.values.map(\.symbol) + [fallback.symbol])) }
}

/// One illustration: an emoji key (or `.symbol`) drawn as a designed tile, halo or inline glyph.
struct Glyph: View {
  enum Style { case tile, halo, plain }
  let spec: ArtSpec
  var size: CGFloat = 44
  var style: Style = .tile
  init(_ key: String, size: CGFloat = 44, style: Style = .tile) { spec = Art.spec(key); self.size = size; self.style = style }
  init(symbol: String, hue: Hue, size: CGFloat = 44, style: Style = .tile) { spec = ArtSpec(symbol: symbol, hue: hue); self.size = size; self.style = style }

  var body: some View {
    Group {
      switch style {
      case .tile:
        RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
          .fill(LinearGradient(colors: [spec.hue.light, spec.hue.color], startPoint: .topLeading, endPoint: .bottomTrailing))
          .overlay(RoundedRectangle(cornerRadius: size * 0.3, style: .continuous).strokeBorder(.white.opacity(0.35), lineWidth: max(0.5, size * 0.02)))
          .overlay(Image(systemName: spec.symbol).font(.system(size: size * 0.48, weight: .semibold)).foregroundStyle(.white).shadow(color: .black.opacity(0.12), radius: 1, y: 1))
          .frame(width: size, height: size)
          .shadow(color: spec.hue.color.opacity(0.28), radius: size * 0.16, y: size * 0.08)
      case .halo:
        ZStack {
          Circle().fill(RadialGradient(colors: [spec.hue.light.opacity(0.9), spec.hue.light.opacity(0)], center: .center, startRadius: size * 0.1, endRadius: size * 0.62))
          Circle().fill(spec.hue.light.opacity(0.55)).frame(width: size * 0.74, height: size * 0.74)
          Image(systemName: spec.symbol).font(.system(size: size * 0.38, weight: .semibold)).foregroundStyle(spec.hue.color)
            .symbolRenderingMode(.hierarchical)
        }
        .frame(width: size, height: size)
      case .plain:
        Image(systemName: spec.symbol).font(.system(size: size * 0.8, weight: .semibold)).foregroundStyle(spec.hue.color).symbolRenderingMode(.hierarchical)
          .frame(width: size, height: size)
      }
    }
    .accessibilityHidden(true)
  }
}

extension Color {
  /// Linear blend in sRGB (iOS 17; `Color.mix` is iOS 18+).
  func blend(with other: Color, by t: Double) -> Color {
    let a = UIColor(self), b = UIColor(other)
    var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0, r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
    a.getRed(&r1, green: &g1, blue: &b1, alpha: &a1); b.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
    let k = CGFloat(t)
    return Color(.sRGB, red: Double(r1 + (r2 - r1) * k), green: Double(g1 + (g2 - g1) * k), blue: Double(b1 + (b2 - b1) * k), opacity: Double(a1 + (a2 - a1) * k))
  }
}
