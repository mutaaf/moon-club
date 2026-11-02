import XCTest
import MoonClubCore
@testable import MoonClub

/// Market World never stacks things on each other: no two stop circles, star pills or Luna's rocket
/// intersect (with 8 pt of air between stops), for every land and every place the rocket can park, at
/// iPhone SE, iPhone 17 and iPad widths. Also: everything stays inside the map, and stops keep clear of
/// the land banners.
@MainActor
final class MapLayoutTests: XCTestCase {
  static let widths: [(String, CGFloat)] = [("iPhone SE", 375), ("iPhone 17", 402), ("iPad", 834)]

  func regions() throws -> [Region] {
    let url = try XCTUnwrap(Bundle(for: AppModel.self).url(forResource: "kids-content", withExtension: "json"))
    return World.regions(try KidsContent.load(try Data(contentsOf: url)))
  }

  func testNoStopsPillsOrRocketOverlapAnywhere() throws {
    let rs = try regions()
    for (name, w) in Self.widths {
      let L = MapLayout(regions: rs, width: w)
      // Every stop's footprint (circle + its pill) across the whole map.
      var marks: [(String, CGRect)] = []
      for (ri, r) in rs.enumerated() {
        for ni in r.nodes.indices {
          marks.append(("\(r.nodes[ni].id) circle", L.circleFrame(ri, ni, r)))
          marks.append(("\(r.nodes[ni].id) stars", L.pillFrame(ri, ni, r)))
        }
      }
      for i in marks.indices {
        for j in marks.indices where j > i && !sameStop(marks[i].0, marks[j].0) {
          XCTAssertFalse(marks[i].1.insetBy(dx: -4, dy: -4).intersects(marks[j].1.insetBy(dx: -4, dy: -4)),
                         "\(name): \(marks[i].0) touches \(marks[j].0)")
        }
        XCTAssertTrue(CGRect(origin: .zero, size: L.size).contains(marks[i].1), "\(name): \(marks[i].0) is off the map")
      }
      // The rocket, parked at each stop in turn, touches nothing but air.
      for (ri, r) in rs.enumerated() {
        for ni in r.nodes.indices {
          let rocket = L.rocketFrame(ri, ni, r)
          XCTAssertTrue(CGRect(origin: .zero, size: L.size).contains(rocket), "\(name): rocket at \(r.nodes[ni].id) is off the map")
          for m in marks { XCTAssertFalse(rocket.intersects(m.1), "\(name): rocket at \(r.nodes[ni].id) sits on \(m.0)") }
        }
        // Stops stay clear of this land's banner and the next land's banner.
        for b in [ri, ri + 1] where b < rs.count {
          let c = L.banner(b), banner = CGRect(x: c.x - 150, y: c.y - 24, width: 300, height: 48)
          for ni in r.nodes.indices {
            XCTAssertFalse(banner.intersects(L.circleFrame(ri, ni, r)) || banner.intersects(L.pillFrame(ri, ni, r)), "\(name): \(r.nodes[ni].id) touches a banner")
          }
        }
      }
    }
  }

  private func sameStop(_ a: String, _ b: String) -> Bool { a.split(separator: " ").first == b.split(separator: " ").first }
}
