// Widget buttons. Each intent is tiny and local: update the snapshot first (the widget redraws from it the
// moment the intent returns), then the progress file. No network, no content decoding, nothing leaves the device.
import AppIntents
import MoonClubCore

struct GuessReportIntent: AppIntent {
  static let title: LocalizedStringResource = "Guess a report card"
  static let description = IntentDescription("Guess if a company will beat or miss on its report card day.")
  static let isDiscoverable = false

  @Parameter(title: "Company") var symbol: String
  @Parameter(title: "Report day") var day: String
  @Parameter(title: "Guess") var pick: String

  init() {}
  init(symbol: String, day: String, pick: Pick) { self.symbol = symbol; self.day = day; self.pick = pick.rawValue }

  func perform() async throws -> some IntentResult {
    guard let p = Pick(rawValue: pick) else { return .result() }
    let today = Day.today()
    guard day >= today else { return .result() } // the report is already out: too late to guess
    if let snap = MoonGroup.readSnapshot() { MoonGroup.writeSnapshot(WidgetSnapshots.applyingGuess(snap, s: symbol, d: day, pick: p)) }
    SharedProgressStore().update { $0.guess(Guess(s: symbol, d: day, pick: p, at: today)) }
    return .result()
  }
}

struct ReadStoryIntent: AppIntent {
  static let title: LocalizedStringResource = "I read today's story"
  static let description = IntentDescription("Mark today's Moon Club story as read.")
  static let isDiscoverable = false

  func perform() async throws -> some IntentResult {
    let today = Day.today()
    if var snap = MoonGroup.readSnapshot() { snap.storyRead = true; MoonGroup.writeSnapshot(snap) }
    SharedProgressStore().update { $0.readStory(today: today) }
    return .result()
  }
}
