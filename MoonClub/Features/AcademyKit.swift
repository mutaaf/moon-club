import SwiftUI
import MoonClubCore

// Chart Academy's kit: one chart (`LabChart`) drawn from MoonClubCore `PlotMap`, the same map every
// finger goes through (`LabCanvas`), so what you see is exactly what's graded on every screen. Drag
// handles with a magnet, the iPhone Duo hinge as a knob, and a stage that uses the room it gets:
// stacked on a phone and the closed Duo, side by side on the open Duo or iPad held wide, chart over
// game pad in tabletop.

struct LabStroke {
  var line: ChartLine
  var color: Color
  var dashed = false
  var width: CGFloat = 4
  /// Draw only between these days (nil = the whole chart).
  var from: Double? = nil
  var to: Double? = nil
  /// A faint extension past the ends, so a short line reads as a line.
  var extend = false
}

struct LabLevel {
  var price: Double
  var color: Color
  var dashed = false
  var label: String? = nil
  var band: Double = 0   // a soft zone of ± this much price
}

struct LabSeries {
  var values: [Double?]
  var color: Color
  var dashed = false
}

/// One chart for every Academy drill: a single Canvas (no view per candle).
struct LabChart: View {
  var candles: [Candle]
  var range: ClosedRange<Double>? = nil
  var volume = false
  var reveal: Int? = nil
  /// Columns that glow (the pattern, the answer).
  var glow: [(ClosedRange<Int>, Color)] = []
  var dimOutside: ClosedRange<Int>? = nil
  var strokes: [LabStroke] = []
  var levels: [LabLevel] = []
  var series: [LabSeries] = []
  /// Hide every day after this one behind a curtain ("what might happen?").
  var curtain: Int? = nil
  /// A dot under a day (a tap's result).
  var dots: [(Int, Color)] = []
  var volumeGlow: Int? = nil

  var shownRange: ClosedRange<Double> { range ?? PlotMap.range(candles) }

  var body: some View {
    Canvas { g, size in
      let m = PlotMap(size: size, count: candles.count, range: shownRange, volume: volume)
      let n = candles.count
      let shown = min(reveal ?? n, n)
      for k in 1...3 {
        let gy = m.plot.minY + m.plot.height * CGFloat(k) / 4
        g.stroke(Path { $0.move(to: .init(x: 0, y: gy)); $0.addLine(to: .init(x: size.width, y: gy)) }, with: .color(Palette.line.opacity(0.7)), style: .init(lineWidth: 0.5, dash: [3, 4]))
      }
      for (r, col) in glow where r.lowerBound < n {
        let x0 = m.x(r.lowerBound) - m.step / 2, x1 = m.x(min(r.upperBound, n - 1)) + m.step / 2
        g.fill(Path(roundedRect: CGRect(x: x0, y: 0, width: x1 - x0, height: size.height), cornerRadius: 8), with: .color(col.opacity(0.16)))
        g.stroke(Path(roundedRect: CGRect(x: x0, y: 1, width: x1 - x0, height: size.height - 2), cornerRadius: 8), with: .color(col.opacity(0.7)), lineWidth: 2)
      }
      for lv in levels where lv.band > 0 {
        let y0 = m.y(lv.price + lv.band), y1 = m.y(lv.price - lv.band)
        g.fill(Path(CGRect(x: 0, y: y0, width: size.width, height: y1 - y0)), with: .color(lv.color.opacity(0.14)))
      }
      let bw = m.bodyWidth
      for i in 0..<shown {
        if let c = curtain, i > c { break }
        let k = candles[i]
        var gg = g
        if let d = dimOutside, !d.contains(i) { gg.opacity = 0.35 }
        CandleInk.draw(gg, x: m.x(i), high: m.y(k.h), low: m.y(k.l), top: m.y(k.bodyTop), bottom: m.y(k.bodyBottom), width: bw, up: k.up)
      }
      if volume {
        let vmax = candles.map(\.v).max() ?? 1
        let vh = m.volumeHeight - 6
        for i in 0..<shown {
          if let c = curtain, i > c { break }
          let h = CGFloat(candles[i].v / max(vmax, 1)) * vh
          let w = max(2, m.step * 0.62)
          let hot = i == volumeGlow
          g.fill(Path(roundedRect: CGRect(x: m.x(i) - w / 2, y: size.height - h, width: w, height: h), cornerRadius: 2),
                 with: .color(hot ? Palette.accent : (candles[i].up ? CandleInk.up : CandleInk.down).opacity(0.4)))
        }
      }
      for s in series {
        var p = Path(); var started = false
        for (i, v) in s.values.enumerated() where i < shown {
          if let c = curtain, i > c { break }
          if let v { let pt = m.point(day: Double(i), price: v); started ? p.addLine(to: pt) : p.move(to: pt); started = true }
        }
        g.stroke(p, with: .color(s.color), style: .init(lineWidth: 3.2, lineCap: .round, lineJoin: .round, dash: s.dashed ? [7, 5] : []))
      }
      for lv in levels {
        let y = m.y(lv.price)
        g.stroke(Path { $0.move(to: .init(x: 0, y: y)); $0.addLine(to: .init(x: size.width, y: y)) }, with: .color(lv.color), style: .init(lineWidth: 3.5, lineCap: .round, dash: lv.dashed ? [8, 6] : []))
        if let label = lv.label {
          let t = g.resolve(Text(label).font(.caption.weight(.bold)).foregroundColor(.white))
          let ts = t.measure(in: size)
          let box = CGRect(x: 6, y: y - ts.height / 2 - 4, width: ts.width + 12, height: ts.height + 8)
          g.fill(Path(roundedRect: box, cornerRadius: box.height / 2), with: .color(lv.color))
          g.draw(t, at: CGPoint(x: box.midX, y: box.midY))
        }
      }
      for s in strokes {
        let a = s.from ?? 0, b = s.to ?? Double(n - 1)
        if s.extend {
          g.stroke(Path { $0.move(to: m.point(day: 0, price: s.line.at(0))); $0.addLine(to: m.point(day: Double(n - 1), price: s.line.at(Double(n - 1)))) },
                   with: .color(s.color.opacity(0.3)), style: .init(lineWidth: max(2, s.width - 1.5), lineCap: .round, dash: [4, 6]))
        }
        g.stroke(Path { $0.move(to: m.point(day: a, price: s.line.at(a))); $0.addLine(to: m.point(day: b, price: s.line.at(b))) },
                 with: .color(s.color), style: .init(lineWidth: s.width, lineCap: .round, dash: s.dashed ? [9, 6] : []))
      }
      if let c = curtain, c < n - 1 {
        let x0 = m.x(c) + m.step / 2
        g.fill(Path(roundedRect: CGRect(x: x0, y: 0, width: size.width - x0, height: size.height), cornerRadius: 10), with: .color(Palette.accent.opacity(0.1)))
        g.stroke(Path { $0.move(to: .init(x: x0, y: 0)); $0.addLine(to: .init(x: x0, y: size.height)) }, with: .color(Palette.ink2.opacity(0.6)), style: .init(lineWidth: 1.5, dash: [5, 5]))
        let q = g.resolve(Text("?").font(.system(size: 34, weight: .heavy, design: .rounded)).foregroundColor(Palette.accent.opacity(0.6)))
        g.draw(q, at: CGPoint(x: (x0 + size.width) / 2, y: size.height / 2))
      }
      for (i, col) in dots where i < n {
        let r: CGFloat = 6
        g.fill(Path(ellipseIn: CGRect(x: m.x(i) - r, y: m.plot.maxY + 1, width: r * 2, height: r * 2).offsetBy(dx: 0, dy: volume ? -r * 2 - 2 : -r)), with: .color(col))
      }
    }
    .accessibilityElement()
    .accessibilityLabel(summary)
  }

  private var summary: String {
    guard let f = candles.first, let l = candles.last else { return "Chart" }
    return "Practice chart of \(candles.count) days, from \(coins(f.c)) to \(coins(l.c)). Trend: \(ChartMath.trend(candles.map(\.c)).word)."
  }
}

/// The chart plus everything a finger touches, all in one coordinate space: `content` gets the same
/// `PlotMap` the chart drew with.
struct LabCanvas<Overlay: View>: View {
  let candles: [Candle]
  var range: ClosedRange<Double>? = nil
  var volume = false
  var chart: LabChart
  @ViewBuilder var overlay: (PlotMap) -> Overlay
  var body: some View {
    GeometryReader { geo in
      let m = PlotMap(size: geo.size, count: candles.count, range: range ?? chart.shownRange, volume: volume)
      ZStack(alignment: .topLeading) {
        chart.frame(width: geo.size.width, height: geo.size.height)
        overlay(m)
      }
      .coordinateSpace(name: LabSpace.name)
    }
  }
}

enum LabSpace { static let name = "lab" }

/// A round's layout: prompt, chart and controls. Wide rooms (open Duo or iPad held landscape) put the chart
/// on the leading side and the prompt + controls beside it; tabletop puts the chart on the top half and the
/// controls on the bottom half (the game pad); everywhere else they stack, the chart taking what's left.
struct DrillStage<Prompt: View, Chart: View, Controls: View>: View {
  var caption: String? = nil
  @ViewBuilder var prompt: Prompt
  @ViewBuilder var chart: Chart
  @ViewBuilder var controls: Controls
  @State private var tabletop = false
  @Environment(DuoModel.self) private var duo: DuoModel?

  var body: some View {
    if duo?.pose == .tabletop {
      TabletopStage(active: $tabletop, dark: false) {
        VStack(spacing: 10) { prompt; ChartCard(caption: caption) { chart } }
      } bottom: { controls }
    } else {
      DrillLayout {
        VStack(alignment: .leading, spacing: 8) { prompt }
        ChartCard(caption: caption) { chart }
        VStack(spacing: 10) { controls }
      }
    }
  }
}

/// Stacks prompt / chart / controls (the chart takes the room that's left, at least `chartMin`), or puts
/// them side by side in a wide room. Measures honestly, so CardFitTests catches a screen that's too tall.
struct DrillLayout: Layout {
  var spacing: CGFloat = 12
  var chartMin: CGFloat = 170
  static func wide(_ w: CGFloat, _ h: CGFloat?) -> Bool { guard let h else { return false }; return w >= 640 && w > h * 1.05 }

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let w = proposal.width ?? 390
    if Self.wide(w, proposal.height), let h = proposal.height { return CGSize(width: w, height: h) }
    guard subviews.count == 3 else { return CGSize(width: w, height: proposal.height ?? 300) }
    let ph = subviews[0].sizeThatFits(ProposedViewSize(width: w, height: nil)).height
    let ch = subviews[2].sizeThatFits(ProposedViewSize(width: w, height: nil)).height
    let need = ph + chartMin + ch + spacing * 2
    return CGSize(width: w, height: max(need, proposal.height ?? need))
  }

  func placeSubviews(in b: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    guard subviews.count == 3 else { return }
    if Self.wide(b.width, b.height) {
      let cw = b.width * 0.62, rw = b.width - cw - 16
      subviews[1].place(at: b.origin, proposal: ProposedViewSize(width: cw, height: b.height))
      let ph = subviews[0].sizeThatFits(ProposedViewSize(width: rw, height: nil)).height
      subviews[0].place(at: CGPoint(x: b.minX + cw + 16, y: b.minY), proposal: ProposedViewSize(width: rw, height: ph))
      let ch = subviews[2].sizeThatFits(ProposedViewSize(width: rw, height: nil)).height
      subviews[2].place(at: CGPoint(x: b.minX + cw + 16, y: b.maxY - ch), proposal: ProposedViewSize(width: rw, height: ch))
    } else {
      let ph = subviews[0].sizeThatFits(ProposedViewSize(width: b.width, height: nil)).height
      let ch = subviews[2].sizeThatFits(ProposedViewSize(width: b.width, height: nil)).height
      subviews[0].place(at: b.origin, proposal: ProposedViewSize(width: b.width, height: ph))
      let chartH = max(chartMin, b.height - ph - ch - spacing * (ch > 0 ? 2 : 1))
      subviews[1].place(at: CGPoint(x: b.minX, y: b.minY + ph + spacing), proposal: ProposedViewSize(width: b.width, height: chartH))
      subviews[2].place(at: CGPoint(x: b.minX, y: b.maxY - ch), proposal: ProposedViewSize(width: b.width, height: ch))
    }
  }
}

/// A round handle you drag: a 30 pt dot inside a 60 pt touch target (fingers 8–12 aren't precise).
struct LabHandle: View {
  var color: Color = Palette.accent
  var selected = false
  var label: String? = nil
  var body: some View {
    ZStack {
      Circle().fill(color.opacity(0.18)).frame(width: 44, height: 44).opacity(selected ? 1 : 0)
      Circle().fill(color).frame(width: 28, height: 28)
        .overlay(Circle().stroke(.white, lineWidth: 3))
        .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
      if let label {
        Text(label).font(.caption2.weight(.heavy)).foregroundStyle(.white).padding(.horizontal, 7).padding(.vertical, 3)
          .background(color, in: Capsule()).offset(y: -30).fixedSize()
      }
    }
    .frame(width: 60, height: 60)
    .contentShape(Circle())
  }
}

/// Finds a wick tip within the magnet radius (points) of a finger, for snapping.
enum LabSnap {
  static func tip(near p: CGPoint, candles: [Candle], map m: PlotMap, lows: Bool, radius: CGFloat) -> (day: Int, price: Double)? {
    guard radius > 0 else { return nil }
    var best: (Int, Double, CGFloat)?
    for (i, k) in candles.enumerated() {
      let price = lows ? k.l : k.h
      let d = hypot(m.x(i) - p.x, m.y(price) - p.y)
      if d <= radius, d < (best?.2 ?? .infinity) { best = (i, price, d) }
    }
    return best.map { ($0.0, $0.1) }
  }
}

/// iPhone Duo: while the phone is partly open, the hinge is a knob (30°…170° sweeps 0…1).
struct HingeKnob: ViewModifier {
  var enabled: Bool
  var onTurn: (Double) -> Void
  @Environment(DuoModel.self) private var duo: DuoModel?
  @Environment(AppModel.self) private var app
  @State private var used = false
  var live: Bool { enabled && duo?.reading?.status == .partiallyOpen }
  func body(content: Content) -> some View {
    content
      .onChange(of: duo?.reading?.degrees) { _, deg in
        guard live, let deg else { return }
        onTurn(HingeDial.fraction(deg))
        if !used { used = true; app.mutate { $0.useDuo(.hinge) } }
      }
  }
}

extension View {
  func hingeKnob(_ enabled: Bool = true, onTurn: @escaping (Double) -> Void) -> some View { modifier(HingeKnob(enabled: enabled, onTurn: onTurn)) }
}

/// Shows the hinge tip only while the hinge is a live control.
struct HingeTip: View {
  let text: String
  @Environment(DuoModel.self) private var duo: DuoModel?
  var body: some View {
    if duo?.reading?.status == .partiallyOpen {
      DuoCallout(text: text, symbol: "rectangle.portrait.on.rectangle.portrait.angled.fill").transition(.scale.combined(with: .opacity))
    }
  }
}

/// Luna's tip for the worked-example levels (scaffold 2 shows it; 1 hides it behind a button).
struct LabTip: View {
  let text: String
  let scaffold: Int
  var answered: Bool
  @State private var open = false
  var body: some View {
    if scaffold >= 2 || open {
      Label { Text(text).font(.callout.weight(.semibold)) } icon: { Image(systemName: "lightbulb.fill").foregroundStyle(Hue.gold.color) }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Hue.gold.color.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .transition(.opacity)
    } else if scaffold == 1 && !answered {
      Button { withAnimation(Motion.tap) { open = true } } label: {
        Label("Show me a tip", systemImage: "lightbulb").font(.callout.weight(.bold))
      }
      .buttonStyle(.bordered).tint(Hue.gold.color)
    }
  }
}

/// A small candle picture (cards and choices): one candle, or a few.
struct MiniCandles: View {
  let candles: [Candle]
  var range: ClosedRange<Double>? = nil
  /// A whole-dollar grid with labels every $2 (Story to candle reads prices off it).
  var grid = false
  var body: some View {
    Canvas { g, size in
      let m = PlotMap(size: size, count: candles.count, range: range ?? PlotMap.range(candles))
      if grid {
        for k in stride(from: Int(m.lo.rounded(.up)), through: Int(m.hi), by: 2) {
          let y = m.y(Double(k))
          g.stroke(Path { $0.move(to: .init(x: 22, y: y)); $0.addLine(to: .init(x: size.width, y: y)) }, with: .color(Palette.line), style: .init(lineWidth: 0.7, dash: [3, 3]))
          g.draw(g.resolve(Text("$\(k)").font(.system(size: 10, weight: .semibold).monospacedDigit()).foregroundColor(Palette.ink2)), at: CGPoint(x: 10, y: y))
        }
      }
      for (i, k) in candles.enumerated() {
        CandleInk.draw(g, x: m.x(i), high: m.y(k.h), low: m.y(k.l), top: m.y(k.bodyTop), bottom: m.y(k.bodyBottom), width: min(m.step * 0.62, 34), up: k.up, big: candles.count == 1 && size.height > 120)
      }
    }
    .accessibilityHidden(true)
  }
}

/// A picture card you tap (odd one out, story to candle).
struct PictureChoice<C: View>: View {
  let index: Int
  var state: AnswerState = .idle
  let action: () -> Void
  @ViewBuilder var content: C
  var body: some View {
    Button(action: action) {
      content
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(border, lineWidth: state == .idle ? 1 : 3.5))
        .overlay(alignment: .topTrailing) {
          if state == .right || state == .wrong {
            Image(systemName: state == .right ? "checkmark.circle.fill" : "xmark.circle.fill").font(.title3)
              .foregroundStyle(state == .right ? Palette.good : Palette.bad).padding(6)
          }
        }
        .opacity(state == .dim ? 0.5 : 1)
    }
    .buttonStyle(PressStyle())
  }
  private var border: Color {
    switch state { case .right: return Palette.good; case .wrong: return Palette.bad; default: return Palette.line }
  }
}

func answerState(_ i: Int, correct: Int, picked: Int?, answered: Bool) -> AnswerState {
  guard answered else { return .idle }
  if i == correct { return .right }
  if i == picked { return .wrong }
  return .dim
}
