import SwiftUI

/// A short celebratory particle burst (Canvas — one draw call per frame, no views per particle).
/// Used for badges and finished lessons. Skipped entirely under Reduce Motion.
struct Celebrate: View {
  let trigger: Int
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var start: Date?
  private let particles: [P] = (0..<46).map { i in
    let a = Double(i) / 46 * .pi * 2 + Double.random(in: -0.2...0.2)
    return P(angle: a, speed: .random(in: 180...420), spin: .random(in: -6...6), size: .random(in: 6...12),
             color: [Palette.accent, Palette.moonShade, Palette.blush, Color(hex: 0x7FD1AE), Color(hex: 0xA48BFF)][i % 5], star: i % 3 == 0)
  }
  struct P { let angle: Double, speed: Double, spin: Double, size: Double, color: Color, star: Bool }

  var body: some View {
    TimelineView(.animation(paused: start == nil)) { ctx in
      Canvas { g, size in
        guard let start else { return }
        let t = ctx.date.timeIntervalSince(start)
        guard t < 1.6 else { return }
        let c = CGPoint(x: size.width / 2, y: size.height * 0.42)
        for p in particles {
          let x = c.x + cos(p.angle) * p.speed * t
          let y = c.y + sin(p.angle) * p.speed * t + 420 * t * t
          var ctx2 = g
          ctx2.opacity = max(0, 1 - t / 1.6)
          ctx2.translateBy(x: x, y: y); ctx2.rotate(by: .radians(p.spin * t))
          let r = CGRect(x: -p.size / 2, y: -p.size / 2, width: p.size, height: p.size * (p.star ? 1 : 0.55))
          ctx2.fill(p.star ? Path(ellipseIn: r) : Path(roundedRect: r, cornerRadius: 2), with: .color(p.color))
        }
      }
    }
    .allowsHitTesting(false)
    .accessibilityHidden(true)
    .onChange(of: trigger) { _, _ in
      guard !reduceMotion else { return }
      start = Date()
      Task { try? await Task.sleep(for: .seconds(1.7)); start = nil }
    }
  }
}
