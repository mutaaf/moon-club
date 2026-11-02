// The timeline entry every widget draws (kept apart from the @main bundle so tests can render the views).
import WidgetKit
import Foundation
import MoonClubCore
#if WIDGET_RENDER_TESTS
@testable import MoonClub // the tests compile these views next to the app's Theme and Shared types
#endif

struct MoonEntry: TimelineEntry {
  let date: Date
  let snap: WidgetSnapshot
  var relevance: TimelineEntryRelevance?
  /// The calendar day this entry is drawn for (entries after midnight roll the day forward).
  var today: String { Day.today(date) }
}

extension WidgetSnapshot {
  /// Before the app's first run on this device: honest and empty (the widget invites you in).
  static func empty(today: String) -> WidgetSnapshot {
    WidgetSnapshot(day: today, mood: nil, storyRead: false, reports: [], piggy: nil, streak: 0, lessonsDone: 0, lessonsTotal: 28,
                   nextLesson: nil, level: "Moon Pup", levelProgress: 0, points: 0)
  }
}

