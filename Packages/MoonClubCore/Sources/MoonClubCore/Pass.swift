// Moon Club Pass (0.20): what's free, what a short break opens, and what the yearly pass unlocks.
// Pure rules (no StoreKit, no clock): the app passes in today, whether the pass is on and the device ledger.
//
//  - Every climb (Candle Academy, Line Lab, Moon Tower) has a free run: its first chapter / floor, forever.
//  - Past it, each day opens `dailyFree` new levels. A level you already opened today, or have won, is free to
//    play again (replays never cost anything; out of hearts is still never punitive).
//  - A sponsor break (about 15 s, no tracking, no tapping out) opens `perBreak` more, up to `breaksPerDay` a day.
//  - Moon Club Pass (a yearly subscription a grown-up starts behind the gate) opens everything, with no breaks.
import Foundation

public enum Climb: String, CaseIterable, Codable, Sendable {
  case candles, lines, tower
  public var name: String {
    switch self { case .candles: return "Candle Academy"; case .lines: return "Line Lab"; case .tower: return "Moon Tower" }
  }
}

/// Today's new-level plays on this device (UserDefaults, never synced, nothing about the child).
public struct PlayLedger: Codable, Hashable, Sendable {
  public var day: String = ""
  /// New levels (past the free run, not won yet) opened today, by level id.
  public var opened: [String] = []
  /// Sponsor breaks finished today.
  public var breaks: Int = 0
  public init() {}
  public init(day: String, opened: [String] = [], breaks: Int = 0) { self.day = day; self.opened = opened; self.breaks = breaks }
  /// The ledger as it stands today (a new day starts empty).
  public func on(_ today: String) -> PlayLedger { day == today ? self : PlayLedger(day: today) }
}

public enum PlayPlan {
  /// Free forever: the first chapter of each academy and the first floor of the tower.
  public static func freeRun(_ c: Climb) -> Int { c == .tower ? 10 : 20 }
  public static let dailyFree = 3
  public static let perBreak = 3
  public static let breaksPerDay = 3
  /// About how long a break lasts (the countdown before "Collect").
  public static let breakSeconds = 15
  public static let productID = "com.mutaafaziz.moonclub.pass.yearly"

  public enum Decision: Equatable, Sendable {
    /// Free: the pass, the free run, a won level, or one already opened today. Nothing is counted.
    case free
    /// Allowed, and it uses one of today's new levels; `left` is how many remain after this one.
    case counted(left: Int)
    /// Today's levels are used; a break would open more.
    case needsBreak
    /// Today's levels and breaks are used: come back tomorrow (or a grown-up can start the pass).
    case doneForToday
    public var allowed: Bool { switch self { case .free, .counted: return true; default: return false } }
  }

  /// How many new levels today allows in all (before any are used).
  public static func allowance(_ l: PlayLedger, today: String) -> Int {
    dailyFree + perBreak * min(l.on(today).breaks, breaksPerDay)
  }
  /// New levels left today.
  public static func left(_ l: PlayLedger, today: String) -> Int {
    max(0, allowance(l, today: today) - l.on(today).opened.count)
  }
  public static func canBreak(_ l: PlayLedger, today: String) -> Bool { l.on(today).breaks < breaksPerDay }

  public static func isFree(_ c: Climb, number: Int, id: String, won: Bool, pass: Bool, ledger: PlayLedger, today: String) -> Bool {
    pass || won || number <= freeRun(c) || ledger.on(today).opened.contains(id)
  }

  public static func check(_ c: Climb, number: Int, id: String, won: Bool, pass: Bool, ledger: PlayLedger, today: String) -> Decision {
    if isFree(c, number: number, id: id, won: won, pass: pass, ledger: ledger, today: today) { return .free }
    let n = left(ledger, today: today)
    if n > 0 { return .counted(left: n - 1) }
    return canBreak(ledger, today: today) ? .needsBreak : .doneForToday
  }

  /// Records a play (only counted levels change the ledger).
  public static func record(_ c: Climb, number: Int, id: String, won: Bool, pass: Bool, ledger: PlayLedger, today: String) -> PlayLedger {
    guard case .counted = check(c, number: number, id: id, won: won, pass: pass, ledger: ledger, today: today) else { return ledger.on(today) }
    var l = ledger.on(today)
    l.opened.append(id)
    return l
  }

  /// A finished break opens `perBreak` more new levels today (no more than `breaksPerDay` a day).
  public static func finishBreak(_ ledger: PlayLedger, today: String) -> PlayLedger {
    var l = ledger.on(today)
    if l.breaks < breaksPerDay { l.breaks += 1 }
    return l
  }

  // MARK: Words (kid-facing; tested: no buy/sell/pay words, short)

  public static func chip(_ d: Decision) -> String? {
    switch d {
    case .free: return nil
    case .counted(let left): return left == 0 ? "Last new level today" : "\(left + 1) new levels left today"
    case .needsBreak, .doneForToday: return nil
    }
  }
  public static let limitTitle = "That's today's new levels!"
  public static func limitLine(_ d: Decision) -> String {
    d == .doneForToday
      ? "Great climbing! New levels open again tomorrow. You can still replay any level you've won."
      : "Take a short break to open \(perBreak) more, or replay any level you've won."
  }
  public static let breakButton = "Take a short break"
  public static let askButton = "Ask a grown-up"
  public static let askLine = "A grown-up can open every level with Moon Club Pass."

  /// Luna's own break (when there's no sponsor): one chart fact, picked by the day and the break number.
  public static let facts: [(symbol: String, line: String)] = [
    ("chart.bar.fill", "A candle shows one day: where the price started, ended, and how far it swung."),
    ("arrow.up.right", "A hollow green candle means the price ended the day higher than it started."),
    ("hand.raised.fill", "Buyers and sellers are like two teams in a tug-of-war."),
    ("line.diagonal", "A trend line joins the low points when prices climb, like steps on a hill."),
    ("square.split.1x2", "A floor is a price that buyers keep stopping at."),
    ("waveform.path.ecg", "A moving average smooths out the wiggles, like a long blur photo."),
    ("person.3.fill", "Tall volume bars mean lots of people traded that day."),
    ("lightbulb.fill", "Charts give clues, not promises. Even experts are often surprised!"),
    ("hourglass", "Patient planters often do better than people who check every minute."),
    ("basket.fill", "Spreading out is safer than putting every egg in one basket."),
    ("plus.forwardslash.minus", "A doji is a tiny-body candle: buyers and sellers tied."),
    ("arrow.down.right", "A filled red candle means the price ended lower than it started."),
  ]
  public static func fact(day: String, n: Int) -> (symbol: String, line: String) {
    let h = day.unicodeScalars.reduce(UInt32(7)) { ($0 &* 31) &+ $1.value }
    return facts[(Int(h % UInt32(facts.count)) + n) % facts.count]
  }
}
