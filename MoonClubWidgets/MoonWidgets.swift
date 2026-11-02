// Moon Club widgets: one provider, five widgets, one Live Activity.
// The provider never touches the network: it reads the snapshot the app publishes to the shared keychain group, so a
// timeline is a file read plus a few dates (WidgetTimeline). Countdowns tick on their own with
// Text(timerInterval:), so there are no per-minute entries.
import WidgetKit
import SwiftUI
import MoonClubCore

struct MoonProvider: TimelineProvider {
  func placeholder(in context: Context) -> MoonEntry { MoonEntry(date: .now, snap: .placeholder) }

  func getSnapshot(in context: Context, completion: @escaping (MoonEntry) -> Void) {
    // The gallery shows the lived-in placeholder so families see what each widget is for.
    completion(MoonEntry(date: .now, snap: context.isPreview ? .placeholder : (MoonShare.readSnapshot() ?? .placeholder)))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<MoonEntry>) -> Void) {
    let now = Date()
    let snap = MoonShare.readSnapshot() ?? .empty(today: Day.today(now))
    let entries = WidgetTimeline.entryDates(snap, now: now).map { d -> MoonEntry in
      // Smart Stack: rise on report-card day, sit quietly otherwise.
      let hot = snap.headline.map { $0.d == Day.today(d) && $0.pick != nil } ?? false
      return MoonEntry(date: d, snap: snap, relevance: TimelineEntryRelevance(score: hot ? 80 : 10))
    }
    completion(Timeline(entries: entries, policy: .atEnd))
  }
}

@main
struct MoonClubWidgetBundle: WidgetBundle {
  var body: some Widget {
    ReportWidget()
    StoryWidget()
    PiggyWidget()
    SchoolWidget()
    LunaWidget()
    MoonLiveActivity()
  }
}

struct ReportWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "report", provider: MoonProvider()) { ReportWidgetView(entry: $0) }
      .configurationDisplayName("Report Card Day")
      .description("Your next report card, your guess and a countdown. Guess beat or miss right here.")
      .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryCircular, .accessoryInline])
  }
}

struct StoryWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "story", provider: MoonProvider()) { StoryWidgetView(entry: $0) }
      .configurationDisplayName("Market Weather")
      .description("Today's market mood as weather, in kid words.")
      .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular, .accessoryInline])
  }
}

struct PiggyWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "piggy", provider: MoonProvider()) { PiggyWidgetView(entry: $0) }
      .configurationDisplayName("Pretend Piggy Bank")
      .description("Your pretend coins and how they've moved.")
      .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
  }
}

struct SchoolWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "school", provider: MoonProvider()) { SchoolWidgetView(entry: $0) }
      .configurationDisplayName("Moon School")
      .description("Your lesson streak and the next one-minute lesson.")
      .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular])
  }
}

struct LunaWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "luna", provider: MoonProvider()) { LunaWidgetView(entry: $0) }
      .configurationDisplayName("Luna's Moon")
      .description("Tonight's real moon phase, and your Moon Club level.")
      .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryInline])
  }
}
