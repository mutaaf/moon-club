// The numbers a `grow` lesson step draws (metaphases shared/kidsPacks.ts growSeries / growRows, pinned by the
// `grow` and `growSteps` vectors). Year 0…years, whole numbers, each rounded from the exact value (never from a
// rounded one). compound: growth on growth; simple: the same extra every year; jar: no growth. Pretend numbers.
import Foundation

public enum Growth {
  public enum Kind: String, Sendable { case compound, simple, jar }
  /// JS Math.round for the non-negative values we draw (half rounds up).
  static func round(_ v: Double) -> Int { Int((v + 0.5).rounded(.down)) }
  public static func series(start: Double, rate: Double, years: Int, kind: Kind = .compound) -> [Int] {
    let r = rate / 100
    return (0...max(0, years)).map { y in
      switch kind {
      case .jar: return round(start)
      case .simple: return round(start * (1 + r * Double(y)))
      case .compound: return round(start * pow(1 + r, Double(y)))
      }
    }
  }
  /// The main row and the faint comparison row (a jar, simple growth or another rate).
  public static func rows(_ g: Grow) -> (main: [Int], vs: [Int]?) {
    let main = series(start: g.start, rate: g.rate, years: g.years)
    guard let v = g.vs else { return (main, nil) }
    if v.kind == "rate" { return (main, series(start: g.start, rate: v.rate ?? 0, years: g.years)) }
    return (main, series(start: g.start, rate: g.rate, years: g.years, kind: Kind(rawValue: v.kind) ?? .jar))
  }
}
