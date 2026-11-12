// One mapping between chart data (day index, price) and points on screen, used by BOTH the drawing and
// the finger. Every drag game grades in data space (days and prices), never in points, so a line that
// passes on an iPhone SE passes on an iPad or the open iPhone Duo too: "pixel correct" on every screen.
import CoreGraphics
import Foundation

public struct PlotMap: Equatable, Sendable {
  public let size: CGSize
  public let count: Int
  public let lo: Double
  public let hi: Double
  /// The candle area (volume bars, when shown, sit under it).
  public let plot: CGRect
  /// The volume band's height (0 without volume).
  public let volumeHeight: CGFloat

  public static let topInset: CGFloat = 6
  public static let bottomInset: CGFloat = 6
  public static let volumeShare: CGFloat = 0.22

  /// `range` is the price span to show; nil pads the data's own span by 8% (as `CandleChart` always has).
  public init(size: CGSize, count: Int, range: ClosedRange<Double>, volume: Bool = false, trailing: CGFloat = 0) {
    self.size = size
    self.count = max(count, 1)
    lo = range.lowerBound
    hi = range.upperBound > range.lowerBound ? range.upperBound : range.lowerBound + 1
    volumeHeight = volume ? size.height * Self.volumeShare : 0
    plot = CGRect(x: 0, y: Self.topInset, width: max(1, size.width - trailing),
                  height: max(1, size.height - volumeHeight - Self.topInset - Self.bottomInset - 0))
  }

  /// The padded span `CandleChart` shows for a set of candles.
  public static func range(_ candles: [Candle], extra: [Double] = [], pad: Double = 0.08) -> ClosedRange<Double> {
    let lows = candles.map(\.l) + extra, highs = candles.map(\.h) + extra
    let lo = lows.min() ?? 0, hi = highs.max() ?? 1
    let p = max((hi - lo) * pad, 0.01)
    return (lo - p)...(hi + p)
  }

  public var span: Double { hi - lo }
  /// Width of one day's column.
  public var step: CGFloat { plot.width / CGFloat(count) }
  /// A candle body's width in this column (2…22 pt, as drawn).
  public var bodyWidth: CGFloat { max(2, min(step * 0.62, 22)) }

  /// The x of day `i`'s center. Fractional days are allowed (lines between days).
  public func x(_ i: Double) -> CGFloat { plot.minX + step * (CGFloat(i) + 0.5) }
  public func x(_ i: Int) -> CGFloat { x(Double(i)) }
  public func y(_ p: Double) -> CGFloat { plot.maxY - CGFloat((p - lo) / span) * plot.height }
  public func point(day i: Double, price p: Double) -> CGPoint { CGPoint(x: x(i), y: y(p)) }

  /// The (fractional) day under an x, clamped to the chart.
  public func day(atX xx: CGFloat) -> Double {
    let d = Double((xx - plot.minX) / step - 0.5)
    return max(0, min(Double(count - 1), d))
  }
  /// The nearest whole day under an x.
  public func index(atX xx: CGFloat) -> Int { Int(day(atX: xx).rounded()) }
  /// The price at a y, clamped to the shown range.
  public func price(atY yy: CGFloat) -> Double {
    let t = Double((plot.maxY - yy) / plot.height)
    return lo + max(0, min(1, t)) * span
  }

  /// How many points one unit of price is tall (for tolerances shown on screen).
  public var pointsPerPrice: CGFloat { plot.height / CGFloat(span) }

  /// Rounds a y to the screen's pixel grid (so a 1-px line lands on one row of pixels).
  public static func pixel(_ v: CGFloat, scale: CGFloat) -> CGFloat { (v * scale).rounded() / scale }
}
