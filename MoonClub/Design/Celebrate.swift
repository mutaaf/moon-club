import SwiftUI
import AudioToolbox
import MoonClubCore

// One celebration system, three tiers (rules in MoonClubCore `Party.swift`):
//  • small  — every right answer: a sparkle where you tapped (`Sparkle`), coins to the HUD, Luna bounces,
//             a light haptic and the system click.
//  • medium — combo ×3, a perfect round, a badge tier: a confetti shower, a glow round the screen edge,
//             Luna flips, a success haptic.
//  • large  — a boss beaten, a land won, a rank-up, a chest, a streak milestone: fireworks, two confetti
//             cannons, a camera shake, a rising chime. On an open iPhone Duo the fireworks cross the fold.
// 0.14: the bursts are instanced Metal particles (Particles.swift: one draw call, positions computed on the
// GPU, hidden + paused when idle); the Canvas drawing below stays as the fallback and for the small Sparkle. Reduce Motion swaps particles for a calm glow + the haptic.

// MARK: - Global party (large/medium moments from anywhere)

@MainActor @Observable final class PartyCenter {
  static let shared = PartyCenter()
  private(set) var tick = 0
  private(set) var tier: CelebrationTier = .large
  private(set) var title: String?
  private(set) var shakeTick = 0

  /// Throw a party for a moment. `title` shows big for large moments ("A whole week!").
  func fire(_ m: PartyMoment, title: String? = nil) {
    tier = m.tier
    self.title = m.tier == .large ? title : nil
    tick &+= 1
    if m.tier == .large { shakeTick &+= 1; Chime.rising() }
  }
}

/// A rising three-note chime from system sounds (no licensed audio). Follows the sound switch.
enum Chime {
  @MainActor static func rising() {
    guard UserDefaults.standard.object(forKey: PlayPrefs.soundsKey) as? Bool ?? true else { return }
    for (i, id) in [SystemSoundID(1103), 1057, 1025].enumerated() {
      Task { try? await Task.sleep(for: .milliseconds(140 * i)); AudioServicesPlaySystemSound(id) }
    }
  }
}

/// Sits over the whole window (Root). Shows the current party; full screen on every device, both halves
/// of an iPhone Duo included.
struct PartyOverlay: View {
  @Environment(DuoModel.self) private var duo: DuoModel?
  @State private var party = PartyCenter.shared
  var body: some View {
    GeometryReader { g in
      // An open iPhone Duo (wide, with a hinge): fireworks launch from one page and burst over the other.
      let crossFold = duo?.reading.map { $0.status != .closed } == true && g.size.width > g.size.height
      ZStack {
        Celebrate(trigger: party.tick, tier: party.tier, crossFold: crossFold)
        if let t = party.title { PartyTitle(text: t, trigger: party.tick) }
      }
    }
    .ignoresSafeArea()
    .allowsHitTesting(false)
    .accessibilityHidden(true)
    .sensoryFeedback(trigger: party.tick) { _, _ in party.tier == .small ? .impact(weight: .light) : .success }
  }
}

/// The camera shake for large moments, applied once at the root.
struct PartyShake: ViewModifier {
  @State private var party = PartyCenter.shared
  @Environment(\.accessibilityReduceMotion) private var rm
  func body(content: Content) -> some View {
    content.modifier(Shake(amount: rm ? 0 : 7, tick: party.shakeTick))
      .animation(.linear(duration: 0.45), value: party.shakeTick)
  }
}

private struct PartyTitle: View {
  let text: String; let trigger: Int
  @Environment(\.accessibilityReduceMotion) private var rm
  @State private var shown = false
  var body: some View {
    Text(text)
      .font(.system(size: 40, weight: .black, design: .rounded))
      .multilineTextAlignment(.center)
      .foregroundStyle(LinearGradient(colors: [Hue.lemon.color, Hue.gold.color], startPoint: .top, endPoint: .bottom))
      .shadow(color: .black.opacity(0.35), radius: 8, y: 4)
      .padding(24)
      .scaleEffect(shown ? 1 : (rm ? 1 : 0.3))
      .opacity(shown ? 1 : 0)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .onChange(of: trigger, initial: true) { _, _ in
        withAnimation(Motion.safe(Motion.celebrate, rm)) { shown = true }
        Task { try? await Task.sleep(for: .seconds(2.2)); withAnimation(Motion.fade) { shown = false } }
      }
  }
}

// MARK: - The particles

/// A celebration burst. `tier` picks the show; existing call sites keep the medium confetti burst.
struct Celebrate: View {
  let trigger: Int
  var tier: CelebrationTier = .medium
  var crossFold = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var start: Date?
  @State private var seed: UInt64 = 1

  private var duration: Double { tier == .large ? 2.8 : tier == .medium ? 1.9 : 0.8 }
  /// GPU particles when Metal is available (debug `-particles canvas` compares the old Canvas path).
  static let gpu: Bool = {
    #if DEBUG
    if ProcessInfo.processInfo.arguments.contains("canvas") && ProcessInfo.processInfo.arguments.contains("-particles") { return false }
    #endif
    return ParticleRenderer.shared != nil
  }()

  var body: some View {
    let calm = reduceMotion || !FX.shared.allowsBursts(reduceMotion: reduceMotion)   // Low Power / hot: glow only
    ZStack {
      if calm { EdgeGlow(trigger: trigger, strength: tier == .small ? 0 : 1) }
      else {
        if tier >= .medium { EdgeGlow(trigger: trigger, strength: tier == .large ? 1 : 0.7) }
        if Self.gpu {
          // 0.14: instanced Metal particles (Design/Particles.swift); idle = hidden + paused.
          GPUParticles(trigger: trigger, tier: tier, crossFold: crossFold, duration: duration + 0.6)
        } else {
        TimelineView(.animation(paused: start == nil)) { ctx in
          Canvas { g, size in
            guard let start else { return }
            let t = ctx.date.timeIntervalSince(start)
            guard t < duration else { return }
            switch tier {
            case .small: Burst.draw(&g, size: size, t: t, center: CGPoint(x: size.width / 2, y: size.height * 0.42), count: 18, speed: 220, seed: seed)
            case .medium:
              Burst.draw(&g, size: size, t: t, center: CGPoint(x: size.width / 2, y: size.height * 0.42), count: 46, speed: 420, seed: seed)
              Confetti.shower(&g, size: size, t: t, count: 70, seed: seed)
            case .large:
              Confetti.cannons(&g, size: size, t: t, count: 60, seed: seed)
              Fireworks.draw(&g, size: size, t: t, shells: 5, crossFold: crossFold, seed: seed)
              Confetti.shower(&g, size: size, t: max(0, t - 0.5), count: 90, seed: seed &+ 7)
            }
          }
        }
        }
      }
    }
    .allowsHitTesting(false)
    .accessibilityHidden(true)
    .onChange(of: trigger) { _, _ in
      guard !reduceMotion, !Self.gpu else { return }
      seed = UInt64(trigger &* 2654435761) | 1
      start = Date()
      let d = duration
      Task { try? await Task.sleep(for: .seconds(d + 0.1)); start = nil }
    }
  }
}

/// A small sparkle burst centred on its own frame (an answer button, a chest): the "where you tapped" pop.
struct Sparkle: View {
  let trigger: Int
  var tier: CelebrationTier = .small
  @Environment(\.accessibilityReduceMotion) private var rm
  @State private var start: Date?
  var body: some View {
    TimelineView(.animation(paused: start == nil)) { ctx in
      Canvas { g, size in
        guard let start else { return }
        let t = ctx.date.timeIntervalSince(start)
        guard t < 0.7 else { return }
        Burst.draw(&g, size: size, t: t, center: CGPoint(x: size.width / 2, y: size.height / 2), count: 14, speed: 160, gravity: 60, life: 0.7, stars: true, seed: 9)
      }
    }
    .allowsHitTesting(false)
    .accessibilityHidden(true)
    .onChange(of: trigger) { old, new in
      guard !rm, new > old else { return }
      start = Date()
      Task { try? await Task.sleep(for: .seconds(0.8)); start = nil }
    }
  }
}

/// A soft glow around the screen edge (medium/large, and the Reduce Motion stand-in for particles).
struct EdgeGlow: View {
  let trigger: Int; var strength: Double = 1
  @State private var on = false
  var body: some View {
    RoundedRectangle(cornerRadius: 44, style: .continuous)
      .strokeBorder(AngularGradient(colors: [Hue.lemon.color, Hue.coral.color, Hue.grape.color, Hue.sky.color, Hue.mint.color, Hue.lemon.color], center: .center), lineWidth: 14)
      .blur(radius: 14)
      .opacity(on ? strength : 0)
      .ignoresSafeArea()
      .allowsHitTesting(false)
      .onChange(of: trigger) { _, _ in
        guard strength > 0 else { return }
        withAnimation(.easeOut(duration: 0.25)) { on = true }
        Task { try? await Task.sleep(for: .seconds(1.1)); withAnimation(.easeIn(duration: 0.6)) { on = false } }
      }
  }
}

// MARK: - Drawing (pure functions of time; a tiny LCG keeps every frame consistent without stored arrays)

private struct LCG { var s: UInt64; mutating func next() -> Double { s = s &* 6364136223846793005 &+ 1442695040888963407; return Double(s >> 33) / Double(1 << 31) } }
private let brand: [Color] = [Palette.moonShade, Hue.coral.color, Hue.grape.color, Hue.sky.color, Hue.mint.color, Hue.lemon.color, Palette.blush]

private enum Burst {
  static func draw(_ g: inout GraphicsContext, size: CGSize, t: Double, center c: CGPoint, count: Int, speed: Double, gravity: Double = 420, life: Double = 1.6, stars: Bool = false, seed: UInt64) {
    var r = LCG(s: seed)
    for i in 0..<count {
      let a = Double(i) / Double(count) * .pi * 2 + (r.next() - 0.5) * 0.4
      let v = speed * (0.45 + r.next() * 0.55)
      let x = c.x + cos(a) * v * t, y = c.y + sin(a) * v * t + gravity * t * t
      let sz = 5 + r.next() * 7
      var k = g
      k.opacity = max(0, 1 - t / life)
      k.translateBy(x: x, y: y); k.rotate(by: .radians((r.next() - 0.5) * 12 * t))
      let rect = CGRect(x: -sz / 2, y: -sz / 2, width: sz, height: sz)
      let path = (stars || i % 3 == 0) ? Star.path(in: rect) : Path(roundedRect: rect.insetBy(dx: 0, dy: sz * 0.22), cornerRadius: 2)
      k.fill(path, with: .color(brand[i % brand.count]))
    }
  }
}

private enum Confetti {
  /// Paper falling from the top edge, swaying.
  static func shower(_ g: inout GraphicsContext, size: CGSize, t: Double, count: Int, seed: UInt64) {
    guard t > 0 else { return }
    var r = LCG(s: seed)
    for i in 0..<count {
      let x0 = r.next() * size.width, delay = r.next() * 0.6, fall = 180 + r.next() * 260
      let tt = t - delay; guard tt > 0 else { continue }
      let x = x0 + sin(tt * 3 + Double(i)) * 24, y = -20 + fall * tt
      guard y < size.height + 20 else { continue }
      var k = g
      k.opacity = min(1, max(0, 2.6 - tt))
      k.translateBy(x: x, y: y); k.rotate(by: .radians(tt * (r.next() * 8 - 4)))
      let w = 7 + r.next() * 5
      k.fill(Path(roundedRect: CGRect(x: -w / 2, y: -w * 0.3, width: w, height: w * 0.6), cornerRadius: 1.5), with: .color(brand[i % brand.count]))
    }
  }
  /// Two cannons firing up and inward from the bottom corners.
  static func cannons(_ g: inout GraphicsContext, size: CGSize, t: Double, count: Int, seed: UInt64) {
    var r = LCG(s: seed &+ 3)
    for side in [0.0, 1.0] {
      let origin = CGPoint(x: side == 0 ? 0 : size.width, y: size.height)
      for i in 0..<count / 2 {
        let a = (side == 0 ? -1.15 : -.pi + 1.15) + (r.next() - 0.5) * 0.6
        let v = size.height * (0.9 + r.next() * 0.6)
        let x = origin.x + cos(a) * v * t, y = origin.y + sin(a) * v * t + 900 * t * t
        guard y < size.height + 30 else { continue }
        var k = g
        k.opacity = max(0, 1 - t / 2.6)
        k.translateBy(x: x, y: y); k.rotate(by: .radians(t * (r.next() * 14 - 7)))
        let w = 8 + r.next() * 6
        let rect = CGRect(x: -w / 2, y: -w * 0.3, width: w, height: w * 0.6)
        k.fill(i % 4 == 0 ? Star.path(in: rect.insetBy(dx: 0, dy: -w * 0.2)) : Path(roundedRect: rect, cornerRadius: 1.5), with: .color(brand[(i + Int(side)) % brand.count]))
      }
    }
  }
}

private enum Fireworks {
  /// Shells rise, then burst into rings of sparks. With `crossFold`, shells launch from the left page and
  /// burst over the right one (and back), so the show crosses an open iPhone Duo's fold.
  static func draw(_ g: inout GraphicsContext, size: CGSize, t: Double, shells: Int, crossFold: Bool, seed: UInt64) {
    var r = LCG(s: seed &+ 11)
    for s in 0..<shells {
      let delay = Double(s) * 0.32 + r.next() * 0.1
      let tt = t - delay; guard tt > 0 else { continue }
      let fromLeft = s % 2 == 0
      let x0 = crossFold ? size.width * (fromLeft ? 0.2 : 0.8) : size.width * (0.2 + r.next() * 0.6)
      let x1 = crossFold ? size.width * (fromLeft ? 0.72 : 0.28) + (r.next() - 0.5) * 60 : x0 + (r.next() - 0.5) * 80
      let peak = CGPoint(x: x1, y: size.height * (0.18 + r.next() * 0.22))
      let rise = 0.55
      let color = brand[(s * 2) % brand.count]
      if tt < rise {
        let k = tt / rise, e = 1 - (1 - k) * (1 - k)
        let p = CGPoint(x: x0 + (peak.x - x0) * e, y: size.height + (peak.y - size.height) * e)
        g.fill(Path(ellipseIn: CGRect(x: p.x - 3, y: p.y - 3, width: 6, height: 6)), with: .color(.white))
        var trail = Path(); trail.move(to: p); trail.addLine(to: CGPoint(x: p.x - (peak.x - x0) * 0.05, y: p.y + 26))
        g.stroke(trail, with: .color(color.opacity(0.7)), lineWidth: 2)
      } else {
        let bt = tt - rise
        guard bt < 1.4 else { continue }
        let n = 34
        for i in 0..<n {
          let a = Double(i) / Double(n) * .pi * 2
          let v = 190 + Double(i % 3) * 40
          let x = peak.x + cos(a) * v * bt, y = peak.y + sin(a) * v * bt + 90 * bt * bt
          var k = g
          k.opacity = max(0, 1 - bt / 1.4)
          let sz = 6.5
          k.fill(Path(ellipseIn: CGRect(x: x - sz / 2, y: y - sz / 2, width: sz, height: sz)), with: .color(i % 2 == 0 ? color : .white))
        }
      }
    }
  }
}

private enum Star {
  static func path(in r: CGRect) -> Path {
    var p = Path()
    let c = CGPoint(x: r.midX, y: r.midY), R = min(r.width, r.height) / 2, ri = R * 0.45
    for i in 0..<10 {
      let a = Double(i) * .pi / 5 - .pi / 2, rad = i % 2 == 0 ? R : ri
      let pt = CGPoint(x: c.x + cos(a) * rad, y: c.y + sin(a) * rad)
      if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
    }
    p.closeSubpath(); return p
  }
}
