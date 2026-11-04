// "Why did it move?" — port of metaphases shared/kidsWhy.ts (pinned by the `why`, `whyBuild` and
// `reportResult` vectors). Given a kid company's day or week move plus context we already have (its report
// card, the whole market, its group, a dividend cut-off day, its normal move size), it ranks honest CLUES.
// It never invents news; a big move the numbers don't explain gets "We're not sure". Reviewed by both
// curriculum experts (docs/CURRICULUM.md). The Piggy points-investing work reuses this module.
import Foundation

public enum WhyRange: String, Codable, Sendable, CaseIterable { case day = "1d", week = "5d" }

public struct WhyInput: Codable, Hashable, Sendable {
  public struct Sector: Codable, Hashable, Sendable { public let etf: String; public let name: String; public let move: Double?
    public init(etf: String, name: String, move: Double?) { self.etf = etf; self.name = name; self.move = move } }
  public struct ReportIn: Codable, Hashable, Sendable { public let date: String; public let eA: Double?; public let eE: Double?
    public init(date: String, eA: Double?, eE: Double?) { self.date = date; self.eA = eA; self.eE = eE } }
  public struct Dividend: Codable, Hashable, Sendable { public let date: String; public let amount: Double; public let pct: Double?
    public init(date: String, amount: Double, pct: Double?) { self.date = date; self.amount = amount; self.pct = pct } }
  public let s: String; public let nick: String; public let range: WhyRange
  public let move: Double?; public let market: Double?; public let sector: Sector?
  public let report: ReportIn?; public let dividend: Dividend?; public let normal: Double?; public let asOf: String?
  public init(s: String, nick: String, range: WhyRange, move: Double?, market: Double?, sector: Sector?, report: ReportIn?, dividend: Dividend?, normal: Double?, asOf: String?) {
    self.s = s; self.nick = nick; self.range = range; self.move = move; self.market = market; self.sector = sector; self.report = report; self.dividend = dividend; self.normal = normal; self.asOf = asOf
  }
}

/// `learn`: the Moon School lesson that teaches this clue (shown as "Learn it" when the lesson exists).
public struct WhyCause: Codable, Hashable, Sendable, Identifiable { public let id: String; public let title: String; public let line: String; public let weight: Double; public var learn: String? = nil }
public struct WhyResult: Codable, Hashable, Sendable {
  public let dir: String; public let headline: String; public let size: String; public let sizeLine: String; public let causes: [WhyCause]; public let honest: String
}

public enum Why {
  public static let groups: [String: (etf: String, name: String)] = [
    "tech": ("RSPT", "the tech companies"),
    "media": ("RSPC", "the TV, games and internet companies"),
    "wants": ("RSPD", "the companies that sell things people want, like shoes, toys and treats"),
    "needs": ("RSPS", "the companies that sell things people need, like food and soap"),
  ]
  public static let sectorOf: [String: String] = [
    "AAPL": "tech", "MSFT": "tech",
    "DIS": "media", "RBLX": "media", "NFLX": "media", "GOOGL": "media", "TTWO": "media", "SPOT": "media",
    "MCD": "wants", "NKE": "wants", "SONY": "wants", "HAS": "wants", "AMZN": "wants", "SBUX": "wants", "CMG": "wants", "TSLA": "wants",
    "KO": "needs", "PEP": "needs", "WMT": "needs", "TGT": "needs", "HSY": "needs",
  ]
  public static func group(_ s: String) -> (etf: String, name: String)? { sectorOf[s].flatMap { groups[$0] } }
  static let defaultNormal: [WhyRange: Double] = [.day: 1.5, .week: 3.5]
  static let minClue: [WhyRange: Double] = [.day: 0.4, .week: 0.8]
  public static let honest = "These are clues from the numbers, not the whole story. Nobody knows for sure what comes next."
  /// Each clue → the Core lesson that teaches it (the web's WHY_LEARN; "report" depends on the result).
  public static let learn: [String: String] = ["report": "after", "market": "why-market", "company": "prices", "sector": "why-group", "dividend": "div-day", "wiggle": "why-wiggle", "unknown": "why-unsure"]
  static let order = ["report", "market", "company", "sector", "dividend", "wiggle", "unknown"]

  public enum Result: String, Sendable { case beat, inline, miss }
  /// Beat / in line / miss with a 1% tolerance (an exact match is not a beat).
  public static func reportResult(eA: Double, eE: Double) -> Result {
    let d = eA - eE, tol = max(0.005, abs(eE) * 0.01)
    return abs(d) < tol ? .inline : d > 0 ? .beat : .miss
  }

  /// JS Math.round semantics (half rounds up, also for negatives), so numbers match the web exactly.
  static func r2(_ v: Double) -> Double { (v * 100 + 0.5).rounded(.down) / 100 }
  static func fixed1(_ v: Double) -> String { toFixed(v, 1) }

  /// "today", "on Friday" or "over the past week": always true.
  public static func when(_ range: WhyRange, asOf: String?, today: String?) -> String {
    if range == .week { return "over the past week" }
    guard let asOf, asOf != today else { return "today" }
    return "on \(Day.en("EEEE", asOf))"
  }

  public static func explain(_ x: WhyInput, today: String? = nil) -> WhyResult {
    let w = when(x.range, asOf: x.asOf, today: today)
    let unknown = WhyCause(id: "unknown", title: "We're not sure", line: "Sometimes prices move for reasons we can't see yet.", weight: 0.5, learn: learn["unknown"])
    guard let m = x.move else {
      return WhyResult(dir: "none", headline: "We don't have \(x.nick)'s price yet.", size: "unknown", sizeLine: "", causes: [unknown], honest: honest)
    }
    let am = abs(m)
    let dir = am < 0.05 ? "flat" : m > 0 ? "up" : "down"
    let opp = dir == "up" ? "down" : "up"
    let normal = max(0.1, x.normal ?? defaultNormal[x.range]!)
    let ratio = am / normal
    let size = ratio < 0.5 ? "tiny" : ratio < 1.5 ? "normal" : ratio < 3 ? "big" : "huge"
    let headline = dir == "flat" ? "\(x.nick) barely moved \(w)." : "\(x.nick) went \(dir) \(fixed1(am))% \(w)."
    let sizeLine = ["tiny": "That's smaller than its usual wiggle.", "normal": "That's about its usual size of move.", "big": "That's bigger than its usual move.", "huge": "That's a lot bigger than its usual move."][size]!
    let floor = minClue[x.range]!
    func big(_ v: Double?) -> Bool { v.map { abs($0) >= floor } ?? false }
    func sign(_ v: Double) -> Double { v > 0 ? 1 : v < 0 ? -1 : 0 }
    func sameWay(_ v: Double?) -> Bool { guard let v, dir != "flat", big(v) else { return false }; return sign(v) == sign(m) }
    func otherWay(_ v: Double?) -> Bool { guard let v, dir != "flat", big(v) else { return false }; return sign(v) == -sign(m) }

    var causes: [WhyCause] = []
    if let r = x.report {
      let res = (r.eA != nil && r.eE != nil) ? reportResult(eA: r.eA!, eE: r.eE!) : nil
      let line: String
      if r.eA == nil || res == nil { line = "It shared its report card, so people had lots of new facts." }
      else if dir == "flat" { line = "It shared its report card, but the price barely moved." }
      else if res == .inline { line = "It matched what grown-ups guessed. Hopes and what comes next may have mattered most." }
      else if res == .beat && dir == "up" { line = "It beat what grown-ups guessed, and people may have liked the news." }
      else if res == .beat { line = "It beat what grown-ups guessed, but people may have hoped for even more." }
      else if dir == "down" { line = "It missed what grown-ups guessed, and people may have been let down." }
      else { line = "It missed what grown-ups guessed, but people may have feared even worse." }
      // The lesson for this kind of report day: a surprise the price "disagreed" with is about expectations.
      let lesson = res == nil ? "report-card" : dir == "flat" ? "after" : res == .inline ? "guidance" : (res == .beat) == (dir == "up") ? "after" : "expectations"
      causes.append(WhyCause(id: "report", title: "Report card day", line: line, weight: size == "big" || size == "huge" ? 0.9 : 0.6, learn: lesson))
    }
    if sameWay(x.market), let mk = x.market {
      let share = abs(mk) / am
      causes.append(WhyCause(id: "market", title: "The whole market moved",
        line: share < 0.5 ? "The whole market went \(dir) a little \(w) too, but not nearly this much." : "The whole market went \(dir) \(w) too. On days like that, most companies move the same way.",
        weight: r2(0.3 + 0.6 * min(1, share)), learn: learn["market"]))
    } else if otherWay(x.market) {
      causes.append(WhyCause(id: "company", title: "Not the whole market", line: "The whole market went \(opp) \(w). So this move was probably about \(x.nick) itself.", weight: 0.5, learn: learn["company"]))
    }
    if let sec = x.sector, sameWay(sec.move), let sm = sec.move {
      let excess = abs(sm) - (sameWay(x.market) ? abs(x.market ?? 0) : 0)
      if excess >= 0.3 {
        causes.append(WhyCause(id: "sector", title: "Its group moved together", line: "Its group went \(dir) \(w) too. That group is \(sec.name).", weight: r2(0.25 + 0.6 * min(1, excess / am)), learn: learn["sector"]))
      }
    }
    if let d = x.dividend, dir == "down" {
      let share = d.pct.map { min(1, $0 / am) } ?? 0.3
      let day = x.range == .day ? w : "in the past week"
      causes.append(WhyCause(id: "dividend", title: "Dividend cut-off day",
        line: "Its dividend cut-off day was \(day). The price often drops by about the payout\(d.pct.map { ", here about \(fixed1($0))% of the price" } ?? "").",
        weight: r2(0.3 + 0.6 * share), learn: learn["dividend"]))
    }
    if (size == "tiny" || size == "normal") && !causes.contains(where: { $0.id == "report" }) {
      causes.append(WhyCause(id: "wiggle", title: "A normal wiggle", line: "Prices move a little every day, even with no news.", weight: size == "tiny" ? 0.8 : 0.5, learn: learn["wiggle"]))
    }
    let best = causes.map(\.weight).max() ?? 0
    if causes.isEmpty || ((size == "big" || size == "huge") && best < 0.6) { causes.append(unknown) }
    let sorted = causes.enumerated().sorted { a, b in
      a.element.weight != b.element.weight ? a.element.weight > b.element.weight : (order.firstIndex(of: a.element.id) ?? 9, a.offset) < (order.firstIndex(of: b.element.id) ?? 9, b.offset)
    }.map(\.element)
    return WhyResult(dir: dir, headline: headline, size: size, sizeLine: sizeLine, causes: Array(sorted.prefix(3)), honest: honest)
  }

  // MARK: Building the input from daily closes (raw closes, never adjusted)
  public struct Series: Codable, Hashable, Sendable { public let d: [String]; public let c: [Double]
    public init(d: [String], c: [Double]) { self.d = d; self.c = c } }
  public struct ReportRow: Codable, Hashable, Sendable { public let date: String; public let eA: Double?; public let eE: Double?; public let hour: String?
    public init(date: String, eA: Double?, eE: Double?, hour: String? = nil) { self.date = date; self.eA = eA; self.eE = eE; self.hour = hour } }
  public struct DividendRow: Codable, Hashable, Sendable { public let date: String; public let amount: Double
    public init(date: String, amount: Double) { self.date = date; self.amount = amount } }

  static func change(_ s: Series?, from: String, to: String) -> Double? {
    guard let s, let i = s.d.firstIndex(of: from), let j = s.d.firstIndex(of: to), j > i, s.c[i] > 0 else { return nil }
    return r2((s.c[j] - s.c[i]) / s.c[i] * 100)
  }
  public static func normalMove(_ s: Series?, k: Int) -> Double? {
    guard let s, s.c.count >= k + 10 else { return nil }
    var sum = 0.0, n = 0
    for i in k..<s.c.count { let a = s.c[i - k]; if a > 0 { sum += abs((s.c[i] - a) / a) * 100; n += 1 } }
    return n > 0 ? r2(sum / Double(n)) : nil
  }
  /// A report counts when its first trading reaction lands in (from, last]. Unknown hour stays conservative.
  public static func reportInWindow(date: String, hour: String, from: String, last: String) -> Bool {
    if date > from && date <= last { return !(date == last && hour == "amc") }
    return date == from && hour != "bmo" && hour != "dmh"
  }
  public static func buildInput(s: String, nick: String, range: WhyRange, stock: Series?, spy: Series?, sector: Series?, reports: [ReportRow], dividends: [DividendRow]) -> WhyInput {
    let k = range == .day ? 1 : 5
    let n = stock?.d.count ?? 0
    let from = n > k ? stock?.d[n - 1 - k] : nil
    let last = n > 0 ? stock?.d[n - 1] : nil
    var report: ReportRow?, div: DividendRow?
    if let from, let last {
      report = reports.filter { reportInWindow(date: $0.date, hour: $0.hour ?? "", from: from, last: last) }.sorted { $0.date > $1.date }.first
      div = dividends.filter { $0.date > from && $0.date <= last }.sorted { $0.date > $1.date }.first
    }
    var prev: Double?
    if let div, let st = stock, let di = st.d.firstIndex(of: div.date), di > 0 { prev = st.c[di - 1] }
    let g = group(s)
    func ch(_ x: Series?) -> Double? { guard let from, let last else { return nil }; return change(x, from: from, to: last) }
    return WhyInput(s: s, nick: nick, range: range, move: ch(stock), market: ch(spy),
                    sector: g.map { WhyInput.Sector(etf: $0.etf, name: $0.name, move: ch(sector)) },
                    report: report.map { WhyInput.ReportIn(date: $0.date, eA: $0.eA, eE: $0.eE) },
                    dividend: div.map { d in WhyInput.Dividend(date: d.date, amount: d.amount, pct: prev.map { r2(d.amount / $0 * 100) }) },
                    normal: normalMove(stock, k: k), asOf: last)
  }

  /// What the worker's /api/kids/why returns (the app re-runs `explain` on `input` with its own copy).
  public struct Payload: Codable, Sendable { public let input: WhyInput; public let warnings: [String]? }
  public static func request(_ s: String, range: WhyRange, base: URL = apiBase) -> URLRequest {
    var c = URLComponents(url: base.appendingPathComponent("api/kids/why"), resolvingAgainstBaseURL: false)!
    c.queryItems = [URLQueryItem(name: "s", value: s), URLQueryItem(name: "range", value: range.rawValue)]
    return URLRequest(url: c.url!)
  }
}
