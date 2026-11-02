import XCTest
import MoonClubCore
@testable import MoonClub

/// AppModel sync behaviour with an in-memory "iCloud" shared by two models (two devices).
@MainActor
final class SyncAppTests: XCTestCase {
  final class SharedCloud: SyncService {
    var copy: KidsState?
    var isAvailable: Bool { true }
    var isOn = false
    var lastSynced: Date?
    func pull() -> KidsState? { isOn ? copy : nil }
    func push(_ s: KidsState) { if isOn { copy = s; lastSynced = Date() } }
    func observe(_ onChange: @escaping @MainActor (KidsState) -> Void) {}
  }
  final class Device: SyncService {
    let cloud: SharedCloud; var isOn = false
    init(_ c: SharedCloud) { cloud = c }
    var isAvailable: Bool { true }
    var lastSynced: Date? { cloud.lastSynced }
    func pull() -> KidsState? { isOn ? cloud.copy : nil }
    func push(_ s: KidsState) { if isOn { cloud.copy = cloud.copy.map { $0.merged(with: s) } ?? s; cloud.lastSynced = Date() } }
    func observe(_ onChange: @escaping @MainActor (KidsState) -> Void) {}
  }

  func content() throws -> KidsContent {
    let url = try XCTUnwrap(Bundle(for: AppModel.self).url(forResource: "kids-content", withExtension: "json"))
    return try KidsContent.load(try Data(contentsOf: url))
  }
  func model(_ c: KidsContent, _ s: KidsState, sync: SyncService) -> AppModel {
    AppModel(content: c, services: Services(market: FakeMarket(today: "2026-10-31"), luna: LunaRouter(brains: [FakeBrain(kind: .free)], resolve: { .free }), voice: FakeVoice(), store: MemoryStore(s), clock: FixedClock("2026-10-31"), sync: sync))
  }

  func testTurningSyncOnMergesBothDevicesWithoutDoubling() throws {
    let c = try content(), cloud = SharedCloud()
    var a = KidsState(); a.finishLesson("company", today: "2026-10-28")
    var b = KidsState(); b.finishLesson("share", today: "2026-10-29"); b.finishLesson("company", today: "2026-10-30")
    let ipad = model(c, a, sync: Device(cloud)), phone = model(c, b, sync: Device(cloud))
    ipad.setSync(true); phone.setSync(true); ipad.syncNow()
    XCTAssertEqual(Set(ipad.state.lessons), ["company", "share"])
    XCTAssertEqual(ipad.state, phone.state)
    XCTAssertEqual(ipad.points, phone.points)
    var both = KidsState(); both.finishLesson("company", today: "2026-10-28"); both.finishLesson("share", today: "2026-10-29")
    XCTAssertEqual(ipad.points, both.points(c), "points come from the merged progress, not the sum of two devices")
  }

  func testResetEverywhereReachesOtherDevicesAndDeviceOnlyTurnsSyncOff() throws {
    let c = try content(), cloud = SharedCloud()
    var a = KidsState(); a.finishLesson("company", today: "2026-10-28")
    let ipad = model(c, a, sync: Device(cloud)), phone = model(c, a, sync: Device(cloud))
    ipad.setSync(true); phone.setSync(true)
    ipad.resetProgress(.everywhere); phone.syncNow()
    XCTAssertTrue(phone.state.lessons.isEmpty)
    phone.mutate { $0.finishLesson("share", today: "2026-11-02") }
    phone.resetProgress(.thisDevice)
    XCTAssertFalse(phone.syncOn)
    ipad.syncNow()
    XCTAssertEqual(ipad.state.lessons, ["share"], "a this-device reset doesn't reach the iPad")
  }

  func testImportFromWebsiteCodeIsSafeToRepeat() throws {
    let c = try content()
    let raw = try Data(contentsOf: try XCTUnwrap(Bundle(for: AppModel.self).url(forResource: "kids-content", withExtension: "json")))
    let code = ((try JSONSerialization.jsonObject(with: raw) as! [String: Any])["vectors"] as! [String: Any])["transfer"] as! [String: Any]
    let m = model(c, KidsState(), sync: NoSync())
    guard case .success(let n) = m.importProgress(code["code"] as! String) else { return XCTFail("import failed") }
    XCTAssertGreaterThan(n, 0)
    guard case .success(let again) = m.importProgress(code["code"] as! String) else { return XCTFail("second import failed") }
    XCTAssertEqual(again, 0)
    if case .success = m.importProgress("hello") { XCTFail("accepted junk") }
  }
}
