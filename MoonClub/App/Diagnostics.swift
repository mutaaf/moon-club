import Foundation
import MetricKit
import UIKit
import os

// Observability (0.23), on this device only. Nothing here is sent anywhere: no analytics, no SDK, no server.
//  • `Log.<category>`: os.Logger lines (Console.app / `log stream --predicate 'subsystem == "com.mutaafaziz.moonclub"'`).
//  • `Signpost`: intervals for Instruments (Points of Interest): level runs, sponsor fetches, store refreshes, launch.
//  • `EventLog`: the last few hundred app events (levels, breaks, pass state, sponsor outcomes, hangs, memory
//    warnings), kept in Application Support. Ids only, never anything the child typed or said.
//  • `MetricsInbox`: Apple's MetricKit payloads (launch time, hangs, crashes, CPU, memory), which the system
//    hands to the app about once a day, saved next to the events.
//  • `HangWatch`: a tiny release-safe watchdog: when the main thread doesn't answer for 2 s it records a hang.
// A grown-up can read all of it, and share it if they choose, in the grown-up corner → Diagnostics.

enum Log {
  static let subsystem = "com.mutaafaziz.moonclub"
  static let app = Logger(subsystem: subsystem, category: "app")
  static let pass = Logger(subsystem: subsystem, category: "pass")
  static let play = Logger(subsystem: subsystem, category: "play")
  static let sponsor = Logger(subsystem: subsystem, category: "sponsor")
  static let store = Logger(subsystem: subsystem, category: "store")
  static let perf = Logger(subsystem: subsystem, category: "perf")
}

enum Signpost {
  static let poi = OSSignposter(subsystem: Log.subsystem, category: .pointsOfInterest)
  /// Times `work` as an Instruments interval and returns how long it took (seconds).
  @discardableResult
  static func measure<T>(_ name: StaticString, _ work: () async throws -> T) async rethrows -> (T, Double) {
    let id = poi.makeSignpostID()
    let state = poi.beginInterval(name, id: id)
    let start = ContinuousClock.now
    defer { poi.endInterval(name, state) }
    let v = try await work()
    let d = start.duration(to: .now)
    return (v, Double(d.components.seconds) + Double(d.components.attoseconds) / 1e18)
  }
  static func event(_ name: StaticString) { poi.emitEvent(name) }
}

/// The last `cap` events on this device, newest last. Thread-safe; saved at most every few seconds.
final class EventLog: @unchecked Sendable {
  static let shared = EventLog()
  struct Event: Codable, Hashable, Sendable {
    let t: Date
    let kind: String
    let detail: String
  }
  static let cap = 400
  private let lock = OSAllocatedUnfairLock<[Event]>(initialState: [])
  private let saveQueue = DispatchQueue(label: "moonclub.eventlog", qos: .utility)
  private var dirty = false
  private let url: URL?

  init(directory: URL? = Diagnostics.directory) {
    url = directory?.appending(path: "events.json")
    if let url, let d = try? Data(contentsOf: url), let e = try? JSONDecoder().decode([Event].self, from: d) {
      lock.withLock { $0 = Array(e.suffix(Self.cap)) }
    }
  }

  /// Records one event (kind like "level.open", detail like "candles-22 counted"). Cheap; call from anywhere.
  func add(_ kind: String, _ detail: String = "") {
    let e = Event(t: Date(), kind: kind, detail: String(detail.prefix(200)))
    lock.withLock { list in
      list.append(e)
      if list.count > Self.cap { list.removeFirst(list.count - Self.cap) }
    }
    scheduleSave()
  }

  var events: [Event] { lock.withLock { $0 } }
  func count(_ kind: String, since: Date) -> Int { events.filter { $0.kind == kind && $0.t >= since }.count }

  func clear() { lock.withLock { $0 = [] }; scheduleSave() }

  private func scheduleSave() {
    saveQueue.async { [self] in
      guard !dirty else { return }
      dirty = true
      saveQueue.asyncAfter(deadline: .now() + 3) { [self] in dirty = false; save() }
    }
  }
  /// Writes now (called when the app goes to the background).
  func save() {
    guard let url else { return }
    let list = events
    do {
      try JSONEncoder().encode(list).write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    } catch { Log.app.error("event log save failed: \(error.localizedDescription, privacy: .public)") }
  }
}

enum Diagnostics {
  static let directory: URL? = {
    guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
    let d = base.appending(path: "diagnostics", directoryHint: .isDirectory)
    try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
    var v = d; var rv = URLResourceValues(); rv.isExcludedFromBackup = true; try? v.setResourceValues(rv)
    return d
  }()
  static let launched = Date()
  nonisolated(unsafe) private static var started = false

  /// Starts the watchdog, MetricKit and lifecycle notes. Live app only (not tests / previews).
  @MainActor static func start() {
    guard !started else { return }
    started = true
    MetricsInbox.shared.start()
    HangWatch.shared.start()
    let nc = NotificationCenter.default
    nc.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: nil) { _ in
      EventLog.shared.add("memory.warning", "\(Diagnostics.memoryMB()) MB"); Log.perf.warning("memory warning")
    }
    nc.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) { _ in
      EventLog.shared.add("app.background"); EventLog.shared.save()
    }
    nc.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: nil) { _ in EventLog.shared.add("app.foreground") }
    EventLog.shared.add("app.launch", "\(version) · \(UIDevice.current.model) · iOS \(UIDevice.current.systemVersion)")
  }

  /// The first screen is up: how long launch took (from this process starting).
  @MainActor static func firstFrame() {
    let s = Date().timeIntervalSince(processStart)
    EventLog.shared.add("app.ready", String(format: "%.2f s", s))
    Log.perf.info("first frame after \(s, format: .fixed(precision: 2)) s")
    Signpost.event("first frame")
  }

  static var version: String {
    let i = Bundle.main.infoDictionary
    return "\(i?["CFBundleShortVersionString"] as? String ?? "?") (\(i?["CFBundleVersion"] as? String ?? "?"))"
  }

  /// When this process started (the kernel's own clock), so launch time includes everything before main().
  static let processStart: Date = {
    var info = kinfo_proc(), size = MemoryLayout<kinfo_proc>.size
    var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
    guard sysctl(&mib, 4, &info, &size, nil, 0) == 0 else { return launched }
    let tv = info.kp_proc.p_un.__p_starttime
    return Date(timeIntervalSince1970: Double(tv.tv_sec) + Double(tv.tv_usec) / 1e6)
  }()

  static func memoryMB() -> Int {
    var info = task_vm_info_data_t(), count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
    let r = withUnsafeMutablePointer(to: &info) { $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count) } }
    return r == KERN_SUCCESS ? Int(info.phys_footprint / 1_048_576) : -1
  }

  /// A plain-text report a grown-up can choose to share (version, device, recent events, MetricKit summaries).
  static func report() -> String {
    let f = ISO8601DateFormatter()
    var lines = ["Moon Club diagnostics", "Version \(version)", "Device \(UIDevice.current.model), iOS \(UIDevice.current.systemVersion)",
                 "Memory now \(memoryMB()) MB", "Report made \(f.string(from: Date()))", "", "Apple metrics (MetricKit):"]
    lines += MetricsInbox.shared.summaries().map { "  " + $0 }
    lines += ["", "Recent events (newest last):"]
    lines += EventLog.shared.events.suffix(250).map { "  \(f.string(from: $0.t)) \($0.kind) \($0.detail)" }
    return lines.joined(separator: "\n")
  }
}

/// Main thread watchdog: a utility-queue timer pings the main queue every second. If the main thread hasn't
/// answered for 2 s, that's one hang (recorded once, with how long it lasted when it ends).
final class HangWatch: @unchecked Sendable {
  static let shared = HangWatch()
  private let queue = DispatchQueue(label: "moonclub.hangwatch", qos: .utility)
  private var timer: DispatchSourceTimer?
  private var lastPong = DispatchTime.now()
  private var hangStart: DispatchTime?
  static let threshold: Double = 2

  func start() {
    queue.async { [self] in
      guard timer == nil else { return }
      let t = DispatchSource.makeTimerSource(queue: queue)
      t.schedule(deadline: .now() + 1, repeating: 1, leeway: .milliseconds(250))
      t.setEventHandler { [weak self] in self?.tick() }
      timer = t
      t.resume()
    }
  }

  private func tick() {
    let now = DispatchTime.now()
    let silent = Double(now.uptimeNanoseconds - lastPong.uptimeNanoseconds) / 1e9
    if silent >= Self.threshold, hangStart == nil, UIApplicationStateCache.active {
      hangStart = lastPong
      Log.perf.fault("main thread hang ≥ \(Self.threshold, format: .fixed(precision: 0)) s")
    }
    DispatchQueue.main.async { [weak self] in
      UIApplicationStateCache.active = UIApplication.shared.applicationState == .active
      self?.queue.async { self?.pong() }
    }
  }
  private func pong() {
    let now = DispatchTime.now()
    if let s = hangStart {
      let d = Double(now.uptimeNanoseconds - s.uptimeNanoseconds) / 1e9
      EventLog.shared.add("perf.hang", String(format: "%.1f s", d))
      hangStart = nil
    }
    lastPong = now
  }
}

/// Read on the main thread, used by the watchdog (a backgrounded app isn't hung, it's suspended).
enum UIApplicationStateCache { nonisolated(unsafe) static var active = true }

/// Apple's MetricKit: the system delivers yesterday's metrics and any crash/hang diagnostics to the app.
final class MetricsInbox: NSObject, MXMetricManagerSubscriber, @unchecked Sendable {
  static let shared = MetricsInbox()
  static let keep = 14
  func start() { MXMetricManager.shared.add(self) }

  func didReceive(_ payloads: [MXMetricPayload]) {
    for p in payloads {
      save(p.jsonRepresentation(), kind: "metrics")
      var bits: [String] = []
      if let l = p.applicationLaunchMetrics?.histogrammedTimeToFirstDraw, let m = Self.median(l) { bits.append(String(format: "launch p50 %.0f ms", m)) }
      if let h = p.applicationResponsivenessMetrics?.histogrammedApplicationHangTime, let m = Self.median(h) { bits.append(String(format: "hang p50 %.0f ms", m)) }
      if let c = p.cpuMetrics?.cumulativeCPUTime { bits.append("cpu \(Int(c.converted(to: .seconds).value)) s") }
      if let m = p.memoryMetrics?.peakMemoryUsage { bits.append("peak \(Int(m.converted(to: .megabytes).value)) MB") }
      EventLog.shared.add("metrics.daily", bits.joined(separator: ", "))
    }
  }
  func didReceive(_ payloads: [MXDiagnosticPayload]) {
    for p in payloads {
      save(p.jsonRepresentation(), kind: "diagnostic")
      let parts = ["crashes \(p.crashDiagnostics?.count ?? 0)", "hangs \(p.hangDiagnostics?.count ?? 0)",
                   "cpu \(p.cpuExceptionDiagnostics?.count ?? 0)", "disk \(p.diskWriteExceptionDiagnostics?.count ?? 0)"]
      EventLog.shared.add("metrics.diagnostic", parts.joined(separator: ", "))
    }
  }

  /// One line per saved payload, newest first.
  func summaries() -> [String] {
    let lines = EventLog.shared.events.filter { $0.kind.hasPrefix("metrics.") }.reversed().prefix(20)
    let f = ISO8601DateFormatter()
    return lines.isEmpty ? ["(none yet: iOS delivers them about once a day)"] : lines.map { "\(f.string(from: $0.t)) \($0.kind): \($0.detail)" }
  }

  private func save(_ data: Data, kind: String) {
    guard let dir = Diagnostics.directory else { return }
    let name = "\(kind)-\(Int(Date().timeIntervalSince1970)).json"
    try? data.write(to: dir.appending(path: name), options: .atomic)
    let fm = FileManager.default
    let old = ((try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.creationDateKey])) ?? [])
      .filter { $0.lastPathComponent.hasPrefix(kind + "-") }
      .sorted { $0.lastPathComponent > $1.lastPathComponent }
    for u in old.dropFirst(Self.keep) { try? fm.removeItem(at: u) }
  }

  static func median(_ h: MXHistogram<UnitDuration>) -> Double? {
    var buckets: [(ms: Double, n: Int)] = []
    let e = h.bucketEnumerator
    while let b = e.nextObject() as? MXHistogramBucket<UnitDuration> {
      let mid = (b.bucketStart.converted(to: .milliseconds).value + b.bucketEnd.converted(to: .milliseconds).value) / 2
      buckets.append((mid, b.bucketCount))
    }
    let total = buckets.reduce(0) { $0 + $1.n }
    guard total > 0 else { return nil }
    var seen = 0
    for b in buckets { seen += b.n; if seen * 2 >= total { return b.ms } }
    return buckets.last?.ms
  }
}
