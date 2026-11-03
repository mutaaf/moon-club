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
    "🐷": .init(symbol: "custom.piggy", hue: .berry), "🏦": .init(symbol: "building.columns.fill", hue: .slate),
    "🧾": .init(symbol: "doc.plaintext.fill", hue: .slate), "🏷️": .init(symbol: "tag.fill", hue: .coral),
    "➕": .init(symbol: "plus.circle.fill", hue: .mint), "🎁": .init(symbol: "gift.fill", hue: .coral),
    // growing
    "🌱": .init(symbol: "leaf.fill", hue: .mint), "🌳": .init(symbol: "tree.fill", hue: .mint), "🌻": .init(symbol: "camera.macro", hue: .lemon),
    "🥚": .init(symbol: "oval.portrait.fill", hue: .orange), "🐄": .init(symbol: "pawprint.fill", hue: .choco), "🐢": .init(symbol: "tortoise.fill", hue: .teal),
    // companies & work
    "🏪": .init(symbol: "storefront.fill", hue: .coral), "🏠": .init(symbol: "house.fill", hue: .orange), "🏡": .init(symbol: "house.fill", hue: .mint),
    "🧑‍🍳": .init(symbol: "frying.pan.fill", hue: .orange), "🧑‍💼": .init(symbol: "briefcase.fill", hue: .slate), "🔧": .init(symbol: "wrench.and.screwdriver.fill", hue: .slate),
    "🤝": .init(symbol: "hands.clap.fill", hue: .orange), "🏟️": .init(symbol: "sportscourt.fill", hue: .teal), "👑": .init(symbol: "crown.fill", hue: .gold),
    "🍕": .init(symbol: "chart.pie.fill", hue: .orange), "🍰": .init(symbol: "birthday.cake.fill", hue: .berry), "🎂": .init(symbol: "birthday.cake.fill", hue: .coral),
    "🍋": .init(symbol: "custom.lemon", hue: .lemon), "🍎": .init(symbol: "fork.knife.circle.fill", hue: .coral), "🍭": .init(symbol: "birthday.cake.fill", hue: .berry),
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
    "🏰": .init(symbol: "crown.fill", hue: .berry), "🍟": .init(symbol: "takeoutbag.and.cup.and.straw.fill", hue: .coral), "🥤": .init(symbol: "bubbles.and.sparkles.fill", hue: .coral),
    "🥨": .init(symbol: "fork.knife", hue: .choco), "🍿": .init(symbol: "popcorn.fill", hue: .coral), "▶️": .init(symbol: "play.rectangle.fill", hue: .coral),
    "☕": .init(symbol: "cup.and.saucer.fill", hue: .teal), "🌯": .init(symbol: "fork.knife", hue: .orange), "🍫": .init(symbol: "rectangle.split.3x3.fill", hue: .choco),
    // League players
    "🦊": .init(symbol: "pawprint.fill", hue: .orange), "🦄": .init(symbol: "wand.and.stars", hue: .berry), "🐼": .init(symbol: "teddybear.fill", hue: .slate),
    "🐙": .init(symbol: "fish.fill", hue: .berry),
    // the map & market world
    "🕯️": .init(symbol: "custom.candle", hue: .coral), "🧭": .init(symbol: "safari.fill", hue: .teal), "🌊": .init(symbol: "water.waves", hue: .sky),
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
  /// For review: every emoji key and what it's drawn as ("🍋 → custom.lemon (lemon)"), sorted.
  static var reviewList: [String] { map.map { "\($0.key) → \($0.value.symbol) (\($0.value.hue))" }.sorted() }
  /// Pairs a reviewer flagged as misleading; a test keeps them from coming back.
  static let neverAgain: [String: String] = ["🐄": "drop.fill", "🍋": "drop.circle.fill", "🌻": "sun.min.fill", "🏰": "wand.and.stars", "💰": "drop.fill"]
  /// For tests: every key whose symbol must exist.
  static var allSymbols: [String] { Array(Set(map.values.map(\.symbol) + [fallback.symbol])).filter { !$0.hasPrefix("custom.") } }
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
          .overlay(mark(size * 0.48, color: .white).shadow(color: .black.opacity(0.12), radius: 1, y: 1))
          .frame(width: size, height: size)
          .shadow(color: spec.hue.color.opacity(0.28), radius: size * 0.16, y: size * 0.08)
      case .halo:
        ZStack {
          Circle().fill(RadialGradient(colors: [spec.hue.light.opacity(0.9), spec.hue.light.opacity(0)], center: .center, startRadius: size * 0.1, endRadius: size * 0.62))
          Circle().fill(spec.hue.light.opacity(0.55)).frame(width: size * 0.74, height: size * 0.74)
          mark(size * 0.38, color: spec.hue.color)
        }
        .frame(width: size, height: size)
      case .plain:
        mark(size * 0.8, color: spec.hue.color).frame(width: size, height: size)
      }
    }
    .accessibilityHidden(true)
  }

  /// The symbol itself, or one of Moon Club's own drawn marks (`custom.*`) where no SF Symbol fits.
  @ViewBuilder private func mark(_ s: CGFloat, color: Color) -> some View {
    if spec.symbol == "custom.candle" { CandleMark(color: color).frame(width: s * 1.1, height: s * 1.2) }
    else if spec.symbol == "custom.lemon" { LemonMark(tint: color == .white ? .white : nil).frame(width: s * 1.25, height: s * 1.05) }
    else if spec.symbol == "custom.piggy" { PiggyMark(tint: color == .white ? .white : nil).frame(width: s * 1.3, height: s * 1.05) }
    else { Image(systemName: spec.symbol).font(.system(size: s, weight: .semibold)).foregroundStyle(color).symbolRenderingMode(.hierarchical) }
  }
}

/// The Pretend Piggy Bank, drawn: round pink body, snout, ear, eye, legs and a coin slot on top.
/// `tint` paints it in one color (white on a colored tile); nil uses its own pinks.
struct PiggyMark: View {
  var tint: Color? = nil
  var body: some View {
    Canvas { g, sz in
      let w = sz.width, h = sz.height
      let body = tint ?? Color(hex: 0xF7A6BE), shade = tint?.opacity(0.75) ?? Color(hex: 0xE57FA0), ink = tint == nil ? Palette.midnight : Color(hex: 0xD2508F)
      for x in [0.3, 0.62] { g.fill(Path(roundedRect: CGRect(x: w * x, y: h * 0.72, width: w * 0.12, height: h * 0.24), cornerRadius: w * 0.04), with: .color(shade)) }
      g.fill(Path(ellipseIn: CGRect(x: w * 0.08, y: h * 0.14, width: w * 0.8, height: h * 0.68)), with: .color(body))
      var ear = Path(); ear.move(to: .init(x: w * 0.56, y: h * 0.2)); ear.addLine(to: .init(x: w * 0.66, y: h * 0.02)); ear.addLine(to: .init(x: w * 0.74, y: h * 0.24)); ear.closeSubpath()
      g.fill(ear, with: .color(shade))
      g.fill(Path(ellipseIn: CGRect(x: w * 0.76, y: h * 0.38, width: w * 0.2, height: h * 0.24)), with: .color(shade))
      for dx in [0.82, 0.89] { g.fill(Path(ellipseIn: CGRect(x: w * dx, y: h * 0.46, width: w * 0.035, height: h * 0.07)), with: .color(ink.opacity(0.7))) }
      g.fill(Path(ellipseIn: CGRect(x: w * 0.64, y: h * 0.34, width: w * 0.05, height: h * 0.07)), with: .color(ink))
      g.fill(Path(roundedRect: CGRect(x: w * 0.36, y: h * 0.18, width: w * 0.2, height: h * 0.05), cornerRadius: h * 0.025), with: .color(ink.opacity(0.55)))
      var tail = Path(); tail.move(to: .init(x: w * 0.09, y: h * 0.42)); tail.addQuadCurve(to: .init(x: w * 0.02, y: h * 0.36), control: .init(x: w * 0.0, y: h * 0.46))
      g.stroke(tail, with: .color(shade), style: .init(lineWidth: max(1.5, w * 0.03), lineCap: .round))
    }
    .accessibilityHidden(true)
  }
}

/// A lemon, drawn: a yellow oval with pointed ends and a leaf. `tint` paints it one color (on a tile).
struct LemonMark: View {
  var tint: Color? = nil
  var body: some View {
    Canvas { g, sz in
      let w = sz.width, h = sz.height
      let peel = tint ?? Color(hex: 0xF7CF3B), rind = tint?.opacity(0.7) ?? Color(hex: 0xD99A1E), leaf = tint?.opacity(0.85) ?? Color(hex: 0x3DB97F)
      var l = Path(); l.move(to: .init(x: w * 0.52, y: h * 0.24)); l.addQuadCurve(to: .init(x: w * 0.86, y: h * 0.06), control: .init(x: w * 0.62, y: h * 0.0)); l.addQuadCurve(to: .init(x: w * 0.52, y: h * 0.24), control: .init(x: w * 0.78, y: h * 0.3))
      g.fill(l, with: .color(leaf))
      var b = Path()
      b.move(to: .init(x: w * 0.04, y: h * 0.6))
      b.addQuadCurve(to: .init(x: w * 0.5, y: h * 0.2), control: .init(x: w * 0.14, y: h * 0.2))
      b.addQuadCurve(to: .init(x: w * 0.96, y: h * 0.6), control: .init(x: w * 0.86, y: h * 0.2))
      b.addQuadCurve(to: .init(x: w * 0.5, y: h * 0.98), control: .init(x: w * 0.86, y: h * 0.98))
      b.addQuadCurve(to: .init(x: w * 0.04, y: h * 0.6), control: .init(x: w * 0.14, y: h * 0.98))
      g.fill(b, with: .color(peel))
      g.stroke(b, with: .color(rind), lineWidth: max(1, w * 0.04))
      g.fill(Path(ellipseIn: CGRect(x: w * 0.3, y: h * 0.38, width: w * 0.16, height: h * 0.1)), with: .color(.white.opacity(tint == nil ? 0.55 : 0.3)))
    }
    .accessibilityHidden(true)
  }
}

/// Two candlesticks (one up, one down) drawn as a mark: the picture for "candle" everywhere.
struct CandleMark: View {
  var color: Color
  var body: some View {
    Canvas { g, sz in
      let w = sz.width * 0.3, lw = max(1.5, sz.width * 0.07)
      for (x, top, bot, hi, lo, a) in [(0.28, 0.32, 0.78, 0.12, 0.92, 1.0), (0.72, 0.18, 0.55, 0.04, 0.7, 0.55)] {
        let cx = sz.width * x
        g.stroke(Path { $0.move(to: .init(x: cx, y: sz.height * hi)); $0.addLine(to: .init(x: cx, y: sz.height * lo)) }, with: .color(color.opacity(a)), style: .init(lineWidth: lw, lineCap: .round))
        g.fill(Path(roundedRect: CGRect(x: cx - w / 2, y: sz.height * top, width: w, height: sz.height * (bot - top)), cornerRadius: w * 0.2), with: .color(color.opacity(a)))
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
