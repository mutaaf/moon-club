import SwiftUI
import QuartzCore
import MoonClubCore

// Lesson scenes: each Moon School card is a small living window. An aurora field in the unit's colors
// (the `ribbons` shader) is projected behind Luna and a prop acting out the lesson's idea: a coin drops into
// the piggy bank, a lemonade cup fills, candles grow, a shield pops up. Which scene a lesson gets is pure data
// in MoonClubCore `Scenes.swift` (a new lesson always resolves to one).
//
// The budget (hard, see CLAUDE.md "Lesson scenes"):
//  • ONE shared clock per size class (`SceneClock.tiles` 20 fps, `.hero` 30 fps), a CADisplayLink that runs only
//    while a card that wants it is on screen (LazyVStack onAppear/onDisappear), the app is active, and the
//    graphics budget is full (`FX`: not under Reduce Motion, Low Power Mode or a hot device).
//  • It runs for a few seconds after something wakes it (a card appears, the kid scrolls, the app comes back),
//    then rests: every card settles on a still pose and nothing draws per frame.
//  • A moving card is one small shader rectangle + one `Canvas` (the act and, on small cards, Luna; no view
//    tree per prop, no blur). A card at rest, and every card while the list scrolls (the clock pauses), is ONE
//    cached image of its still frame (`SceneStill`, prewarmed as Moon School opens): creating Canvases while
//    scrolling made the list hitch. Bigger Lunas are the cached shaded texture.
//  • Finished lessons never subscribe to the clock: a calm, still "done" pose.

// MARK: - Colors

extension ScenePalette {
  /// Three aurora ribbon colors (light), over `sky`.
  var ribbons: [Color] {
    switch self {
    case .mint: return [Color(hex: 0x3DF5A6), Color(hex: 0x2BC3E8), Color(hex: 0x9B7BFF)]
    case .sunrise: return [Color(hex: 0xFFB35C), Color(hex: 0xFF6F91), Color(hex: 0xFFE27A)]
    case .gold: return [Color(hex: 0xFFD45C), Color(hex: 0x7CF0B5), Color(hex: 0xFF9F6B)]
    case .coral: return [Color(hex: 0xFF7A7A), Color(hex: 0xFFB86B), Color(hex: 0xB58CFF)]
    case .teal: return [Color(hex: 0x31E6C9), Color(hex: 0x5CB8FF), Color(hex: 0xA8FF8F)]
    case .ocean: return [Color(hex: 0x5C9DFF), Color(hex: 0x37E0E0), Color(hex: 0xB794FF)]
    case .berry: return [Color(hex: 0xFF6FB5), Color(hex: 0xB58CFF), Color(hex: 0x6FD8FF)]
    case .grape: return [Color(hex: 0xA58BFF), Color(hex: 0x6FE3FF), Color(hex: 0xFF8AD8)]
    case .dusk: return [Color(hex: 0x7CF0B5), Color(hex: 0xFFC36B), Color(hex: 0x8CA8FF)]
    }
  }
  /// The night sky behind the ribbons (white text on it is well above AA).
  var sky: Color {
    switch self {
    case .mint, .teal: return Color(hex: 0x0B1A2C)
    case .sunrise, .coral: return Color(hex: 0x1E1233)
    case .gold, .dusk: return Color(hex: 0x14162E)
    case .ocean: return Color(hex: 0x0C1433)
    case .berry: return Color(hex: 0x1A0F30)
    case .grape: return Color(hex: 0x130F33)
    }
  }
}

extension LessonScene {
  /// The prop's picture: the table's symbol, else the lesson's own art (shield scenes always get a shield).
  func symbol(for lesson: Lesson) -> String {
    prop ?? (act == .shield ? "checkmark.shield.fill" : Art.spec(lesson.emoji).symbol)
  }
}

// MARK: - The shared clock

/// One display link for every scene of a size class. Cards `retain()` it while they're on screen; it ticks at
/// `fps` only while someone holds it, the app is active and the budget is full, and only for `runFor` seconds
/// after the last `wake()`. Then it stops (`running` = false) and every card eases into its still pose.
@MainActor @Observable
final class SceneClock {
  static let tiles = SceneClock(fps: 20, maxFps: 24, runFor: 12)
  static let hero = SceneClock(fps: 30, maxFps: 30, runFor: 14)

  /// Seconds, stable while resting (so the aurora keeps its last frame).
  private(set) var t: Double = 0
  private(set) var running = false

  @ObservationIgnored private let fps: Float
  @ObservationIgnored private let maxFps: Float
  @ObservationIgnored private let runFor: Double
  @ObservationIgnored private var holders = 0
  @ObservationIgnored private var link: CADisplayLink?
  @ObservationIgnored private var restAt: CFTimeInterval = 0
  @ObservationIgnored private var active = true
  @ObservationIgnored private var scrolling = false
  @ObservationIgnored private let target = LinkTarget()

  /// Pause while the list is being dragged or flung (the scroll gets the whole main thread), then wake.
  static let pausesWhileScrolling = true

  /// Debug: `-scenes still` never runs (what Reduce Motion looks like), `-scenes full` never rests, `-scenes off`
  /// draws the old icon squares in Moon School (A/B for `-bench school`).
  static let forced: String? = {
    #if DEBUG
    let a = ProcessInfo.processInfo.arguments
    if let i = a.firstIndex(of: "-scenes"), i + 1 < a.count { return a[i + 1] }
    #endif
    return nil
  }()

  private init(fps: Float, maxFps: Float, runFor: Double) {
    self.fps = fps; self.maxFps = maxFps; self.runFor = runFor
    target.clock = self
    let nc = NotificationCenter.default
    nc.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
      MainActor.assumeIsolated { self?.active = false; self?.stop() }
    }
    nc.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
      MainActor.assumeIsolated { self?.active = true; self?.wake() }
    }
    for n in [UIAccessibility.reduceMotionStatusDidChangeNotification, .NSProcessInfoPowerStateDidChange, ProcessInfo.thermalStateDidChangeNotification] {
      nc.addObserver(forName: n, object: nil, queue: .main) { [weak self] _ in MainActor.assumeIsolated { self?.wake() } }
    }
  }

  /// Full graphics budget right now (Reduce Motion, Low Power Mode and a hot device all mean still frames).
  private var allowed: Bool {
    if Self.forced == "still" { return false }
    return FX.shared.level(visible: true, active: active, reduceMotion: UIAccessibility.isReduceMotionEnabled) == .full
  }

  /// A card coming on screen wakes the clock too (on iOS 17, with no scroll phases, that is how scrolling wakes it).
  func retain() { holders += 1; wake() }
  func release() { holders = max(0, holders - 1); if holders == 0 { stop() } }

  /// Run (again) for `runFor` seconds, if anyone is watching and the budget allows.
  func wake() {
    guard holders > 0, active, !(scrolling && Self.pausesWhileScrolling), allowed else { stop(); return }
    restAt = CACurrentMediaTime() + (Self.forced == "full" ? .infinity : runFor)
    if link == nil {
      let l = CADisplayLink(target: target, selector: #selector(LinkTarget.tick(_:)))
      l.preferredFrameRateRange = CAFrameRateRange(minimum: min(15, fps), maximum: maxFps, preferred: fps)
      l.add(to: .main, forMode: .common)
      link = l
    }
    if !running { running = true }
  }

  func stop() {
    link?.invalidate(); link = nil
    if running { withAnimation(.easeInOut(duration: 0.5)) { running = false } }
  }

  /// The list started or stopped scrolling (iOS 18+ scroll phases). Moving wakes the cards afterwards.
  func setScrolling(_ on: Bool) {
    guard on != scrolling else { return }
    scrolling = on
    settle?.cancel()
    if on && Self.pausesWhileScrolling { stop(); return }
    // Wake once the list has rested a moment (a kid flicking again right away never restarts it in between).
    settle = Task { [weak self] in
      try? await Task.sleep(for: .milliseconds(400))
      if !Task.isCancelled { self?.wake() }
    }
  }
  @ObservationIgnored private var settle: Task<Void, Never>?

  fileprivate func tick(_ l: CADisplayLink) {
    let _ = Perf.body("SceneTick")
    t = l.targetTimestamp.truncatingRemainder(dividingBy: 3_600)
    if l.timestamp >= restAt { stop() }
  }

  private final class LinkTarget: NSObject {
    weak var clock: SceneClock?
    @objc func tick(_ l: CADisplayLink) { MainActor.assumeIsolated { clock?.tick(l) } }
  }
}

/// Holds the clock while the view is on screen and `live`, and tells the view (`onScreen`) so it reads the clock
/// only then. Moon School is a LazyVStack, so "appeared" is "on screen or just about to be"; a lesson pushed on
/// top makes it disappear. (A plain VStack with per-row scroll-visibility tracking measured worse: 13 ms/frame
/// of main thread while scrolling, every row built up front.)
struct ClockHold: ViewModifier {
  let clock: SceneClock
  let live: Bool
  @Binding var onScreen: Bool
  @State private var held = false
  func body(content: Content) -> some View {
    content
      .onAppear { onScreen = true; sync() }
      .onDisappear { onScreen = false; sync() }
      .onChange(of: live) { _, _ in sync() }
  }
  private func sync() {
    let want = onScreen && live
    if want && !held { held = true; clock.retain() } else if !want && held { held = false; clock.release() }
  }
}

// MARK: - The pieces

/// The aurora sky: one `ribbons` shader rectangle while it moves; at rest, a cached still image (a flat night
/// color under Reduce Transparency). The still matters while scrolling: a shader layer is re-run every frame it
/// moves on screen, so a list of live shader tiles made the scroll hitch (~85 hitches on the iPhone 17 sim's
/// `-bench school`); a still image only gets composited.
struct SceneSky: View {
  let palette: ScenePalette
  var t: Double
  var glow: Double = 1
  var live = true
  @Environment(\.accessibilityReduceTransparency) private var solid
  @Environment(\.displayScale) private var scale
  var body: some View {
    if solid {
      palette.sky
    } else if !live {
      GeometryReader { g in
        if let img = SkyStill.image(palette, size: g.size, glow: glow, scale: scale) {
          Image(uiImage: img).resizable().frame(width: g.size.width, height: g.size.height)
        }
      }
      .transition(.opacity)
    } else {
      let c = palette.ribbons, sky = palette.sky, tt = Float(t), g = Float(glow)
      Rectangle().visualEffect { content, proxy in
        content.colorEffect(ShaderLibrary.ribbons(.float2(proxy.size), .float(tt), .color(c[0]), .color(c[1]), .color(c[2]), .color(sky), .float(g)))
      }
    }
  }
}

/// Still skies, rendered once per palette, size and glow (shaded with `ImageRenderer`, which runs SwiftUI
/// shaders, like `LunaTexture`). Neighbouring cards of one unit share a still; ~20 images cover the list.
@MainActor enum SkyStill {
  /// The time the still sky is drawn at (a nice frame).
  static let t: Double = 23
  private static var cache: [String: UIImage] = [:]
  static func image(_ palette: ScenePalette, size: CGSize, glow: Double, scale: CGFloat) -> UIImage? {
    let w = (size.width).rounded(), h = (size.height).rounded()
    guard w > 0, h > 0 else { return nil }
    let key = "\(palette.rawValue)|\(Int(w))x\(Int(h))|\(Int(glow * 100))|\(Int(scale))"
    if let hit = cache[key] { return hit }
    let c = palette.ribbons
    let view = Rectangle().frame(width: w, height: h)
      .colorEffect(ShaderLibrary.ribbons(.float2(w, h), .float(Float(t)), .color(c[0]), .color(c[1]), .color(c[2]), .color(palette.sky), .float(Float(glow))))
    let r = ImageRenderer(content: view)
    r.scale = scale
    r.isOpaque = true
    guard let img = r.uiImage else { return nil }
    if cache.count > 48 { cache.removeAll() }
    cache[key] = img
    return img
  }
}

/// Pictures of small cards' still frames (sky + act + Luna), drawn once with `ImageRenderer`. A Canvas costs
/// most when it's created: each new one made the list hitch while scrolling (~75 extra hitches on the iPhone
/// 17 sim's `-bench school`, the same with a still clock), while an image is cheap to show. Moon School
/// prewarms the pictures in small batches when it opens; one picture is ~140 KB at 3x.
@MainActor enum SceneStill {
  private static var cache: [String: UIImage] = [:]
  static func image(_ frame: SceneFrame, scale: CGFloat) -> UIImage? {
    let key = frame.stillKey + "|\(Int(scale))"
    if let hit = cache[key] { return hit }
    var f = frame
    f.rasterizesStill = false; f.forRaster = true; f.clock = nil
    let r = ImageRenderer(content: f.environment(\.colorScheme, .dark))
    r.scale = scale
    r.isOpaque = frame.showsSky
    guard let img = r.uiImage else { return nil }
    if cache.count > 160 { cache.removeAll() }
    cache[key] = img
    return img
  }
  /// Draws the pictures for these cards a few per frame, so opening Moon School never stalls.
  static func prewarm(_ frames: [SceneFrame], scale: CGFloat) async {
    for (i, f) in frames.enumerated() {
      guard !Task.isCancelled else { return }
      _ = image(f, scale: scale)
      if i % 3 == 2 { try? await Task.sleep(for: .milliseconds(20)) }
    }
  }
}

/// Where a card is in its life: not started, up next, finished.
enum SceneStatus { case open, next, done }

/// Draws one frame of an act in a `Canvas`. `p` is 0..<1 through the loop (the action plays in the first ~60%,
/// then holds); `prop` is the canvas symbol id of the prop view.
struct ActPainter {
  let act: SceneAct
  let colors: [Color]
  let sky: Color
  let p: Double

  static let coin = Color(hex: 0xFFD45C), coinEdge = Color(hex: 0xC98A12)
  static let up = Color(hex: 0x7CF0B5), down = Color(hex: 0xFF8A80), flag = Color(hex: 0xFF5A5A)
  static let lemonade = Color(hex: 0xFFE27A), leaf = Color(hex: 0x7CF0B5), soil = Color(hex: 0x9A6A4A)

  func draw(_ g: inout GraphicsContext, _ size: CGSize) {
    let u = min(size.width, size.height)
    let c = CGPoint(x: size.width / 2, y: size.height / 2)
    func pt(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: c.x + x * u, y: c.y + y * u) }
    func circle(_ x: Double, _ y: Double, _ r: Double) -> Path { Path(ellipseIn: CGRect(x: c.x + (x - r) * u, y: c.y + (y - r) * u, width: 2 * r * u, height: 2 * r * u)) }
    /// Draws the prop (a resolved symbol view) at (x, y), `scale` × its base size.
    func prop(_ x: Double, _ y: Double, scale: Double = 1, sx: Double = 1, angle: Double = 0, opacity: Double = 1) {
      guard let s = g.resolveSymbol(id: 0), opacity > 0.01 else { return }
      g.drawLayer { l in
        l.opacity = opacity
        l.translateBy(x: c.x + x * u, y: c.y + y * u)
        if angle != 0 { l.rotate(by: .degrees(angle)) }
        l.scaleBy(x: scale * sx, y: scale)
        l.draw(s, at: .zero, anchor: .center)
      }
    }
    func symbol(_ name: String, _ x: Double, _ y: Double, _ side: Double, _ color: Color, angle: Double = 0, opacity: Double = 1, flipX: Bool = false) {
      guard opacity > 0.01, side > 0.001 else { return }
      var img = g.resolve(Image(systemName: name))
      img.shading = .color(color)
      g.drawLayer { l in
        l.opacity = opacity
        l.translateBy(x: c.x + x * u, y: c.y + y * u)
        if angle != 0 { l.rotate(by: .degrees(angle)) }
        if flipX { l.scaleBy(x: -1, y: 1) }
        let s = img.size, k = side * u / max(s.width, s.height)
        l.draw(img, in: CGRect(x: -s.width * k / 2, y: -s.height * k / 2, width: s.width * k, height: s.height * k))
      }
    }
    func coin(_ x: Double, _ y: Double, _ r: Double, opacity: Double = 1) {
      guard opacity > 0.01 else { return }
      g.drawLayer { l in
        l.opacity = opacity
        l.fill(circle(x, y, r), with: .color(Self.coin))
        l.stroke(circle(x, y, r * 0.86), with: .color(Self.coinEdge), lineWidth: max(1, r * u * 0.22))
        l.fill(circle(x - r * 0.3, y - r * 0.3, r * 0.22), with: .color(.white.opacity(0.7)))
      }
    }
    let fade = 1 - ramp(p, 0.9, 0.99)

    // A soft glow behind the prop so it reads on any ribbon.
    g.fill(circle(0.02, 0.04, 0.36), with: .radialGradient(Gradient(colors: [.white.opacity(0.16), .white.opacity(0)]), center: pt(0.02, 0.04), startRadius: 0, endRadius: 0.36 * u))

    switch act {
    case .drop:
      let k = ramp(p, 0, 0.42)
      coin(0.04, -0.42 + 0.44 * k * k, 0.085, opacity: 1 - ramp(p, 0.38, 0.46))
      let squash = bump(p, 0.42, 0.62)
      prop(0.04, 0.17 + 0.015 * squash, scale: 1 - 0.07 * squash, sx: 1 + 0.15 * squash)
      let sp = bump(p, 0.44, 0.72)
      symbol("sparkle", -0.2, -0.06 - 0.06 * sp, 0.14 * sp, Self.coin)
      symbol("sparkle", 0.3, -0.1 - 0.05 * sp, 0.1 * sp, .white)

    case .fill:
      let top = -0.2, bot = 0.32, half = 0.2, halfB = 0.14, cx = 0.06
      var cup = Path()
      cup.move(to: pt(cx - half, top)); cup.addLine(to: pt(cx + half, top)); cup.addLine(to: pt(cx + halfB, bot)); cup.addLine(to: pt(cx - halfB, bot)); cup.closeSubpath()
      let level = 0.9 * ramp(p, 0.06, 0.62)
      let surface = bot - (bot - top) * level
      if p < 0.66 { // the pour
        let s = bump(p, 0.0, 0.66)
        g.fill(Path(roundedRect: CGRect(x: c.x + (cx - 0.02) * u, y: c.y - 0.48 * u, width: 0.04 * u, height: (surface + 0.48) * u * min(1, s * 3)), cornerRadius: 0.02 * u), with: .color(Self.lemonade.opacity(0.9)))
      }
      g.drawLayer { l in
        l.clip(to: cup)
        l.fill(Path(CGRect(x: c.x + (cx - half) * u, y: c.y + surface * u, width: 2 * half * u, height: (bot - surface) * u)), with: .color(Self.lemonade))
        l.fill(Path(CGRect(x: c.x + (cx - half) * u, y: c.y + surface * u, width: 2 * half * u, height: 0.03 * u)), with: .color(.white.opacity(0.6)))
      }
      g.stroke(Path { $0.move(to: pt(cx + 0.1, -0.36)); $0.addLine(to: pt(cx + 0.02, 0.16)) }, with: .color(Self.down), style: .init(lineWidth: 0.035 * u, lineCap: .round))
      g.stroke(cup, with: .color(.white), style: .init(lineWidth: 0.035 * u, lineJoin: .round))
      let lemon = ramp(p, 0.6, 0.7)
      if lemon > 0 {
        g.fill(circle(cx - half + 0.02, top + 0.01, 0.075 * lemon), with: .color(Self.lemonade))
        g.stroke(circle(cx - half + 0.02, top + 0.01, 0.075 * lemon), with: .color(Self.coinEdge), lineWidth: 0.018 * u)
      }

    case .candles:
      let xs = [-0.24, 0.0, 0.24], hs = [0.22, 0.3, 0.18], bottoms = [0.3, 0.16, 0.06], ups = [true, true, false]
      for i in 0..<3 {
        let k = ramp(p, Double(i) * 0.17, Double(i) * 0.17 + 0.24)
        guard k > 0 else { continue }
        let h = hs[i] * k, b = bottoms[i], col = ups[i] ? Self.up : Self.down
        g.stroke(Path { $0.move(to: pt(xs[i], b + 0.06 * k)); $0.addLine(to: pt(xs[i], b - h - 0.07 * k)) }, with: .color(col), style: .init(lineWidth: 0.03 * u, lineCap: .round))
        let r = CGRect(x: c.x + (xs[i] - 0.07) * u, y: c.y + (b - h) * u, width: 0.14 * u, height: h * u)
        // Up = hollow, down = filled: direction never by colour alone (CandleInk).
        if ups[i] {
          g.fill(Path(roundedRect: r, cornerRadius: 0.02 * u), with: .color(sky))
          g.stroke(Path(roundedRect: r.insetBy(dx: 0.016 * u, dy: 0.016 * u), cornerRadius: 0.02 * u), with: .color(col), lineWidth: 0.032 * u)
        } else {
          g.fill(Path(roundedRect: r, cornerRadius: 0.02 * u), with: .color(col))
        }
      }

    case .inflate:
      let k = ramp(p, 0, 0.45)
      prop(0.02, 0.06, scale: 0.62 + 0.42 * back(k))
      let a = ramp(p, 0.25, 0.4)
      symbol("arrow.up", 0.32, -0.26 - 0.05 * bump(p, 0.3, 0.7), 0.2 * a, Self.down, opacity: a)

    case .shield:
      prop(0.12, 0.02, scale: back(ramp(p, 0, 0.3)))
      let inK = ramp(p, 0.22, 0.4), outK = ramp(p, 0.4, 0.64)
      if inK > 0 && outK < 1 {
        let x = -0.52 + 0.4 * inK - 0.3 * outK, y = -0.08 + 0.42 * outK * outK
        symbol("flag.fill", x, y, 0.22, Self.flag, angle: -130 * outK, opacity: 1 - outK)
      }
      let ring = bump(p, 0.38, 0.6)
      if ring > 0 { g.stroke(circle(0.12, 0.02, 0.22 + 0.12 * ramp(p, 0.38, 0.6)), with: .color(.white.opacity(0.7 * ring)), lineWidth: 0.025 * u) }

    case .pop:
      let k = ramp(p, 0, 0.32)
      prop(0.04, 0.04 - 0.08 * bump(p, 0, 0.36), scale: 0.3 + 0.7 * back(k))
      let r = 0.2 + 0.14 * ramp(p, 0.25, 0.55), o = bump(p, 0.25, 0.7)
      for (i, a) in [-50.0, -125.0, -15.0].enumerated() {
        let rad = a * .pi / 180
        symbol("sparkle", 0.04 + r * cos(rad), 0.04 + r * sin(rad), [0.14, 0.11, 0.09][i], i == 1 ? .white : Self.coin, opacity: o)
      }

    case .collect:
      let starts = [(-0.44, -0.3), (0.0, -0.5), (0.46, -0.32)], ends = [(-0.06, 0.08), (0.06, 0.05), (0.16, 0.09)]
      for i in 0..<3 {
        let a = 0.06 + Double(i) * 0.16, k = ramp(p, a, a + 0.24)
        guard k > 0 else { continue }
        let x = starts[i].0 + (ends[i].0 - starts[i].0) * k
        let y = starts[i].1 + (ends[i].1 - starts[i].1) * k - 0.2 * sin(.pi * k)
        g.drawLayer { l in
          l.opacity = min(1, k * 5) * fade
          l.fill(circle(x, y, 0.075), with: .color(colors[i]))
          l.stroke(circle(x, y, 0.075), with: .color(.white.opacity(0.8)), lineWidth: 0.018 * u)
        }
      }
      symbol("basket.fill", 0.06, 0.22, 0.46, .white)

    case .sprout:
      g.fill(Path(ellipseIn: CGRect(x: c.x - 0.3 * u, y: c.y + 0.26 * u, width: 0.6 * u, height: 0.14 * u)), with: .color(Self.soil))
      let stem = 0.4 * ramp(p, 0, 0.35)
      if stem > 0 {
        g.stroke(Path { $0.move(to: pt(0.02, 0.3)); $0.addQuadCurve(to: pt(0.02, 0.3 - stem), control: pt(-0.04, 0.3 - stem / 2)) }, with: .color(Self.leaf), style: .init(lineWidth: 0.045 * u, lineCap: .round))
      }
      let l1 = back(ramp(p, 0.28, 0.46)), l2 = back(ramp(p, 0.38, 0.56))
      symbol("leaf.fill", -0.1, 0.0, 0.22 * l1, Self.leaf, angle: -20, flipX: true)
      symbol("leaf.fill", 0.14, -0.08, 0.24 * l2, Self.leaf, angle: 10)
      let s = bump(p, 0.52, 0.8)
      symbol("sparkle", 0.28, -0.3, 0.12 * s, Self.coin)

    case .roll:
      g.stroke(Path { $0.move(to: pt(-0.5, 0.1)); $0.addLine(to: pt(0.5, 0.38)) }, with: .color(.white.opacity(0.55)), style: .init(lineWidth: 0.025 * u, lineCap: .round))
      let k = ramp(p, 0, 0.62)
      let x = -0.36 + 0.62 * k, r = 0.07 + 0.13 * k
      let gy = 0.1 + (x + 0.5) * 0.28
      let y = gy - r - 0.01
      g.drawLayer { l in
        l.opacity = fade
        l.fill(circle(x, y, r), with: .color(.white))
        l.stroke(circle(x, y, r), with: .color(Color(hex: 0xA9C4FF)), lineWidth: 0.02 * u)
        let a = k * 4 * .pi
        for d in [0.0, 2.1, 4.2] {
          l.fill(circle(x + r * 0.55 * cos(a + d), y + r * 0.55 * sin(a + d), r * 0.13), with: .color(Color(hex: 0xA9C4FF)))
        }
      }

    case .climb, .wiggle:
      let pts = act == .climb ? Self.hill : Self.wiggly
      var path = Path(); path.move(to: pt(pts[0].0, pts[0].1)); for q in pts.dropFirst() { path.addLine(to: pt(q.0, q.1)) }
      let k = ramp(p, 0, 0.6)
      if act == .wiggle { g.stroke(Path { $0.move(to: pt(-0.42, 0.04)); $0.addLine(to: pt(0.42, 0.04)) }, with: .color(.white.opacity(0.3 * fade)), style: .init(lineWidth: 0.02 * u, dash: [0.04 * u, 0.04 * u])) }
      g.drawLayer { l in
        l.opacity = fade
        l.stroke(path.trimmedPath(from: 0, to: max(0.001, k)), with: .color(colors[0]), style: .init(lineWidth: 0.05 * u, lineCap: .round, lineJoin: .round))
        let head = point(on: pts, at: k)
        l.fill(circle(head.0, head.1, 0.055), with: .color(.white))
      }

    case .slice:
      let center = pt(0, 0.06), r = 0.3 * u
      var pie = Path(); pie.move(to: center); pie.addArc(center: center, radius: r, startAngle: .degrees(0), endAngle: .degrees(300), clockwise: false); pie.closeSubpath()
      g.fill(pie, with: .color(colors[1]))
      g.stroke(pie, with: .color(.white.opacity(0.85)), style: .init(lineWidth: 0.025 * u, lineJoin: .round))
      let out = 0.11 * back(ramp(p, 0.1, 0.4)) * u
      let mid = -30.0 * .pi / 180
      let wc = CGPoint(x: center.x + out * cos(mid), y: center.y + out * sin(mid) - 0.04 * u * bump(p, 0.1, 0.5))
      var w = Path(); w.move(to: wc); w.addArc(center: wc, radius: r, startAngle: .degrees(300), endAngle: .degrees(360), clockwise: false); w.closeSubpath()
      g.fill(w, with: .color(colors[0]))
      g.stroke(w, with: .color(.white), style: .init(lineWidth: 0.025 * u, lineJoin: .round))

    case .slide:
      let k = ramp(p, 0, 0.36)
      let x = -0.75 + 0.79 * (1 - (1 - k) * (1 - k))
      let streak = bump(p, 0.02, 0.42)
      for (i, dy) in [-0.1, 0.03, 0.14].enumerated() {
        let len = [0.2, 0.28, 0.16][i]
        g.stroke(Path { $0.move(to: pt(x - 0.28, 0.06 + dy)); $0.addLine(to: pt(x - 0.28 - len, 0.06 + dy)) }, with: .color(.white.opacity(0.6 * streak)), style: .init(lineWidth: 0.025 * u, lineCap: .round))
      }
      prop(x, 0.06 - 0.03 * bump(p, 0.34, 0.5), opacity: fade * min(1, k * 4 + 0.001))

    case .scan:
      prop(-0.04, 0.06)
      let a = p * 2 * .pi
      let mx = 0.0 + 0.16 * cos(a), my = 0.02 + 0.12 * sin(a)
      g.fill(circle(mx - 0.035, my - 0.035, 0.09), with: .color(.white.opacity(0.22)))
      symbol("magnifyingglass", mx, my, 0.34, .white)
      let s = bump(p, 0.55, 0.85)
      symbol("sparkle", 0.3, -0.28, 0.13 * s, Self.coin)

    case .flip:
      let k = ramp(p, 0.2, 0.5)
      // The prop turns over on its axis (it never shows mirrored: the width just narrows and comes back).
      prop(0.03, 0.04, sx: max(0.08, abs(cos(2 * .pi * k))))
      let s = bump(p, 0.48, 0.75)
      symbol("sparkle", 0.28, -0.26, 0.12 * s, Self.coin)
      symbol("sparkle", -0.26, -0.18, 0.08 * s, .white)

    case .wave:
      for i in 0..<3 {
        let k = (p * 1.0 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
        let r = (0.1 + 0.34 * k) * u
        var arc = Path(); arc.addArc(center: pt(0.0, 0.04), radius: r, startAngle: .degrees(-38), endAngle: .degrees(38), clockwise: false)
        g.stroke(arc, with: .color(colors[i].opacity(1 - k)), style: .init(lineWidth: 0.04 * u, lineCap: .round))
      }
      prop(-0.18, 0.04)

    case .tip:
      let th = 14 * (ramp(p, 0.05, 0.3) - 2 * ramp(p, 0.45, 0.7) + ramp(p, 0.85, 1.0))
      let r = th * .pi / 180, py = -0.12
      g.stroke(Path { $0.move(to: pt(0, 0.34)); $0.addLine(to: pt(0, py)) }, with: .color(.white), style: .init(lineWidth: 0.035 * u, lineCap: .round))
      g.fill(Path { $0.move(to: pt(-0.14, 0.36)); $0.addLine(to: pt(0.14, 0.36)); $0.addLine(to: pt(0, 0.26)); $0.closeSubpath() }, with: .color(.white))
      let lx = -0.32 * cos(r), ly = py - 0.32 * sin(r), rx = 0.32 * cos(r), ry = py + 0.32 * sin(r)
      g.stroke(Path { $0.move(to: pt(lx, ly)); $0.addLine(to: pt(rx, ry)) }, with: .color(.white), style: .init(lineWidth: 0.035 * u, lineCap: .round))
      for (x, y) in [(lx, ly), (rx, ry)] {
        g.stroke(Path { $0.move(to: pt(x, y)); $0.addLine(to: pt(x, y + 0.12)) }, with: .color(.white.opacity(0.7)), lineWidth: 0.018 * u)
        var pan = Path(); pan.addArc(center: pt(x, y + 0.12), radius: 0.11 * u, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
        g.fill(pan, with: .color(colors[0].opacity(0.9)))
      }
      prop(lx, ly + 0.04, scale: 0.5)
      symbol("star.fill", rx, ry + 0.05, 0.15, Self.coin)

    case .launch:
      let k = ramp(p, 0.08, 0.55)
      let y = 0.2 - 0.34 * (1 - (1 - k) * (1 - k)) - 0.02 * bump(p, 0.55, 0.9)
      let o = fade * min(1, p / 0.06 + 0.001)
      for i in 0..<3 {
        let q = ramp(p, 0.08 + Double(i) * 0.08, 0.5 + Double(i) * 0.08)
        g.fill(circle(0.05 + 0.04 * Double(i - 1), y + 0.26 + 0.14 * q, 0.04 + 0.04 * q), with: .color(.white.opacity(0.5 * (1 - q) * o * (k > 0 ? 1 : 0))))
      }
      g.drawLayer { l in
        l.opacity = o
        let w = 0.4, x0 = 0.05 - w / 2, y0 = y - w / 2
        func P(_ a: Double, _ b: Double) -> CGPoint { pt(x0 + a * w, y0 + b * w) }
        let flick = 0.96 + 0.08 * sin(p * 80)
        var f = Path(); f.move(to: P(0.4, 0.78)); f.addQuadCurve(to: P(0.6, 0.78), control: P(0.5, 0.78 + 0.22 * flick * (k > 0 ? 1 : 0.4))); f.closeSubpath()
        l.fill(f, with: .color(Color(hex: 0xFFB35C)))
        var fl = Path(); fl.move(to: P(0.36, 0.5)); fl.addLine(to: P(0.18, 0.78)); fl.addLine(to: P(0.38, 0.72)); fl.closeSubpath()
        var fr = Path(); fr.move(to: P(0.64, 0.5)); fr.addLine(to: P(0.82, 0.78)); fr.addLine(to: P(0.62, 0.72)); fr.closeSubpath()
        l.fill(fl, with: .color(Self.down)); l.fill(fr, with: .color(Self.down))
        var b = Path(); b.move(to: P(0.5, 0.04)); b.addQuadCurve(to: P(0.64, 0.76), control: P(0.78, 0.36)); b.addLine(to: P(0.36, 0.76)); b.addQuadCurve(to: P(0.5, 0.04), control: P(0.22, 0.36))
        l.fill(b, with: .color(.white))
        l.fill(Path(ellipseIn: CGRect(origin: P(0.42, 0.28), size: CGSize(width: 0.16 * w * u, height: 0.16 * w * u))), with: .color(colors[0]))
      }

    case .stack:
      prop(-0.18, 0.08, scale: 0.85)
      for i in 0..<4 {
        let a = 0.04 + Double(i) * 0.12, k = ramp(p, a, a + 0.14)
        guard k > 0 else { continue }
        let target = 0.3 - Double(i) * 0.075
        let y = -0.45 + (target + 0.45) * k * k
        let r = CGRect(x: c.x + 0.13 * u, y: c.y + (y - 0.04) * u, width: 0.24 * u, height: 0.08 * u)
        g.drawLayer { l in
          l.opacity = fade
          l.fill(Path(ellipseIn: r), with: .color(Self.coin))
          l.stroke(Path(ellipseIn: r), with: .color(Self.coinEdge), lineWidth: 0.016 * u)
        }
      }
    }
  }

  static let hill: [(Double, Double)] = [(-0.42, 0.28), (-0.24, 0.12), (-0.12, 0.2), (0.06, -0.02), (0.18, 0.04), (0.4, -0.26)]
  static let wiggly: [(Double, Double)] = stride(from: -0.42, through: 0.42, by: 0.06).map { (x: Double) -> (Double, Double) in
    let y: Double = 0.04 + 0.11 * sin(x * 15) * (0.6 + 0.4 * cos(x * 4))
    return (x, y)
  }

  private func point(on pts: [(Double, Double)], at k: Double) -> (Double, Double) {
    var lens: [Double] = [], total = 0.0
    for i in 1..<pts.count { let d = hypot(pts[i].0 - pts[i - 1].0, pts[i].1 - pts[i - 1].1); lens.append(d); total += d }
    var left = k * total
    for i in 1..<pts.count {
      if left <= lens[i - 1] || i == pts.count - 1 {
        let f = lens[i - 1] > 0 ? min(1, left / lens[i - 1]) : 0
        return (pts[i - 1].0 + (pts[i].0 - pts[i - 1].0) * f, pts[i - 1].1 + (pts[i].1 - pts[i - 1].1) * f)
      }
      left -= lens[i - 1]
    }
    return pts[pts.count - 1]
  }
}

/// Smoothstep from a to b.
@inline(__always) func ramp(_ p: Double, _ a: Double, _ b: Double) -> Double {
  let x = min(1, max(0, (p - a) / (b - a))); return x * x * (3 - 2 * x)
}
/// 0 → 1 → 0 across [a, b].
@inline(__always) func bump(_ p: Double, _ a: Double, _ b: Double) -> Double {
  guard p > a, p < b else { return 0 }; return sin((p - a) / (b - a) * .pi)
}
/// Ease out with a little overshoot (a spring's pop).
@inline(__always) func back(_ x: Double) -> Double {
  let c = 1.7, y = x - 1; return x <= 0 ? 0 : 1 + (c + 1) * y * y * y + c * y * y
}

/// The prop as a view (an SF Symbol, or one of Moon Club's drawn marks), handed to the Canvas as symbol 0.
struct PropMark: View {
  let symbol: String
  let side: CGFloat
  var body: some View {
    Group {
      if symbol == "custom.piggy" { PiggyMark(tint: .white).frame(width: side * 1.25, height: side) }
      else if symbol == "custom.lemon" { LemonMark().frame(width: side * 1.2, height: side) }
      else if symbol == "custom.candle" { CandleMark(color: .white).frame(width: side, height: side * 1.1) }
      else { Image(systemName: symbol).font(.system(size: side * 0.86, weight: .semibold)).foregroundStyle(.white).symbolRenderingMode(.hierarchical) }
    }
  }
}

/// Luna for a small card, drawn straight into the scene's Canvas: the moon, two eyes (arcs when she's happy),
/// a smile and blush. Same look as `LunaView`'s small vector disc, without a view per row.
enum MiniLuna {
  static func draw(_ g: inout GraphicsContext, center c: CGPoint, r: CGFloat, happy: Bool) {
    let disc = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
    g.fill(Path(ellipseIn: CGRect(x: c.x - r * 1.25, y: c.y - r * 1.25, width: 2.5 * r, height: 2.5 * r)),
           with: .radialGradient(Gradient(colors: [Palette.moon.opacity(0.35), Palette.moon.opacity(0)]), center: c, startRadius: r * 0.8, endRadius: r * 1.25))
    g.fill(disc, with: .radialGradient(Gradient(colors: [Color(hex: 0xFFF8DA), Palette.moon, Palette.moonShade]), center: CGPoint(x: c.x - r * 0.25, y: c.y - r * 0.35), startRadius: 0, endRadius: r * 1.3))
    let s = r / 32
    g.fill(Path(ellipseIn: CGRect(x: c.x + 11 * s, y: c.y - 21 * s, width: 9 * s, height: 9 * s)), with: .color(Palette.moonShade.opacity(0.5)))
    let ink = Palette.midnight, eyeY = c.y - 4 * s
    for dx in [-8.5 * s, 8.5 * s] {
      if happy {
        var e = Path(); e.move(to: CGPoint(x: c.x + dx - 3.5 * s, y: eyeY + 1.5 * s)); e.addQuadCurve(to: CGPoint(x: c.x + dx + 3.5 * s, y: eyeY + 1.5 * s), control: CGPoint(x: c.x + dx, y: eyeY - 4 * s))
        g.stroke(e, with: .color(ink), style: .init(lineWidth: max(1, 2.4 * s), lineCap: .round))
      } else {
        g.fill(Path(roundedRect: CGRect(x: c.x + dx - 2.7 * s, y: eyeY - 3 * s, width: 5.4 * s, height: 6 * s), cornerRadius: 2.7 * s), with: .color(ink))
      }
      g.fill(Path(ellipseIn: CGRect(x: c.x + dx * 1.25 - 3.5 * s, y: c.y + 3 * s, width: 7 * s, height: 5 * s)), with: .color(Palette.blush.opacity(0.6)))
    }
    var m = Path(); m.move(to: CGPoint(x: c.x - 7 * s, y: c.y + 6 * s)); m.addQuadCurve(to: CGPoint(x: c.x + 7 * s, y: c.y + 6 * s), control: CGPoint(x: c.x, y: c.y + (happy ? 14 : 11) * s))
    g.stroke(m, with: .color(ink), style: .init(lineWidth: max(1, 2.4 * s), lineCap: .round))
  }
}

/// One frame of a scene: sky + act + Luna. `clock` nil = a still frame at `pose`.
struct SceneFrame: View {
  let scene: LessonScene
  let symbol: String
  /// The frame is a square this many points wide.
  let side: CGFloat
  var status: SceneStatus = .open
  var clock: SceneClock?
  /// How long one loop takes.
  var period: Double = 3.4
  var luna: CGFloat
  var lunaAt: Alignment = .bottomLeading
  var glow: Double = 1
  /// Where the act sits in the frame (0...1 of the width), so Luna has her corner.
  var actShift: CGFloat = 0.08
  /// False when the frame sits on a bigger sky (the hero card, the lesson stage).
  var showsSky = true
  /// Small cards at rest show a cached picture of their still frame (`SceneStill`) instead of a Canvas.
  var rasterizesStill = false
  /// Drawing that picture: everything vector, the sky shader at its still time.
  fileprivate var forRaster = false
  @Environment(\.displayScale) private var scale

  var body: some View {
    let _ = Perf.body("SceneFrame")
    let live = clock?.running == true
    if rasterizesStill && !live, let img = SceneStill.image(self, scale: scale) {
      Image(uiImage: img).resizable().frame(width: side, height: side).transition(.opacity)
    } else {
      drawn(live: live)
    }
  }

  /// The key of this frame's still picture: neighbours with the same act, prop, palette and state share one.
  var stillKey: String { "\(scene.act)|\(scene.palette)|\(symbol)|\(status)|\(Int(side * 4))|\(Int(glow * 100))|\(Int(luna * 4))|\(Int(actShift * 100))" }

  @ViewBuilder private func drawn(live: Bool) -> some View {
    let t = clock.map { $0.t } ?? 0
    // Not started: the still frame is mid-action (it shows the idea); done: the settled end.
    let rest = status == .done ? 0.9 : scene.act == .flip ? 0.7 : 0.42
    let p = live ? (t / period + scene.seed).truncatingRemainder(dividingBy: 1) : rest
    let skyT = (clock?.t ?? 0) + scene.seed * 97
    let stage = side * (luna > 0 ? 0.92 : 1)
    ZStack(alignment: lunaAt) {
        if showsSky { SceneSky(palette: scene.palette, t: forRaster ? SkyStill.t : skyT, glow: glow, live: live || forRaster) }
        // One Canvas draws the act and, on small cards, Luna too (no view tree, no shadow per row).
        let small = luna > 0 && luna < LunaView.shadedFrom
        let bob = live ? -0.06 * sin(p * 2 * .pi) : 0
        Canvas(rendersAsynchronously: false) { g, size in
          var a = g
          a.translateBy(x: side * (0.5 + actShift) - stage / 2, y: side * 0.5 - stage / 2)
          ActPainter(act: scene.act, colors: scene.palette.ribbons, sky: scene.palette.sky, p: p).draw(&a, CGSize(width: stage, height: stage))
          if small {
            let r = luna / 2, pad = luna * 0.12
            MiniLuna.draw(&g, center: CGPoint(x: pad + r, y: side - pad - r + bob * luna), r: r, happy: status == .done)
          }
        } symbols: {
          PropMark(symbol: symbol, side: stage * 0.42).tag(0)
        }
        .frame(width: side, height: side)
        if luna >= LunaView.shadedFrom {
          Luna(size: luna, mood: status == .done ? .happy : .idle)
            .offset(y: live ? -luna * 0.06 * sin(p * 2 * .pi) : 0)
            .padding(luna * 0.12)
        }
    }
    .frame(width: side, height: side)
  }
}

// MARK: - The three places a scene shows

/// A lesson row's living window (replaces the flat icon square).
struct SceneTile: View {
  let lesson: Lesson
  let scene: LessonScene
  let status: SceneStatus
  @ScaledMetric(relativeTo: .headline) private var side: CGFloat = 62
  @Environment(\.accessibilityReduceMotion) private var rm
  @State private var onScreen = false

  var body: some View {
    let s = min(side, 86)
    let live = status != .done && !rm
    Self.frame(lesson: lesson, scene: scene, status: status, side: s, clock: live && onScreen ? SceneClock.tiles : nil)
      .clipShape(RoundedRectangle(cornerRadius: s * 0.27, style: .continuous))
      .overlay(RoundedRectangle(cornerRadius: s * 0.27, style: .continuous).strokeBorder(.white.opacity(0.28), lineWidth: 1))
      .overlay(alignment: .topTrailing) {
        if status == .done {
          Image(systemName: "checkmark").font(.system(size: s * 0.2, weight: .heavy)).foregroundStyle(.white)
            .frame(width: s * 0.34, height: s * 0.34)
            .background(Circle().fill(Color(hex: 0x1F9A60)))
            .overlay(Circle().strokeBorder(.white, lineWidth: 1.5))
            .offset(x: s * 0.1, y: -s * 0.1)
        }
      }
      .modifier(ClockHold(clock: SceneClock.tiles, live: live, onScreen: $onScreen))
      .accessibilityHidden(true)
  }

  /// The tile's frame (also what `SceneStill.prewarm` draws, so the keys match).
  static func frame(lesson: Lesson, scene: LessonScene, status: SceneStatus, side s: CGFloat, clock: SceneClock? = nil) -> SceneFrame {
    SceneFrame(scene: scene, symbol: scene.symbol(for: lesson), side: s, status: status, clock: clock,
               luna: s * 0.4, glow: status == .open ? 0.72 : 1, actShift: 0.1, rasterizesStill: true)
  }
  /// The tile's side at the current text size (matches its @ScaledMetric).
  static var side: CGFloat { min(UIFontMetrics(forTextStyle: .headline).scaledValue(for: 62), 86) }
}

/// Moon School's Up Next card: the whole card is the aurora, Luna acts out the lesson with her hook line.
struct UpNextHero: View {
  let lesson: Lesson
  let unitTitle: String
  @Environment(\.accessibilityReduceMotion) private var rm
  @Environment(\.dynamicTypeSize) private var type
  @State private var onScreen = false
  /// A narrow card (one page of the iPhone Duo book spread): the scene goes above the words.
  @State private var narrow = false

  var body: some View {
    let scene = Scenes.scene(for: lesson)
    let stacked = type >= .accessibility1 || narrow
    let layout = stacked ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) : AnyLayout(HStackLayout(alignment: .center, spacing: 10))
    layout {
      if stacked { stage(scene, side: 120) }
      VStack(alignment: .leading, spacing: 8) {
        Text("UP NEXT · \(unitTitle.uppercased())").font(.kEyebrow).tracking(1.2).foregroundStyle(.white.opacity(0.85))
        Text(lesson.title).font(.kTitle).foregroundStyle(.white).fixedSize(horizontal: false, vertical: true)
        HookBubble(text: scene.hook, tail: !stacked)
        HStack(spacing: 8) {
          Text("\(lesson.steps.count) tiny steps").font(.subheadline.weight(.semibold)).foregroundStyle(.white.opacity(0.9))
          Image(systemName: "arrow.right.circle.fill").font(.title2.weight(.bold)).foregroundStyle(.white)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      if !stacked { stage(scene, side: 128) }
    }
    .padding(18)
    .background {
      ZStack {
        SceneHeroSky(scene: scene, live: !rm && onScreen)
        // A scrim under the words: the title stays readable over the brightest ribbon.
        LinearGradient(stops: [.init(color: scene.palette.sky.opacity(0.8), location: 0), .init(color: scene.palette.sky.opacity(0.45), location: 0.45), .init(color: scene.palette.sky.opacity(0), location: 0.75)],
                       startPoint: .leading, endPoint: .trailing)
      }
    }
    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(.white.opacity(0.22), lineWidth: 1))
    .shadow(color: scene.palette.ribbons[0].opacity(0.28), radius: 18, y: 10)
    .environment(\.colorScheme, .dark)
    .modifier(ClockHold(clock: SceneClock.hero, live: !rm, onScreen: $onScreen))
    .onGeometryChange(for: Bool.self) { $0.size.width < 320 } action: { narrow = $0 }
  }

  private func stage(_ scene: LessonScene, side: CGFloat) -> some View {
    SceneFrame(scene: scene, symbol: scene.symbol(for: lesson), side: side, status: .next, clock: !rm && onScreen ? SceneClock.hero : nil,
               luna: side * 0.4, actShift: 0.14, showsSky: false)
      .accessibilityHidden(true)
  }
}

/// The hero's sky: the card-wide aurora on the hero clock (the stage draws its own act over a clear sky).
private struct SceneHeroSky: View {
  let scene: LessonScene
  let live: Bool
  var body: some View {
    let clock = SceneClock.hero
    SceneSky(palette: scene.palette, t: (live ? clock.t : 0) + scene.seed * 97, glow: 1.25, live: live && clock.running)
      .accessibilityHidden(true)
  }
}

/// Luna's one line, in a speech bubble pointing at her (right).
struct HookBubble: View {
  let text: String
  var tail = true
  var body: some View {
    Text(text).font(.callout.weight(.semibold)).foregroundStyle(Palette.midnight)
      .fixedSize(horizontal: false, vertical: true)
      .padding(.horizontal, 12).padding(.vertical, 8)
      .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white))
      .overlay(alignment: .trailing) {
        if tail {
          Path { p in p.move(to: .init(x: 0, y: 0)); p.addLine(to: .init(x: 10, y: 7)); p.addLine(to: .init(x: 0, y: 14)); p.closeSubpath() }
            .fill(Color.white).frame(width: 10, height: 14).offset(x: 9)
        }
      }
  }
}

/// The scene, big, at the top of a lesson's first step: card → lesson feels like one picture growing.
/// Spare-room like `ArtPanel`: it grows up to `maxHeight` and hides when squeezed under 72 pt.
struct SceneStage: View {
  let lesson: Lesson
  var maxHeight: CGFloat = 420
  var minHeight: CGFloat = 150
  @Environment(\.accessibilityReduceMotion) private var rm
  @State private var tooSmall = false
  @State private var onScreen = false
  var body: some View {
    let scene = Scenes.scene(for: lesson)
    let live = !rm && onScreen
    GeometryReader { geo in
      let side = max(1, min(geo.size.height, geo.size.width * 0.62, 260))
      ZStack {
        SceneSky(palette: scene.palette, t: (live ? SceneClock.hero.t : 0) + scene.seed * 97, glow: 1, live: live && SceneClock.hero.running)
        SceneFrame(scene: scene, symbol: scene.symbol(for: lesson), side: side, status: .next, clock: live ? SceneClock.hero : nil, luna: side * 0.34, actShift: 0.06, showsSky: false)
      }
      .frame(width: geo.size.width, height: geo.size.height)
    }
    .opacity(tooSmall ? 0 : 1)
    .frame(minHeight: min(minHeight, maxHeight), maxHeight: maxHeight)
    .onGeometryChange(for: Bool.self) { $0.size.height < 72 } action: { tooSmall = $0 }
    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    .modifier(ClockHold(clock: SceneClock.hero, live: !rm, onScreen: $onScreen))
    .accessibilityHidden(true)
  }
}

