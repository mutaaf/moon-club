// Every widget, every family. Rules of thumb used throughout:
// - System content margins (no extra outer padding), 8/12 pt internal rhythm, one idea per widget.
// - Text scales with Dynamic Type, never truncates mid-word (lineLimit + minimumScaleFactor).
// - Buttons are App Intents with big, ≥ 40 pt targets; the redraw comes from the snapshot the intent writes.
// - Accessory families: no colored fills, key marks are .widgetAccentable() so tinted modes stay legible.
import SwiftUI
import WidgetKit
import AppIntents
import MoonClubCore
#if WIDGET_RENDER_TESTS
@testable import MoonClub // the tests compile these views next to the app's Theme and Shared types
#endif

// MARK: - Report Card Day

struct ReportWidgetView: View {
  let entry: MoonEntry
  var forced: WidgetFamily? = nil
  @Environment(\.widgetFamily) private var envFamily
  var family: WidgetFamily { forced ?? envFamily }
  var body: some View {
    Group {
      if let r = entry.snap.headline {
        switch family {
        case .systemSmall: small(r)
        case .systemMedium: medium(r)
        case .systemLarge: large
        case .accessoryRectangular: rect(r)
        case .accessoryCircular: circ(r)
        default: inline(r)
        }
      } else { ReportEmpty(family: family) }
    }
    .widgetURL(MoonLink.tab("guess"))
    .containerBackground(for: .widget) { WidgetBackdrop(surface: .guess) }
  }

  func small(_ r: WidgetSnapshot.Report, chip: Bool = true) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(alignment: .top) {
        Text(r.emoji).font(.system(size: 34))
        Spacer(minLength: 4)
        if chip, let p = r.pick { PickChip(pick: p) }
      }
      Spacer(minLength: 6)
      WEyebrow(text: "Report card")
      Text(r.nick).font(.kTitle).foregroundStyle(Palette.ink).lineLimit(1).minimumScaleFactor(0.7).padding(.top, 2)
      WhenLine(report: r, entry: entry, compact: true).padding(.top, 2)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
  }

  func medium(_ r: WidgetSnapshot.Report) -> some View {
    HStack(spacing: 14) {
      small(r, chip: false) // the filled button already shows the pick
      VStack(alignment: .leading, spacing: 8) {
        Text(question(r)).font(.system(.subheadline, design: .rounded).weight(.semibold)).foregroundStyle(Palette.ink)
          .lineLimit(2).minimumScaleFactor(0.85).fixedSize(horizontal: false, vertical: true)
        PickButtons(report: r, entry: entry, height: 42)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
  }

  var large: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .firstTextBaseline) {
        VStack(alignment: .leading, spacing: 2) {
          WEyebrow(text: "Report card days")
          Text("Beat or miss?").font(.kTitle).foregroundStyle(Palette.ink)
        }
        Spacer()
        LunaMark(size: 36)
      }
      ForEach(entry.snap.reports.prefix(4)) { r in
        HStack(spacing: 10) {
          Text(r.emoji).font(.system(size: 26)).frame(width: 34)
          VStack(alignment: .leading, spacing: 1) {
            Text(r.nick).font(.kHeadline).foregroundStyle(Palette.ink).lineLimit(1)
            WhenLine(report: r, entry: entry, compact: true)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          PickButtons(report: r, entry: entry, height: 36, compact: true).frame(width: 128)
        }
        .padding(.vertical, 2)
        if r.id != entry.snap.reports.prefix(4).last?.id { Divider().overlay(Palette.line) }
      }
      Spacer(minLength: 0)
      Text("Tap to guess right here. Results show up in Moon Club.").font(.caption).foregroundStyle(Palette.ink2).lineLimit(1).minimumScaleFactor(0.8)
    }
  }

  func rect(_ r: WidgetSnapshot.Report) -> some View {
    VStack(alignment: .leading, spacing: 1) {
      HStack(spacing: 4) { Text(r.emoji); Text(r.nick).font(.headline).lineLimit(1).widgetAccentable() }
      WhenLine(report: r, entry: entry, compact: true)
      Text(r.pick.map { "You said \($0 == .beat ? "beat" : "miss")" } ?? "Tap to guess").font(.caption).foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  func circ(_ r: WidgetSnapshot.Report) -> some View {
    ZStack {
      AccessoryWidgetBackground()
      VStack(spacing: 0) {
        Text(r.emoji).font(.system(size: 20))
        switch ReportClock.phase(r, today: entry.today, now: entry.date) {
        case .later(let d): Text(d == 1 ? "1 day" : "\(d) days").font(.system(.caption2, design: .rounded).weight(.bold))
        case .resultsIn: Text("In!").font(.system(.caption2, design: .rounded).weight(.bold))
        default: Text("Today").font(.system(.caption2, design: .rounded).weight(.bold))
        }
      }
      .widgetAccentable()
    }
    .accessibilityLabel("\(r.nick) report card")
  }

  func inline(_ r: WidgetSnapshot.Report) -> some View {
    Text("\(r.emoji) \(r.nick) · \(kidWhen(r.d, r.h, today: entry.today))")
  }

  func question(_ r: WidgetSnapshot.Report) -> String {
    switch ReportClock.phase(r, today: entry.today, now: entry.date) {
    case .resultsIn: return "Open Moon Club to see if you were right!"
    default: return r.pick == nil ? "Will \(r.nick) beat or miss?" : "Changed your mind? Tap the other one."
    }
  }
}

/// Two big buttons. The chosen one is filled; tapping writes the snapshot, so it redraws at once.
struct PickButtons: View {
  let report: WidgetSnapshot.Report
  let entry: MoonEntry
  var height: CGFloat = 40
  var compact = false
  var open: Bool { if case .resultsIn = ReportClock.phase(report, today: entry.today, now: entry.date) { return false }; return true }
  var body: some View {
    HStack(spacing: 6) {
      ForEach(Pick.allCases, id: \.self) { p in
        let on = report.pick == p
        Button(intent: GuessReportIntent(symbol: report.s, day: report.d, pick: p)) {
          Text(compact ? (p == .beat ? "👍 Beat" : "👎 Miss") : (p == .beat ? "Beat 👍" : "Miss 👎"))
            .font(.system(compact ? .caption : .subheadline, design: .rounded).weight(.bold))
            .lineLimit(1).minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity, minHeight: height)
            .foregroundStyle(on ? Color.white : Palette.ink)
            .background(RoundedRectangle(cornerRadius: height / 2.6, style: .continuous).fill(on ? (p == .beat ? Palette.good : Palette.bad) : Palette.card))
            .overlay(RoundedRectangle(cornerRadius: height / 2.6, style: .continuous).strokeBorder(on ? .clear : Palette.line, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!open)
        .invalidatableContent()
        .accessibilityLabel("Guess \(report.nick) will \(p.rawValue)")
        .accessibilityAddTraits(on ? .isSelected : [])
      }
    }
    .opacity(open ? 1 : 0.45)
  }
}

struct ReportEmpty: View {
  let family: WidgetFamily
  var body: some View {
    switch family {
    case .accessoryInline: Text("🌙 No report cards soon")
    case .accessoryCircular: ZStack { AccessoryWidgetBackground(); LunaMark(size: 30, face: true).widgetAccentable() }
    case .accessoryRectangular:
      VStack(alignment: .leading) { Text("Report cards").font(.headline); Text("Open Moon Club to find the next one").font(.caption).foregroundStyle(.secondary) }
        .frame(maxWidth: .infinity, alignment: .leading)
    default:
      VStack(alignment: .leading, spacing: 6) {
        LunaMark(size: 40)
        Spacer(minLength: 0)
        WEyebrow(text: "Report cards")
        Text("Open Moon Club to find the next report card day.").font(.subheadline.weight(.medium)).foregroundStyle(Palette.ink).lineLimit(3).minimumScaleFactor(0.85)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
  }
}

// MARK: - Market Weather (Story)

struct StoryWidgetView: View {
  let entry: MoonEntry
  var forced: WidgetFamily? = nil
  @Environment(\.widgetFamily) private var envFamily
  var family: WidgetFamily { forced ?? envFamily }
  var body: some View {
    Group {
      if let w = entry.snap.weather, entry.snap.day == entry.today || entry.snap.day == Day.add(entry.today, -1) {
        switch family {
        case .systemSmall: small(w)
        case .systemMedium: medium(w)
        case .accessoryRectangular:
          VStack(alignment: .leading, spacing: 1) {
            Label(w.title, systemImage: WFormat.weatherSymbol(w.icon)).font(.headline).widgetAccentable()
            Text("Market mood \(entry.snap.mood ?? 0) of 100").font(.caption).foregroundStyle(.secondary)
          }.frame(maxWidth: .infinity, alignment: .leading)
        case .accessoryCircular:
          Gauge(value: Double(entry.snap.mood ?? 50), in: 0...100) { Image(systemName: WFormat.weatherSymbol(w.icon)) } currentValueLabel: {
            Image(systemName: WFormat.weatherSymbol(w.icon))
          }
          .gaugeStyle(.accessoryCircular).widgetAccentable()
          .accessibilityLabel("Market weather: \(w.title)")
        default: Text("\(w.emoji) Market weather: \(w.title)")
        }
      } else {
        switch family {
        case .accessoryInline: Text("🌙 Check today's market weather")
        case .accessoryCircular: ZStack { AccessoryWidgetBackground(); Image(systemName: "cloud.sun").widgetAccentable() }
        case .accessoryRectangular: VStack(alignment: .leading) { Text("Market weather").font(.headline); Text("Open Moon Club to check").font(.caption) }.frame(maxWidth: .infinity, alignment: .leading)
        default:
          VStack(alignment: .leading, spacing: 6) {
            LunaMark(size: 40); Spacer(minLength: 0)
            WEyebrow(text: "Market weather")
            Text("Open Moon Club to check today's weather.").font(.subheadline.weight(.medium)).foregroundStyle(Palette.ink).lineLimit(3)
          }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
      }
    }
    .widgetURL(MoonLink.tab("story"))
    .containerBackground(for: .widget) { WidgetBackdrop(surface: .story) }
  }

  func small(_ w: Weather) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(alignment: .top) {
        Image(systemName: WFormat.weatherSymbol(w.icon)).symbolRenderingMode(.multicolor).font(.system(size: 34))
        Spacer()
        if entry.snap.storyRead { Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.good).font(.title3).accessibilityLabel("Read today") }
      }
      Spacer(minLength: 6)
      WEyebrow(text: "Market weather")
      Text(w.title).font(.kTitle).foregroundStyle(Palette.ink).lineLimit(1).minimumScaleFactor(0.7).padding(.top, 2)
      Text("Mood \(entry.snap.mood ?? 0) of 100").font(.caption).foregroundStyle(Palette.ink2).padding(.top, 2)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
  }

  func medium(_ w: Weather) -> some View {
    HStack(spacing: 14) {
      small(w).frame(width: 118)
      VStack(alignment: .leading, spacing: 8) {
        Text(w.line).font(.subheadline).foregroundStyle(Palette.ink).lineLimit(4).minimumScaleFactor(0.85).fixedSize(horizontal: false, vertical: true)
        Spacer(minLength: 0)
        if entry.snap.storyRead {
          Label("Read today. Nice!", systemImage: "checkmark.circle.fill").font(.system(.subheadline, design: .rounded).weight(.bold)).foregroundStyle(Palette.good)
            .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
        } else {
          Button(intent: ReadStoryIntent()) {
            Label("I read it", systemImage: "checkmark")
              .font(.system(.subheadline, design: .rounded).weight(.bold))
              .frame(maxWidth: .infinity, minHeight: 40)
              .foregroundStyle(.white)
              .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(Palette.accent))
          }
          .buttonStyle(.plain)
          .invalidatableContent()
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
  }
}

// MARK: - Pretend Piggy Bank

struct PiggyWidgetView: View {
  let entry: MoonEntry
  var forced: WidgetFamily? = nil
  @Environment(\.widgetFamily) private var envFamily
  var family: WidgetFamily { forced ?? envFamily }
  var body: some View {
    Group {
      if let p = entry.snap.piggy {
        switch family {
        case .systemSmall: small(p)
        case .systemMedium: medium(p)
        case .accessoryRectangular:
          HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
              Text("🐷 \(WFormat.coins(p.value))").font(.headline).widgetAccentable().lineLimit(1).minimumScaleFactor(0.8)
              Text("\(WFormat.pct(p.change)) · pretend").font(.caption).foregroundStyle(.secondary)
            }
            Sparkline(values: p.spark, start: p.start).frame(width: 44, height: 26)
          }
        default: Text("🐷 \(WFormat.coins(p.value)) · \(WFormat.pct(p.change))")
        }
      } else {
        switch family {
        case .accessoryInline: Text("🐷 Start a pretend piggy bank")
        case .accessoryRectangular: VStack(alignment: .leading) { Text("🐷 Piggy Bank").font(.headline); Text("Start one in Moon Club").font(.caption) }.frame(maxWidth: .infinity, alignment: .leading)
        default:
          VStack(alignment: .leading, spacing: 6) {
            Text("🐷").font(.system(size: 34)); Spacer(minLength: 0)
            WEyebrow(text: "Pretend piggy bank")
            Text("Start one with 🌙 $1,000 pretend coins.").font(.subheadline.weight(.medium)).foregroundStyle(Palette.ink).lineLimit(3).minimumScaleFactor(0.85)
          }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
      }
    }
    .widgetURL(MoonLink.tab("piggy"))
    .containerBackground(for: .widget) { WidgetBackdrop(surface: .piggy) }
  }

  func value(_ p: WidgetSnapshot.PiggyLine) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      WEyebrow(text: "Pretend coins")
      Text(WFormat.coins(p.value)).font(.system(.title, design: .rounded).weight(.heavy)).foregroundStyle(Palette.ink)
        .lineLimit(1).minimumScaleFactor(0.6).contentTransition(.numericText(value: p.value))
      Text("\(WFormat.pct(p.change)) since you started").font(.caption.weight(.semibold)).foregroundStyle(p.change >= 0 ? Palette.good : Palette.bad).lineLimit(1).minimumScaleFactor(0.8)
    }
    .accessibilityElement(children: .combine)
  }

  func small(_ p: WidgetSnapshot.PiggyLine) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      value(p)
      Sparkline(values: p.spark, start: p.start).frame(maxHeight: .infinity)
    }
  }

  func medium(_ p: WidgetSnapshot.PiggyLine) -> some View {
    HStack(spacing: 16) {
      VStack(alignment: .leading) {
        value(p)
        Spacer(minLength: 0)
        Text("Real prices, pretend coins. Nothing is bought for real.").font(.caption2).foregroundStyle(Palette.ink2).lineLimit(2)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      Sparkline(values: p.spark, start: p.start).frame(maxWidth: .infinity)
    }
  }
}

// MARK: - Moon School

struct SchoolWidgetView: View {
  let entry: MoonEntry
  var forced: WidgetFamily? = nil
  @Environment(\.widgetFamily) private var envFamily
  var family: WidgetFamily { forced ?? envFamily }
  var s: WidgetSnapshot { entry.snap }
  var body: some View {
    Group {
      switch family {
      case .systemSmall: small
      case .systemMedium: medium
      case .accessoryCircular:
        Gauge(value: Double(s.lessonsDone), in: 0...Double(max(1, s.lessonsTotal))) { Image(systemName: "graduationcap.fill") } currentValueLabel: { Text("\(s.lessonsDone)") }
          .gaugeStyle(.accessoryCircularCapacity).widgetAccentable()
          .accessibilityLabel("\(s.lessonsDone) of \(s.lessonsTotal) lessons done")
      default:
        VStack(alignment: .leading, spacing: 1) {
          Text(s.streak > 0 ? "🌙 \(s.streak)-day streak" : "🌙 Moon School").font(.headline).widgetAccentable()
          Text(s.nextLesson.map { "Next: \($0.title)" } ?? "Every lesson done! 🌕").font(.caption).lineLimit(2)
        }.frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .widgetURL(s.nextLesson.map { MoonLink.lesson($0.id) } ?? MoonLink.tab("school"))
    .containerBackground(for: .widget) { WidgetBackdrop(surface: .school) }
  }

  var streakLine: some View {
    HStack(alignment: .firstTextBaseline, spacing: 4) {
      Text("\(s.streak)").font(.system(.largeTitle, design: .rounded).weight(.heavy)).foregroundStyle(Palette.ink).contentTransition(.numericText(value: Double(s.streak)))
      Text(s.streak == 1 ? "day\nstreak" : "days\nstreak").font(.caption2.weight(.semibold)).foregroundStyle(Palette.ink2).lineSpacing(-2)
    }
    .accessibilityElement(children: .ignore).accessibilityLabel("\(s.streak) day streak")
  }

  var small: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(alignment: .top) { streakLine; Spacer(); Text(s.nextLesson?.emoji ?? "🌕").font(.system(size: 26)) }
      Spacer(minLength: 6)
      WEyebrow(text: s.nextLesson == nil ? "All done" : "Next lesson")
      Text(s.nextLesson?.title ?? "You finished Moon School!").font(.kHeadline).foregroundStyle(Palette.ink).lineLimit(2).minimumScaleFactor(0.85).padding(.top, 2)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
  }

  var medium: some View {
    HStack(spacing: 16) {
      small
      VStack(alignment: .leading, spacing: 8) {
        Text("\(s.lessonsDone) of \(s.lessonsTotal) lessons").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
        MoonBar(value: Double(s.lessonsDone) / Double(max(1, s.lessonsTotal)), height: 8)
        Spacer(minLength: 0)
        if let n = s.nextLesson {
          Link(destination: MoonLink.lesson(n.id)) {
            Label("Start · \(n.steps) steps", systemImage: "play.fill")
              .font(.system(.subheadline, design: .rounded).weight(.bold))
              .frame(maxWidth: .infinity, minHeight: 40)
              .foregroundStyle(.white)
              .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(Palette.accent))
          }
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
  }
}

// MARK: - Luna's Moon

struct LunaWidgetView: View {
  let entry: MoonEntry
  var forced: WidgetFamily? = nil
  @Environment(\.widgetFamily) private var envFamily
  var family: WidgetFamily { forced ?? envFamily }
  var body: some View {
    let phase = LunarPhase.name(entry.date)
    Group {
      switch family {
      case .systemSmall:
        VStack(alignment: .leading, spacing: 0) {
          HStack { Spacer(); LunaMark.tonight(entry.date, size: 64); Spacer() }
          Spacer(minLength: 6)
          WEyebrow(text: "Tonight's moon")
          Text(phase.name).font(.kHeadline).foregroundStyle(Palette.ink).lineLimit(1).minimumScaleFactor(0.75).padding(.top, 2)
          HStack(spacing: 6) {
            Text(entry.snap.level).font(.caption2.weight(.semibold)).foregroundStyle(Palette.ink2).lineLimit(1)
            MoonBar(value: entry.snap.levelProgress, height: 5)
          }.padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tonight's moon: \(phase.name). Your level: \(entry.snap.level).")
      case .accessoryCircular:
        ZStack { AccessoryWidgetBackground(); LunaMark.tonight(entry.date, size: 40, face: false).widgetAccentable() }
          .accessibilityLabel("Tonight's moon: \(phase.name)")
      default: Text("\(phase.emoji) \(phase.name)")
      }
    }
    .widgetURL(MoonLink.tab("luna"))
    .containerBackground(for: .widget) { WidgetBackdrop(surface: .luna) }
  }
}
