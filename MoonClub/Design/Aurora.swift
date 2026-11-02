import SwiftUI
import os

/// The one reusable aurora field. A single full-screen Metal `colorEffect` layer driven by
/// `TimelineView(.animation(minimumInterval: 1/30))`. It pauses when off-screen, when the app is
/// not active, in Low Power Mode, and shows a still frame under Reduce Motion. No per-frame
/// allocations: the shader arguments are value types computed from the timeline date.
struct AuroraField: View {
  let surface: Surface
  var strength: Double = 0.75

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.scenePhase) private var phase
  @Environment(\.colorScheme) private var scheme
  @State private var visible = false
  @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled

  private var paused: Bool { reduceMotion || lowPower || phase != .active || !visible }

  var body: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: paused)) { ctx in
      let t = Float(paused ? 42 : ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 10_000))
      GeometryReader { geo in
        Rectangle()
          .colorEffect(ShaderLibrary.aurora(
            .float2(geo.size), .float(t),
            .color(surface.aurora[0]), .color(surface.aurora[1]), .color(surface.aurora[2]),
            .color(scheme == .dark ? Color(hex: 0x0F0E22) : Color(hex: 0xFBFAF7)),
            .float(Float(scheme == .dark ? strength * 0.55 : strength))))
          .onChange(of: ctx.date) { _, _ in FrameProbe.shared.tick() }
      }
    }
    .ignoresSafeArea()
    .accessibilityHidden(true)
    .onAppear { visible = true }
    .onDisappear { visible = false }
    .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
      lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    }
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
