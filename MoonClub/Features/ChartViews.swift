import SwiftUI
import MoonClubCore

/// One fast chart for every Market World game: candles (or a close line), optional volume bars, a
/// horizontal level, a trendline, a smooth line, a highlighted day and a "future" curtain. A single
/// Canvas draw — no view per candle — so it stays smooth while a finger drags a line over it.
struct CandleChart: View {
  var candles: [Candle]
  var line = false
  var volume = false
  var level: Double? = nil
  var levelColor: Color = Palette.accent
  var levelLabel: String? = nil
  var answerLevel: Double? = nil
  var trend: (Double, Double)? = nil
  var answerTrend: (Double, Double)? = nil
  var smooth: [[Double?]] = []
  var smoothColors: [Color] = []
  var highlight: Int? = nil
  var reveal: Int? = nil          // draw only the first `reveal` candles
  var cut: Int? = nil             // a dashed "today" line after this index
  var domain: ClosedRange<Double>? = nil

  static let up = CandleInk.up, down = CandleInk.down

  var range: ClosedRange<Double> {
    if let domain { return domain }
    let lo = candles.map(\.l).min() ?? 0, hi = candles.map(\.h).max() ?? 1
    let pad = max((hi - lo) * 0.08, 0.01)
    return (lo - pad)...(hi + pad)
  }

  var body: some View {
    Canvas { g, size in
      let n = max(candles.count, 1)
      let volH = volume ? size.height * 0.22 : 0
      let plot = CGRect(x: 0, y: 6, width: size.width, height: size.height - volH - 12)
      let r = range
      func y(_ p: Double) -> CGFloat { plot.maxY - CGFloat((p - r.lowerBound) / (r.upperBound - r.lowerBound)) * plot.height }
      let step = plot.width / CGFloat(n)
      func x(_ i: Int) -> CGFloat { plot.minX + step * (CGFloat(i) + 0.5) }
      let shown = min(reveal ?? n, n)

      // soft grid
      for k in 1...3 {
        let gy = plot.minY + plot.height * CGFloat(k) / 4
        g.stroke(Path { $0.move(to: .init(x: 0, y: gy)); $0.addLine(to: .init(x: size.width, y: gy)) }, with: .color(Palette.line.opacity(0.7)), style: .init(lineWidth: 0.5, dash: [3, 4]))
      }
      if let h = highlight, h < n {
        g.fill(Path(roundedRect: CGRect(x: x(h) - step / 2, y: 0, width: step, height: size.height), cornerRadius: 6), with: .color(Palette.accent.opacity(0.12)))
      }
      if line {
        var p = Path()
        for i in 0..<shown { let pt = CGPoint(x: x(i), y: y(candles[i].c)); i == 0 ? p.move(to: pt) : p.addLine(to: pt) }
        g.stroke(p, with: .color(Palette.ink), style: .init(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
      } else {
        let bw = max(2, min(step * 0.62, 22))
        for i in 0..<shown {
          let c = candles[i]
          CandleInk.draw(g, x: x(i), high: y(c.h), low: y(c.l), top: y(c.bodyTop), bottom: y(c.bodyBottom), width: bw, up: c.up)
        }
      }
      if volume {
        let vmax = candles.map(\.v).max() ?? 1
        for i in 0..<shown {
          let h = CGFloat(candles[i].v / max(vmax, 1)) * (volH - 4)
          let bw = max(2, step * 0.62)
          g.fill(Path(roundedRect: CGRect(x: x(i) - bw / 2, y: size.height - h, width: bw, height: h), cornerRadius: 2),
                 with: .color((i == highlight ? Palette.accent : Palette.ink2.opacity(0.35))))
        }
      }
      for (k, series) in smooth.enumerated() {
        var p = Path(); var started = false
        for (i, v) in series.enumerated() where i < shown { if let v { let pt = CGPoint(x: x(i), y: y(v)); started ? p.addLine(to: pt) : p.move(to: pt); started = true } }
        g.stroke(p, with: .color(k < smoothColors.count ? smoothColors[k] : Palette.accent), style: .init(lineWidth: 3, lineCap: .round, lineJoin: .round))
      }
      if let cut, cut < n - 1 {
        let cx = x(cut) + step / 2
        g.stroke(Path { $0.move(to: .init(x: cx, y: 0)); $0.addLine(to: .init(x: cx, y: size.height)) }, with: .color(Palette.ink2.opacity(0.6)), style: .init(lineWidth: 1.5, dash: [5, 5]))
      }
      if let (a, b) = answerTrend { g.stroke(Path { $0.move(to: .init(x: x(0), y: y(a))); $0.addLine(to: .init(x: x(n - 1), y: y(b))) }, with: .color(Hue.gold.color), style: .init(lineWidth: 4, lineCap: .round, dash: [8, 6])) }
      if let (a, b) = trend { g.stroke(Path { $0.move(to: .init(x: x(0), y: y(a))); $0.addLine(to: .init(x: x(n - 1), y: y(b))) }, with: .color(Palette.accent), style: .init(lineWidth: 4, lineCap: .round)) }
      if let al = answerLevel { g.stroke(Path { $0.move(to: .init(x: 0, y: y(al))); $0.addLine(to: .init(x: size.width, y: y(al))) }, with: .color(Hue.gold.color), style: .init(lineWidth: 4, lineCap: .round, dash: [8, 6])) }
      if let level {
        g.stroke(Path { $0.move(to: .init(x: 0, y: y(level))); $0.addLine(to: .init(x: size.width, y: y(level))) }, with: .color(levelColor), style: .init(lineWidth: 4, lineCap: .round))
        if let levelLabel {
          let t = g.resolve(Text(levelLabel).font(.caption.weight(.bold)).foregroundColor(.white))
          let ts = t.measure(in: size)
          let box = CGRect(x: size.width - ts.width - 18, y: y(level) - ts.height / 2 - 4, width: ts.width + 12, height: ts.height + 8)
          g.fill(Path(roundedRect: box, cornerRadius: box.height / 2), with: .color(levelColor))
          g.draw(t, at: CGPoint(x: box.midX, y: box.midY))
        }
      }
    }
    .accessibilityElement()
    .accessibilityLabel(accessibilitySummary)
  }

  private var accessibilitySummary: String {
    guard let f = candles.first, let l = candles.last else { return "Chart" }
    let t = ChartMath.trend(candles.map(\.c))
    return "Chart of \(candles.count) days, from \(coins(f.c)) to \(coins(l.c)). Trend: \(t.word)."
  }

  /// Price at a y position (for drags).
  static func price(atY yy: CGFloat, height: CGFloat, range r: ClosedRange<Double>, volume: Bool = false) -> Double {
    let volH = volume ? height * 0.22 : 0
    let plotH = height - volH - 12
    let t = Double((6 + plotH - yy) / plotH)
    return r.lowerBound + max(0, min(1, t)) * (r.upperBound - r.lowerBound)
  }
}

/// One big candle with labels, used by "Read the day" and "Build the candle".
struct BigCandle: View {
  var o: Double, h: Double, l: Double, c: Double
  var domain: ClosedRange<Double>
  var labels = true
  var body: some View {
    Canvas { g, size in
      func y(_ p: Double) -> CGFloat { size.height - 10 - CGFloat((p - domain.lowerBound) / (domain.upperBound - domain.lowerBound)) * (size.height - 20) }
      let cx = size.width * 0.38, bw: CGFloat = min(70, size.width * 0.26)
      CandleInk.draw(g, x: cx, high: y(h), low: y(l), top: y(max(o, c)), bottom: y(min(o, c)), width: bw, up: c >= o, big: true)
      guard labels else { return }
      // Labels never overlap: equal prices share one label ("Start and end"), and close ones are pushed apart.
      let rows = BigCandle.labels(o: o, h: h, l: l, c: c).map { (text: $0.text, y: y($0.price)) }
      let lineH = g.resolve(Text("Hg").font(.subheadline.weight(.semibold))).measure(in: size).height + 2
      for (text, yy) in zip(rows.map(\.text), BigCandle.spread(rows.map(\.y), gap: lineH, in: 0...size.height)) {
        let t = g.resolve(Text(text).font(.subheadline.weight(.semibold)).foregroundColor(Palette.ink2))
        g.draw(t, at: CGPoint(x: cx + bw / 2 + 16, y: yy), anchor: .leading)
      }
    }
    .accessibilityElement()
    .accessibilityLabel("A \(c >= o ? "hollow green, up" : "filled red, down") candle. Started at \(coins(o)), ended at \(coins(c)), highest \(coins(h)), lowest \(coins(l)).")
  }
}

extension BigCandle {
  /// Label rows top to bottom. Prices that round to the same cent share one row, so "Start" and "Low" (or
  /// "Start" and "End" on a flat day) never print on top of each other.
  static func labels(o: Double, h: Double, l: Double, c: Double) -> [(text: String, price: Double)] {
    let rows: [(String, Double)] = [("High", h), (c >= o ? "End" : "Start", max(o, c)), (c >= o ? "Start" : "End", min(o, c)), ("Low", l)]
    var out: [(text: String, price: Double)] = []
    for (name, v) in rows {
      if let last = out.last, coins(last.price) == coins(v) {
        out[out.count - 1].text = last.text.replacingOccurrences(of: " \(coins(v))", with: "") + " and \(name.lowercased()) \(coins(v))"
      } else { out.append((text: "\(name) \(coins(v))", price: v)) }
    }
    return out
  }
  /// Pushes label centers (top to bottom) apart so neighbours are at least `gap` apart, kept inside `bounds`.
  static func spread(_ ys: [CGFloat], gap: CGFloat, in bounds: ClosedRange<CGFloat>) -> [CGFloat] {
    var r = ys
    for i in r.indices.dropFirst() where r[i] - r[i - 1] < gap { r[i] = r[i - 1] + gap }
    if let last = r.last, last > bounds.upperBound - gap / 2 {
      let shift = last - (bounds.upperBound - gap / 2)
      r = r.map { $0 - shift }
      for i in r.indices.reversed().dropFirst() where r[i + 1] - r[i] < gap { r[i] = r[i + 1] - gap }
    }
    return r
  }
}

/// How every candle is drawn, so direction never depends on colour alone (colour-blind safe):
///  • up (ended higher): a HOLLOW green body (outline only)
///  • down (ended lower): a FILLED red body
///  • big candles also carry an arrow inside the body; candles too thin to show a hollow body (< 5 pt)
///    get a tiny tick on the wick's end that points the way it went.
enum CandleInk {
  static let up = Color(hex: 0x1FA36A), down = Color(hex: 0xE0533F)
  static func draw(_ g: GraphicsContext, x: CGFloat, high: CGFloat, low: CGFloat, top: CGFloat, bottom: CGFloat, width bw: CGFloat, up isUp: Bool, big: Bool = false) {
    let col = isUp ? up : down
    let lw = big ? 5 : max(1, bw * 0.16)
    let h = max(bottom - top, big ? 4 : 1.5)
    let body = CGRect(x: x - bw / 2, y: top, width: bw, height: h)
    let radius = big ? 10 : min(3, bw * 0.2)
    if isUp {
      // The wick stops at the body, so the hollow stays empty.
      g.stroke(Path { $0.move(to: .init(x: x, y: high)); $0.addLine(to: .init(x: x, y: top)); $0.move(to: .init(x: x, y: body.maxY)); $0.addLine(to: .init(x: x, y: low)) }, with: .color(col), style: .init(lineWidth: lw, lineCap: .round))
      let stroke = big ? 5 : max(1, min(2, bw * 0.22))
      g.fill(Path(roundedRect: body, cornerRadius: radius), with: .color(col.opacity(0.14)))
      g.stroke(Path(roundedRect: body.insetBy(dx: stroke / 2, dy: min(stroke / 2, h / 2)), cornerRadius: max(0, radius - stroke / 2)), with: .color(col), lineWidth: stroke)
    } else {
      g.stroke(Path { $0.move(to: .init(x: x, y: high)); $0.addLine(to: .init(x: x, y: low)) }, with: .color(col), style: .init(lineWidth: lw, lineCap: .round))
      g.fill(Path(roundedRect: body, cornerRadius: radius), with: .color(col))
    }
    if big, h >= 28 {
      let a = min(bw * 0.42, h * 0.5)
      var p = Path()
      let cy = body.midY, s = a / 2
      if isUp { p.move(to: .init(x: x - s, y: cy + s * 0.5)); p.addLine(to: .init(x: x, y: cy - s * 0.6)); p.addLine(to: .init(x: x + s, y: cy + s * 0.5)) }
      else { p.move(to: .init(x: x - s, y: cy - s * 0.5)); p.addLine(to: .init(x: x, y: cy + s * 0.6)); p.addLine(to: .init(x: x + s, y: cy - s * 0.5)) }
      g.stroke(p, with: .color(isUp ? col : .white), style: .init(lineWidth: max(3, a * 0.18), lineCap: .round, lineJoin: .round))
    } else if bw < 5 {
      // Thin candles: a 2-pt tick at the end of the move (top for up, bottom for down).
      let t: CGFloat = 2.2
      let yy = isUp ? high - t - 0.5 : low + t + 0.5
      var p = Path()
      if isUp { p.move(to: .init(x: x - t, y: yy + t)); p.addLine(to: .init(x: x, y: yy)); p.addLine(to: .init(x: x + t, y: yy + t)) }
      else { p.move(to: .init(x: x - t, y: yy - t)); p.addLine(to: .init(x: x, y: yy)); p.addLine(to: .init(x: x + t, y: yy - t)) }
      g.stroke(p, with: .color(col), style: .init(lineWidth: 1, lineCap: .round, lineJoin: .round))
    }
  }
}
