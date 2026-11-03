// Layered caching used by every network-backed service: memory → disk → network, with
// stale-while-revalidate, per-key TTLs, an LRU size cap on disk, and request coalescing (one
// in-flight load per key, every other caller awaits it). Platform-free and unit-tested.
import Foundation

/// A tiny LRU byte store on disk. Entries carry their write time; eviction drops the least
/// recently *used* files once the directory exceeds `capacity` bytes.
public final class DiskLRU: @unchecked Sendable {
  public let dir: URL
  public let capacity: Int
  private let lock = NSLock()
  private let fm = FileManager.default

  public init(dir: URL, capacity: Int) {
    self.dir = dir; self.capacity = capacity
    try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
  }
  static func fileName(_ key: String) -> String {
    // FNV-1a 64 — stable, fast, filename-safe.
    var h: UInt64 = 0xcbf29ce484222325
    for b in key.utf8 { h ^= UInt64(b); h = h &* 0x100000001b3 }
    return String(h, radix: 16)
  }
  private func url(_ key: String) -> URL { dir.appendingPathComponent(Self.fileName(key)) }

  /// Returns the bytes and their age in seconds, touching the entry (LRU).
  public func get(_ key: String, now: Date = Date()) -> (data: Data, age: TimeInterval)? {
    lock.lock(); defer { lock.unlock() }
    let u = url(key)
    guard let d = try? Data(contentsOf: u), d.count >= 8 else { return nil }
    let written = d.prefix(8).withUnsafeBytes { $0.loadUnaligned(as: Double.self) }
    try? fm.setAttributes([.modificationDate: now], ofItemAtPath: u.path)
    return (d.dropFirst(8), now.timeIntervalSince1970 - written)
  }
  public func set(_ key: String, _ data: Data, now: Date = Date()) {
    lock.lock(); defer { lock.unlock() }
    var t = now.timeIntervalSince1970
    var blob = Data(bytes: &t, count: 8); blob.append(data)
    try? blob.write(to: url(key), options: .atomic)
    try? fm.setAttributes([.modificationDate: now], ofItemAtPath: url(key).path)
    evict()
  }
  public func remove(_ key: String) { lock.lock(); try? fm.removeItem(at: url(key)); lock.unlock() }
  public var totalBytes: Int { lock.lock(); defer { lock.unlock() }; return entries().reduce(0) { $0 + $1.size } }

  private func entries() -> [(url: URL, size: Int, used: Date)] {
    let keys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey]
    return ((try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: keys)) ?? []).compactMap { u in
      let v = try? u.resourceValues(forKeys: Set(keys))
      return (u, v?.fileSize ?? 0, v?.contentModificationDate ?? .distantPast)
    }
  }
  private func evict() {
    var all = entries().sorted { $0.used < $1.used }
    var total = all.reduce(0) { $0 + $1.size }
    while total > capacity, let oldest = all.first { try? fm.removeItem(at: oldest.url); total -= oldest.size; all.removeFirst() }
  }
}

/// One in-flight task per key: concurrent callers share the same load.
public actor Coalescer {
  private var inflight: [String: Task<Data, Error>] = [:]
  public init() {}
  public func run(_ key: String, _ work: @escaping @Sendable () async throws -> Data) async throws -> Data {
    if let t = inflight[key] { return try await t.value }
    let t = Task { try await work() }
    inflight[key] = t
    defer { inflight[key] = nil }
    return try await t.value
  }
}

public struct CachePolicy: Sendable {
  /// Fresh for `ttl`; served stale (and refreshed in the background) until `maxStale`.
  public let ttl: TimeInterval; public let maxStale: TimeInterval
  public init(ttl: TimeInterval, maxStale: TimeInterval) { self.ttl = ttl; self.maxStale = maxStale }
  public static let calendar = CachePolicy(ttl: 30 * 60, maxStale: 7 * 86400)
  public static let mood = CachePolicy(ttl: 15 * 60, maxStale: 3 * 86400)
  public static let quotes = CachePolicy(ttl: 2 * 60, maxStale: 3 * 86400)
  public static let ticker = CachePolicy(ttl: 6 * 3600, maxStale: 14 * 86400)
  /// "Why did it move?": refreshed every 15 minutes, an old answer is still worth showing for a day.
  public static let why = CachePolicy(ttl: 15 * 60, maxStale: 86400)
  public static let luna = CachePolicy(ttl: 7 * 86400, maxStale: 7 * 86400)
}

/// memory → disk → network. Stale-while-revalidate: a stale hit returns instantly and a refresh
/// runs in the background; when the network fails, the last good copy (up to maxStale) is served.
public final class LayeredCache: @unchecked Sendable {
  private let disk: DiskLRU
  private let memory = NSCache<NSString, NSData>()
  private var memTime: [String: Date] = [:]
  private let lock = NSLock()
  private let coalescer = Coalescer()
  private let now: @Sendable () -> Date

  public init(disk: DiskLRU, now: @escaping @Sendable () -> Date = { Date() }) { self.disk = disk; self.now = now; memory.countLimit = 64 }

  public func data(_ key: String, policy: CachePolicy, load: @escaping @Sendable () async throws -> Data) async throws -> Data {
    let t = now()
    let (m, mt) = lock.withLock { (memory.object(forKey: key as NSString), memTime[key]) }
    if let m, let mt, t.timeIntervalSince(mt) < policy.ttl { return m as Data }
    if let (d, age) = disk.get(key, now: t) {
      if age < policy.ttl { remember(key, d, at: t.addingTimeInterval(-age)); return d }
      if age < policy.maxStale {
        Task { [weak self] in _ = try? await self?.refresh(key, load) }
        return d
      }
    }
    do { return try await refresh(key, load) }
    catch { if let (d, age) = disk.get(key, now: t), age < policy.maxStale { return d }; throw error }
  }
  @discardableResult
  private func refresh(_ key: String, _ load: @escaping @Sendable () async throws -> Data) async throws -> Data {
    let d = try await coalescer.run(key, load)
    disk.set(key, d, now: now()); remember(key, d, at: now())
    return d
  }
  private func remember(_ key: String, _ d: Data, at: Date) { lock.withLock { memory.setObject(d as NSData, forKey: key as NSString); memTime[key] = at } }
}

/// Normalizes a Luna question so "What's a share?" and "what is a share" share one cache entry.
public func lunaCacheKey(_ question: String, contentVersion: String) -> String {
  let q = question.lowercased().replacingOccurrences(of: "what's", with: "what is")
    .unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) || $0 == " " }
  let words = String(String.UnicodeScalarView(q)).split(separator: " ").joined(separator: " ")
  return "luna:\(contentVersion):\(words)"
}
