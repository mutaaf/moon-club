// App → widgets and Live Activities. Everything here is local: a small file in the App Group, a
// timeline reload, and ActivityKit calls with no push token (nothing about the child leaves the device).
import ActivityKit
import Foundation
import MoonClubCore
import WidgetKit

@MainActor
enum WidgetPublisher {
  /// Rebuild the snapshot; write and reload only when it actually changed (reloads are budgeted by iOS).
  static func publish(_ app: AppModel) {
    let snap = WidgetSnapshots.build(state: app.state, content: app.content, events: app.events, mood: app.mood, today: app.today)
    if MoonGroup.writeSnapshot(snap) { WidgetCenter.shared.reloadAllTimelines() }
    LiveActivities.syncReport(snap)
  }
}

@MainActor
enum LiveActivities {
  typealias A = MoonActivityAttributes
  static var enabled: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }
  static var all: [Activity<A>] { Activity<A>.activities }

  /// Keep exactly one "Report Card Day" activity: for today's report card you guessed. End the rest.
  static func syncReport(_ snap: WidgetSnapshot, now: Date = .now) {
    let want = LiveReport.candidate(snap, now: now)
    for a in all where a.attributes.kind == .report && a.attributes.key != want?.id {
      Task { await a.end(nil, dismissalPolicy: .immediate) }
    }
    guard let r = want, enabled, !all.contains(where: { $0.attributes.key == r.id }), let at = ReportClock.time(r.d, r.h) else { return }
    let attrs = A(kind: .report, key: r.id, emoji: r.emoji, title: r.nick, pick: r.pick?.rawValue)
    // staleDate = the report time: the view flips itself to "Results are in!" without another update.
    _ = try? Activity.request(attributes: attrs, content: .init(state: .init(reportAt: at), staleDate: at, relevanceScore: 80), pushType: nil)
  }

  // MARK: Lesson in progress (shows in the Dynamic Island if the kid leaves mid-lesson)
  static func lesson(_ l: Lesson, step: Int) {
    guard enabled else { return }
    let st = A.ContentState(step: step, steps: l.steps.count)
    if let a = all.first(where: { $0.attributes.kind == .lesson && $0.attributes.key == l.id }) {
      Task { await a.update(.init(state: st, staleDate: .now.addingTimeInterval(3600))) }
      return
    }
    for a in all where a.attributes.kind == .lesson { Task { await a.end(nil, dismissalPolicy: .immediate) } }
    _ = try? Activity.request(attributes: A(kind: .lesson, key: l.id, emoji: l.emoji, title: l.title, pick: nil),
                              content: .init(state: st, staleDate: .now.addingTimeInterval(3600), relevanceScore: 50), pushType: nil)
  }
  static func lessonDone(_ l: Lesson) {
    for a in all where a.attributes.kind == .lesson && a.attributes.key == l.id {
      Task { await a.end(.init(state: .init(step: l.steps.count, steps: l.steps.count, done: true), staleDate: nil), dismissalPolicy: .after(.now.addingTimeInterval(8))) }
    }
  }
  static func lessonLeft(_ l: Lesson) {
    for a in all where a.attributes.kind == .lesson && a.attributes.key == l.id { Task { await a.end(nil, dismissalPolicy: .immediate) } }
  }
}
