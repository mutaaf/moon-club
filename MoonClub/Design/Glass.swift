import SwiftUI

// Liquid Glass (iOS 26+), behind one adaptor so the deployment target can stay iOS 17.
//  • iOS 26+: `glassEffect(Glass.regular[.tint][.interactive], in: shape)`, grouped by `GlassGroup`
//    (a `GlassEffectContainer`) so neighbouring pieces blend and morph, and `glassMorph(id:in:)`
//    (`glassEffectID`) so a piece can flow into another (HUD points pill → results, map stop → game).
//  • iOS 17–25: the material the app always used (`.regularMaterial` / `.thinMaterial`).
//  • Reduce Transparency (any iOS): a solid card colour, so text contrast never depends on what's behind.
// The system tab bar, navigation bars and toolbars adopt Liquid Glass on their own on iOS 26.
// API names checked against the iOS 27.2 SDK's SwiftUICore.swiftinterface (Glass, GlassEffectContainer,
// glassEffect(_:in:), glassEffectID(_:in:)).

enum GlassWeight { case regular, thin }

struct MoonGlass<S: InsettableShape>: ViewModifier {
  let shape: S
  var tint: Color? = nil
  var interactive = false
  var weight: GlassWeight = .regular
  /// A dark stage (bosses): the fallback is a smoky black, and the solid fallback is midnight.
  var dark = false
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

  func body(content: Content) -> some View {
    if reduceTransparency {
      content.background(dark ? Palette.midnight : Palette.card, in: shape)
        .overlay(shape.strokeBorder(Palette.line, lineWidth: 1))
    } else if #available(iOS 26.0, *) {
      content.glassEffect(glass, in: shape)
    } else {
      content.background(fallback, in: shape)
    }
  }

  @available(iOS 26.0, *)
  private var glass: Glass {
    var g: Glass = .regular
    if let tint { g = g.tint(tint) } else if dark { g = g.tint(.black.opacity(0.35)) }
    if interactive { g = g.interactive() }
    return g
  }

  private var fallback: AnyShapeStyle {
    if dark { return AnyShapeStyle(Color.black.opacity(0.28)) }
    if let tint { return AnyShapeStyle(tint.opacity(0.85)) }
    return weight == .thin ? AnyShapeStyle(.thinMaterial) : AnyShapeStyle(.regularMaterial)
  }
}

extension View {
  /// Liquid Glass on iOS 26+, the old material before, solid with Reduce Transparency.
  func moonGlass<S: InsettableShape>(_ shape: S, tint: Color? = nil, interactive: Bool = false, weight: GlassWeight = .regular, dark: Bool = false) -> some View {
    modifier(MoonGlass(shape: shape, tint: tint, interactive: interactive, weight: weight, dark: dark))
  }
  /// Rounded-rect glass, the app's card shape.
  func moonGlass(radius: CGFloat, tint: Color? = nil, interactive: Bool = false, weight: GlassWeight = .regular, dark: Bool = false) -> some View {
    moonGlass(RoundedRectangle(cornerRadius: radius, style: .continuous), tint: tint, interactive: interactive, weight: weight, dark: dark)
  }

  /// Lets this glass piece morph into another with the same id in the same namespace (iOS 26+).
  @ViewBuilder func glassMorph<ID: Hashable & Sendable>(_ id: ID, in ns: Namespace.ID) -> some View {
    if #available(iOS 26.0, *) { glassEffectID(id, in: ns) } else { self }
  }
}

// MARK: - Morphing between screens of one play stage

private struct GlassNSKey: EnvironmentKey { static let defaultValue: Namespace.ID? = nil }
extension EnvironmentValues { var glassNamespace: Namespace.ID? { get { self[GlassNSKey.self] } set { self[GlassNSKey.self] = newValue } } }

/// A play stage (a game, boss or lesson): one glass container and one namespace, so a piece tagged with
/// `GlassMorphID` (the HUD's points pill) flows into the piece with the same id when the screen changes
/// (the results' points card).
struct GlassStage<Content: View>: View {
  @ViewBuilder var content: Content
  @Namespace private var ns
  var body: some View { GlassGroup { content }.environment(\.glassNamespace, ns) }
}

extension View { func glassStage() -> some View { GlassStage { self } } }

struct GlassMorphID: ViewModifier {
  let id: String
  @Environment(\.glassNamespace) private var ns
  func body(content: Content) -> some View {
    if let ns { content.glassMorph(id, in: ns) } else { content }
  }
}

// MARK: - Map stop → game (zoom navigation transition, iOS 18+)

extension View {
  @ViewBuilder func zoomSource<ID: Hashable>(_ id: ID, in ns: Namespace.ID) -> some View {
    if #available(iOS 18.0, *) { matchedTransitionSource(id: id, in: ns) } else { self }
  }
  @ViewBuilder func zoomFrom<ID: Hashable>(_ id: ID, in ns: Namespace.ID) -> some View {
    if #available(iOS 18.0, *) { navigationTransition(.zoom(sourceID: id, in: ns)) } else { self }
  }
}

/// Groups glass pieces so they render as one sheet of glass and can merge/morph (iOS 26+).
struct GlassGroup<Content: View>: View {
  var spacing: CGFloat? = nil
  @ViewBuilder var content: Content
  var body: some View {
    if #available(iOS 26.0, *) { GlassEffectContainer(spacing: spacing) { content } } else { content }
  }
}
