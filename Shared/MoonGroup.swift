// The App Group the app and its widgets share. The app owns the truth (progress.json) and publishes a
// tiny WidgetSnapshot; widgets and their intents read the snapshot and make small, local edits.
// Nothing here touches the network.
import Foundation
import MoonClubCore

enum MoonGroup {
  static let id = "group.com.mutaafaziz.moonclub"
  /// The shared container; nil only if the entitlement is missing (then the app falls back to its own folder).
  static var container: URL? { FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) }
  static var snapshotURL: URL? { container?.appendingPathComponent("widget-snapshot.json") }
  static var progressURL: URL? { container?.appendingPathComponent("progress.json") }

  /// Lock Screen and StandBy widgets render while the phone is locked, so shared files stay readable
  /// after first unlock (not `.complete`).
  static let protection: Data.WritingOptions = [.atomic, .completeFileProtectionUntilFirstUserAuthentication]

  static func readSnapshot() -> WidgetSnapshot? {
    guard let u = snapshotURL, let d = try? Data(contentsOf: u) else { return nil }
    return WidgetSnapshot.decode(d)
  }
  /// Writes only when something changed. Returns true if it wrote (callers then reload timelines).
  @discardableResult static func writeSnapshot(_ s: WidgetSnapshot) -> Bool {
    guard let u = snapshotURL else { return false }
    let d = s.encoded()
    if (try? Data(contentsOf: u)) == d { return false }
    try? d.write(to: u, options: protection)
    return true
  }
}

/// The kid's progress file, shared so a widget tap (a guess, "I read it") lands where the app reads.
final class SharedProgressStore: ProgressStore, @unchecked Sendable {
  let url: URL
  private let lock = NSLock()
  init() {
    let legacyDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("MoonClub")
    let legacy = legacyDir.appendingPathComponent("progress.json")
    if let shared = MoonGroup.progressURL {
      // One-time move from the pre-widget location (0.1.x kept progress in the app's own folder).
      if !FileManager.default.fileExists(atPath: shared.path), FileManager.default.fileExists(atPath: legacy.path) {
        try? FileManager.default.copyItem(at: legacy, to: shared)
      }
      url = shared
    } else {
      try? FileManager.default.createDirectory(at: legacyDir, withIntermediateDirectories: true)
      url = legacy
    }
  }
  func load() -> KidsState { lock.withLock { (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode(KidsState.self, from: $0) } ?? KidsState() } }
  func save(_ s: KidsState) { lock.withLock { if let d = try? JSONEncoder().encode(s) { try? d.write(to: url, options: MoonGroup.protection) } } }
  /// Read-modify-write for widget intents (tiny, synchronous, local).
  func update(_ f: (inout KidsState) -> Void) { var s = load(); f(&s); save(s) }
}

/// In-app deep links (widgets, Live Activities). Internal navigation only, never a link out of the app.
enum MoonLink {
  static let scheme = "moonclub"
  static func tab(_ name: String) -> URL { URL(string: "\(scheme)://tab/\(name)")! }
  static func lesson(_ id: String) -> URL { URL(string: "\(scheme)://lesson/\(id)")! }
}
