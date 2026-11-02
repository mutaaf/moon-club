// swift-tools-version: 6.0
import PackageDescription

// MoonClubCore: pure, platform-free logic + models + content decoding for Moon Club.
// No UIKit/SwiftUI here — everything is unit-tested and mirrors the web (metaphases shared/kids*.ts)
// through the vectors exported in kids-content.json.
let package = Package(
  name: "MoonClubCore",
  platforms: [.iOS(.v17), .macOS(.v14)],
  products: [.library(name: "MoonClubCore", targets: ["MoonClubCore"])],
  targets: [
    .target(name: "MoonClubCore", swiftSettings: [.swiftLanguageMode(.v5)]),
    .testTarget(name: "MoonClubCoreTests", dependencies: ["MoonClubCore"], resources: [.copy("Resources/kids-content.json"), .copy("Resources/candles.json")], swiftSettings: [.swiftLanguageMode(.v5)]),
  ]
)
