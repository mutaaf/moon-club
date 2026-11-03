// Luna's coaching for Guess the Report Card and the Pretend Piggy Bank. A port of metaphases
// shared/kidsCoach.ts (pinned by the `coach` vectors). The words come from the pack's courses, so a new pack
// can re-voice them. The Piggy points-investing work builds on `Coach.piggyTip` and `Why.explain`.
import Foundation

public enum Coach {
  public struct Next: Hashable, Sendable { public let id: String; public let index: Int; public let of: Int }
  /// The next lesson on a course ladder the kid hasn't finished (nil when the course is done).
  public static func next(_ ladder: [String], done: [String]) -> Next? {
    guard let i = ladder.firstIndex(where: { !done.contains($0) }) else { return nil }
    return Next(id: ladder[i], index: i, of: ladder.count)
  }

  /// What a revealed report card + price move means (hedged; in line is not a beat).
  public static func reveal(_ c: GuessCourse, eA: Double?, eE: Double?, move: Double?) -> String {
    guard let eA, let eE, let move else { return c.reveal.unknown }
    switch Why.reportResult(eA: eA, eE: eE) {
    case .inline: return c.reveal.inLine
    case .beat: return move >= 0 ? c.reveal.beatUp : c.reveal.beatDown
    case .miss: return move >= 0 ? c.reveal.missUp : c.reveal.missDown
    }
  }

  public struct PiggyIn: Hashable, Sendable {
    public let holdings: Int; public let started: String; public let today: String; public let value: Double; public let start: Double; public let peeks: Int
    public init(holdings: Int, started: String, today: String, value: Double, start: Double, peeks: Int) { self.holdings = holdings; self.started = started; self.today = today; self.value = value; self.start = start; self.peeks = peeks }
  }
  /// The one tip the piggy bank shows. Order: too many peeks → a big move → one basket → brand new → old → baskets.
  public static func piggyTip(_ c: PiggyCourse, _ x: PiggyIn) -> (key: String, text: String) {
    let age = max(0, Day.between(x.started, x.today))
    let chg = x.start > 0 ? (x.value - x.start) / x.start * 100 : 0
    let key =
      x.peeks > c.peekLimit ? "peekMany" :
      chg <= -10 ? "bigDrop" :
      chg >= 10 ? "bigRise" :
      x.holdings <= 1 ? "oneBasket" :
      age < 7 ? "newBank" :
      age >= 30 ? "longTime" :
      x.holdings >= 5 ? "manyBaskets" : "fewBaskets"
    let vars = ["n": String(key == "peekMany" ? x.peeks : x.holdings), "days": String(age), "pct": toFixed(abs(chg), 0)]
    var t = c.tips[key] ?? ""
    for (k, v) in vars { t = t.replacingOccurrences(of: "{\(k)}", with: v) }
    return (key, t)
  }
}
