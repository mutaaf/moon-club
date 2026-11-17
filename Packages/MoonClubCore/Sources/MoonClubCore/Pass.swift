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
  /// The ledger as it stands today (a new day starts empty). 0.22: a clock moved *back* (today before the ledger's
  /// day) carries the ledger onto today, so winding the date forward and back never hands out a fresh day, and
  /// a date set far ahead never locks the next real days either.
  public func on(_ today: String) -> PlayLedger {
    if day == today { return self }
    if !day.isEmpty && today < day { return PlayLedger(day: today, opened: opened, breaks: breaks) }
    return PlayLedger(day: today)
  }
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

  /// Today at a glance (the moons in the limit sheet, the card and the grown-up corner).
  public struct Today: Equatable, Sendable {
    public let pass: Bool
    /// New levels opened today.
    public let used: Int
    /// New levels today allows so far (the daily ones plus what finished breaks opened).
    public let allowance: Int
    public let breaksUsed: Int
    public var left: Int { max(0, allowance - used) }
    public var breaksLeft: Int { max(0, PlayPlan.breaksPerDay - breaksUsed) }
    /// The most new levels a day can ever open without the pass.
    public static var most: Int { PlayPlan.dailyFree + PlayPlan.perBreak * PlayPlan.breaksPerDay }
    /// One slot per possible new level today, in order: used, open, or still behind a break.
    public enum Slot: Equatable, Sendable { case used, open, locked }
    public var slots: [Slot] {
      (0..<Today.most).map { i in i < used ? .used : i < allowance ? .open : .locked }
    }
  }
  public static func today(_ l: PlayLedger, pass: Bool, today: String) -> Today {
    let t = l.on(today)
    return Today(pass: pass, used: t.opened.count, allowance: allowance(l, today: today), breaksUsed: min(t.breaks, breaksPerDay))
  }

  /// "New levels in 5 h 12 min" (minutes until the device's midnight). Kid-facing and short.
  public static func resetLine(minutes: Int) -> String {
    let m = max(1, minutes)
    if m < 60 { return m == 1 ? "New levels in 1 minute" : "New levels in \(m) minutes" }
    let h = m / 60, r = m % 60
    return r == 0 ? "New levels in \(h) h" : "New levels in \(h) h \(r) min"
  }
  /// Minutes from `now` to the next midnight in `tz`.
  public static func minutesToTomorrow(_ now: Date = Date(), tz: TimeZone = .current) -> Int {
    var c = Calendar(identifier: .gregorian); c.timeZone = tz
    guard let next = c.nextDate(after: now, matching: DateComponents(hour: 0, minute: 0), matchingPolicy: .nextTime) else { return 1 }
    return Int((next.timeIntervalSince(now) / 60).rounded(.up))
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
  public static func breakButton(left: Int) -> String { left == 1 ? "Take today's last break" : "Take a short break" }
  public static let breakButton = "Take a short break"
  public static let replayButton = "Replay a level I've won"
  public static let collectButton = "Collect \(perBreak) new levels"
  public static let collected = "\(perBreak) new levels are open!"
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
  /// 0.22: Luna's break is a tiny quiz, so the 15 seconds teach something. One true-or-false question per fact,
  /// written at reading grade ≤ 5; a miss is never scolded (`why` explains it either way).
  public struct Quiz: Equatable, Sendable {
    public let symbol: String
    public let fact: String
    public let question: String
    public let choices: [String]
    public let answer: Int
    public let why: String
  }
  public static let quizzes: [Quiz] = [
    Quiz(symbol: "chart.bar.fill", fact: facts[0].line, question: "How many days does one candle show?", choices: ["One day", "One year"], answer: 0,
         why: "Each candle is one day of prices."),
    Quiz(symbol: "arrow.up.right", fact: facts[1].line, question: "A hollow green candle ended the day…", choices: ["Higher", "Lower"], answer: 0,
         why: "Green and hollow means it closed above where it opened."),
    Quiz(symbol: "hand.raised.fill", fact: facts[2].line, question: "If buyers pull harder, the price goes…", choices: ["Up", "Down"], answer: 0,
         why: "More buyers than sellers pushes the price up."),
    Quiz(symbol: "line.diagonal", fact: facts[3].line, question: "A rising trend line joins the…", choices: ["Low points", "High points"], answer: 0,
         why: "When prices climb, the line goes under the lows, like steps."),
    Quiz(symbol: "square.split.1x2", fact: facts[4].line, question: "A floor is where buyers keep…", choices: ["Stopping the fall", "Running away"], answer: 0,
         why: "Buyers step in at the floor, so the price stops falling there."),
    Quiz(symbol: "waveform.path.ecg", fact: facts[5].line, question: "A moving average makes the line…", choices: ["Smoother", "Wigglier"], answer: 0,
         why: "It averages many days, so the wiggles blur out."),
    Quiz(symbol: "person.3.fill", fact: facts[6].line, question: "A tall volume bar means…", choices: ["Lots of trading", "A quiet day"], answer: 0,
         why: "Volume counts how much was traded that day."),
    Quiz(symbol: "lightbulb.fill", fact: facts[7].line, question: "Can a chart promise what happens next?", choices: ["No, only clues", "Yes, always"], answer: 0,
         why: "Charts give clues. Nobody knows the future for sure."),
    Quiz(symbol: "hourglass", fact: facts[8].line, question: "Who often does better?", choices: ["Patient planters", "Minute checkers"], answer: 0,
         why: "Waiting and planning usually beats checking all the time."),
    Quiz(symbol: "basket.fill", fact: facts[9].line, question: "Which is safer?", choices: ["Many baskets", "One basket"], answer: 0,
         why: "If one basket drops, the other eggs are still fine."),
    Quiz(symbol: "plus.forwardslash.minus", fact: facts[10].line, question: "A doji means buyers and sellers…", choices: ["Tied", "Gave up"], answer: 0,
         why: "The price ended right where it started: a tie."),
    Quiz(symbol: "arrow.down.right", fact: facts[11].line, question: "A filled red candle ended the day…", choices: ["Lower", "Higher"], answer: 0,
         why: "Red and filled means it closed below where it opened."),
  ]
  /// Today's quiz for break `n`, with the choices shuffled the same way every time (so the right one isn't always first).
  public static func quiz(day: String, n: Int) -> Quiz {
    let h = day.unicodeScalars.reduce(UInt32(7)) { ($0 &* 31) &+ $1.value }
    let i = (Int(h % UInt32(quizzes.count)) + n) % quizzes.count
    let q = quizzes[i]
    guard (n + i / 2 + Int(h % 5)) % 2 == 1 else { return q }
    return Quiz(symbol: q.symbol, fact: q.fact, question: q.question, choices: q.choices.reversed(), answer: q.choices.count - 1 - q.answer, why: q.why)
  }
  public static let rightLine = "Yes! You got it."
  public static let missLine = "Good guess! Here's the trick:"

  public static func fact(day: String, n: Int) -> (symbol: String, line: String) {
    let h = day.unicodeScalars.reduce(UInt32(7)) { ($0 &* 31) &+ $1.value }
    return facts[(Int(h % UInt32(facts.count)) + n) % facts.count]
  }
}
