// iPhone Duo, as pure logic. The app reads SwiftUI's `DeviceHinge` and `ReservedRegion` and hands plain
// values to these functions, so every pose decision is unit-tested and the views stay thin.
//
// Apple's rule, kept here: the hinge drives *effects* (Luna's moon phase, the piggy lid, "tuck Luna in"),
// never layout. Layout comes from the fold's reserved region (`Fold`) and from size classes.
import CoreGraphics
import Foundation

/// A platform-free mirror of SwiftUI's `DeviceHinge` (status + angle; 180° is flat).
public struct HingeReading: Equatable, Sendable {
  public enum Status: String, Sendable, CaseIterable { case closed, partiallyOpen, fullyOpen }
  public var status: Status
  public var degrees: Double
  public init(_ status: Status, degrees: Double) { self.status = status; self.degrees = degrees }

  /// 0 when closed … 1 when flat. Clamped: the sensor's rate and precision are system policy.
  public var openness: Double { max(0, min(1, degrees / 180)) }
}

/// How the device is being held, for copy and effects. (Layout uses `Fold`, not this.)
public enum Pose: String, Equatable, Sendable {
  /// No hinge at all (every iPhone and iPad before iPhone Duo).
  case noHinge
  /// Closed: the app is on the outer display.
  case closed
  /// Partially open with a vertical fold, like a book in two hands.
  case book
  /// Partially open with a horizontal fold, set down like a tiny laptop.
  case tabletop
  /// Fully open and flat.
  case flat
  /// Stood up like a tent (0.14). The SDK has no posture API: `Pose.of` never returns this; it comes from
  /// `Stance` (a steady, narrow, half-open angle) or the debug pin `-pose tent`.
  case tent

  /// `fold` is the active division region's frame (if any). A fold taller than it is wide splits the
  /// display left | right (book); a wider one splits it top / bottom (tabletop).
  public static func of(_ hinge: HingeReading?, fold: CGRect?) -> Pose {
    guard let hinge else { return .noHinge }
    switch hinge.status {
    case .closed: return .closed
    case .fullyOpen: return .flat
    case .partiallyOpen:
      guard let fold else { return .book }
      return fold.height >= fold.width ? .book : .tabletop
    }
  }

  /// A short kid-friendly name, used in the Game Night hint and accessibility.
  public var kidName: String {
    switch self {
    case .noHinge: "One screen"
    case .closed: "Closed"
    case .book: "Book"
    case .tabletop: "Tabletop"
    case .flat: "Wide open"
    case .tent: "Tent"
    }
  }
}

/// Luna's moon follows the hinge: a new moon when closed, waxing as it opens, full when flat —
/// the Metaphases moon-phase mark, made physical.
public enum HingeMoon {
  /// 0 (new) … 1 (full).
  public static func illumination(_ h: HingeReading?) -> Double {
    guard let h else { return 1 }
    switch h.status {
    case .closed: return 0
    case .fullyOpen: return 1
    case .partiallyOpen: return h.openness
    }
  }
  /// The five badge phases (0 new … 4 full), rounded from the illumination.
  public static func phase(_ h: HingeReading?) -> Int { Int((illumination(h) * 4).rounded()) }
  /// Read-aloud and VoiceOver words for the phase.
  public static func name(_ phase: Int) -> String {
    ["New moon", "Crescent moon", "Half moon", "Almost full moon", "Full moon"][max(0, min(4, phase))]
  }
}

/// The piggy bank's lid lifts with the hinge (0 shut … 1 wide open). Shut unless partially open, so
/// the lid only moves while someone is actually opening the phone.
public enum PiggyLid {
  public static func open(_ h: HingeReading?) -> Double {
    guard let h, h.status == .partiallyOpen else { return 0 }
    let t = max(0, min(1, (h.degrees - 15) / 110))
    return t * t * (3 - 2 * t) // smoothstep, so it eases at both ends
  }
}

/// Discrete hinge moments worth a haptic.
public enum HingeMoment: Equatable, Sendable {
  /// The phone just closed: if a lesson was finished, Luna gets tucked in for the night.
  case closed
  /// The phone just opened flat: the storybook spread is ready.
  case openedFlat

  public static func between(_ old: HingeReading?, _ new: HingeReading?) -> HingeMoment? {
    guard let old, let new, old.status != new.status else { return nil }
    if new.status == .closed { return .closed }
    if new.status == .fullyOpen { return .openedFlat }
    return nil
  }
}

/// Where two pages go around the fold. `fold` is a division region (active or inactive) in the same
/// coordinate space as `bounds`, margins already included. Returns nil when there's no usable fold or
/// a page would be too narrow to read, and the caller falls back to one page.
public enum Fold {
  public struct Spread: Equatable, Sendable {
    public let first: CGRect, second: CGRect, sideBySide: Bool
  }

  public static func spread(in bounds: CGRect, fold: CGRect?, minPage: CGFloat = 260) -> Spread? {
    guard let fold, bounds.intersects(fold) else { return nil }
    if fold.height >= fold.width {
      let l = CGRect(x: bounds.minX, y: bounds.minY, width: fold.minX - bounds.minX, height: bounds.height)
      let r = CGRect(x: fold.maxX, y: bounds.minY, width: bounds.maxX - fold.maxX, height: bounds.height)
      guard l.width >= minPage, r.width >= minPage else { return nil }
      return Spread(first: l, second: r, sideBySide: true)
    } else {
      let t = CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: fold.minY - bounds.minY)
      let b = CGRect(x: bounds.minX, y: fold.maxY, width: bounds.width, height: bounds.maxY - fold.maxY)
      guard t.height >= minPage * 0.75, b.height >= minPage * 0.75 else { return nil }
      return Spread(first: t, second: b, sideBySide: false)
    }
  }

  /// Grid columns for a width: as many as fit, but an *even* number whenever a fold crosses the grid,
  /// so cards divide cleanly on either side (Apple's iPhone Duo guidance).
  public static func columns(width: CGFloat, minimum: CGFloat, spacing: CGFloat, foldCrosses: Bool) -> Int {
    let n = max(1, Int((width + spacing) / (minimum + spacing)))
    guard foldCrosses else { return n }
    return max(2, n - n % 2)
  }
}

/// Game Night: two players, one phone, a report card that already came out, instant reveal.
/// Nothing is saved (it's a party game, not progress), so it never touches `KidsState` or the web's codes.
public struct GameNight: Equatable, Sendable {
  public struct Round: Equatable, Sendable {
    public let s: String, d: String, report: Report
    public init(s: String, d: String, report: Report) { self.s = s; self.d = d; self.report = report }
  }
  public let rounds: [Round]
  public private(set) var index = 0
  public private(set) var picks: [Pick?] = [nil, nil]
  public private(set) var scores = [0, 0]
  public private(set) var revealed = false

  /// Rounds are the newest past report cards with a real result (beat or miss is known), at most `limit`.
  public init(events: [(s: String, d: String, report: Report)], today: String, limit: Int = 5) {
    rounds = events
      .filter { $0.d < today && resolveGuess(.beat, $0.report) != .pending && resolveGuess(.beat, $0.report) != .unknown }
      .sorted { ($0.d, $0.s) > ($1.d, $1.s) }
      .prefix(limit)
      .map { Round(s: $0.s, d: $0.d, report: $0.report) }
  }

  public var round: Round? { index < rounds.count ? rounds[index] : nil }
  public var isOver: Bool { round == nil }
  public var bothPicked: Bool { picks.allSatisfy { $0 != nil } }
  /// The real answer for this round (beat if the profit was at least what grown-ups expected).
  public var answer: Pick? { round.map { resolveGuess(.beat, $0.report) == .right ? .beat : .miss } }

  /// A player locks in a pick. Picks are hidden until both are in, then revealed together.
  public mutating func pick(_ player: Int, _ p: Pick) {
    guard !revealed, picks.indices.contains(player), round != nil else { return }
    picks[player] = p
    if bothPicked { reveal() }
  }
  private mutating func reveal() {
    guard let a = answer else { return }
    for i in picks.indices where picks[i] == a { scores[i] += 1 }
    revealed = true
  }
  public mutating func next() {
    guard revealed else { return }
    index += 1; picks = [nil, nil]; revealed = false
  }
  /// Who's ahead at the end: 0 or 1, or nil for a tie.
  public var winner: Int? { scores[0] == scores[1] ? nil : (scores[0] > scores[1] ? 0 : 1) }
}
