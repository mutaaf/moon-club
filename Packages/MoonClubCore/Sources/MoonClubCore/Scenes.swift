import Foundation

// Lesson scenes: every Moon School card is a small living window, an aurora field in the unit's colors
// with Luna acting out the lesson's idea (a coin dropping into a piggy bank, a cup filling, a candle growing).
// This file is the ONE table that says which scene a lesson gets. It is pure data, so a new lesson or a new
// pack's unit always resolves to a sensible scene: lesson override → unit default → a palette picked from
// the unit id and the gentle `pop` act. The app draws it (MoonClub/Design/LessonScenes.swift).

/// What Luna's prop does in the loop. Each act has a calm "done" pose at its end.
public enum SceneAct: String, CaseIterable, Sendable {
  /// A coin drops into a container (piggy, jar, bank).
  case drop
  /// A lemonade cup fills up.
  case fill
  /// Candles grow one by one (hollow = up, filled = down, like every chart in the app).
  case candles
  /// A price tag puffs up bigger, with an up arrow.
  case inflate
  /// A shield pops up and a red flag bounces off it.
  case shield
  /// The prop springs up with a little sparkle.
  case pop
  /// Small tokens hop into a basket.
  case collect
  /// A sprout grows two leaves.
  case sprout
  /// A snowball rolls and grows.
  case roll
  /// A line climbs a hill.
  case climb
  /// A line wiggles sideways.
  case wiggle
  /// A slice comes out of a pie.
  case slice
  /// The prop slides across the window.
  case slide
  /// A magnifying glass looks over the prop.
  case scan
  /// The prop turns over (an hourglass, a calendar, a clock).
  case flip
  /// Rings ripple out of the prop (ads, hype, volume).
  case wave
  /// A balance tips one way, then the other.
  case tip
  /// A rocket lifts off.
  case launch
  /// Coins stack up next to the prop.
  case stack
  /// The prop floats on a soft breeze, with twinkles (a lesson's later pictures).
  case float
  /// Little coins circle the prop.
  case orbit
  /// The prop drops in and bounces to a stop.
  case bounce
  /// The prop glows while sparkles twinkle around it.
  case sparkle
  /// Luna is thinking: the prop tilts and a "?" thought bubble pops up (quiz steps).
  case think
}

/// The aurora colors for a scene (the app maps each to three ribbon colors over a night sky).
public enum ScenePalette: String, CaseIterable, Sendable {
  case mint, sunrise, gold, coral, teal, ocean, berry, grape, dusk
}

/// One lesson's scene: the act, the palette, an optional prop symbol (SF Symbol name; nil = the lesson's own
/// art) and Luna's one-line hook for the Up Next card.
public struct LessonScene: Hashable, Sendable {
  public let act: SceneAct
  public let palette: ScenePalette
  public let prop: String?
  public let hook: String
  /// 0..<1: where in the loop this card starts, so neighbouring cards don't move in step.
  public let seed: Double
  public init(act: SceneAct, palette: ScenePalette, prop: String?, hook: String, seed: Double) {
    self.act = act; self.palette = palette; self.prop = prop; self.hook = hook; self.seed = seed
  }
}

public enum Scenes {
  /// Unit → palette + default act.
  public static let units: [String: (ScenePalette, SceneAct)] = [
    "money": (.mint, .drop), "earning": (.sunrise, .fill), "goals": (.gold, .drop), "spending": (.coral, .scan),
    "safety": (.teal, .shield), "companies": (.ocean, .stack), "shares": (.berry, .slice), "piggy": (.gold, .drop),
    "growing": (.mint, .sprout), "inflation": (.coral, .inflate), "borrowing": (.grape, .roll), "dividends": (.berry, .slice),
    "funds": (.teal, .collect), "smart": (.grape, .collect), "report": (.ocean, .scan), "why": (.dusk, .scan),
    "candles": (.dusk, .candles), "trends": (.ocean, .climb), "patterns": (.grape, .climb), "signals": (.teal, .wave),
  ]

  /// Lesson → act (and optionally a prop symbol) when the unit's default doesn't tell its story.
  public static let lessons: [String: (SceneAct, String?)] = [
    // Money basics
    "money": (.slide, "banknote.fill"), "earn": (.fill, nil), "needs": (.tip, nil), "budget": (.scan, nil), "choose": (.tip, nil),
    // Earning
    "jobs": (.fill, nil), "gifts": (.pop, "gift.fill"), "boss": (.fill, nil), "paid": (.flip, "clock.fill"), "taxes": (.drop, "building.columns.fill"),
    // Saving goals
    "goal": (.slide, "bicycle"), "wait": (.flip, "hourglass"), "bank-safe": (.drop, "building.columns.fill"), "hard-save": (.tip, nil), "rainy-day": (.pop, "umbrella.fill"),
    // Smart spending
    "compare": (.scan, "tag.fill"), "in-game": (.inflate, "diamond.fill"), "give": (.pop, "gift.fill"), "borrow": (.slide, "book.fill"),
    "ads": (.wave, "megaphone.fill"), "pay-ways": (.slide, "creditcard.fill"),
    // Staying safe
    "risk-life": (.shield, nil), "private": (.pop, "lock.fill"), "free-gems": (.shield, nil), "scam-signs": (.shield, nil), "insurance": (.shield, "umbrella.fill"),
    // Companies
    "company": (.stack, "storefront.fill"), "profit": (.stack, "storefront.fill"), "grow": (.sprout, nil),
    // Shares
    "share": (.slice, nil), "market": (.collect, nil), "prices": (.climb, nil), "owner": (.pop, "crown.fill"), "ticker": (.slide, "textformat.abc"),
    // Piggy Bank school
    "piggy-start": (.drop, "custom.piggy"), "piggy-spread": (.collect, nil), "piggy-updown": (.wiggle, nil), "piggy-peek": (.flip, "clock.fill"), "piggy-time": (.flip, "hourglass"),
    // Saving and investing
    "saving": (.drop, "cylinder.fill"), "interest": (.stack, "building.columns.fill"), "risk": (.wiggle, nil), "snowball": (.roll, nil),
    "compound": (.sprout, nil), "double": (.flip, "hourglass"), "which": (.tip, nil),
    // Prices over time
    "prices-rise": (.inflate, nil), "buy-less": (.inflate, nil), "beat-prices": (.sprout, nil),
    // Borrowing
    "owe-interest": (.stack, nil), "lender": (.stack, "building.columns.fill"), "credit-card": (.slide, "creditcard.fill"), "debt-snowball": (.roll, nil),
    // Dividends
    "dividend": (.slice, nil), "no-dividend": (.launch, nil), "replant": (.sprout, nil), "div-day": (.flip, "calendar"), "div-yield": (.drop, "cylinder.fill"),
    // Baskets
    "spread-groups": (.collect, nil), "fund": (.collect, nil), "fees": (.sprout, nil), "index": (.scan, "list.bullet.clipboard.fill"),
    // Money-smart
    "baskets": (.collect, nil), "patience": (.flip, "moon.fill"), "hype": (.wave, "megaphone.fill"), "too-good": (.shield, nil), "clues": (.scan, nil),
    // Report cards
    "guess": (.pop, nil), "beat": (.pop, "target"), "after": (.climb, nil), "per-share": (.slice, nil), "sales-profit": (.stack, nil),
    "expectations": (.pop, nil), "guidance": (.scan, nil), "surprise": (.pop, "target"), "calendar": (.flip, "calendar"),
    // Why did it move?
    "why-wiggle": (.wiggle, nil), "why-market": (.wave, "globe.americas.fill"), "why-group": (.collect, nil), "why-unsure": (.scan, nil),
    // Trends, floors and ceilings, signals
    "sideways": (.wiggle, nil), "zoom-out": (.scan, nil), "breakout": (.launch, nil), "hindsight": (.scan, nil),
    "volume": (.wave, "speaker.wave.2.fill"), "moving-average": (.wiggle, nil), "report-jump": (.climb, nil),
  ]

  /// Luna's line when the lesson's own first sentence is too long for the bubble.
  public static let hooks: [SceneAct: String] = [
    .drop: "Every coin you save adds up!", .fill: "Work a little, earn a little!", .candles: "Each candle tells a day's story.",
    .inflate: "Why do prices creep up?", .shield: "Spot the trick. Stay safe!", .pop: "Ready for a surprise?",
    .collect: "Lots of companies in one basket!", .sprout: "Watch a little grow big!", .roll: "Small things can grow and grow.",
    .climb: "Follow the line up the hill!", .wiggle: "Wiggles are normal!", .slice: "Everyone gets a slice!",
    .slide: "Let's see how it works!", .scan: "Let's look for clues!", .flip: "Good things take time.",
    .wave: "Loud is not the same as true.", .tip: "Pick one, give up the other.", .launch: "Up, up and away!",
    .stack: "Money in, money out!", .float: "Watch it float along!", .orbit: "Round and round it goes!",
    .bounce: "Boing! Here it comes!", .sparkle: "Look how it shines!", .think: "Hmm, let's think it out!",
  ]
  // MARK: Step pictures (every picture in a lesson after the first step)

  /// Acts that draw the step's own picture as their prop (the others draw their own things: a cup, candles).
  public static let propActs: Set<SceneAct> = [.drop, .flip, .inflate, .pop, .scan, .shield, .slide, .stack, .tip, .wave,
                                               .float, .orbit, .bounce, .sparkle, .think]
  /// The gentle acts a picture with no entry below gets (picked per step, so a lesson's pages don't all match).
  public static let gentleActs: [SceneAct] = [.float, .bounce, .sparkle, .orbit]

  /// A step picture (its emoji key, drawn by the app's `Art`) → the act that tells its story. Every act here is a
  /// `propActs` act (ScenesTests). Pictures not listed get a gentle act.
  public static let pictureActs: [String: SceneAct] = [
    // Money going somewhere safe
    "🏦": .drop, "🫙": .drop, "💰": .drop, "🐷": .drop, "🏫": .drop,
    // Money and things that add up
    "🪙": .orbit, "💵": .stack, "🏪": .stack, "🧱": .stack, "🤝": .orbit, "👥": .orbit, "🧺": .orbit, "🍕": .orbit,
    // Looking for clues
    "🔍": .scan, "🕵️": .scan, "🔭": .scan, "👀": .scan, "🧾": .scan, "📋": .scan, "📝": .scan, "📊": .scan, "📏": .scan,
    // Time
    "📅": .flip, "⏳": .flip, "🌙": .flip, "🔁": .flip, "🎭": .flip, "🌦️": .flip,
    // Prices and tags
    "🏷️": .inflate, "🛒": .slide, "💳": .slide, "🚲": .slide, "🐢": .slide, "🛤️": .slide,
    // Staying safe
    "🛡️": .shield, "⛑️": .shield, "☔": .shield, "🚩": .shield,
    // Loud things
    "📣": .wave, "🔔": .wave,
    // Surprises and treats
    "🎁": .pop, "✨": .sparkle, "🎯": .pop, "🍋": .pop, "🍰": .pop, "🍎": .pop, "🥚": .pop, "😮": .pop, "🎓": .sparkle,
    // Thinking it through
    "🤔": .think, "🧠": .think, "❓": .think, "🤷": .think, "🔮": .think, "🧩": .think,
    // Ups and downs, wiggles and rides
    "📈": .bounce, "📉": .float, "🎢": .float, "〰️": .float, "🌳": .sparkle, "🌱": .sparkle, "🙋": .bounce, "🤞": .sparkle,
    "🎮": .bounce, "🧸": .bounce, "⛄": .bounce, "🐶": .bounce,
  ]

  /// The scene for a picture at step `index` of `lesson` (nil: no lesson, e.g. a measuring test): the unit's
  /// palette, an act that fits the picture (quiz steps: Luna `think`s), a seed per step. The prop is nil: the
  /// app draws the picture from its own `Art` table.
  public static func step(_ lesson: Lesson?, at index: Int, picture: String, quiz: Bool = false) -> LessonScene {
    let palette = lesson.map { units[$0.unit]?.0 ?? fallbackPalette($0.unit) } ?? fallbackPalette(picture)
    let key = "\(lesson?.id ?? "-")#\(index)#\(picture)"
    let act = quiz ? .think : pictureAct(picture, key: key)
    return LessonScene(act: act, palette: palette, prop: nil, hook: hooks[act] ?? "", seed: seed(key))
  }

  /// The act for a picture: the table's, else a gentle act picked from `key`.
  public static func pictureAct(_ picture: String, key: String) -> SceneAct {
    pictureActs[picture] ?? gentleActs[Int(stableHash(key) % UInt64(gentleActs.count))]
  }

  /// Every picture a lesson shows after its first step (step index, emoji key, is it a quiz), as the player shows
  /// them: say and example steps their own picture, quiz steps the last thing Luna said ("❓"/"🤔" before any).
  public static func pictures(_ lesson: Lesson) -> [(index: Int, picture: String, quiz: Bool)] {
    var out: [(Int, String, Bool)] = []
    var lastSay: String?
    for (i, s) in lesson.steps.enumerated() {
      switch s {
      case let .say(e, _): if i > 0 { out.append((i, e, false)) }; lastSay = e
      case let .example(x): out.append((i, x.emoji, false))
      case .check: out.append((i, lastSay ?? "❓", true))
      case .sort: out.append((i, lastSay ?? "🤔", true))
      case .grow: break
      }
    }
    return out
  }

  /// The bubble holds about this many characters on the smallest phone.
  public static let hookLimit = 44

  public static func scene(for lesson: Lesson) -> LessonScene {
    let unit = units[lesson.unit]
    let palette = unit?.0 ?? fallbackPalette(lesson.unit)
    let pick = lessons[lesson.id]
    let act = pick?.0 ?? unit?.1 ?? .pop
    return LessonScene(act: act, palette: palette, prop: pick?.1, hook: hook(lesson, act: act), seed: seed(lesson.id))
  }

  /// The lesson's own first sentence when it's short enough for the bubble, else the act's line.
  public static func hook(_ lesson: Lesson, act: SceneAct) -> String {
    for s in lesson.steps {
      guard case let .say(_, text) = s else { continue }
      if let first = firstSentence(text), first.count <= hookLimit, first.count >= 8 { return first }
      break
    }
    return hooks[act] ?? "Let's learn something new!"
  }

  static func firstSentence(_ text: String) -> String? {
    let t = text.trimmingCharacters(in: .whitespaces)
    guard let i = t.firstIndex(where: { ".!?".contains($0) }) else { return t.isEmpty ? nil : t }
    return String(t[...i])
  }

  /// A palette for a unit this table has never heard of (a new pack): stable, picked from its id.
  public static func fallbackPalette(_ unit: String) -> ScenePalette {
    let all = ScenePalette.allCases
    return all[Int(stableHash(unit) % UInt64(all.count))]
  }

  static func seed(_ id: String) -> Double { Double(stableHash(id) % 1000) / 1000 }

  /// FNV-1a: the same on every device and every launch (Swift's `hashValue` is randomized per process).
  static func stableHash(_ s: String) -> UInt64 {
    var h: UInt64 = 0xcbf29ce484222325
    for b in s.utf8 { h ^= UInt64(b); h = h &* 0x100000001b3 }
    return h
  }
}
