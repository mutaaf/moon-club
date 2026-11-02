// The Live Activity: "Report Card Day" (countdown → Results are in!) and "Lesson in progress".
// The countdown is Text(timerInterval:), drawn by the system every second with no updates from us.
// When the report time passes, the activity goes stale (staleDate = reportAt) and `context.isStale`
// flips the view to "Results are in!", so it works even if the app never runs again.
import ActivityKit
import SwiftUI
import WidgetKit
import MoonClubCore
#if WIDGET_RENDER_TESTS
@testable import MoonClub // the tests compile these views next to the app's Theme and Shared types
#endif

struct MoonLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: MoonActivityAttributes.self) { context in
      LiveLockScreen(a: context.attributes, st: context.state, stale: context.isStale)
        .activityBackgroundTint(Palette.paper.opacity(0.92))
        .activitySystemActionForegroundColor(Palette.accent)
        .widgetURL(link(context.attributes))
    } dynamicIsland: { context in
      let a = context.attributes, st = context.state
      return DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          HStack(spacing: 8) {
            Glyph(a.emoji, size: 38)
            VStack(alignment: .leading, spacing: 0) {
              Text(a.kind == .report ? "Report card" : "Moon School").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
              Text(a.title).font(.system(.headline, design: .rounded)).lineLimit(1).minimumScaleFactor(0.8)
            }
          }
          .padding(.leading, 4)
        }
        DynamicIslandExpandedRegion(.trailing) {
          if a.kind == .report, let p = a.pick.flatMap(Pick.init(rawValue:)) { PickChip(pick: p).padding(.trailing, 4) }
          else if a.kind == .lesson { StepRing(step: st.step, steps: st.steps, done: st.done).frame(width: 34, height: 34).padding(.trailing, 4) }
        }
        DynamicIslandExpandedRegion(.bottom) {
          LiveStatus(a: a, st: st, stale: context.isStale, big: true).padding(.horizontal, 4).padding(.top, 4)
        }
      } compactLeading: {
        Image(systemName: Art.spec(a.emoji).symbol).font(.system(size: 14, weight: .semibold)).foregroundStyle(Art.spec(a.emoji).hue.light).padding(.leading, 2)
      } compactTrailing: {
        CompactStatus(a: a, st: st, stale: context.isStale)
      } minimal: {
        if a.kind == .lesson { StepRing(step: st.step, steps: st.steps, done: st.done).padding(2) }
        else { Image(systemName: context.isStale ? "sparkles" : Art.spec(a.emoji).symbol).font(.system(size: 13, weight: .semibold)).foregroundStyle(Art.spec(a.emoji).hue.light) }
      }
      .widgetURL(link(a))
      .keylineTint(Palette.accent)
    }
  }

  func link(_ a: MoonActivityAttributes) -> URL { a.kind == .lesson ? MoonLink.lesson(a.key) : MoonLink.tab("guess") }
}

/// The Lock Screen / StandBy banner.
struct LiveLockScreen: View {
  let a: MoonActivityAttributes
  let st: MoonActivityAttributes.ContentState
  let stale: Bool
  var body: some View {
    HStack(spacing: 14) {
      ZStack {
        Circle().fill(a.kind == .report ? Palette.mint : Palette.sky)
        Glyph(a.emoji, size: 34)
      }
      .frame(width: 52, height: 52)
      VStack(alignment: .leading, spacing: 3) {
        HStack(spacing: 6) {
          Text(a.kind == .report ? "REPORT CARD DAY" : "MOON SCHOOL").font(.system(.caption2, design: .monospaced).weight(.semibold)).tracking(1.1).foregroundStyle(Palette.wAccent)
          Spacer(minLength: 0)
          if a.kind == .report, let p = a.pick.flatMap(Pick.init(rawValue:)) { PickChip(pick: p) }
        }
        Text(a.title).font(.system(.title3, design: .rounded).weight(.bold)).foregroundStyle(Palette.ink).lineLimit(1).minimumScaleFactor(0.8)
        LiveStatus(a: a, st: st, stale: stale, big: false)
      }
      if a.kind == .lesson { StepRing(step: st.step, steps: st.steps, done: st.done).frame(width: 40, height: 40) }
    }
    .padding(16)
    .accessibilityElement(children: .combine)
  }
}

/// One line of status: the live countdown, "Results are in!", or lesson progress.
struct LiveStatus: View {
  let a: MoonActivityAttributes
  let st: MoonActivityAttributes.ContentState
  let stale: Bool
  var big: Bool
  var body: some View {
    switch a.kind {
    case .report:
      if stale || (st.reportAt.map { $0 <= .now } ?? false) {
        Text("Results are in! Open Moon Club to see if you were right.").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.goodInk).lineLimit(2)
      } else if let t = st.reportAt {
        HStack(spacing: 6) {
          Image(systemName: "timer")
          Text(timerInterval: Date.now...t, countsDown: true).monospacedDigit().font(.system(big ? .title2 : .headline, design: .rounded).weight(.bold))
          Text("until the report card").font(.subheadline).foregroundStyle(Palette.ink2).lineLimit(1).minimumScaleFactor(0.8)
        }
        .foregroundStyle(Palette.wAccent)
      }
    case .lesson:
      if st.done { Text("Lesson done! Nice work.").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.goodInk) }
      else { Text("Step \(min(st.step + 1, st.steps)) of \(st.steps) · tap to keep going").font(.subheadline).foregroundStyle(Palette.ink2) }
    }
  }
}

/// Compact trailing: the countdown (fixed width so the island doesn't jitter) or "3/5".
struct CompactStatus: View {
  let a: MoonActivityAttributes
  let st: MoonActivityAttributes.ContentState
  let stale: Bool
  var body: some View {
    Group {
      switch a.kind {
      case .report:
        if stale || (st.reportAt.map { $0 <= .now } ?? true) { Text("✨ In!").font(.caption.weight(.bold)) }
        else if let t = st.reportAt {
          Text(timerInterval: Date.now...t, countsDown: true, showsHours: true)
            .monospacedDigit().font(.caption.weight(.semibold)).multilineTextAlignment(.trailing).frame(width: 52)
        }
      case .lesson:
        Text(st.done ? "🌕" : "\(min(st.step + 1, st.steps))/\(st.steps)").font(.caption.weight(.bold)).monospacedDigit()
      }
    }
    .foregroundStyle(Palette.moon)
    .padding(.trailing, 2)
  }
}

/// Lesson progress as a ring that fills like the moon.
struct StepRing: View {
  let step: Int, steps: Int, done: Bool
  var body: some View {
    let f = done ? 1 : (steps > 0 ? Double(step) / Double(steps) : 0)
    ZStack {
      Circle().stroke(Palette.line.opacity(0.6), lineWidth: 3)
      Circle().trim(from: 0, to: f).stroke(Palette.wAccent, style: .init(lineWidth: 3, lineCap: .round)).rotationEffect(.degrees(-90))
      Text(done ? "🌕" : "🌙").font(.system(size: 12))
    }
    .accessibilityLabel(done ? "Lesson done" : "Step \(step + 1) of \(steps)")
  }
}
