// iPhone Duo play (0.14), as pure logic: the hinge as a light source, tent-mode detection, page flicks,
// the fold-to-save lid, Luna's pocket glance, the Market Race board game, the World atlas pages and the
// graphics budget. The app hands plain values in (a `HingeReading`, a fold rect, an acceleration, the
// thermal state) and draws what comes back, so every decision is unit-tested (DuoPlayTests).
//
// SDK audit (Xcode 27.2, iOS 27.2 SDK): `DeviceHinge` (status + angle), `onHingeChange`, `ReservedRegion`
// (.division / .occlusion, .includeInactive), `ArrangementView` (.split / .overlay / .automatic),
// `toolbarVerticalEdge`, `ExternalNonInteractiveAccessory` and UIKit's `UIHinge`/`UIHingeInteraction`.
// 27.2 adds only `CustomStringConvertible` on ReservedRegion and `toolbarTitleAlignment`. There is NO
// posture / tent API, so tent mode is emulated from the hinge angle (`Stance`).
import CoreGraphics
import Foundation

// MARK: - The hinge as light

/// The hinge drives light in the shaders: the World's sun rises as the phone opens, Luna's light swings
/// round, the fold casts a seam, and the fog over locked lands parts a little. Never layout.
public enum HingeLight {
  /// 0 = the sun is down (closed) … 1 = high noon (flat). No hinge = always full day.
  public static func sun(_ h: HingeReading?) -> Double {
    guard let h else { return 1 }
    switch h.status {
    case .closed: return 0
    case .fullyOpen: return 1
    case .partiallyOpen:
      let t = max(0, min(1, (h.degrees - 10) / 160))
      return t * t * (3 - 2 * t)
    }
  }
  /// Where the light comes from on Luna, in radians (0 = from the right, -π/2 = from above). It swings
  /// from low on the left (closed) to high on the right (flat). No hinge = upper left, like a lamp.
  public static func lunaLight(_ h: HingeReading?) -> Double {
    guard h != nil else { return -2.2 }
    return -2.9 + 2.2 * sun(h)
  }
  /// How dark the fold's seam is: deep when half open, a faint light line when flat, none without a fold.
  public static func seam(_ h: HingeReading?) -> Double {
    guard let h, h.status != .closed else { return 0 }
    if h.status == .fullyOpen { return 0.12 }
    return 0.12 + 0.5 * (1 - max(0, min(1, (h.degrees - 30) / 150)))
  }
  /// How far the fog over locked lands parts as the phone unfolds (0 … 0.35). It never clears a lock:
  /// it only gives a peek, so the land below still has to be won.
  public static func fogPart(_ h: HingeReading?) -> Double {
    guard let h, h.status == .partiallyOpen else { return 0 }
    return 0.35 * max(0, min(1, (h.degrees - 20) / 150))
  }
}

// MARK: - Stance (tent mode, emulated)

/// How the phone stands, beyond `Pose`. The 27.x SDK has no posture API, so a **tent** is emulated: half
/// open with a vertical fold (or no fold report) at a narrow angle, steady for a moment. Stood up like a
/// tent on a table, each half faces a different side, which is what the puppet show needs.
public enum Stance: String, Equatable, Sendable {
  case none, tent
  /// The angle window for a tent. Wider than this reads as a book in two hands.
  public static let tentRange: ClosedRange<Double> = 30...100
  /// How long the angle must stay in the window before it counts (a book passing through doesn't).
  public static let settle: Double = 1.2

  public static func isTentAngle(_ h: HingeReading?, fold: CGRect?) -> Bool {
    guard let h, h.status == .partiallyOpen, tentRange.contains(h.degrees) else { return false }
    if let fold { return fold.height >= fold.width }   // a horizontal fold is tabletop, not a tent
    return true
  }

  /// Debounces the tent: feed every reading with its time; `tent` turns on after `settle` seconds in the
  /// window and off as soon as the phone leaves it.
  public struct Tracker: Equatable, Sendable {
    public private(set) var since: Double?
    public private(set) var tent = false
    public init() {}
    public mutating func feed(_ h: HingeReading?, fold: CGRect? = nil, at t: Double) -> Bool {
      if isTentAngle(h, fold: fold) {
        if since == nil { since = t }
        tent = t - (since ?? t) >= settle
      } else { since = nil; tent = false }
      return tent
    }
  }
}

// MARK: - Fold flick (turn the page)

/// A quick "fold flick" turns a page in the World atlas: the phone dips at least `dip` degrees from where it
/// was and comes back within `back` degrees, all inside `window` seconds. Slow moves never count.
public struct PageFlick: Equatable, Sendable {
  public static let dip = 25.0, back = 10.0, window = 1.2
  private var peak: (deg: Double, t: Double)?
  private var low: Double?
  public init() {}
  public static func == (a: PageFlick, b: PageFlick) -> Bool { a.peak?.deg == b.peak?.deg && a.low == b.low }

  /// Returns true once, at the moment a flick completes.
  public mutating func feed(_ h: HingeReading?, at t: Double) -> Bool {
    guard let h, h.status == .partiallyOpen else { peak = nil; low = nil; return false }
    let d = h.degrees
    guard let p = peak, t - p.t <= Self.window else { peak = (d, t); low = nil; return false }
    if d > p.deg && low == nil { peak = (d, t); return false }       // still opening: move the peak up
    low = min(low ?? d, d)
    if let l = low, p.deg - l >= Self.dip, p.deg - d <= Self.back {
      peak = (d, t); low = nil
      return true
    }
    return false
  }
}

// MARK: - Fold to save (Moon Garden)

/// Closing the phone while the planting sheet is ready confirms the planting. The pot's lid follows the
/// hinge on the way down (0 open … 1 shut), so the kid sees what closing will do before it happens.
public enum FoldSave {
  public static func lid(_ h: HingeReading?) -> Double {
    guard let h else { return 0 }
    switch h.status {
    case .closed: return 1
    case .fullyOpen: return 0
    case .partiallyOpen:
      let t = max(0, min(1, (70 - h.degrees) / 62))
      return t * t * (3 - 2 * t)
    }
  }
  /// True when this hinge change should plant: it just closed and the sheet had a valid planting.
  public static func commits(from old: HingeReading?, to new: HingeReading?, ready: Bool) -> Bool {
    ready && HingeMoment.between(old, new) == .closed
  }
}

// MARK: - Luna's pocket (the outer display while closed)

/// What the little closed-phone screen shows at a glance: today's missions and the Moon Garden.
public struct PocketGlance: Equatable, Sendable {
  public let missionsDone: Int, missionsTotal: Int
  public let gardenValue: Int, gardenPlanted: Int
  public let chestReady: Bool
  public var gardenUp: Bool { gardenValue >= gardenPlanted }
  /// Luna's one line, grade 2 words, never "buy" or "hurry".
  public var line: String {
    if chestReady { return "Your chest is ready! Open me up." }
    if missionsTotal > 0, missionsDone == missionsTotal { return "All missions done. Great job!" }
    if missionsDone == 0 { return missionsTotal == 1 ? "A mission is waiting for you." : "\(missionsTotal) missions are waiting for you." }
    return "\(missionsTotal - missionsDone) more \(missionsTotal - missionsDone == 1 ? "mission" : "missions") to go!"
  }

  public static func make(_ s: KidsState, _ c: KidsContent, candles: [String: CandleSeries], today: String) -> PocketGlance {
    let ms = Missions.today(today, s, c)
    let book = s.gardenBook
    let value = book.growing.reduce(0) { $0 + $1.value(Garden.close(candles[$1.s], onOrBefore: today)?.c) }
    return PocketGlance(missionsDone: ms.filter(\.done).count, missionsTotal: ms.count, gardenValue: value,
                        gardenPlanted: book.principal, chestReady: Missions.chestReady(today, s, c) && !Missions.chestOpened(today, s))
  }
  public init(missionsDone: Int, missionsTotal: Int, gardenValue: Int, gardenPlanted: Int, chestReady: Bool) {
    self.missionsDone = missionsDone; self.missionsTotal = missionsTotal
    self.gardenValue = gardenValue; self.gardenPlanted = gardenPlanted; self.chestReady = chestReady
  }
}

/// Luna wakes up when the closed phone is picked up: a change in the device's user acceleration (in g)
/// above a small threshold. No permission is needed for device motion, and nothing is stored.
public enum PocketWake {
  public static let threshold = 0.08
  public static func wakes(x: Double, y: Double, z: Double) -> Bool { (x * x + y * y + z * z).squareRoot() >= threshold }
}

// MARK: - Market Race (Tabletop Game Night 2.0)

/// A two-player board game for a phone lying flat: each player answers on their own half, and both
/// rockets race along a shared track that sits on the fold line. A right answer moves you one space; the
/// first player to lock in a right answer gets a boost of one more. First to the finish wins. Questions are
/// real candles: "Did this day go up or down?" and "Which way did these days trend?". Nothing is saved.
public struct MarketRace: Equatable, Sendable {
  public enum Ask: Equatable, Sendable {
    /// One real candle: did it end higher (up) than it started?
    case day(Candle, symbol: String)
    /// A few closes: which way is the trend?
    case trend([Double], symbol: String)
    public var symbol: String { switch self { case let .day(_, s), let .trend(_, s): s } }
    public var answerUp: Bool {
      switch self {
      case let .day(c, _): return c.up
      case let .trend(cs, _): return ChartMath.trend(cs) == .up
      }
    }
    public var question: String {
      switch self {
      case .day: return "Did this day go up or down?"
      case .trend: return "Which way are these days going?"
      }
    }
  }

  public static let finish = 8
  public let asks: [Ask]
  public private(set) var index = 0
  public private(set) var spots = [0, 0]
  public private(set) var picks: [Bool?] = [nil, nil]
  public private(set) var first: Int?
  public private(set) var revealed = false
  /// What each player gained on the last reveal (0, 1 or 2).
  public private(set) var gained = [0, 0]

  /// Builds `count` questions from real candle series, seeded so both halves (and a rematch) agree.
  public init(series: [CandleSeries], seed: Int, count: Int = 24) {
    var g = Seeded(seed)
    let usable = series.filter { $0.candles.count >= 12 }.sorted { $0.s < $1.s }
    var out: [Ask] = []
    var tries = 0
    while out.count < count, !usable.isEmpty, tries < count * 8 {
      tries += 1
      let s = usable[Int.random(in: 0..<usable.count, using: &g)]
      if out.count % 3 == 2 {
        let start = Int.random(in: 0...(s.candles.count - 8), using: &g)
        let closes = s.candles[start..<(start + 8)].map(\.c)
        guard ChartMath.trend(closes) != .sideways else { continue }   // only clear trends: fair for kids
        out.append(.trend(closes, symbol: s.s))
      } else {
        let c = s.candles[Int.random(in: 0..<s.candles.count, using: &g)]
        guard abs(c.c - c.o) / max(c.o, 0.01) >= 0.004 else { continue } // skip near-flat days
        out.append(.day(c, symbol: s.s))
      }
    }
    asks = out
  }

  public var ask: Ask? { index < asks.count && winner == nil ? asks[index] : nil }
  public var winner: Int? {
    let done = spots.indices.filter { spots[$0] >= Self.finish }
    if done.count == 1 { return done[0] }
    if done.count == 2 { return spots[0] == spots[1] ? nil : (spots[0] > spots[1] ? 0 : 1) }
    return nil
  }
  /// Both crossed on the same reveal with the same score.
  public var isTie: Bool { spots[0] >= Self.finish && spots[0] == spots[1] }
  public var isOver: Bool { winner != nil || isTie || (index >= asks.count && !asks.isEmpty) }

  public mutating func pick(_ player: Int, up: Bool) {
    guard !revealed, picks.indices.contains(player), picks[player] == nil, let a = ask else { return }
    picks[player] = up
    if first == nil, up == a.answerUp { first = player }
    if picks.allSatisfy({ $0 != nil }) { reveal(a) }
  }
  private mutating func reveal(_ a: Ask) {
    for p in 0..<2 {
      let right = picks[p] == a.answerUp
      gained[p] = right ? (first == p ? 2 : 1) : 0
      spots[p] = min(Self.finish, spots[p] + gained[p])
    }
    revealed = true
  }
  public mutating func next() {
    guard revealed else { return }
    index += 1; picks = [nil, nil]; first = nil; revealed = false; gained = [0, 0]
  }
}

// MARK: - The World atlas (book mode)

/// In book mode the World becomes an atlas spread: the left page tells the land's story, the right page is
/// the island. Pure page math and the stories (reading grade ≤ 5, no advice).
public enum Atlas {
  public struct Page: Equatable, Sendable {
    public let title: String, story: [String], fact: String
  }
  /// The story for a land. Unknown lands fall back to their blurb.
  public static func page(_ r: Region) -> Page {
    switch r.id {
    case "coast": return Page(title: r.name, story: ["This is where Luna's trip begins.", "Little shops sit by the sea. Each one sells something people want.", "A share is a tiny piece of a company. Its price can change every day."], fact: "When you own a share, you own a tiny piece of a company.")
    case "isle": return Page(title: r.name, story: ["Tall trees grow here slowly, a little every day.", "Saving works the same way. Small bits add up.", "Some companies even share a little of their profit. That is a dividend."], fact: "Saving a little each week adds up over time.")
    case "canyon": return Page(title: r.name, story: ["The canyon walls are made of candles!", "Each candle shows one day of a price: where it started, where it ended, and how high and low it went.", "Read the candles to cross the canyon."], fact: "A hollow candle went up. A filled candle went down.")
    case "trails": return Page(title: r.name, story: ["These trails go up, down and sideways.", "A trend is the way a price moves over many days.", "Follow the trails and spot the trend."], fact: "One day is a step. A trend is the whole walk.")
    case "peaks": return Page(title: r.name, story: ["High on the peaks, shapes hide in the charts.", "Floors, ceilings and bounces show up again and again.", "Patterns are clues, not promises."], fact: "Patterns can help you guess, but prices can surprise you.")
    case "sea": return Page(title: r.name, story: ["Out on the sea, signals blink like lighthouses.", "Busy days, big moves and smooth lines all tell a story.", "Sail carefully and read every signal."], fact: "A smooth line shows the trend without the bumpy days.")
    case "castle": return Page(title: r.name, story: ["At the top of the world stands the castle.", "Here companies share their report cards: how much they sold and how much they kept.", "Did they beat what grown-ups expected, or miss? Find out why!"], fact: "A beat or a miss is a surprise compared to a guess, not a grade.")
    default: return Page(title: r.name, story: [r.blurb], fact: "Every land has something new to learn.")
    }
  }
  /// The next page after a swipe or a fold flick, clamped to the atlas.
  public static func turn(_ index: Int, by step: Int, count: Int) -> Int { max(0, min(max(0, count - 1), index + step)) }
}

// MARK: - The graphics budget

/// How much motion the Metal effects may use right now. Every effect asks this (through `FX` in the app):
/// off screen or in the background = paused; Low Power Mode, a hot device or Reduce Motion = still frames.
public enum FXLevel: Int, Comparable, Sendable {
  /// Nothing draws (off screen, app in the background).
  case paused
  /// A still frame: the effect's look without motion.
  case still
  /// Animated.
  case full
  public static func < (a: FXLevel, b: FXLevel) -> Bool { a.rawValue < b.rawValue }

  /// `thermal` follows `ProcessInfo.ThermalState.rawValue` (0 nominal, 1 fair, 2 serious, 3 critical).
  public static func of(visible: Bool, active: Bool, reduceMotion: Bool, lowPower: Bool, thermal: Int) -> FXLevel {
    guard visible, active else { return .paused }
    if reduceMotion || lowPower || thermal >= 2 { return .still }
    return .full
  }
}
