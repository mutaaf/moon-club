import SwiftUI

/// Every animation in Moon Club comes from these few tokens, so nothing competes or feels "off":
/// - tap: instant press feedback (<1 frame to start, ~0.2 s settle)
/// - card: cards and steps moving in and out
/// - page: big layout changes (tabs, spreads, the map camera)
/// - celebrate: the one bouncy moment (stars, conquering, badges)
/// - gentle: ambient loops (Luna's float, clouds); ease, never spring
/// Reduce Motion swaps every one of them for a short cross-fade (`Motion.safe`).
enum Motion {
  static let tap = Animation.spring(response: 0.22, dampingFraction: 0.75)
  static let card = Animation.spring(response: 0.42, dampingFraction: 0.86)
  static let page = Animation.spring(response: 0.55, dampingFraction: 0.9)
  static let celebrate = Animation.spring(response: 0.5, dampingFraction: 0.6)
  static let gentle = Animation.easeInOut(duration: 2.8)
  static let fade = Animation.easeOut(duration: 0.18)

  static func safe(_ a: Animation, _ reduceMotion: Bool) -> Animation { reduceMotion ? fade : a }
}

/// Appear animations that run once per app session for a given id (not on every tab switch / re-appear).
@MainActor final class AppearOnce {
  static let shared = AppearOnce()
  private var seen = Set<String>()
  func first(_ id: String) -> Bool { seen.insert(id).inserted }
}

extension View {
  /// Fades + rises in the first time `id` appears this session; afterwards it's simply there.
  func enterOnce(_ id: String, delay: Double = 0) -> some View { modifier(EnterOnce(id: id, delay: delay)) }
}

private struct EnterOnce: ViewModifier {
  let id: String; let delay: Double
  @Environment(\.accessibilityReduceMotion) private var rm
  @State private var shown: Bool? = nil
  func body(content: Content) -> some View {
    content
      .opacity(shown == false ? 0 : 1)
      .offset(y: shown == false && !rm ? 14 : 0)
      .onAppear {
        guard shown == nil else { return }
        if AppearOnce.shared.first(id) {
          shown = false
          withAnimation(Motion.safe(Motion.card, rm).delay(rm ? 0 : delay)) { shown = true }
        } else { shown = true }
      }
  }
}
