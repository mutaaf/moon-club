import SwiftUI
import QuartzCore

/// Debug-only performance probes (free in release builds):
///  • `Perf.body("Name")` counts body re-evaluations per view (call it as `let _ = Perf.body("Name")`).
///  • `FrameMonitor` watches every display frame with a CADisplayLink and counts hitches (a frame that took
///    longer than 1.5× the display's interval).
///  • `-bench` runs a fixed script from RootView (switch every tab, bank points ten times, come back to
///    Story) and prints one `BENCH …` report to stdout, so a change can be measured before and after the
///    same way: `xcrun simctl launch --console-pty <sim> com.mutaafaziz.moonclub -demo -bench`.
@MainActor enum Perf {
  #if DEBUG
  static let on = ProcessInfo.processInfo.arguments.contains("-bench")
  /// `-bench screen`: measure the screen the other launch args opened instead of running the tab script.
  static let screen: Bool = {
    let a = ProcessInfo.processInfo.arguments
    return a.firstIndex(of: "-bench").map { $0 + 1 < a.count && a[$0 + 1] == "screen" } ?? false
  }()
  private(set) static var counts: [String: Int] = [:]
  #endif
  @discardableResult static func body(_ name: String) -> Int {
    #if DEBUG
    guard on else { return 0 }
    counts[name, default: 0] += 1
    #endif
    return 0
  }
  static func reset() {
    #if DEBUG
    counts = [:]
    #endif
  }
  static func report(_ phase: String) -> String {
    #if DEBUG
    let total = counts.values.reduce(0, +)
    let top = counts.sorted { $0.value > $1.value }.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
    return "BENCH \(phase) bodies=\(total) \(top)"
    #else
    return ""
    #endif
  }
}

/// Counts frames and hitches while it runs (debug bench only).
@MainActor final class FrameMonitor: NSObject {
  private var link: CADisplayLink?
  private var last: CFTimeInterval = 0
  private(set) var frames = 0, hitches = 0
  private(set) var hitchTime: CFTimeInterval = 0, total: CFTimeInterval = 0, worst: CFTimeInterval = 0
  private var intervals: [CFTimeInterval] = []

  func start() {
    frames = 0; hitches = 0; hitchTime = 0; total = 0; worst = 0; intervals = []; last = 0
    let l = CADisplayLink(target: self, selector: #selector(tick(_:)))
    l.add(to: .main, forMode: .common); link = l
  }
  func stop() { link?.invalidate(); link = nil }

  @objc private func tick(_ l: CADisplayLink) {
    let now = l.timestamp
    defer { last = now }
    guard last > 0 else { return }
    let dt = now - last, target = max(1.0 / 120, l.targetTimestamp - l.timestamp)
    frames += 1; total += dt; intervals.append(dt); worst = max(worst, dt)
    if dt > target * 1.5 { hitches += 1; hitchTime += dt - target }
  }

  /// "frames=… avg=…ms p95=…ms worst=…ms hitches=… hitchRatio=…ms/s"
  var summary: String {
    let sorted = intervals.sorted()
    let p95 = sorted.isEmpty ? 0 : sorted[min(sorted.count - 1, Int(Double(sorted.count) * 0.95))]
    let avg = frames == 0 ? 0 : total / Double(frames)
    let ratio = total == 0 ? 0 : hitchTime * 1000 / total
    return String(format: "frames=%d avg=%.1fms p95=%.1fms worst=%.0fms hitches=%d hitchRatio=%.1fms/s", frames, avg * 1000, p95 * 1000, worst * 1000, hitches, ratio)
  }
}

/// Screenshot readiness (debug + `-demo` only): appends a token ("root", "play") to
/// Library/Caches/moonclub.ready once that screen is really on screen, so scripts wait for it instead of
/// sleeping (boss screens on iPad were captured blank before the app had finished launching).
enum Ready {
  static func mark(_ token: String) {
    #if DEBUG
    guard ProcessInfo.processInfo.arguments.contains("-demo"),
          let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
    let url = dir.appendingPathComponent("moonclub.ready")
    let line = Data((token + "\n").utf8)
    if let h = try? FileHandle(forWritingTo: url) { h.seekToEndOfFile(); h.write(line); try? h.close() }
    else { try? line.write(to: url) }
    #endif
  }
}

/// Debug `-window WxH`: lays the whole app out in a window of that size (in points), scaled to fit the
/// screen. The simulator can't rotate or resize from the command line, so this is how landscape, Split View
/// and Stage Manager sizes are checked and captured. Width ≥ 600 gets the regular size class (split view), like iPad Split View and an open iPhone Duo.
struct DebugWindow: ViewModifier {
  let size: CGSize?
  init() {
    #if DEBUG
    let a = ProcessInfo.processInfo.arguments
    if let i = a.firstIndex(of: "-window"), i + 1 < a.count {
      let p = a[i + 1].split(separator: "x").compactMap { Double($0) }
      size = p.count == 2 ? CGSize(width: p[0], height: p[1]) : nil
    } else { size = nil }
    #else
    size = nil
    #endif
  }
  func body(content: Content) -> some View {
    if let size {
      GeometryReader { geo in
        let k = min(1, geo.size.width / size.width, geo.size.height / size.height)
        content
          .environment(\.horizontalSizeClass, size.width >= 600 ? .regular : .compact)
          .frame(width: size.width, height: size.height)
          .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
          .scaleEffect(k)
          .frame(width: geo.size.width, height: geo.size.height)
      }
      .background(Color(white: 0.12).ignoresSafeArea())
    } else { content }
  }
}
