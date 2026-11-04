import SwiftUI
import QuartzCore
import MoonClubCore

// iPhone Duo, the SwiftUI side. One `onHingeChange` per scene feeds a tiny @Observable model; every
// decision is a pure function in MoonClubCore (Duo.swift). Two rules from Apple's guidance:
//  • the hinge drives effects only (Luna's moon, the piggy lid, tucking Luna in) — never layout;
//  • layout reads the fold's reserved region (`TwoPage`, `FoldColumns`) and size classes.
// On every device without a hinge the context is nil and nothing here changes the app.

/// Per-scene hinge state. Split into separate properties so Observation only redraws the views that
/// read each one: most screens never touch it, the hero moon reads `phase`, the piggy reads `lid`.
@MainActor @Observable
final class DuoModel {
  private(set) var reading: HingeReading?
  private(set) var illumination = 1.0
  private(set) var phase = 4
  private(set) var lid = 0.0
  /// Ticks once each time the phone closes / opens flat — triggers for haptics and "tuck Luna in".
  private(set) var closedTick = 0
  private(set) var flatTick = 0
  /// 0.14 hinge light (MoonClubCore `HingeLight`), rounded so shaders redraw only on visible changes.
  private(set) var sun = 1.0
  private(set) var lunaLight = HingeLight.lunaLight(nil)
  private(set) var seam = 0.0
  private(set) var fogPart = 0.0
  /// Stood up like a tent, steady for a moment (emulated: the SDK has no posture API).
  private(set) var isTent = false
  /// Ticks on each quick fold flick (turns the World atlas page).
  private(set) var flickTick = 0
  @ObservationIgnored private var tentTracker = Stance.Tracker()
  @ObservationIgnored private var flick = PageFlick()
  /// Debug-only pose pinned by a launch argument (`-pose book|tabletop|flat|closed`, `-hinge 110`).
  let pinned: Pose?

  init() {
    #if DEBUG
    let a = ProcessInfo.processInfo.arguments
    pinned = a.firstIndex(of: "-pose").flatMap { $0 + 1 < a.count ? Pose(rawValue: a[$0 + 1]) : nil }
    let deg = a.firstIndex(of: "-hinge").flatMap { $0 + 1 < a.count ? Double(a[$0 + 1]) : nil }
    switch pinned {
    case .closed?: apply(.init(.closed, degrees: 0))
    case .flat?: apply(.init(.fullyOpen, degrees: 180))
    case .book?, .tabletop?: apply(.init(.partiallyOpen, degrees: deg ?? 110))
    case .tent?: apply(.init(.partiallyOpen, degrees: deg ?? 75)); isTent = true
    default: break
    }
    #else
    pinned = nil
    #endif
  }

  var pose: Pose { pinned ?? Pose.of(reading, fold: nil) }
  /// The pose including the emulated tent.
  var stance: Pose { isTent ? .tent : pose }
  var isPartiallyOpen: Bool { reading?.status == .partiallyOpen }

  /// Called from the hinge handler: cheap value math only, assigns only what changed.
  func update(_ new: HingeReading?) {
    guard pinned == nil, new != reading else { return }
    apply(new)
  }

  private func apply(_ new: HingeReading?) {
    switch HingeMoment.between(reading, new) {
    case .closed?: closedTick &+= 1
    case .openedFlat?: flatTick &+= 1
    case nil: break
    }
    reading = new
    let ill = (HingeMoon.illumination(new) * 50).rounded() / 50   // 2% steps: smooth to the eye, few redraws
    if ill != illumination { illumination = ill }
    let ph = HingeMoon.phase(new); if ph != phase { phase = ph }
    let l = (PiggyLid.open(new) * 50).rounded() / 50; if l != lid { lid = l }
    let q = { (v: Double) in (v * 50).rounded() / 50 }
    let su = q(HingeLight.sun(new)); if su != sun { sun = su }
    let ll = q(HingeLight.lunaLight(new)); if ll != lunaLight { lunaLight = ll }
    let se = q(HingeLight.seam(new)); if se != seam { seam = se }
    let fp = q(HingeLight.fogPart(new)); if fp != fogPart { fogPart = fp }
    guard pinned == nil else { return }
    let now = CACurrentMediaTime()
    let tent = tentTracker.feed(new, at: now); if tent != isTent { isTent = tent }
    if tentTracker.since != nil, !tent {
      Task { @MainActor [weak self] in try? await Task.sleep(for: .seconds(Stance.settle + 0.05)); self?.tickTent() }
    }
    if flick.feed(new, at: now) { flickTick &+= 1 }
  }

  #if DEBUG
  /// Debug recordings only: plays a hinge reading even when a pose is pinned (the simulator can't fold).
  func debugSet(_ r: HingeReading) { apply(r) }
  #endif

  /// Re-checks the tent clock (the hinge may sit still once it's in the window, so no new reading arrives).
  func tickTent() {
    guard pinned == nil else { return }
    let tent = tentTracker.feed(reading, at: CACurrentMediaTime()); if tent != isTent { isTent = tent }
  }
}

extension HingeReading {
  @available(iOS 27.1, *)
  init(_ h: DeviceHinge) {
    let s: Status = h.status == .closed ? .closed : h.status == .fullyOpen ? .fullyOpen : .partiallyOpen
    self.init(s, degrees: h.angle.degrees)
  }
}

/// The one hinge listener, at the root of each scene.
struct TracksHinge: ViewModifier {
  let duo: DuoModel
  func body(content: Content) -> some View {
    if #available(iOS 27.1, *) {
      content
        .onHingeChange(isEnabled: duo.pinned == nil) { _, new in duo.update(new.hinge.map(HingeReading.init)) }
        .environment(duo)
    } else {
      content.environment(duo)
    }
  }
}

extension EnvironmentValues {
  /// True when a toolbar item sits in a vertical bar (iPhone Duo moves bars to the side).
  var toolbarVertical: Bool {
    if #available(iOS 27.1, *) { return toolbarVerticalEdge != nil }
    return false
  }
}

// MARK: - The fold

/// What a container knows about the fold: its width and the division region in its own coordinates.
struct FoldInfo: Equatable {
  var width: CGFloat = 0
  var fold: CGRect?
}

/// Measures the container and reads the fold's division region (active when partially open, inactive
/// when flat — both are where content shouldn't sit, so both shape the gutter). Debug poses synthesize
/// a 40 pt fold at the center so the layouts can be screenshot on simulators that can't fold.
private struct FoldProbe: ViewModifier {
  @Binding var info: FoldInfo
  @Environment(DuoModel.self) private var duo: DuoModel?
  func body(content: Content) -> some View {
    content.background {
      GeometryReader { proxy in
        let i = FoldInfo(width: proxy.size.width, fold: fold(proxy))
        Color.clear
          .onAppear { info = i }
          .onChange(of: i) { _, n in info = n }
      }
    }
  }
  private func fold(_ proxy: GeometryProxy) -> CGRect? {
    if #available(iOS 27.1, *),
       let r = proxy.reservedRegions(kind: .division, options: [.includeInactive]).first,
       r.frame.intersects(CGRect(origin: .zero, size: proxy.size)) {
      return r.frame
    }
    #if DEBUG
    if let p = duo?.pinned, [.book, .flat, .tent].contains(p), proxy.size.width >= 560 {
      return CGRect(x: proxy.size.width / 2 - 20, y: 0, width: 40, height: proxy.size.height)
    }
    #endif
    return nil
  }
}
extension View { func foldProbe(_ info: Binding<FoldInfo>) -> some View { modifier(FoldProbe(info: info)) } }

/// A storybook spread: two pages side by side, one on each side of the fold, when there's room;
/// otherwise the pages stack in one column. Pages never sit across the fold. With no hinge but a wide
/// window (iPad, iPhone Duo flat before the region reports), the gutter is the center.
struct TwoPage<First: View, Second: View>: View {
  var spacing: CGFloat = 18
  var minPage: CGFloat = 280
  @ViewBuilder var first: First
  @ViewBuilder var second: Second
  var body: some View {
    Storybook(spacing: spacing, minPage: minPage) {
      VStack(alignment: .leading, spacing: spacing) { first; second }
    } first: { first } second: { second }
  }
}

/// The general form: `single` when there's one page's worth of room, `first | second` around the fold
/// when there are two. `fill` stretches both pages to the full height (for non-scrolling players).
struct Storybook<Single: View, First: View, Second: View>: View {
  var spacing: CGFloat = 18
  var minPage: CGFloat = 280
  var fill = false
  @ViewBuilder var single: Single
  @ViewBuilder var first: First
  @ViewBuilder var second: Second
  @State private var info = FoldInfo()
  @Environment(\.accessibilityReduceMotion) private var rm

  var body: some View {
    let s = split
    Group {
      if let s {
        PageSplit(split: s, fill: fill) {
          VStack(alignment: .leading, spacing: spacing) { first }
            .frame(maxWidth: .infinity, maxHeight: fill ? .infinity : nil, alignment: .topLeading)
          VStack(alignment: .leading, spacing: spacing) { second }
            .frame(maxWidth: .infinity, maxHeight: fill ? .infinity : nil, alignment: .topLeading)
        }
        .transition(.opacity)
      } else {
        single.transition(.opacity)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: fill ? .infinity : nil, alignment: .topLeading)
    .foldProbe($info)
    .animation(rm ? nil : .spring(response: 0.5, dampingFraction: 0.86), value: s == nil)
  }

  private var split: FoldInfo.Split? { info.split(minPage: minPage) }
}

/// Lays out exactly two pages with a gutter, always at the *proposed* width (scaling the measured split
/// if the container changed size), so the measurement can never feed back into a wider frame.
struct PageSplit: Layout {
  var split: FoldInfo.Split
  var fill = false
  private func widths(_ w: CGFloat) -> (CGFloat, CGFloat, CGFloat) {
    let total = split.lead + split.gap + split.trail
    let k = total > 0 ? w / total : 1
    return (split.lead * k, split.gap * k, split.trail * k)
  }
  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let w = proposal.width ?? (split.lead + split.gap + split.trail)
    let (a, _, c) = widths(w)
    if fill, let h = proposal.height { return CGSize(width: w, height: h) }
    let hs = zip(subviews, [a, c]).map { $0.sizeThatFits(ProposedViewSize(width: $1, height: proposal.height)).height }
    return CGSize(width: w, height: hs.max() ?? 0)
  }
  func placeSubviews(in b: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    let (a, g, c) = widths(b.width)
    let h: CGFloat? = fill ? b.height : nil
    if subviews.count > 0 { subviews[0].place(at: CGPoint(x: b.minX, y: b.minY), proposal: ProposedViewSize(width: a, height: h)) }
    if subviews.count > 1 { subviews[1].place(at: CGPoint(x: b.minX + a + g, y: b.minY), proposal: ProposedViewSize(width: c, height: h)) }
  }
}

extension FoldInfo {
  struct Split: Equatable { var lead: CGFloat, gap: CGFloat, trail: CGFloat }
  /// Two page widths and the gutter between them, or nil for one page. A vertical fold (book pose, or
  /// flat) sets the gutter; with no fold, a wide window splits at the center.
  func split(minPage: CGFloat) -> Split? {
    guard width > 0 else { return nil }
    if let f = fold, f.height >= f.width,
       let sp = Fold.spread(in: CGRect(x: 0, y: 0, width: width, height: max(f.maxY, 1)), fold: f, minPage: minPage) {
      return Split(lead: sp.first.width, gap: f.width, trail: sp.second.width)
    }
    guard width >= minPage * 2 + 32 else { return nil }
    return Split(lead: (width - 32) / 2, gap: 32, trail: (width - 32) / 2)
  }
}

/// iPhone Duo tabletop mode: when the fold is horizontal and *active* (half open, set down like a laptop),
/// `top` (the chart, the boss) fills the upright half and `bottom` (the answers) becomes the game pad on
/// the flat half, with nothing on the crease. Anywhere else (no hinge, book pose, flat, iPad) the two simply
/// stack. Decided by the fold region (capability), never by device. `active` reports the mode to the
/// caller (for the Tabletop Trader trophy and Luna's line).
struct TabletopStage<Top: View, Bottom: View>: View {
  @Binding var active: Bool
  var spacing: CGFloat = 12
  var dark = true
  @ViewBuilder var top: Top
  @ViewBuilder var bottom: Bottom
  @Environment(DuoModel.self) private var duo: DuoModel?
  @Environment(\.accessibilityReduceMotion) private var rm

  var body: some View {
    GeometryReader { g in
      let f = horizontalFold(g)
      Group {
        if let f {
          VStack(spacing: 0) {
            top.frame(maxWidth: .infinity).frame(height: max(0, f.minY - 8))
            Color.clear.frame(height: f.height + 16).accessibilityHidden(true)
            VStack(spacing: 8) {
              DuoCallout(text: "Tabletop mode: this half is your game pad", symbol: "laptopcomputer", dark: dark)
              bottom
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
          }
          .transition(.opacity)
        } else {
          VStack(spacing: spacing) { top; bottom }
        }
      }
      .animation(rm ? nil : Motion.page, value: f != nil)
      .onChange(of: f != nil, initial: true) { _, on in if active != on { active = on } }
    }
  }

  private func horizontalFold(_ proxy: GeometryProxy) -> CGRect? {
    if #available(iOS 27.1, *),
       let r = proxy.reservedRegions(kind: .division).first(where: { $0.frame.width > $0.frame.height }),
       r.frame.intersects(CGRect(origin: .zero, size: proxy.size)) {
      return r.frame
    }
    #if DEBUG
    if duo?.pinned == .tabletop, proxy.size.height >= 400 {
      return CGRect(x: 0, y: proxy.size.height / 2 - 20, width: proxy.size.width, height: 40)
    }
    #endif
    return nil
  }
}

/// Grid columns that stay even whenever the fold crosses the grid, so cards split cleanly.
struct FoldColumns<Content: View>: View {
  var minimum: CGFloat
  var spacing: CGFloat = 12
  @ViewBuilder var content: Content
  @State private var info = FoldInfo()
  var body: some View {
    let crosses = info.fold.map { $0.height >= $0.width } ?? false
    let n = Fold.columns(width: info.width, minimum: minimum, spacing: spacing, foldCrosses: crosses)
    // With a fold, the middle gap becomes a gutter as wide as the fold (margins included).
    let cols = (0..<n).map { i in GridItem(.flexible(), spacing: crosses && i == n / 2 - 1 ? max(spacing, info.fold!.width) : spacing) }
    LazyVGrid(columns: cols, spacing: spacing) { content }
      .foldProbe($info)
  }
}

// MARK: - Hinge effects (no layout)

/// A moon whose lit part follows the hinge: new when closed, waxing as it opens, full when flat.
struct MoonDisc: View {
  var illumination: Double
  var size: CGFloat = 56
  var body: some View {
    Canvas { ctx, sz in
      let r = min(sz.width, sz.height) / 2, c = CGPoint(x: sz.width / 2, y: sz.height / 2)
      let disc = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
      ctx.fill(disc, with: .color(Palette.midnight.opacity(0.85)))
      // Lit region = right half-disc ± a terminator ellipse whose half-width is |1 - 2k| · r.
      let k = max(0, min(1, illumination)), w = abs(1 - 2 * k) * r
      var lit = Path()
      lit.addArc(center: c, radius: r, startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: false)
      let term = Path(ellipseIn: CGRect(x: c.x - w, y: c.y - r, width: 2 * w, height: 2 * r))
      ctx.fill(lit, with: .color(Palette.moon))
      if k < 0.5 { ctx.fill(term, with: .color(Palette.midnight.opacity(0.85))) }   // crescent
      else { ctx.fill(term, with: .color(Palette.moon)) }                          // gibbous
      ctx.stroke(disc, with: .color(Palette.accent), lineWidth: max(1.5, r * 0.08))
    }
    .frame(width: size, height: size)
    .shadow(color: Palette.moon.opacity(0.5 * illumination), radius: size * 0.25)
    .accessibilityHidden(true)
  }
}

/// Hero art: Luna (or the screen's emoji) — but while the phone is partly open, Luna's moon waxes
/// with the hinge. Only this small view observes the hinge, so the rest of the screen never redraws.
struct HingeHeroArt<Rest: View>: View {
  var enabled = true
  var size: CGFloat = 56
  @ViewBuilder var rest: Rest
  @Environment(DuoModel.self) private var duo: DuoModel?
  @Environment(\.accessibilityReduceMotion) private var rm
  var body: some View {
    if enabled, let duo, duo.isPartiallyOpen {
      MoonDisc(illumination: duo.illumination, size: size)
        .animation(rm ? nil : .interactiveSpring(response: 0.2), value: duo.illumination)
        .sensoryFeedback(.selection, trigger: duo.phase)
        .accessibilityElement()
        .accessibilityLabel(HingeMoon.name(duo.phase))
        .transition(.scale.combined(with: .opacity))
    } else {
      rest
    }
  }
}

/// 🐷 The piggy bank's lid lifts as the phone opens, and coins peek out.
struct PiggyArt: View {
  var size: CGFloat = 44
  @Environment(DuoModel.self) private var duo: DuoModel?
  @Environment(\.accessibilityReduceMotion) private var rm
  var body: some View {
    let lid = rm ? 0 : (duo?.lid ?? 0)
    ZStack(alignment: .top) {
      PiggyMark().frame(width: size * 1.1, height: size * 0.9).offset(y: size * 0.12)
      // The lid: a little coin-slot hatch on the pig's back, hinged at the left.
      Capsule().fill(Palette.blush).frame(width: size * 0.5, height: size * 0.12)
        .overlay(Capsule().strokeBorder(Palette.midnight.opacity(0.5), lineWidth: 1))
        .rotationEffect(.degrees(-70 * lid), anchor: .leading)
        .offset(y: size * 0.02)
      ForEach(0..<3, id: \.self) { i in
        Glyph("🪙", size: size * 0.36, style: .plain)
          .offset(x: CGFloat(i - 1) * size * 0.2, y: -size * 0.45 * lid * (1 + Double(i % 2) * 0.4))
          .opacity(min(1, lid * 3))
      }
    }
    .frame(width: size * 1.2, height: size * 1.2)
    .animation(rm ? nil : .interactiveSpring(response: 0.25), value: lid)
    .accessibilityHidden(true)
  }
}

/// Luna asleep: shown when a finished lesson is closed up for the night.
struct SleepyLuna: View {
  var size: CGFloat = 110
  var body: some View {
    ZStack(alignment: .topTrailing) {
      Luna(size: size).overlay {
        // Closed, smiling eyes over Luna's open ones.
        HStack(spacing: size * 0.2) { lid; lid }.offset(y: -size * 0.045)
      }
      Image(systemName: "moon.zzz.fill").font(.system(size: size * 0.26, weight: .bold)).foregroundStyle(Hue.grape.color).offset(x: size * 0.18, y: -size * 0.12)
    }
    .accessibilityHidden(true)
  }
  private var lid: some View {
    Path { p in p.addArc(center: .init(x: size * 0.05, y: 0), radius: size * 0.05, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false) }
      .stroke(Palette.midnight, style: .init(lineWidth: size * 0.035, lineCap: .round))
      .frame(width: size * 0.1, height: size * 0.06)
      .background(Palette.moon.frame(width: size * 0.12, height: size * 0.11).offset(y: -size * 0.02))
  }
}
