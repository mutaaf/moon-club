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

  /// Which reveal a report card + price move gets (in line is not a beat). Port of the web's guessRevealKey.
  public static func revealKey(eA: Double?, eE: Double?, move: Double?) -> String {
    guard let eA, let eE, let move else { return "unknown" }
    switch Why.reportResult(eA: eA, eE: eE) {
    case .inline: return "inLine"
    case .beat: return move >= 0 ? "beatUp" : "beatDown"
    case .miss: return move >= 0 ? "missUp" : "missDown"
    }
  }
  /// What a revealed report card + price move means (hedged; in line is not a beat).
  public static func reveal(_ c: GuessCourse, eA: Double?, eE: Double?, move: Double?) -> String {
    let r = c.reveal
    switch revealKey(eA: eA, eE: eE, move: move) {
    case "inLine": return r.inLine
    case "beatUp": return r.beatUp
    case "beatDown": return r.beatDown
    case "missUp": return r.missUp
    case "missDown": return r.missDown
    default: return r.unknown
    }
  }
  /// The lesson that explains this reveal (e.g. a beat that dropped → "Why a beat can still drop"), if the pack names one.
  public static func learn(_ c: GuessCourse, eA: Double?, eE: Double?, move: Double?) -> String? { c.learn?[revealKey(eA: eA, eE: eE, move: move)] }

  public struct PiggyIn: Hashable, Sendable {
    public let holdings: Int; public let started: String; public let today: String; public let value: Double; public let start: Double; public let peeks: Int
    /// How many different groups (sectors) the companies are in; nil when unknown.
    public let groups: Int?
    public init(holdings: Int, started: String, today: String, value: Double, start: Double, peeks: Int, groups: Int? = nil) { self.holdings = holdings; self.started = started; self.today = today; self.value = value; self.start = start; self.peeks = peeks; self.groups = groups }
  }
  /// How many groups these companies are in (nil if any company has no known group).
  public static func groups(_ symbols: [String]) -> Int? {
    let g = symbols.map { Why.sectorOf[$0] }
    return g.contains(nil) ? nil : Set(g.compactMap { $0 }).count
  }
  /// The one tip the piggy bank shows. Order: too many peeks → a big move → one basket → one group → brand new → old → baskets.
  public static func piggyTip(_ c: PiggyCourse, _ x: PiggyIn) -> (key: String, text: String) {
    let age = max(0, Day.between(x.started, x.today))
    let chg = x.start > 0 ? (x.value - x.start) / x.start * 100 : 0
    let key =
      x.peeks > c.peekLimit ? "peekMany" :
      chg <= -10 ? "bigDrop" :
      chg >= 10 ? "bigRise" :
      x.holdings <= 1 ? "oneBasket" :
      x.groups == 1 && c.tips["oneGroup"] != nil ? "oneGroup" :
      age < 7 ? "newBank" :
      age >= 30 ? "longTime" :
      x.holdings >= 5 ? "manyBaskets" : "fewBaskets"
    let vars = ["n": String(key == "peekMany" ? x.peeks : x.holdings), "days": String(age), "pct": toFixed(abs(chg), 0)]
    var t = c.tips[key] ?? ""
    for (k, v) in vars { t = t.replacingOccurrences(of: "{\(k)}", with: v) }
    return (key, t)
  }
}
