import XCTest
import SwiftUI
import WidgetKit
import MoonClubCore
@testable import MoonClub

/// Draws every widget family and every Live Activity presentation with ImageRenderer, at real iPhone
/// sizes, in light and dark. Always checks that each view renders; writes PNGs only when
/// WIDGET_SHOTS_DIR is set (scripts/widget-shots.sh), for design review.
@MainActor
final class WidgetRenderTests: XCTestCase {
  let ny: Calendar = { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "America/New_York")!; return c }()
  /// Real "now": Text(timerInterval:) counts against the real clock even inside ImageRenderer.
  let now = Date()
  /// A session for today whose report time is still ahead (so the countdown shows), else nil.
  var openSession: Session? { [Session.bmo, .dmh, .amc].first { (ReportClock.time(Day.today(now), $0) ?? .distantPast) > now } }
  var outDir: URL? { ProcessInfo.processInfo.environment["WIDGET_SHOTS_DIR"].map { URL(fileURLWithPath: $0) } }

  // iPhone 17 (402 pt wide) widget sizes.
  let sizes: [WidgetFamily: CGSize] = [
    .systemSmall: .init(width: 170, height: 170), .systemMedium: .init(width: 364, height: 170), .systemLarge: .init(width: 364, height: 382),
    .accessoryCircular: .init(width: 76, height: 76), .accessoryRectangular: .init(width: 172, height: 76), .accessoryInline: .init(width: 257, height: 26),
  ]

  func snap(_ f: (inout WidgetSnapshot) -> Void = { _ in }) -> WidgetSnapshot {
    var s = WidgetSnapshot.placeholder
    s.day = Day.today(now)
    s.reports = [
      .init(s: "AAPL", nick: "Apple", emoji: "🍎", d: openSession == nil ? Day.add(s.day, 1) : s.day, h: openSession ?? .bmo, pick: .beat),
      .init(s: "NKE", nick: "Nike", emoji: "👟", d: Day.add(s.day, 1), h: .amc, pick: nil),
      .init(s: "DIS", nick: "Disney", emoji: "🏰", d: Day.add(s.day, 3), h: .bmo, pick: .miss),
      .init(s: "MCD", nick: "McDonald's", emoji: "🍟", d: Day.add(s.day, 4), h: .bmo, pick: nil),
    ]
    f(&s)
    return s
  }

  func render<V: View>(_ name: String, _ v: V, family: WidgetFamily, surface: Surface, dark: Bool = false) throws {
    let size = sizes[family]!
    let accessory = [.accessoryCircular, .accessoryRectangular, .accessoryInline].contains(family)
    let framed = ZStack {
      if accessory { LinearGradient(colors: [Color(hex: 0x2B3A67), Color(hex: 0x4E3B6E)], startPoint: .top, endPoint: .bottom) }
      else { WidgetBackdrop(surface: surface) }
      v.padding(accessory ? 0 : 16).frame(width: size.width, height: size.height)
    }
    .frame(width: size.width, height: size.height)
    .clipShape(RoundedRectangle(cornerRadius: accessory ? (family == .accessoryCircular ? 38 : 10) : 22, style: .continuous))
    .foregroundStyle(accessory ? Color.white : Palette.ink)
    .environment(\.colorScheme, dark || accessory ? .dark : .light)
    try write(name + (dark ? "-dark" : ""), framed)
  }

  func write<V: View>(_ name: String, _ v: V) throws {
    let r = ImageRenderer(content: v.padding(12).background(Color(white: 0.93)))
    r.scale = 3
    let img = try XCTUnwrap(r.uiImage, "\(name) failed to render")
    XCTAssertGreaterThan(img.size.width, 10)
    guard let dir = outDir else { return }
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    try XCTUnwrap(img.pngData()).write(to: dir.appendingPathComponent("\(name).png"))
  }

  func testEveryWidgetFamilyRenders() throws {
    let e = MoonEntry(date: now, snap: snap())
    for dark in [false, true] {
      for f in [WidgetFamily.systemSmall, .systemMedium, .systemLarge] { try render("report-\(f)", ReportWidgetView(entry: e, forced: f), family: f, surface: .guess, dark: dark) }
      for f in [WidgetFamily.systemSmall, .systemMedium] {
        try render("story-\(f)", StoryWidgetView(entry: e, forced: f), family: f, surface: .story, dark: dark)
        try render("piggy-\(f)", PiggyWidgetView(entry: e, forced: f), family: f, surface: .piggy, dark: dark)
        try render("school-\(f)", SchoolWidgetView(entry: e, forced: f), family: f, surface: .school, dark: dark)
      }
      try render("luna-systemSmall", LunaWidgetView(entry: e, forced: .systemSmall), family: .systemSmall, surface: .luna, dark: dark)
    }
    for f in [WidgetFamily.accessoryCircular, .accessoryRectangular, .accessoryInline] {
      try render("lock-report-\(f)", ReportWidgetView(entry: e, forced: f), family: f, surface: .guess)
      try render("lock-story-\(f)", StoryWidgetView(entry: e, forced: f), family: f, surface: .story)
      if f != .accessoryCircular { try render("lock-piggy-\(f)", PiggyWidgetView(entry: e, forced: f), family: f, surface: .piggy) }
      if f != .accessoryInline { try render("lock-school-\(f)", SchoolWidgetView(entry: e, forced: f), family: f, surface: .school) }
      if f != .accessoryRectangular { try render("lock-luna-\(f)", LunaWidgetView(entry: e, forced: f), family: f, surface: .luna) }
    }
  }

  func testStatesRender() throws {
    // Story already read; report results in; first-run empty widgets.
    try render("story-read-systemMedium", StoryWidgetView(entry: MoonEntry(date: now, snap: snap { $0.storyRead = true }), forced: .systemMedium), family: .systemMedium, surface: .story)
    let past = snap { $0.reports[0].d = Day.add($0.day, -1) }
    try render("report-resultsin-systemMedium", ReportWidgetView(entry: MoonEntry(date: now, snap: past), forced: .systemMedium), family: .systemMedium, surface: .guess)
    try render("report-unpicked-systemMedium", ReportWidgetView(entry: MoonEntry(date: now, snap: snap { $0.reports.removeFirst() }), forced: .systemMedium), family: .systemMedium, surface: .guess)
    let empty = MoonEntry(date: now, snap: .empty(today: Day.today(now)))
    try render("empty-report-systemSmall", ReportWidgetView(entry: empty, forced: .systemSmall), family: .systemSmall, surface: .guess)
    try render("empty-piggy-systemSmall", PiggyWidgetView(entry: empty, forced: .systemSmall), family: .systemSmall, surface: .piggy)
    try render("empty-story-systemSmall", StoryWidgetView(entry: empty, forced: .systemSmall), family: .systemSmall, surface: .story)
    try render("piggy-down-systemSmall", PiggyWidgetView(entry: MoonEntry(date: now, snap: snap { $0.piggy = .init(value: 962.4, start: 1000, spark: [1000, 990, 1004, 981, 970, 962.4]) }), forced: .systemSmall), family: .systemSmall, surface: .piggy)
    try render("school-done-systemSmall", SchoolWidgetView(entry: MoonEntry(date: now, snap: snap { $0.nextLesson = nil; $0.lessonsDone = 28; $0.streak = 12 }), forced: .systemSmall), family: .systemSmall, surface: .school)
  }

  func testLiveActivityPresentationsRender() throws {
    let at = now.addingTimeInterval(2 * 3600 + 13 * 60)
    let report = MoonActivityAttributes(kind: .report, key: "AAPL:2026-10-31", emoji: "🍎", title: "Apple", pick: "beat")
    let lesson = MoonActivityAttributes(kind: .lesson, key: "what-is-a-share", emoji: "🍕", title: "What is a share?", pick: nil)
    let cases: [(String, MoonActivityAttributes, MoonActivityAttributes.ContentState, Bool)] = [
      ("report", report, .init(reportAt: at), false),
      ("report-results", report, .init(reportAt: at), true),
      ("lesson", lesson, .init(step: 2, steps: 5), false),
      ("lesson-done", lesson, .init(step: 5, steps: 5, done: true), false),
    ]
    for (name, a, st, stale) in cases {
      for dark in [false, true] {
        let lock = LiveLockScreen(a: a, st: st, stale: stale)
          .frame(width: 364)
          .background(Palette.paper.opacity(0.92))
          .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
          .environment(\.colorScheme, dark ? .dark : .light)
        try write("live-lock-\(name)\(dark ? "-dark" : "")", lock)
      }
      // Dynamic Island, expanded (leading · trailing / bottom), always on black.
      let expanded = VStack(spacing: 6) {
        HStack {
          HStack(spacing: 8) {
            Text(a.emoji).font(.system(size: 30))
            VStack(alignment: .leading, spacing: 0) {
              Text(a.kind == .report ? "Report card" : "Moon School").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
              Text(a.title).font(.system(.headline, design: .rounded)).lineLimit(1)
            }
          }
          Spacer()
          if a.kind == .report, let p = a.pick.flatMap(Pick.init(rawValue:)) { PickChip(pick: p) } else { StepRing(step: st.step, steps: st.steps, done: st.done).frame(width: 34, height: 34) }
        }
        LiveStatus(a: a, st: st, stale: stale, big: true).frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(.horizontal, 20).padding(.vertical, 16)
      .frame(width: 371)
      .background(RoundedRectangle(cornerRadius: 44, style: .continuous).fill(.black))
      .foregroundStyle(.white)
      .environment(\.colorScheme, .dark)
      try write("live-island-expanded-\(name)", expanded)
      let compact = HStack {
        Text(a.emoji).font(.system(size: 16))
        Spacer()
        CompactStatus(a: a, st: st, stale: stale)
      }
      .padding(.horizontal, 12)
      .frame(width: 250, height: 37)
      .background(Capsule().fill(.black))
      .environment(\.colorScheme, .dark)
      try write("live-island-compact-\(name)", compact)
    }
  }
}
