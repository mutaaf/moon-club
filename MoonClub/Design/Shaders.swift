import SwiftUI
import CoreMotion
import Metal
import MoonClubCore

// The Swift face of Shaders.metal (0.14). Every Metal effect in Moon Club goes through here:
//  • `FX.shared` knows Low Power Mode and the thermal state; `FXLevel.of` (MoonClubCore, tested) turns that,
//    plus visibility, scene phase and Reduce Motion, into paused / still / full.
//  • `FXClock` is the one animated clock: a TimelineView that runs only at `.full`, for a few seconds after
//    it appears or is woken (then rests on a still frame, like the 0.13 aurora), at up to the display's
//    rate (ProMotion 120 Hz where available) or a cap.
//  • `ShaderWarmup` compiles every shader and the particle pipeline off the main thread at launch, so the
//    first map, boss or party never hitches.
//  • `MotionTilt` is the one CoreMotion reader (device motion needs no permission prompt), for parallax and
//    holographic tilt, and for waking Luna's pocket. Nothing it reads is stored or leaves the device.

@MainActor @Observable
final class FX {
  static let shared = FX()
  private(set) var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
  private(set) var thermal = ProcessInfo.processInfo.thermalState.rawValue

  /// Debug: `-fx still` forces still frames (what Low Power Mode looks like), `-fx full` ignores the budget.
  static let forced: String? = {
    #if DEBUG
    let a = ProcessInfo.processInfo.arguments
    if let i = a.firstIndex(of: "-fx"), i + 1 < a.count { return a[i + 1] }
    #endif
    return nil
  }()

  private init() {
    let nc = NotificationCenter.default
    nc.addObserver(forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main) { _ in
      MainActor.assumeIsolated { FX.shared.lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled }
    }
    nc.addObserver(forName: ProcessInfo.thermalStateDidChangeNotification, object: nil, queue: .main) { _ in
      MainActor.assumeIsolated { FX.shared.thermal = ProcessInfo.processInfo.thermalState.rawValue }
    }
  }

  func level(visible: Bool, active: Bool, reduceMotion: Bool) -> FXLevel {
    if Self.forced == "full" { return visible && active ? .full : .paused }
    let l = FXLevel.of(visible: visible, active: active, reduceMotion: reduceMotion, lowPower: lowPower, thermal: thermal)
    return Self.forced == "still" ? min(l, .still) : l
  }
  /// Particles and other bursts: allowed only at full budget (otherwise the calm glow stands in).
  func allowsBursts(reduceMotion: Bool) -> Bool { level(visible: true, active: true, reduceMotion: reduceMotion) == .full }
}

/// The one animated clock for shader effects. `content` gets the time in seconds (stable when resting) and
/// the current level. It runs while the level is `.full` and, if `runFor` is set, for that long after it
/// appears or `wake` changes; then it rests on its last frame. `fps` caps the rate (nil = display rate).
struct FXClock<Content: View>: View {
  var fps: Double? = nil
  var runFor: Duration? = .seconds(8)
  var wake: Int = 0
  /// Start on a still frame and move only after the first `wake` (e.g. the sea moves once you scroll).
  var waitForWake = false
  @ViewBuilder var content: (Float, FXLevel) -> Content
  @Environment(\.accessibilityReduceMotion) private var rm
  @Environment(\.scenePhase) private var phase
  @State private var visible = false
  @State private var resting = false
  private var fx: FX { FX.shared }

  var body: some View {
    let level = fx.level(visible: visible, active: phase == .active, reduceMotion: rm)
    let calm = level != .full || resting
    TimelineView(.animation(minimumInterval: fps.map { 1 / $0 }, paused: calm)) { ctx in
      let t = Float(ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3_600))
      content(t, level)
    }
    .task(id: "\(visible)|\(phase == .active)|\(wake)") {
      if waitForWake && wake == 0 { resting = true; return }
      resting = false
      guard let runFor, visible, phase == .active else { return }
      try? await Task.sleep(for: runFor)
      if !Task.isCancelled { resting = true }
    }
    .onAppear { visible = true }
    .onDisappear { visible = false }
  }
}

// MARK: - Effects as modifiers

extension View {
  /// A soft bloom that flares when `trigger` changes (a right candle), then fades. Static content otherwise.
  func candleBloom(trigger: Int) -> some View { modifier(CandleBloom(trigger: trigger)) }
  /// The Chart Time Machine sweep: chromatic split + film grain for `duration` seconds from `start`.
  func timeWarp(start: Date?, duration: Double) -> some View { modifier(TimeWarp(start: start, duration: duration)) }
  /// A shockwave ripples out from the middle when `trigger` changes (boss defeated).
  func shockwave(trigger: Int) -> some View { modifier(Shockwave(trigger: trigger)) }
  /// Shimmer + holographic tilt for badges and rare shop items. `holo` adds the rainbow and the 3D tilt.
  func shimmer(_ on: Bool = true, holo: Bool = false) -> some View { modifier(Shimmer(on: on, holo: holo)) }
}

private struct CandleBloom: ViewModifier {
  let trigger: Int
  @Environment(\.accessibilityReduceMotion) private var rm
  @State private var start: Date?
  static let length = 0.9
  func body(content: Content) -> some View {
    TimelineView(.animation(paused: start == nil)) { ctx in
      // Flare in fast, fade out slowly: 0 → 1 in 0.15 s, back to 0 by `length`.
      let e = start.map { ctx.date.timeIntervalSince($0) } ?? Self.length
      let a = e < 0.15 ? e / 0.15 : max(0, 1 - (e - 0.15) / (Self.length - 0.15))
      content.layerEffect(ShaderLibrary.bloom(.float(10), .float(Float(a))), maxSampleOffset: CGSize(width: 12, height: 12), isEnabled: a > 0.01)
    }
    .onChange(of: trigger) { old, new in
      guard new > old, !rm, FX.shared.allowsBursts(reduceMotion: rm) else { return }
      start = Date()
      Task { try? await Task.sleep(for: .seconds(Self.length + 0.05)); start = nil }
    }
  }
}

private struct TimeWarp: ViewModifier {
  let start: Date?
  let duration: Double
  @Environment(\.accessibilityReduceMotion) private var rm
  func body(content: Content) -> some View {
    let on = start != nil && FX.shared.allowsBursts(reduceMotion: rm)
    TimelineView(.animation(paused: !on)) { ctx in
      let p = on ? min(1, max(0, ctx.date.timeIntervalSince(start ?? ctx.date) / duration)) : 0
      let t = Float(ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 600))
      content.visualEffect { c, g in
        c.layerEffect(ShaderLibrary.timeWarp(.float2(g.size), .float(Float(p)), .float(t)), maxSampleOffset: CGSize(width: 12, height: 0), isEnabled: p > 0.001 && p < 0.999)
      }
    }
  }
}

private struct Shockwave: ViewModifier {
  let trigger: Int
  @Environment(\.accessibilityReduceMotion) private var rm
  @State private var start: Date?
  func body(content: Content) -> some View {
    TimelineView(.animation(paused: start == nil)) { ctx in
      let t = start.map { min(1, ctx.date.timeIntervalSince($0) / 0.9) } ?? 1
      content.visualEffect { c, g in
        c.distortionEffect(ShaderLibrary.shockwave(.float2(g.size.width / 2, g.size.height * 0.4), .float(Float(t)), .float2(g.size)),
                           maxSampleOffset: CGSize(width: 24, height: 24), isEnabled: t < 1)
      }
    }
    .onChange(of: trigger) { old, new in
      guard new > old, !rm, FX.shared.allowsBursts(reduceMotion: rm) else { return }
      start = Date()
      Task { try? await Task.sleep(for: .seconds(1)); start = nil }
    }
  }
}

private struct Shimmer: ViewModifier {
  let on: Bool, holo: Bool
  @Environment(\.accessibilityReduceMotion) private var rm
  func body(content: Content) -> some View {
    if on {
      FXClock(fps: 60, runFor: .seconds(5)) { t, level in
        TiltReader(enabled: holo && level == .full) { tilt in
          content
            .visualEffect { c, g in
              c.colorEffect(ShaderLibrary.shimmer(.float2(g.size), .float(level == .full ? t : 1.1), .float2(CGFloat(tilt.x), CGFloat(tilt.y)), .float(holo ? 1 : 0)))
            }
            .rotation3DEffect(.degrees(holo ? Double(tilt.x) * 9 : 0), axis: (0, 1, 0), perspective: 0.6)
            .rotation3DEffect(.degrees(holo ? Double(-tilt.y) * 9 : 0), axis: (1, 0, 0), perspective: 0.6)
        }
      }
    } else { content }
  }
}

/// The fold's seam on iPhone Duo: a soft shadow down the crease that deepens as the phone closes. Sits over
/// the whole window, never takes touches, and draws nothing without a vertical division region.
struct FoldSeam: View {
  @Environment(DuoModel.self) private var duo: DuoModel?
  var body: some View {
    GeometryReader { proxy in
      if let f = seam(proxy), let duo, duo.seam > 0.01 {
        Rectangle()
          .colorEffect(ShaderLibrary.foldSeam(.float2(f.width * 3, f.height), .float(Float(duo.seam))))
          .frame(width: f.width * 3, height: f.height)
          .position(x: f.midX, y: f.midY)
          .animation(.interactiveSpring(response: 0.25), value: duo.seam)
      }
    }
    .ignoresSafeArea()
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }
  private func seam(_ proxy: GeometryProxy) -> CGRect? {
    if #available(iOS 27.1, *),
       let r = proxy.reservedRegions(kind: .division, options: [.includeInactive]).first(where: { $0.frame.height >= $0.frame.width }) {
      return r.frame
    }
    #if DEBUG
    if let p = duo?.pinned, [.book, .flat, .tent].contains(p), proxy.size.width >= 560 {
      return CGRect(x: proxy.size.width / 2 - 20, y: 0, width: 40, height: proxy.size.height)
    }
    #endif
    return nil
  }
}

// MARK: - Device tilt (CoreMotion)

/// The one CoreMotion reader. Views that want tilt `retain()` it while on screen; it runs only while
/// someone holds it and the budget is full (never under Reduce Motion or Low Power Mode). 30 Hz, low-pass
/// filtered and rounded so views redraw only when it really moves. `jolt` ticks when the phone is picked
/// up (Luna's pocket wakes). Device motion needs no permission prompt; nothing is stored or sent.
@MainActor @Observable
final class MotionTilt {
  static let shared = MotionTilt()
  /// -1 … 1 on each axis (roll, pitch), relative to how the phone was held when tilt started.
  private(set) var tilt = SIMD2<Float>(0, 0)
  private(set) var jolt = 0
  @ObservationIgnored private let mm = CMMotionManager()
  @ObservationIgnored private var holders = 0
  @ObservationIgnored private var rest: SIMD2<Double>?
  @ObservationIgnored private var smooth = SIMD2<Double>(0, 0)
  @ObservationIgnored private var lastJolt = Date.distantPast

  func retain() {
    holders += 1
    guard holders == 1, mm.isDeviceMotionAvailable else { return }
    mm.deviceMotionUpdateInterval = 1.0 / 30.0
    rest = nil
    mm.startDeviceMotionUpdates(to: .main) { [weak self] m, _ in
      guard let m else { return }
      MainActor.assumeIsolated { self?.feed(m) }
    }
  }
  func release() {
    holders = max(0, holders - 1)
    if holders == 0 { mm.stopDeviceMotionUpdates(); tilt = .zero }
  }
  private func feed(_ m: CMDeviceMotion) {
    let a = SIMD2(m.attitude.roll, m.attitude.pitch)
    if rest == nil { rest = a }
    let d = (a - (rest ?? a)) / 0.35
    smooth = smooth * 0.8 + d * 0.2
    let q = SIMD2<Float>(Float(max(-1, min(1, smooth.x))), Float(max(-1, min(1, smooth.y))))
    let r = (q * Float(50)).rounded(.toNearestOrAwayFromZero) / Float(50)
    if r != tilt { tilt = r }
    let u = m.userAcceleration
    if PocketWake.wakes(x: u.x, y: u.y, z: u.z), Date().timeIntervalSince(lastJolt) > 1 { lastJolt = Date(); jolt &+= 1 }
  }
}

/// Gives its content the device tilt while it's on screen (zero when disabled).
struct TiltReader<Content: View>: View {
  var enabled = true
  @ViewBuilder var content: (SIMD2<Float>) -> Content
  @State private var motion = MotionTilt.shared
  @State private var held = false
  var body: some View {
    content(enabled ? motion.tilt : .zero)
      .onAppear { if enabled, !held { held = true; motion.retain() } }
      .onChange(of: enabled) { _, on in
        if on, !held { held = true; motion.retain() } else if !on, held { held = false; motion.release() }
      }
      .onDisappear { if held { held = false; motion.release() } }
  }
}

/// A parallax layer: shifts its content by the device tilt × `depth` points. Very subtle by design; off
/// under Reduce Motion and Low Power Mode.
struct TiltLayer<Content: View>: View {
  var depth: CGFloat
  @ViewBuilder var content: Content
  @Environment(\.accessibilityReduceMotion) private var rm
  var body: some View {
    TiltReader(enabled: !rm && !FX.shared.lowPower) { t in
      content.offset(x: CGFloat(t.x) * depth, y: CGFloat(t.y) * depth)
        .animation(.interactiveSpring(response: 0.4), value: t)
    }
  }
}

// MARK: - Warm-up

/// Compiles every shader and builds the particle pipeline off the main thread at launch, so the first
/// map, boss or party never stalls on a compile. iOS 18+ precompiles SwiftUI shaders (`Shader.compile`);
/// on iOS 17 they compile on first use (still once).
enum ShaderWarmup {
  nonisolated static func run() {
    Task.detached(priority: .utility) {
      let start = CFAbsoluteTimeGetCurrent()
      ParticleRenderer.prepareShared()
      if #available(iOS 18.0, *) {
        let color = ["aurora", "sea", "fog", "luna", "shimmer", "foldSeam"]
        let layer = ["bloom", "timeWarp"]
        for n in color { try? await Shader(function: ShaderFunction(library: .default, name: n), arguments: []).compile(as: .colorEffect) }
        for n in layer { try? await Shader(function: ShaderFunction(library: .default, name: n), arguments: []).compile(as: .layerEffect) }
        try? await Shader(function: ShaderFunction(library: .default, name: "shockwave"), arguments: []).compile(as: .distortionEffect)
      }
      #if DEBUG
      print(String(format: "FX warm-up %.0f ms (off the main thread)", (CFAbsoluteTimeGetCurrent() - start) * 1000)); fflush(stdout)
      #endif
    }
  }
}
