// Small, static design pieces for widgets and Live Activities. Same palette and type as the app,
// with no animation loops (widgets are snapshots) and everything vector, so Luna is crisp at any size.
import SwiftUI
import WidgetKit
import MoonClubCore
#if WIDGET_RENDER_TESTS
@testable import MoonClub // the tests compile these views next to the app's Theme and Shared types
#endif

/// The app's aurora, calmed down for a widget: a paper base with two soft blooms. Readable text on top in
/// light and dark. In tinted and clear modes the system removes it, and the content still reads.
struct WidgetBackdrop: View {
  let surface: Surface
  @Environment(\.colorScheme) private var scheme
  var body: some View {
    let c = surface.aurora
    // Light: the surface's soft aurora on paper. Dark: a clean midnight with one faint glow — warm
    // aurora tints over a dark base turned muddy (brown-purple) and cost text contrast.
    ZStack {
      if scheme == .dark {
        LinearGradient(colors: [Color(hex: 0x1A1940), Color(hex: 0x100F26)], startPoint: .top, endPoint: .bottom)
        RadialGradient(colors: [c[2].opacity(0.16), .clear], center: .topTrailing, startRadius: 0, endRadius: 200)
      } else {
        Palette.paper
        RadialGradient(colors: [c[0].opacity(0.5), .clear], center: .topLeading, startRadius: 0, endRadius: 220)
        RadialGradient(colors: [c[1].opacity(0.4), .clear], center: .bottomTrailing, startRadius: 0, endRadius: 200)
        RadialGradient(colors: [c[2].opacity(0.28), .clear], center: .topTrailing, startRadius: 0, endRadius: 160)
      }
    }
  }
}

/// Luna, drawn as tonight's moon: `lit` 0 (new) … 1 (full), `waxing` puts the light on the right.
struct LunaMark: View {
  var size: CGFloat = 56
  var lit: Double = 1
  var waxing = true
  var face = true
  var body: some View {
    let s = size / 64
    ZStack {
      Circle().fill(Palette.moon)
      // The night side: a shadow disc that slides off as the moon fills.
      Circle().fill(Palette.midnight.opacity(0.62))
        .offset(x: (waxing ? -1 : 1) * CGFloat(lit) * size * 1.02)
        .clipShape(Circle())
      Circle().strokeBorder(Palette.moonShade.opacity(0.9), lineWidth: max(1, 1.5 * s))
      if face {
        HStack(spacing: 13 * s) { Capsule().fill(Palette.midnight).frame(width: 4.6 * s, height: 6.4 * s); Capsule().fill(Palette.midnight).frame(width: 4.6 * s, height: 6.4 * s) }
          .offset(y: -3 * s)
        Path { p in p.move(to: .init(x: 25.5 * s, y: 38 * s)); p.addQuadCurve(to: .init(x: 38.5 * s, y: 38 * s), control: .init(x: 32 * s, y: 43.5 * s)) }
          .stroke(Palette.midnight, style: .init(lineWidth: 2.4 * s, lineCap: .round))
          .frame(width: size, height: size)
        HStack(spacing: 19 * s) { Circle().fill(Palette.blush.opacity(0.7)).frame(width: 6 * s); Circle().fill(Palette.blush.opacity(0.7)).frame(width: 6 * s) }.offset(y: 4 * s)
      }
    }
    .frame(width: size, height: size)
    .accessibilityHidden(true)
  }
}

extension LunaMark {
  /// Luna lit like the real moon right now.
  static func tonight(_ date: Date, size: CGFloat, face: Bool = true) -> LunaMark {
    let f = LunarPhase.fraction(date)
    return LunaMark(size: size, lit: LunarPhase.illumination(date), waxing: f < 0.5, face: face)
  }
}

/// A tiny line chart: no axes, one end dot, a faint start line. Values are normalized to the frame.
struct Sparkline: View {
  let values: [Double]
  var start: Double?
  var up: Bool { (values.last ?? 0) >= (start ?? values.first ?? 0) }
  var body: some View {
    GeometryReader { g in
      let lo = (values + [start].compactMap { $0 }).min() ?? 0, hi = (values + [start].compactMap { $0 }).max() ?? 1
      let span = max(hi - lo, 0.0001)
      let pt = { (i: Int, v: Double) -> CGPoint in
        CGPoint(x: values.count < 2 ? g.size.width : g.size.width * CGFloat(i) / CGFloat(values.count - 1),
                y: g.size.height * (1 - CGFloat((v - lo) / span)) * 0.86 + g.size.height * 0.07)
      }
      ZStack(alignment: .topLeading) {
        if let start {
          Path { p in let y = pt(0, start).y; p.move(to: .init(x: 0, y: y)); p.addLine(to: .init(x: g.size.width, y: y)) }
            .stroke(Palette.ink2.opacity(0.35), style: .init(lineWidth: 1, dash: [3, 3]))
        }
        if values.count > 1 {
          Path { p in for (i, v) in values.enumerated() { i == 0 ? p.move(to: pt(i, v)) : p.addLine(to: pt(i, v)) } }
            .stroke(up ? Palette.goodInk : Palette.badInk, style: .init(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
            .widgetAccentable()
          let last = pt(values.count - 1, values.last ?? 0)
          // The end mark points the way it went, so up/down never relies on green/red alone (colour-blind safe).
          Image(systemName: up ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill").font(.system(size: 7, weight: .black))
            .foregroundStyle(up ? Palette.goodInk : Palette.badInk).position(last).widgetAccentable()
        }
      }
    }
    .accessibilityHidden(true)
  }
}

extension Palette {
  /// The accent, lifted in dark mode so small type keeps its contrast on midnight.
  static let wAccent = Color(light: 0x2346D8, dark: 0x9DB0FF)
}

/// Small caps label, the app's eyebrow style.
struct WEyebrow: View {
  let text: String
  var body: some View { Text(text.uppercased()).font(.system(.caption2, design: .monospaced).weight(.semibold)).tracking(1.2).foregroundStyle(Palette.wAccent).lineLimit(1).minimumScaleFactor(0.8) }
}

/// A calm capsule progress bar (drawn, so it looks the same in every widget mode).
struct MoonBar: View {
  let value: Double
  var height: CGFloat = 6
  var body: some View {
    GeometryReader { g in
      ZStack(alignment: .leading) {
        Capsule().fill(Palette.line)
        Capsule().fill(Palette.wAccent).frame(width: max(height, g.size.width * CGFloat(min(1, max(0, value))))).widgetAccentable()
      }
    }
    .frame(height: height)
    .accessibilityHidden(true)
  }
}

enum WFormat {
  static func coins(_ v: Double) -> String {
    let f = NumberFormatter(); f.numberStyle = .currency; f.currencyCode = "USD"; f.maximumFractionDigits = v >= 1000 ? 0 : 2
    return f.string(from: NSNumber(value: v)) ?? "$\(Int(v))"
  }
  static func pct(_ v: Double) -> String { String(format: "%@%.1f%%", v >= 0 ? "+" : "−", abs(v * 100)) }
  /// Short "when" for tight rows: "Today · after school", "Tue · before school", "Nov 17 · school day".
  static func shortWhen(_ d: String, _ h: Session, today: String) -> String {
    let n = Day.between(today, d)
    let day = n == 0 ? "Today" : n == 1 ? "Tomorrow" : n < 7 ? Day.en("EEE", d) : Day.en("MMM d", d)
    let part: String? = switch h { case .bmo: "before school"; case .dmh: "school day"; case .amc: "after school"; case .none: nil }
    return part.map { "\(day) · \($0)" } ?? day
  }
  static func weatherSymbol(_ icon: String) -> String {
    switch icon { case "storm": "cloud.bolt.rain.fill"; case "cloud": "cloud.fill"; case "partly": "cloud.sun.fill"; default: "sun.max.fill" }
  }
}

/// The kid's pick as a calm chip (thumb symbols, not emoji).
struct PickChip: View {
  let pick: Pick
  var body: some View {
    Label(pick == .beat ? "Beat" : "Miss", systemImage: pick == .beat ? "hand.thumbsup.fill" : "hand.thumbsdown.fill")
      .font(.system(.caption, design: .rounded).weight(.bold))
      .padding(.horizontal, 8).padding(.vertical, 4)
      .background(Capsule().fill(pick == .beat ? Palette.mint : Palette.peach))
      .foregroundStyle(Palette.midnight)
      .accessibilityLabel("Your guess: \(pick.rawValue)")
  }
}

/// The report card's moment, as words or a live countdown.
struct WhenLine: View {
  let report: WidgetSnapshot.Report
  let entry: MoonEntry
  var compact = false
  var body: some View {
    switch ReportClock.phase(report, today: entry.today, now: entry.date) {
    case let .countdown(to: t):
      HStack(spacing: 4) {
        Image(systemName: "timer").imageScale(.small)
        Text(timerInterval: entry.date...t, countsDown: true).monospacedDigit()
      }
      .font(.system(compact ? .caption : .subheadline, design: .rounded).weight(.semibold))
      .foregroundStyle(Palette.wAccent)
      .accessibilityLabel("Report card comes out \(t.formatted(date: .omitted, time: .shortened))")
    case .resultsIn:
      Label("Results are in!", systemImage: "sparkles").font(.system(compact ? .caption : .subheadline, design: .rounded).weight(.bold)).foregroundStyle(Palette.goodInk)
    case .today, .later:
      Text(WFormat.shortWhen(report.d, report.h, today: entry.today))
        .font(compact ? .caption : .subheadline).foregroundStyle(Palette.ink2).lineLimit(1).minimumScaleFactor(0.8)
    }
  }
}

extension String { var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() } }
