// Game On (0.10): Today's 3 missions, the mission chest, the play streak and the rocket skins. All pure,
// so the same day and state always give the same missions, on every device, and sync can't inflate them.
import Foundation

public enum MissionKind: String, CaseIterable, Sendable { case lesson, chart, guess }

public enum MissionTarget: Hashable, Sendable {
  case lesson(String)   // a lesson id
  case node(String)     // a Market World node id (a chart game)
  case guess            // Guess the Report Card
}

public struct Mission: Hashable, Identifiable, Sendable {
  public let kind: MissionKind
  public let title: String
  public let detail: String
  public let art: String
  public let target: MissionTarget
  public let done: Bool
  public var id: String { kind.rawValue }
}

public enum Missions {
  /// One lesson, one chart game and one guess for `today`.
  public static func today(_ today: String, _ s: KidsState, _ c: KidsContent) -> [Mission] {
    let seed = today.unicodeScalars.reduce(17) { ($0 &* 31 &+ Int($1.value)) & 0x7fff_ffff }
    let log = Set((s.played ?? []).filter { $0.hasPrefix(today + "|") })
    func did(_ kind: String) -> Bool { log.contains { $0.hasPrefix("\(today)|\(kind)|") } }

    // Lesson: the one finished today if any (so the card doesn't jump), else the next new one, else a replay.
    let finishedToday = c.lessons.first { s.lessonDates[$0.id] == today }
    let lesson = finishedToday ?? c.lessons.first { !s.lessons.contains($0.id) } ?? (c.lessons.isEmpty ? nil : c.lessons[seed % c.lessons.count])
    let lessonDone = finishedToday != nil || did("lesson")

    // Chart game: a game from the open lands (rotates by day), else the first game on the map.
    let regions = World.regions(c)
    let games = regions.enumerated().flatMap { ri, r in r.nodes.filter { if case .game = $0.kind { return true }; return false }.map { (ri, $0) } }
    let open = games.filter { World.regionOpen($0.0, regions, s, c) }.map(\.1)
    let pool = open.isEmpty ? Array(games.prefix(1).map(\.1)) : open
    let game = pool.isEmpty ? nil : pool[seed % pool.count]

    let guessDone = did("guess") || s.guesses.contains { $0.at == today }

    var out: [Mission] = []
    if let l = lesson {
      out.append(Mission(kind: .lesson, title: l.title, detail: "Learn one tiny thing", art: l.emoji, target: .lesson(l.id), done: lessonDone))
    }
    if let g = game {
      out.append(Mission(kind: .chart, title: g.title, detail: "Play a chart game", art: g.art, target: .node(g.id), done: did("game")))
    }
    out.append(Mission(kind: .guess, title: "Guess a report card", detail: "Beat or miss?", art: "🎯", target: .guess, done: guessDone))
    return out
  }

  public static func doneCount(_ today: String, _ s: KidsState, _ c: KidsContent) -> Int { Self.today(today, s, c).filter(\.done).count }
  /// The chest opens once all three missions are done, once per day.
  public static func chestReady(_ today: String, _ s: KidsState, _ c: KidsContent) -> Bool {
    let m = Self.today(today, s, c)
    return !m.isEmpty && m.allSatisfy(\.done) && !(s.chests ?? []).contains(today)
  }
  public static func chestOpened(_ today: String, _ s: KidsState) -> Bool { (s.chests ?? []).contains(today) }
}

// MARK: - Play streak

extension Streak {
  /// Days in a row with any play (a lesson, a game, a boss, a quest or a guess), ending today or yesterday.
  public static func play(_ s: KidsState, today: String) -> Int {
    Streak.days(Streak.activeDays(s), today: today)
  }
}

// MARK: - Rocket skins (cosmetic only: bought with earned Moon points in the Moon Shop, never real money)

public struct RocketSkin: Hashable, Identifiable, Sendable {
  public let id: String; public let name: String; public let body: UInt32; public let fin: UInt32; public let flame: UInt32
}

public enum Skins {
  public static let all: [RocketSkin] = [
    RocketSkin(id: "classic", name: "Moon Classic", body: 0xF4F1FF, fin: 0xEC6461, flame: 0xF0893E),
    RocketSkin(id: "mint", name: "Mint Comet", body: 0xD9F3E6, fin: 0x1FA99A, flame: 0xF2BE2E),
    RocketSkin(id: "sunset", name: "Sunset Zoom", body: 0xFFE4D2, fin: 0xD2508F, flame: 0xF0893E),
    RocketSkin(id: "galaxy", name: "Galaxy Grape", body: 0xECE4FF, fin: 0x7E62EE, flame: 0x3F82EE),
    RocketSkin(id: "gold", name: "Gold Star", body: 0xFFF3C4, fin: 0xD99A1E, flame: 0xEC6461),
    RocketSkin(id: "ocean", name: "Deep Sea", body: 0xDFE8FF, fin: 0x2346D8, flame: 0x3DB97F),
    RocketSkin(id: "night", name: "Night Owl", body: 0x2F2C63, fin: 0xF2BE2E, flame: 0xFF9FB0),
  ]
  /// iPhone Duo only (0.14): earned through Duo play, never by chests. Kept out of `all` on purpose:
  /// `Shop.legacy` grants a prefix of `all` for old chests, and a Duo rocket must never arrive that way.
  public static let duo: [RocketSkin] = [
    RocketSkin(id: "twin", name: "Twin Moon", body: 0xE6ECFF, fin: 0x5B4BD8, flame: 0x46C8E8),
  ]
  /// Every rocket there is (the hangar's shelf).
  public static var every: [RocketSkin] { all + duo }
  /// Rockets the kid owns: the classic one, any bought in the Moon Shop, and those chests unlocked before it.
  public static func unlocked(_ s: KidsState) -> [RocketSkin] { let o = Shop.owned(s); return every.filter { o.contains("rocket.\($0.id)") } }
  /// The next rocket not owned yet, if any.
  public static func next(_ s: KidsState) -> RocketSkin? { let have = Set(unlocked(s).map(\.id)); return all.first { !have.contains($0.id) } }
  /// The rocket the kid flies (the Moon Shop's equipped rocket).
  public static func current(_ s: KidsState) -> RocketSkin { Shop.rocket(s) }
}
