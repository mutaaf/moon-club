import SwiftUI
import MoonClubCore

/// Moon Club's palette: calm, minimal, Apple-quiet. Moon cream, midnight ink, one ultramarine accent.
enum Palette {
  static let moon = Color(hex: 0xFFF3C4)
  static let moonShade = Color(hex: 0xECD88F)
  static let midnight = Color(hex: 0x16152B)
  /// The accent follows the kid's "App colors" pick in the Moon Shop (ThemeColor, set at the root).
  static var accent: Color { Color(hex: ThemeColor.hex) }
  /// The accent for TEXT, ICONS, LINES and system tint: the accent in light mode, lifted halfway to white in dark
  /// mode so it reads on the night paper and cards (≥ 4.5:1). Fills with white text on top keep `accent`.
  static var accentInk: Color { Color(light: ThemeColor.hex, dark: lift(ThemeColor.hex)) }
  /// Mixes a colour toward white (dark-mode inks).
  static func lift(_ hex: UInt32, _ t: Double = 0.5) -> UInt32 {
    func ch(_ v: UInt32) -> UInt32 { UInt32((Double(v) + (255 - Double(v)) * t).rounded()) }
    return ch((hex >> 16) & 0xff) << 16 | ch((hex >> 8) & 0xff) << 8 | ch(hex & 0xff)
  }
  static let lavender = Color(hex: 0xECE4FF)
  static let mint = Color(hex: 0xD9F3E6)
  static let peach = Color(hex: 0xFFE4D2)
  static let sky = Color(hex: 0xDFE8FF)
  static let good = Color(hex: 0x1F7A4D)
  static let bad = Color(hex: 0xB4472F)
  /// Text / line versions that keep AA contrast on dark backgrounds too.
  static let goodInk = Color(light: 0x1F7A4D, dark: 0x6BDCA6)
  static let badInk = Color(light: 0xB4472F, dark: 0xFF9480)
  static let blush = Color(hex: 0xFF9FB0)
  static let paper = Color(light: 0xFBFAF7, dark: 0x0F0E22)
  static let card = Color(light: 0xFFFFFF, dark: 0x1D1C3D)
  static let ink = Color(light: 0x16152B, dark: 0xF4F1FF)
  static let ink2 = Color(light: 0x4A4862, dark: 0xDAD6F4)
  static let line = Color(light: 0xE6E1F2, dark: 0x45417F)
}

/// The app's accent color (the Moon Shop's "App colors" slot; widgets keep the default). Set by the root.
enum ThemeColor {
  nonisolated(unsafe) static var hex: UInt32 = 0x2346D8
}

extension Color {
  init(hex: UInt32, alpha: Double = 1) {
    self.init(.sRGB, red: Double((hex >> 16) & 0xff) / 255, green: Double((hex >> 8) & 0xff) / 255, blue: Double(hex & 0xff) / 255, opacity: alpha)
  }
  init(light: UInt32, dark: UInt32) {
    self.init(UIColor { $0.userInterfaceStyle == .dark ? UIColor(Color(hex: dark)) : UIColor(Color(hex: light)) })
  }
}

/// Type scale: SF Pro Rounded for headlines (friendly), SF Pro for reading. Everything scales with Dynamic Type.
extension Font {
  static let kHero = Font.system(.largeTitle, design: .rounded).weight(.heavy)
  static let kTitle = Font.system(.title2, design: .rounded).weight(.bold)
  static let kHeadline = Font.system(.headline, design: .rounded).weight(.semibold)
  static let kRead = Font.system(.title3, design: .default).weight(.medium)
  static let kBody = Font.system(.body)
  static let kEyebrow = Font.system(.caption, design: .monospaced).weight(.medium)
}

struct Eyebrow: View {
  let text: String
  var body: some View { Text(text.uppercased()).font(.kEyebrow).tracking(1.6).foregroundStyle(Palette.accentInk) }
}

/// The surfaces each get their own aurora palette (Story = dawn, Quest = lemon, School = calm blue, Luna = moonlight).
enum Surface {
  case story, quest, school, luna, piggy, guess, grownups
  var aurora: [Color] {
    switch self {
    case .story: return [Color(hex: 0xC9B8FF), Color(hex: 0xFFC9D9), Color(hex: 0xBFD3FF)]
    case .quest: return [Color(hex: 0xFFE27A), Color(hex: 0xFFC48A), Color(hex: 0xC8F0B4)]
    case .school: return [Color(hex: 0xA9C4FF), Color(hex: 0xB8E6F2), Color(hex: 0xD6CCFF)]
    case .luna: return [Color(hex: 0xFFF3C4), Color(hex: 0xC9C2FF), Color(hex: 0x9DB4FF)]
    case .piggy: return [Color(hex: 0xFFC9D6), Color(hex: 0xFFE4B8), Color(hex: 0xD6C9FF)]
    case .guess: return [Color(hex: 0xB9F0D8), Color(hex: 0xBFD3FF), Color(hex: 0xFFD9B8)]
    case .grownups: return [Color(hex: 0xD9D6E8), Color(hex: 0xE8E3D6), Color(hex: 0xD6E3E8)]
    }
  }
}
