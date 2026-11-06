// Start here: the ONE thing a kid should tap when they open the app. Pure, so the same day and progress
// always pick the same step, and it's tested (NextUpTests). The Story tab's hero button shows it.
//
// Order:
//  1. a quest chapter the kid started and didn't finish ("Keep going")
//  2. the first unfinished daily mission (a lesson in a half-done unit says "Keep going")
//  3. a ready mission chest ("Open")
//  4. the next World stop: where Luna's rocket waits on the map (a half-done unit says "Keep going")
//  5. something fun: Guess or the Piggy Bank
import Foundation

public enum NextTarget: Hashable, Sendable {
  case lesson(String)   // a lesson id (opens the lesson player)
  case node(String)     // a Market World node id (opens the stop)
  case quest(String)    // a quest chapter id
  case guess            // the Guess tab
  case piggy            // the Piggy Bank tab
  case chest            // open today's mission chest
}

/// The tab that holds the step (raw values match the app's `Tab`). The app puts a small glowing dot on it
/// when it isn't Story.
public enum NextHome: String, Hashable, Sendable { case story, guess, piggy, school }

public enum NextReason: String, Hashable, Sendable { case keepGoing, mission, chest, world, fun }

public struct NextStep: Hashable, Sendable {
  public let reason: NextReason
  /// One short verb: Learn, Play, Start, Open, Visit, Keep going.
  public let verb: String
  public let title: String
  /// Emoji key for `Glyph` (never drawn as an emoji).
  public let art: String
  /// About how long it takes, in minutes (nil: a tap, like opening the chest).
  public let minutes: Int?
  public let target: NextTarget
  public let home: NextHome
  public var keepGoing: Bool { verb == NextUp.keepGoing }
  /// "Play: Candle match"
  public var label: String { "\(verb): \(title)" }
  public init(reason: NextReason, verb: String, title: String, art: String, minutes: Int?, target: NextTarget, home: NextHome) {
    self.reason = reason; self.verb = verb; self.title = title; self.art = art; self.minutes = minutes; self.target = target; self.home = home
  }
}

public enum NextUp {
  public static let keepGoing = "Keep going"

  /// Nothing played yet, ever (a brand-new install). Opening the app logs a "visit" (`checkIn`); that
  /// doesn't count as playing.
  public static func isNew(_ s: KidsState) -> Bool {
    s.lessons.isEmpty && s.guesses.isEmpty && s.quest.isEmpty && !s.questDone
      && (s.played ?? []).allSatisfy { $0.contains("|visit|") }
      && s.piggy == nil && (s.stars ?? [:]).isEmpty && (s.chests ?? []).isEmpty
  }

  /// The single best next step.
  public static func step(_ today: String, _ s: KidsState, _ c: KidsContent) -> NextStep {
    let chapters = c.questChapters?.CHAPTERS ?? []
    // 1. A quest chapter that's started but not done.
    if let ch = chapters.first(where: { started($0.id, s, c) && !finished($0.id, s, c) }) {
      return NextStep(reason: .keepGoing, verb: keepGoing, title: ch.title, art: ch.emoji, minutes: 5, target: .quest(ch.id), home: .story)
    }
    // 2. The first unfinished daily mission.
    let ms = Missions.today(today, s, c)
    if let m = ms.first(where: { !$0.done }) {
      switch m.target {
      case let .lesson(id):
        let unitStarted = c.lessons.first { $0.id == id }.map { l in c.lessons.contains { $0.unit == l.unit && s.lessons.contains($0.id) } } ?? false
        return NextStep(reason: .mission, verb: unitStarted ? keepGoing : "Learn", title: m.title, art: m.art, minutes: 2, target: m.target.next, home: .story)
      case .node:
        return NextStep(reason: .mission, verb: "Play", title: m.title, art: m.art, minutes: 2, target: m.target.next, home: .story)
      case .guess:
        return NextStep(reason: .mission, verb: "Play", title: m.title, art: m.art, minutes: 1, target: .guess, home: .guess)
      }
    }
    // 3. All three done: the chest.
    if Missions.chestReady(today, s, c) {
      return NextStep(reason: .chest, verb: "Open", title: "Your mission chest", art: "🎁", minutes: nil, target: .chest, home: .story)
    }
    // 4. Where the rocket waits on the map.
    let rs = World.regions(c)
    let at = World.current(rs, s, c)
    if at.region < rs.count, at.node < rs[at.region].nodes.count {
      let n = rs[at.region].nodes[at.node]
      if World.stars(n, s, c) == 0, !n.isOptional { return world(n, s, c) }
    }
    // 5. Something fun.
    if s.piggy == nil {
      return NextStep(reason: .fun, verb: "Start", title: "Your piggy bank", art: "🐷", minutes: 2, target: .piggy, home: .piggy)
    }
    let seed = today.unicodeScalars.reduce(7) { ($0 &* 31 &+ Int($1.value)) & 0x7fff_ffff }
    return seed % 2 == 0
      ? NextStep(reason: .fun, verb: "Play", title: "Guess a report card", art: "🎯", minutes: 1, target: .guess, home: .guess)
      : NextStep(reason: .fun, verb: "Visit", title: "Your piggy bank", art: "🐷", minutes: 2, target: .piggy, home: .piggy)
  }

  /// Luna's one short line above the button.
  public static func greeting(_ step: NextStep, _ today: String, _ s: KidsState, _ c: KidsContent) -> String {
    if isNew(s) { return "Hi! Let's start here." }
    switch step.reason {
    case .keepGoing: return "Welcome back!"
    case .chest: return "All 3 done. Wow!"
    case .world: return "Missions done! Next up:"
    case .fun: return "All done today! Just for fun:"
    case .mission:
      if step.keepGoing { return "Welcome back!" }
      return Missions.doneCount(today, s, c) > 0 ? "Nice! Next up:" : "Welcome back! Next up:"
    }
  }

  /// The tab that should carry the glowing dot (nil when the step lives on Story).
  public static func dotTab(_ step: NextStep) -> NextHome? { step.home == .story ? nil : step.home }

  // MARK: helpers

  static func started(_ id: String, _ s: KidsState, _ c: KidsContent) -> Bool {
    if id == "lemonade" { return Chapters.lemonadeStages.contains(where: s.quest.contains) }
    return s.quest.contains { $0.hasPrefix(id + ":") }
  }
  static func finished(_ id: String, _ s: KidsState, _ c: KidsContent) -> Bool {
    id == "lemonade" ? (s.questDone || s.chapters(c).contains(id)) : s.chapters(c).contains(id)
  }

  static func world(_ n: WorldNode, _ s: KidsState, _ c: KidsContent) -> NextStep {
    let t: NextTarget = .node(n.id)
    switch n.kind {
    case let .unit(u):
      let ls = c.requiredLessons(u)
      let half = ls.contains { s.lessons.contains($0.id) }
      return NextStep(reason: .world, verb: half ? keepGoing : "Learn", title: n.title, art: n.art, minutes: 2, target: t, home: .school)
    case .lesson: return NextStep(reason: .world, verb: "Learn", title: n.title, art: n.art, minutes: 2, target: t, home: .school)
    case let .quest(q):
      return NextStep(reason: .world, verb: started(q, s, c) ? keepGoing : "Start", title: n.title, art: n.art, minutes: 5, target: t, home: .school)
    case .review, .timeMachine: return NextStep(reason: .world, verb: "Play", title: n.title, art: n.art, minutes: 3, target: t, home: .school)
    case .game, .guess, .practice: return NextStep(reason: .world, verb: "Play", title: n.title, art: n.art, minutes: 2, target: t, home: .school)
    }
  }
}

extension MissionTarget {
  var next: NextTarget {
    switch self {
    case let .lesson(id): return .lesson(id)
    case let .node(id): return .node(id)
    case .guess: return .guess
    }
  }
}
