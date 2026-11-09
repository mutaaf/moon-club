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
  static let screen: Bool = mode == "screen"
  /// `-bench world`: settle on Story, then open the World tab and report every 0.5 s for 8 s (its first seconds).
  /// `-bench launch`: report every 0.5 s for the first 10 s after the root appears (pair with `-tab school`).
  static let mode: String? = {
    let a = ProcessInfo.processInfo.arguments
    return a.firstIndex(of: "-bench").flatMap { $0 + 1 < a.count ? a[$0 + 1] : nil }
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
  /// (seconds since start, frame interval, main-thread CPU used since the last frame) for `buckets(_:)`.
  /// The CPU column is what the simulator can show honestly: its GPU is the Mac's, so frame intervals there
  /// stay at 16.7 ms long after a real iPad has started missing frames.
  private var timeline: [(CFTimeInterval, CFTimeInterval, CFTimeInterval)] = []
  private var lastCPU: CFTimeInterval = 0
  private static func threadCPU() -> CFTimeInterval {
    var ts = timespec(); clock_gettime(CLOCK_THREAD_CPUTIME_ID, &ts)
    return CFTimeInterval(ts.tv_sec) + CFTimeInterval(ts.tv_nsec) / 1e9
  }
  private var began: CFTimeInterval = 0

  func start() {
    frames = 0; hitches = 0; hitchTime = 0; total = 0; worst = 0; intervals = []; last = 0
    timeline = []; began = CACurrentMediaTime(); lastCPU = Self.threadCPU()
    let l = CADisplayLink(target: self, selector: #selector(tick(_:)))
    l.add(to: .main, forMode: .common); link = l
  }
  func stop() { link?.invalidate(); link = nil }

  @objc private func tick(_ l: CADisplayLink) {
    let now = l.timestamp
    let cpu = Self.threadCPU()
    defer { last = now; lastCPU = cpu }
    guard last > 0 else { return }
    let dt = now - last, target = max(1.0 / 120, l.targetTimestamp - l.timestamp)
    frames += 1; total += dt; intervals.append(dt); worst = max(worst, dt)
    timeline.append((now - began, dt, cpu - lastCPU))
    if dt > target * 1.5 { hitches += 1; hitchTime += dt - target }
  }

  /// One line per `width`-second window: "t=0.0-0.5s frames=… avg=…ms worst=…ms mainCPU=…ms/frame" (the first seconds of a screen).
  func buckets(_ width: CFTimeInterval) -> [String] {
    guard let end = timeline.last?.0 else { return [] }
    return stride(from: 0.0, to: end, by: width).map { a in
      let rows = timeline.filter { $0.0 >= a && $0.0 < a + width }
      let w = rows.map(\.1), c = rows.map(\.2)
      let avg = w.isEmpty ? 0 : w.reduce(0, +) / Double(w.count)
      let cpu = c.isEmpty ? 0 : c.reduce(0, +) / Double(c.count)
      return String(format: "t=%.1f-%.1fs frames=%d avg=%.1fms worst=%.0fms mainCPU=%.2fms/frame", a, a + width, w.count, avg * 1000, (w.max() ?? 0) * 1000, cpu * 1000)
    }
  }

  /// "frames=… avg=…ms p95=…ms worst=…ms hitches=… hitchRatio=…ms/s"
  var summary: String {
    let sorted = intervals.sorted()
    let p95 = sorted.isEmpty ? 0 : sorted[min(sorted.count - 1, Int(Double(sorted.count) * 0.95))]
    let avg = frames == 0 ? 0 : total / Double(frames)
    let ratio = total == 0 ? 0 : hitchTime * 1000 / total
    let cpu = timeline.isEmpty ? 0 : timeline.map(\.2).reduce(0, +) / Double(timeline.count)
    return String(format: "frames=%d avg=%.1fms p95=%.1fms worst=%.0fms hitches=%d hitchRatio=%.1fms/s mainCPU=%.2fms/frame", frames, avg * 1000, p95 * 1000, worst * 1000, hitches, ratio, cpu * 1000)
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
