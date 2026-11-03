import Foundation

/// Which build this is. App Store builds are archived with the `STORE_BUILD` compilation condition
/// (`make appstore-build`, docs/APPSTORE.md); TestFlight family builds and Debug builds are not.
///
/// An App Store build never offers a grown-up's own AI or voice key: a child's typed questions must not go to a
/// third-party AI company (App Review 1.3 / 5.1.4, COPPA, and most providers' terms exclude under-13s). Luna then
/// thinks on the device (Apple Intelligence) or uses our own free kid-safe brain, which keeps nothing.
/// The check is compile-time, so App Review sees exactly what the App Store ships.
enum Distribution {
  #if STORE_BUILD
  static let isStore = true
  #else
  static let isStore = false
  #endif
  /// Grown-up "bring your own key" features (Super Luna, provider voices).
  static var allowsOwnKeys: Bool { !isStore }
}
