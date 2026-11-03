import SwiftUI
import os

/// The one reusable aurora field. A single full-screen Metal `colorEffect` layer driven by
/// `TimelineView(.animation(minimumInterval: 1/30))`. It drifts for a few seconds when a screen appears,
/// then rests; it pauses when off-screen, when the app is not active, in Low Power Mode, and shows a still
/// frame under Reduce Motion. No per-frame
/// allocations: the shader arguments are value types computed from the timeline date.
struct AuroraField: View {
  let surface: Surface
  var strength: Double = 0.75

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.scenePhase) private var phase
  @Environment(\.colorScheme) private var scheme
  @State private var visible = false
  @State private var resting = false
  @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled

  private var paused: Bool { reduceMotion || lowPower || phase != .active || !visible }

  /// Debug: `-aurora full` keeps drifting forever (the pre-0.13 behaviour), `-aurora still` never moves.
  static let mode: String = {
    #if DEBUG
    let a = ProcessInfo.processInfo.arguments
    if let i = a.firstIndex(of: "-aurora"), i + 1 < a.count { return a[i + 1] }
    #endif
    return "default"
  }()
  /// How long the aurora drifts after a screen appears (or the app comes back) before it rests.
  static let drift: Duration = .seconds(6)

  var body: some View {
    // The aurora drifts when a screen arrives, then rests as a still frame. Every frame it moves, every
    // glass card above it has to be re-blurred: on iPad that held the Story at ~10 fps (0.13 perf pass).
    let calm = paused || resting || Self.mode == "still"
    TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: calm)) { ctx in
      // Time keeps its value when paused, so resting never jumps to another frame.
      let t = Float(ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 10_000))
      GeometryReader { geo in field(t, geo.size) }
        .onChange(of: ctx.date) { _, _ in FrameProbe.shared.tick() }
    }
    .task(id: "\(visible)|\(phase == .active)") {
      resting = false
      guard Self.mode != "full", visible, phase == .active else { return }
      try? await Task.sleep(for: Self.drift)
      if !Task.isCancelled { resting = true }
    }
    .ignoresSafeArea()
    .accessibilityHidden(true)
    .onAppear { visible = true }
    .onDisappear { visible = false }
    .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
      lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    }
  }

  private func field(_ t: Float, _ size: CGSize) -> some View {
    Rectangle()
      .colorEffect(ShaderLibrary.aurora(
        .float2(size), .float(t),
        .color(surface.aurora[0]), .color(surface.aurora[1]), .color(surface.aurora[2]),
        .color(scheme == .dark ? Color(hex: 0x0F0E22) : Color(hex: 0xFBFAF7)),
        .float(Float(scheme == .dark ? strength * 0.55 : strength))))
  }
}

/// Debug-only frame-time probe: logs the average aurora frame interval every 120 frames
/// (view in Console.app, subsystem com.mutaafaziz.moonclub, category "aurora"). Free in release.
final class FrameProbe {
  static let shared = FrameProbe()
  #if DEBUG
  private let log = Logger(subsystem: "com.mutaafaziz.moonclub", category: "aurora")
  private var last = CACurrentMediaTime(), sum = 0.0, n = 0
  #endif
  func tick() {
    #if DEBUG
    let now = CACurrentMediaTime(); sum += now - last; last = now; n += 1
    if n == 120 { log.debug("aurora avg frame interval \(self.sum / 120 * 1000, format: .fixed(precision: 1)) ms"); sum = 0; n = 0 }
    #endif
  }
}
