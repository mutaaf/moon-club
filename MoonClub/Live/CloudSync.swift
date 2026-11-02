import Foundation
import MoonClubCore

/// Progress sync between the family's own devices. The only live implementation is iCloud key-value
/// storage: progress goes into the family's iCloud account, never to a server of ours. A grown-up turns it
/// on behind the gate. It's off by default, because two children sharing one Apple ID would otherwise merge
/// their progress.
protocol SyncService: AnyObject {
  /// iCloud is signed in on this device (the toggle explains why it can't turn on otherwise).
  var isAvailable: Bool { get }
  var isOn: Bool { get set }
  var lastSynced: Date? { get }
  /// The latest synced copy, if any.
  func pull() -> KidsState?
  /// Queue a write (debounced, so a burst of taps is one write).
  func push(_ s: KidsState)
  /// Called on the main actor when another device changed the synced copy.
  func observe(_ onChange: @escaping @MainActor (KidsState) -> Void)
}

/// No sync: tests, previews, and builds without the iCloud entitlement.
final class NoSync: SyncService {
  var isAvailable: Bool { false }
  var isOn = false
  var lastSynced: Date? { nil }
  func pull() -> KidsState? { nil }
  func push(_ s: KidsState) {}
  func observe(_ onChange: @escaping @MainActor (KidsState) -> Void) {}
}

/// Demo mode (screenshots): looks signed in, keeps everything in memory.
final class DemoSync: SyncService {
  var isAvailable: Bool { true }
  var isOn: Bool
  var lastSynced: Date?
  private var copy: KidsState?
  init(on: Bool) { isOn = on; lastSynced = on ? Date(timeIntervalSinceNow: -120) : nil }
  func pull() -> KidsState? { copy }
  func push(_ s: KidsState) { copy = s; lastSynced = Date() }
  func observe(_ onChange: @escaping @MainActor (KidsState) -> Void) {}
}

/// iCloud key-value storage (`NSUbiquitousKeyValueStore`). It holds one compact JSON value, well under
/// the 1 MB limit (`Sync.payload` trims old guesses). Writes are debounced by 1.5 s; changes from other
/// devices arrive through `didChangeExternallyNotification`. The on/off switch and "last synced" live in
/// this device's UserDefaults, so turning sync off on one device doesn't turn it off everywhere.
final class ICloudSync: SyncService {
  static let key = "progress.v1"
  private let kv = NSUbiquitousKeyValueStore.default
  private let defaults = UserDefaults.standard
  private var pending: DispatchWorkItem?
  private var token: NSObjectProtocol?

  var isAvailable: Bool { FileManager.default.ubiquityIdentityToken != nil }
  var isOn: Bool {
    get { defaults.bool(forKey: "sync.on") }
    set { defaults.set(newValue, forKey: "sync.on"); if newValue { kv.synchronize() } }
  }
  var lastSynced: Date? { defaults.object(forKey: "sync.last") as? Date }

  func pull() -> KidsState? {
    guard isOn, let d = kv.data(forKey: Self.key) else { return nil }
    return Sync.decode(d)
  }

  func push(_ s: KidsState) {
    guard isOn else { return }
    pending?.cancel()
    let data = Sync.payload(s)
    let work = DispatchWorkItem { [weak self] in
      guard let self, self.isOn else { return }
      if self.kv.data(forKey: Self.key) != data { self.kv.set(data, forKey: Self.key) }
      self.kv.synchronize()
      self.defaults.set(Date(), forKey: "sync.last")
    }
    pending = work
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
  }

  func observe(_ onChange: @escaping @MainActor (KidsState) -> Void) {
    token = NotificationCenter.default.addObserver(forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: kv, queue: .main) { [weak self] note in
      guard let self, self.isOn else { return }
      let keys = note.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] ?? []
      guard keys.isEmpty || keys.contains(Self.key), let d = self.kv.data(forKey: Self.key), let s = Sync.decode(d) else { return }
      self.defaults.set(Date(), forKey: "sync.last")
      MainActor.assumeIsolated { onChange(s) }
    }
    kv.synchronize()
  }

  deinit { if let token { NotificationCenter.default.removeObserver(token) } }
}
