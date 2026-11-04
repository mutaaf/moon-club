import SwiftUI
import MoonClubCore

// Market World's Metal layer (0.14): the sea, the fog over locked lands, the comet that lights the trail
// as Luna's rocket flies, and the book-mode atlas page. Shaders live in Design/Shaders.metal; every clock
// goes through `FXClock` (paused off screen and in the background, still under Reduce Motion, Low Power
// Mode and serious heat; it moves for a few seconds after the map appears or is scrolled, then rests).

/// The map's scroll position, read only by the sea (so scrolling never re-renders the map itself).
@MainActor @Observable final class MapScroll {
  var offset: CGPoint = .zero
  var wake = 0
}

/// The sea: viewport-sized, behind the scrolling map, so the shader only ever shades what's on screen.
/// The scroll offset keeps the water moving with the islands; the hinge's sun lights it on iPhone Duo.
struct SeaLayer: View {
  let mapHeight: CGFloat
  /// [centerY, r, g, b] per land, in map coordinates (region color grading).
  let grade: [Float]
  let scroll: MapScroll
  @Environment(DuoModel.self) private var duo: DuoModel?
  var body: some View {
    let sun = Float(duo?.sun ?? 1)
    FXClock(fps: 20, runFor: .seconds(5), wake: scroll.wake) { t, level in
      TiltReader(enabled: level == .full && !FX.shared.lowPower) { tilt in
        GeometryReader { g in
          Rectangle()
            .colorEffect(ShaderLibrary.sea(.float2(g.size), .float(t), .float2(scroll.offset), .float(Float(mapHeight)),
                                           .float(sun), .float2(CGFloat(tilt.x), CGFloat(tilt.y)), .floatArray(grade)))
        }
      }
    }
    .animation(.easeInOut(duration: 0.4), value: sun)
    .ignoresSafeArea()
    .accessibilityHidden(true)
  }

  /// The grading array for these lands: each land's color near it, slate for lands still locked.
  static func grade(_ regions: [Region], layout: MapLayout, open: (Int) -> Bool) -> [Float] {
    regions.indices.flatMap { ri -> [Float] in
      let y = Float(layout.center(ri).y)
      guard open(ri) else { return [y, 0.55, 0.60, 0.72] }
      var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
      UIColor(Hue.named(regions[ri].hue).color).getRed(&r, green: &g, blue: &b, alpha: &a)
      return [y, Float(r), Float(g), Float(b)]
    }
  }
}

/// Fog over a land you haven't reached: shader fog that swirls, parts a little as an iPhone Duo unfolds,
/// and burns away with a golden edge when the land opens (`burnStart`).
struct FogFX: View {
  let region: Region
  var burnStart: Date? = nil
  var wake = 0
  @Environment(DuoModel.self) private var duo: DuoModel?
  @Environment(\.accessibilityReduceMotion) private var rm
  static let burn = 1.8

  var body: some View {
    let part = Float(duo?.fogPart ?? 0)
    let seed = Float(region.id.hashValueStable % 97) / 9
    ZStack {
      if let burnStart, !rm {
        TimelineView(.animation) { ctx in
          let d = min(1, ctx.date.timeIntervalSince(burnStart) / Self.burn)
          fog(t: Float(ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3_600)), dissolve: Float(d), part: part, seed: seed)
        }
      } else {
        // Resting fog is a still frame (it lives inside the scrolling map: an animated layer there made the
        // whole map's display list update every frame). It moves when it parts (hinge) or burns away.
        fog(t: seed * 7, dissolve: 0, part: part, seed: seed)
        Label("Locked", systemImage: "lock.fill").font(.caption.weight(.bold)).foregroundStyle(Palette.ink2)
          .padding(.horizontal, 10).padding(.vertical, 5).background(.white, in: Capsule())
      }
    }
    .animation(.interactiveSpring(response: 0.35), value: part)
    .accessibilityHidden(true)
  }
  private func fog(t: Float, dissolve: Float, part: Float, seed: Float) -> some View {
    GeometryReader { g in
      Rectangle().colorEffect(ShaderLibrary.fog(.float2(g.size), .float(t), .float(dissolve), .float(part), .float(seed)))
    }
  }
}

/// The light that runs along the trail behind Luna's rocket when she flies to the next stop.
struct TrailComet: View {
  struct Flight: Equatable { let a: CGPoint, b: CGPoint, start: Date; let color: Color }
  let flight: Flight?
  static let duration = 0.95
  var body: some View {
    TimelineView(.animation(paused: flight == nil)) { ctx in
      Canvas { g, _ in
        guard let f = flight else { return }
        let k = min(1, ctx.date.timeIntervalSince(f.start) / Self.duration)
        let fade = k > 0.8 ? (1 - k) / 0.2 : 1
        let mid = CGPoint(x: (f.a.x + f.b.x) / 2 + (f.b.y - f.a.y) * 0.18, y: (f.a.y + f.b.y) / 2 - 40)
        func pt(_ u: Double) -> CGPoint {
          let v = 1 - u
          return CGPoint(x: v * v * f.a.x + 2 * v * u * mid.x + u * u * f.b.x, y: v * v * f.a.y + 2 * v * u * mid.y + u * u * f.b.y)
        }
        let head = k * k * (3 - 2 * k)
        var p = Path(); p.move(to: f.a)
        for i in 1...24 { p.addLine(to: pt(head * Double(i) / 24)) }
        g.drawLayer { l in
          l.addFilter(.blur(radius: 8))
          l.stroke(p, with: .color(f.color.opacity(0.9 * fade)), style: .init(lineWidth: 16, lineCap: .round))
        }
        g.stroke(p, with: .color(.white.opacity(0.85 * fade)), style: .init(lineWidth: 3, lineCap: .round))
        let h = pt(head)
        g.fill(Path(ellipseIn: CGRect(x: h.x - 9, y: h.y - 9, width: 18, height: 18)), with: .radialGradient(Gradient(colors: [.white, f.color.opacity(0)]), center: h, startRadius: 0, endRadius: 9))
      }
    }
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }
}

// MARK: - Book-mode atlas (iPhone Duo)

/// The World as an atlas spread: open an iPhone Duo like a book and the left page tells the land's story
/// while the right page is the island. Swipe the page, or give the phone a quick fold flick, to turn to
/// the next land; the map flies there. Shown only where a fold exists (capability, never device).
struct AtlasPage: View {
  let regions: [Region]
  @Binding var page: Int
  let current: (region: Int, node: Int)
  let play: (WorldNode) -> Void
  @Environment(AppModel.self) private var app
  @Environment(DuoModel.self) private var duo: DuoModel?
  @Environment(\.accessibilityReduceMotion) private var rm
  @State private var forward = true

  var body: some View {
    let r = regions[safe: page]
    VStack(alignment: .leading, spacing: 14) {
      DuoCallout(text: "Atlas: swipe or flick the fold to turn", symbol: "book.pages.fill")
      if let r {
        let p = Atlas.page(r)
        let open = World.regionOpen(page, regions, app.state, app.content)
        let stars = r.nodes.reduce(0) { $0 + World.stars($1, app.state, app.content) }
        VStack(alignment: .leading, spacing: 12) {
          HStack(spacing: 12) {
            Glyph(r.art, size: 52)
            VStack(alignment: .leading, spacing: 2) {
              Eyebrow(text: "Land \(page + 1) of \(regions.count)")
              Text(p.title).font(.kTitle).lineLimit(2).minimumScaleFactor(0.7)
            }
          }
          ForEach(p.story, id: \.self) { line in
            Text(line).font(.kRead).fixedSize(horizontal: false, vertical: true)
          }
          HStack(alignment: .top, spacing: 10) {
            Luna(size: 44, mood: .happy)
            VStack(alignment: .leading, spacing: 2) {
              Text("Luna's fact").font(.caption.weight(.heavy)).foregroundStyle(Palette.ink2)
              Text(p.fact).font(.callout.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
            }
          }
          .padding(12)
          .moonGlass(radius: 20, weight: .thin)
          Label(open ? "\(stars) of \(r.nodes.count * 3) stars here" : "Win the land before this one to open it",
                systemImage: open ? (World.conquered(r, app.state, app.content) ? "flag.checkered" : "star.fill") : "lock.fill")
            .font(.callout.weight(.bold)).foregroundStyle(open ? Hue.gold.color : Palette.ink2)
          if open, let n = nextStop(r) {
            Button("Play: \(n.title)") { play(n) }.buttonStyle(ChunkyPrimary())
          }
        }
        .id(page)
        .transition(rm ? .opacity : .asymmetric(insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                                                removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)))
      }
      Spacer(minLength: 0)
      HStack {
        Button { turn(-1) } label: { Image(systemName: "chevron.left").font(.headline.weight(.heavy)).frame(width: 48, height: 48) }
          .disabled(page == 0).accessibilityLabel("Previous land")
        Spacer()
        HStack(spacing: 6) {
          ForEach(regions.indices, id: \.self) { i in Circle().fill(i == page ? Palette.accent : Palette.line).frame(width: 7, height: 7) }
        }
        .accessibilityHidden(true)
        Spacer()
        Button { turn(1) } label: { Image(systemName: "chevron.right").font(.headline.weight(.heavy)).frame(width: 48, height: 48) }
          .disabled(page >= regions.count - 1).accessibilityLabel("Next land")
      }
      .buttonStyle(PressStyle())
    }
    .padding(20)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(Palette.card.opacity(0.92), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    .padding(.vertical, 12)
    .contentShape(Rectangle())
    .gesture(DragGesture(minimumDistance: 30).onEnded { v in
      if v.translation.width < -60 { turn(1) } else if v.translation.width > 60 { turn(-1) }
    })
    .onChange(of: duo?.flickTick ?? 0) { _, _ in turn(page >= regions.count - 1 ? -(regions.count - 1) : 1) }
    .sensoryFeedback(.selection, trigger: page)
    .accessibilityAction(named: "Next land") { turn(1) }
    .accessibilityAction(named: "Previous land") { turn(-1) }
  }

  private func nextStop(_ r: Region) -> WorldNode? {
    r.nodes.first { World.stars($0, app.state, app.content) == 0 && World.nodeOpen($0, in: r, regionOpen: true, app.state, app.content) }
      ?? r.nodes.last { World.nodeOpen($0, in: r, regionOpen: true, app.state, app.content) }
  }

  private func turn(_ step: Int) {
    let next = Atlas.turn(page, by: step, count: regions.count)
    guard next != page else { return }
    forward = next > page
    withAnimation(Motion.safe(Motion.page, rm)) { page = next }
    if duo?.hasHinge == true { app.mutate { $0.useDuo(.atlas) } }
  }
}
