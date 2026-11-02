// Live Activity model, shared by the app (which starts, updates and ends it, locally) and the widget
// extension (which draws it). No push token is ever requested: updates come only from the app.
import ActivityKit
import Foundation

struct MoonActivityAttributes: ActivityAttributes {
  enum Kind: String, Codable, Hashable { case report, lesson }
  var kind: Kind
  /// Report: "SYM:YYYY-MM-DD". Lesson: the lesson id.
  var key: String
  var emoji: String
  /// App content only: a company nickname or a lesson title.
  var title: String
  /// Report: the kid's guess ("beat" / "miss").
  var pick: String?

  struct ContentState: Codable, Hashable {
    /// Report: when the report card comes out. The countdown ticks on-device; at this moment the
    /// activity goes stale and the view flips to "Results are in!" with no update needed.
    var reportAt: Date?
    var step: Int = 0
    var steps: Int = 0
    var done = false
  }
}
