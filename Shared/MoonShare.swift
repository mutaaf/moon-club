// What the app and its widgets share: the kid's progress and a tiny WidgetSnapshot.
//
// Storage is a shared *keychain access group* (`<TeamID>.com.mutaafaziz.moonclub.shared`), not an App Group:
// every provisioning profile on this team already allows `<TeamID>.*` keychain groups, so app + widget
// share data with zero developer-portal setup (the App Store Connect API has no App Groups endpoint, and
// our API key can't run Xcode's automatic provisioning). Items are `AfterFirstUnlockThisDeviceOnly`:
// readable by Lock Screen/StandBy widgets after the first unlock, never synced to iCloud, never in backups
// that leave the device. Nothing here touches the network.
import Foundation
import Security
import MoonClubCore

enum MoonShare {
  /// From Info.plist (`MoonKeychainGroup = $(AppIdentifierPrefix)com.mutaafaziz.moonclub.shared`).
  static let accessGroup: String? = Bundle.main.object(forInfoDictionaryKey: "MoonKeychainGroup") as? String
  static let service = "com.mutaafaziz.moonclub.shared"

  private static func base(_ key: String) -> [String: Any] {
    var q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: key,
                            kSecUseDataProtectionKeychain as String: true]
    if let g = accessGroup, !g.isEmpty, !g.hasPrefix("$(") { q[kSecAttrAccessGroup as String] = g }
    return q
  }
  static func read(_ key: String) -> Data? {
    var q = base(key); q[kSecReturnData as String] = true; q[kSecMatchLimit as String] = kSecMatchLimitOne
    var out: CFTypeRef?
    return SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess ? out as? Data : nil
  }
  @discardableResult static func write(_ key: String, _ data: Data) -> Bool {
    let attrs: [String: Any] = [kSecValueData as String: data, kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
    let st = SecItemUpdate(base(key) as CFDictionary, attrs as CFDictionary)
    if st == errSecItemNotFound { return SecItemAdd(base(key).merging(attrs) { $1 } as CFDictionary, nil) == errSecSuccess }
    return st == errSecSuccess
  }
  static func remove(_ key: String) { SecItemDelete(base(key) as CFDictionary) }

  // MARK: Widget snapshot
  static func readSnapshot() -> WidgetSnapshot? { read("snapshot").flatMap(WidgetSnapshot.decode) }
  /// Writes only when something changed. Returns true if it wrote (callers then reload timelines).
  @discardableResult static func writeSnapshot(_ s: WidgetSnapshot) -> Bool {
    let d = s.encoded()
    if read("snapshot") == d { return false }
    return write("snapshot", d)
  }
}

/// The kid's progress, shared so a widget tap (a guess, "I read it") lands where the app reads it.
final class SharedProgressStore: ProgressStore, @unchecked Sendable {
  private let lock = NSLock()
  private let key = "progress"
  init() {
    // One-time move from the pre-widget file (0.1.x – 0.2.x kept progress in Application Support).
    let legacy = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("MoonClub/progress.json")
    if MoonShare.read(key) == nil, let d = try? Data(contentsOf: legacy), (try? JSONDecoder().decode(KidsState.self, from: d)) != nil {
      if MoonShare.write(key, d) { try? FileManager.default.removeItem(at: legacy) }
    }
  }
  func load() -> KidsState { lock.withLock { MoonShare.read(key).flatMap { try? JSONDecoder().decode(KidsState.self, from: $0) } ?? KidsState() } }
  func save(_ s: KidsState) { lock.withLock { if let d = try? JSONEncoder().encode(s) { MoonShare.write(key, d) } } }
  /// Read-modify-write for widget intents (tiny, synchronous, local).
  func update(_ f: (inout KidsState) -> Void) { var s = load(); f(&s); save(s) }
}

/// In-app deep links (widgets, Live Activities). Internal navigation only, never a link out of the app.
enum MoonLink {
  static let scheme = "moonclub"
  static func tab(_ name: String) -> URL { URL(string: "\(scheme)://tab/\(name)")! }
  static func lesson(_ id: String) -> URL { URL(string: "\(scheme)://lesson/\(id)")! }
}
