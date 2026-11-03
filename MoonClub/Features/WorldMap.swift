import SwiftUI
import MoonClubCore

/// Market World: the heart of the app. One explorable map, bottom to top, seven lands to conquer. It
/// replaced Moon School's list as a tab because the map *is* the curriculum: one path, every lesson on it,
/// and the chart games and bosses live between the lessons. The full lesson list is still one tap away.
///
/// Performance: the sea, islands and trail are one Canvas (redrawn only when progress changes); nodes are
/// plain buttons; the cloud parallax uses `visualEffect` (no state writes while scrolling).
struct WorldView: View {
  @Environment(AppModel.self) private var app
  @Environment(\.openQuest) private var openQuest
  @Environment(\.accessibilityReduceMotion) private var rm
  @State private var selected: WorldNode?
  @State private var playing: WorldNode?
  @State private var lesson: Lesson?
  @State private var zoom: CGFloat = 1
  @GestureState private var pinch: CGFloat = 1
  @State private var fold = FoldInfo()
  @State private var conquered: Set<String> = []
  @State private var burst = 0
  @State private var didScroll = false
  /// Where Luna's rocket is drawn; it flies along the trail to the next stop after a win.
  @State private var rocketAt: CGPoint?
  @State private var rocketKey = ""
  @State private var rocketTilt: Double = 0

  var body: some View {
    let regions = World.regions(app.content)
    let cur = World.current(regions, app.state, app.content)
    let currentNode = regions.isEmpty ? nil : regions[cur.region].nodes[cur.node]
    GeometryReader { geo in
      let split = fold.split(minPage: 300)
      Group {
        if let split {
          // iPhone Duo open / iPad: the map on one page, the level preview on the other — never on the fold.
          PageSplit(split: split, fill: true) {
            map(regions, current: cur, width: split.lead)
            NodePanel(node: selected ?? currentNode, regions: regions, play: play)
              .padding(.vertical, 12)
          }
        } else {
          map(regions, current: cur, width: geo.size.width)
        }
      }
      .foldProbe($fold)
      .sheet(item: Binding(get: { fold.split(minPage: 300) == nil ? selected : nil }, set: { selected = $0 })) { n in
        NodePanel(node: n, regions: regions, play: { selected = nil; play($0) })
          .padding(.top, 8)
          .presentationDetents([.height(360)])
          .presentationCornerRadius(32)
          .presentationBackground(.regularMaterial)
      }
    }
    .navigationDestination(item: $playing) { n in NodePlayer(node: n, regions: regions) }
    .navigationDestination(item: $lesson) { LessonPlayer(lesson: $0) }
    .onAppear {
      conquered = Set(regions.filter { World.conquered($0, app.state, app.content) }.map(\.id))
      if let id = app.pendingLesson { app.pendingLesson = nil; lesson = app.content.lessons.first { $0.id == id } }
      let a = ProcessInfo.processInfo.arguments
      if let i = a.firstIndex(of: "-lesson"), i + 1 < a.count, lesson == nil { lesson = app.content.lessons.first { $0.id == a[i + 1] } }
      if let i = a.firstIndex(of: "-play"), i + 1 < a.count, playing == nil, lesson == nil, let n = regions.flatMap(\.nodes).first(where: { $0.id == a[i + 1] }) { play(n) }
      #if DEBUG
      // Screen recordings: -conquer wins the current land after a moment (fog lifts, flag, rocket flies on).
      if a.contains("-conquer") {
        Task {
          try? await Task.sleep(for: .seconds(2))
          let cur = World.current(regions, app.state, app.content)
          for n in regions[cur.region].nodes { app.mutate { $0.earn(n.id, stars: 3) } }
        }
      }
      #endif
    }
    .onChange(of: app.pendingLesson) { _, id in if let id { app.pendingLesson = nil; lesson = app.content.lessons.first { $0.id == id } } }
    .onChange(of: regions.filter { World.conquered($0, app.state, app.content) }.map(\.id)) { _, now in
      let fresh = Set(now).subtracting(conquered)
      conquered = Set(now)
      if !fresh.isEmpty { burst += 1 }
    }
    .overlay(Celebrate(trigger: burst))
    .sensoryFeedback(.success, trigger: burst)
  }

  private func play(_ n: WorldNode) {
    switch n.kind {
    case let .quest(q): openQuest(q)
    case let .lesson(l): lesson = app.content.lessons.first { $0.id == l }
    case let .unit(u):
      let ls = app.content.lessons.filter { $0.unit == u }
      lesson = ls.first { !app.state.lessons.contains($0.id) } ?? ls.first
    default: playing = n
    }
  }

  // MARK: The map

  private func map(_ regions: [Region], current: (region: Int, node: Int), width: CGFloat) -> some View {
    let z = min(1.7, max(1, zoom * pinch))
    let layout = MapLayout(regions: regions, width: width * z)
    return ScrollViewReader { proxy in
      ScrollView([.vertical, .horizontal], showsIndicators: false) {
        ZStack(alignment: .topLeading) {
          MapCanvas(layout: layout, regions: regions, state: app.state, content: app.content)
            .frame(width: layout.size.width, height: layout.size.height)
          // Every marker sits at its own frame (MapPlacement), so scrollTo and hit-testing see real sizes.
          MapPlacement {
            ForEach(Array(regions.enumerated()), id: \.element.id) { ri, r in
              let open = World.regionOpen(ri, regions, app.state, app.content)
              ForEach(Array(MapDecor.items(for: r, ri).enumerated()), id: \.offset) { _, d in
                Glyph(symbol: d.symbol, hue: open ? hue(r) : .slate, size: d.size, style: .plain)
                  .opacity(open ? 0.6 : 0.25)
                  .place(layout.decor(ri, angle: d.angle, radius: d.radius))
              }
              if !open {
                Fog(region: r).frame(width: layout.islandSize(ri).width * 1.1, height: layout.islandSize(ri).height * 1.08)
                  .place(layout.center(ri))
                  .transition(.opacity.combined(with: .scale(scale: 1.15)))
              }
            }
          }
          .allowsHitTesting(false)
          Clouds(size: layout.size)
            .allowsHitTesting(false)
            .visualEffect { c, g in c.offset(y: -g.frame(in: .scrollView).minY * 0.25) }
          MapPlacement {
            ForEach(Array(regions.enumerated()), id: \.element.id) { ri, r in
              let open = World.regionOpen(ri, regions, app.state, app.content)
              RegionBanner(region: r, open: open, conquered: World.conquered(r, app.state, app.content))
                .place(layout.banner(ri))
              if open {
                ForEach(Array(r.nodes.enumerated()), id: \.element.id) { ni, n in
                  let nodeOpen = World.nodeOpen(n, in: r, regionOpen: true, app.state, app.content)
                  NodeButton(node: n, stars: World.stars(n, app.state, app.content), open: nodeOpen,
                             current: current.region == ri && current.node == ni, hue: hue(r),
                             tap: { if nodeOpen { play(n) } else { selected = n } }, info: { selected = n })
                    .id(n.id)
                    .place(layout.node(ri, ni, count: r.nodes.count))
                }
              }
            }
            ForEach(Array(regions.enumerated()), id: \.element.id) { ri, r in
              if World.conquered(r, app.state, app.content) {
                PlantedFlag(hue: hue(r)).allowsHitTesting(false).place(layout.decor(ri, angle: -.pi / 2 + (ri % 2 == 0 ? -0.5 : 0.5), radius: 0.5))
                  .transition(.move(edge: .top).combined(with: .opacity))
              }
            }
            if layout.nodeIfAny(current.region, current.node, regions) != nil {
              let target = layout.rocketCenter(current.region, current.node, regions[current.region])
              RocketLuna(skin: Skins.current(app.state)).rotationEffect(.degrees(rocketTilt)).allowsHitTesting(false).place(rocketAt ?? target)
                .onAppear { rocketAt = target; rocketKey = "\(current.region)-\(current.node)" }
                .onChange(of: target) { old, new in fly(from: rocketAt ?? old, to: new, key: "\(current.region)-\(current.node)") }
            }
          }
        }
        .frame(width: layout.size.width, height: layout.size.height)
        .animation(Motion.safe(Motion.page, rm), value: app.state.stars)
      }
      .defaultScrollAnchor(.bottom)
      // The first land's banner sits at the very bottom of the map: keep it clear of the floating tab bar,
      // and keep the top land's banner clear of the header.
      .contentMargins(.bottom, 96, for: .scrollContent)
      .contentMargins(.top, 12, for: .scrollContent)
      .background(Color(hex: 0x6FB7E8))
      .simultaneousGesture(MagnifyGesture().updating($pinch) { v, s, _ in s = v.magnification }.onEnded { v in zoom = min(1.7, max(1, zoom * v.magnification)) })
      .safeAreaInset(edge: .top) { WorldHeader(regions: regions) }
      .onChange(of: burst) { _, _ in
        // A land was just won: once the flag is planted, the camera follows Luna's rocket to the next land.
        guard let n = regions[safe: current.region]?.nodes[safe: current.node] else { return }
        Task {
          try? await Task.sleep(for: .milliseconds(rm ? 0 : 900))
          withAnimation(Motion.safe(Motion.page, rm)) { proxy.scrollTo(n.id, anchor: UnitPoint(x: 0.5, y: 0.55)) }
        }
      }
      .task {
        // Open on Luna: center the map on the node she's waiting at (once per visit to the tab).
        guard !didScroll, let n = regions[safe: current.region]?.nodes[safe: current.node] else { return }
        didScroll = true
        try? await Task.sleep(for: .milliseconds(60))
        proxy.scrollTo(n.id, anchor: UnitPoint(x: 0.5, y: 0.55))
      }
    }
  }

  private func hue(_ r: Region) -> Hue { Hue.named(r.hue) }

  /// After a win the rocket flies to the next stop on a gentle arc (two legs, tilting into the turn).
  /// A zoom or rotation only moves the stops, so the rocket simply follows without a flight.
  private func fly(from a: CGPoint, to b: CGPoint, key: String) {
    guard key != rocketKey, !rm else { rocketAt = b; rocketKey = key; return }
    rocketKey = key
    let mid = CGPoint(x: (a.x + b.x) / 2 + (b.y - a.y) * 0.18, y: (a.y + b.y) / 2 - 40)
    let tilt = max(-35, min(35, Double(b.x - a.x) / 4))
    withAnimation(.easeIn(duration: 0.45)) { rocketAt = mid; rocketTilt = tilt } completion: {
      withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { rocketAt = b; rocketTilt = 0 }
    }
  }
}

extension Hue {
  static func named(_ s: String) -> Hue { Hue.allCases.first { "\($0)" == s } ?? .grape }
}
extension Array { subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil } }

/// Places each child centered on its `.place(_:)` point; the layout itself fills the proposed size.
struct MapPlacement: Layout {
  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize { proposal.replacingUnspecifiedDimensions() }
  func placeSubviews(in b: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    for v in subviews {
      let p = v[PlaceAt.self]
      v.place(at: CGPoint(x: b.minX + p.x, y: b.minY + p.y), anchor: .center, proposal: .unspecified)
    }
  }
}
private struct PlaceAt: LayoutValueKey { static let defaultValue = CGPoint.zero }
extension View { func place(_ p: CGPoint) -> some View { layoutValue(key: PlaceAt.self, value: p) } }

/// A few landmarks per land, in the same symbol style as everything else, around the island's rim.
enum MapDecor {
  struct Item { let symbol: String; let angle: Double; let radius: CGFloat; let size: CGFloat }
  static func items(for r: Region, _ ri: Int) -> [Item] {
    let symbols: [String]
    switch r.id {
    case "coast": symbols = ["sun.max.fill", "beach.umbrella.fill", "sailboat.fill", "storefront.fill"]
    case "isle": symbols = ["tree.fill", "leaf.fill", "tree.fill", "archivebox.fill"]
    case "canyon": symbols = ["chart.bar.fill", "mountain.2.fill", "flame.fill", "chart.bar.xaxis"]
    case "trails": symbols = ["signpost.right.fill", "chart.line.uptrend.xyaxis", "figure.hiking", "signpost.left.fill"]
    case "peaks": symbols = ["mountain.2.fill", "triangle.fill", "mountain.2.fill", "flag.fill"]
    case "sea": symbols = ["water.waves", "fish.fill", "sailboat.fill", "antenna.radiowaves.left.and.right"]
    default: symbols = ["building.columns.fill", "crown.fill", "flag.2.crossed.fill", "doc.text.fill"]
    }
    let angles = [0.35, 2.6, 3.7, 5.6].map { $0 + Double(ri) * 0.4 }
    return symbols.enumerated().map { Item(symbol: $0.element, angle: angles[$0.offset], radius: 0.74, size: 30 + CGFloat(($0.offset + ri) % 3) * 8) }
  }
}

/// Geometry of the map: regions stack bottom → top as islands that zig-zag left and right, and each
/// island's nodes climb an S-shaped trail from its shore to its boss.
struct MapLayout {
  let regions: [Region]
  let width: CGFloat
  // Footprints. A stop is its circle (60 pt, a boss 76 pt) with a star pill hanging 4 pt below it.
  static let diameter: CGFloat = 60, bossDiameter: CGFloat = 76
  static let pill = CGSize(width: 52, height: 18), pillGap: CGFloat = 4
  static let rocket = CGSize(width: 70, height: 90), rocketGap: CGFloat = 12
  /// Vertical distance between stops: the tallest stop's lower half + pill (boss 38 + 22) + the next stop's
  /// upper half (30) + 16 pt of air = 106, rounded up. Stops never overlap, whatever their x.
  static let step: CGFloat = 108
  /// Room above the boss and below the first stop (keeps stops clear of the land banners).
  static let margin: CGFloat = 130
  static func diameter(_ n: WorldNode) -> CGFloat { n.isBoss ? bossDiameter : diameter }

  /// Each land is as tall as its trail needs, so stars never touch the next stop.
  func band(_ ri: Int) -> CGFloat {
    let n = CGFloat(max((regions[safe: ri]?.nodes.count ?? 4) - 1, 0))
    return max(width * 0.9, n * Self.step + 2 * Self.margin)
  }
  var size: CGSize { CGSize(width: width, height: regions.indices.reduce(0) { $0 + band($1) } + 180) }
  var islandSize: CGSize { islandSize(0) }
  func islandSize(_ ri: Int) -> CGSize { CGSize(width: width * 0.86, height: band(ri) * 0.86) }
  func center(_ ri: Int) -> CGPoint {
    let below = (0..<max(ri, 0)).reduce(0) { $0 + band($1) }
    let y = size.height - 90 - below - band(ri) / 2
    return CGPoint(x: width * (ri % 2 == 0 ? 0.47 : 0.53), y: y)
  }
  /// The center of a stop's circle: an S-curve in x, a fixed `step` in y (first stop at the bottom).
  func node(_ ri: Int, _ ni: Int, count: Int) -> CGPoint {
    let c = center(ri)
    let t = count > 1 ? CGFloat(ni) / CGFloat(count - 1) : 0
    let dir: CGFloat = ri % 2 == 0 ? 1 : -1
    let x = c.x + dir * sin(t * .pi * 1.6 - 0.6) * width * 0.25
    let y = c.y + (CGFloat(count - 1) / 2 - CGFloat(ni)) * Self.step
    return CGPoint(x: x, y: y)
  }
  func circleFrame(_ ri: Int, _ ni: Int, _ r: Region) -> CGRect {
    let p = node(ri, ni, count: r.nodes.count), d = Self.diameter(r.nodes[ni])
    return CGRect(x: p.x - d / 2, y: p.y - d / 2, width: d, height: d)
  }
  func pillFrame(_ ri: Int, _ ni: Int, _ r: Region) -> CGRect {
    let c = circleFrame(ri, ni, r)
    return CGRect(x: c.midX - Self.pill.width / 2, y: c.maxY + Self.pillGap, width: Self.pill.width, height: Self.pill.height)
  }
  /// Luna's rocket parks beside the current stop (on the side facing the middle of the map), never on a stop.
  func rocketCenter(_ ri: Int, _ ni: Int, _ r: Region) -> CGPoint {
    let p = node(ri, ni, count: r.nodes.count), d = Self.diameter(r.nodes[ni])
    let side: CGFloat = p.x < width / 2 ? 1 : -1
    return CGPoint(x: p.x + side * (d / 2 + Self.rocketGap + Self.rocket.width / 2), y: p.y)
  }
  func rocketFrame(_ ri: Int, _ ni: Int, _ r: Region) -> CGRect {
    let c = rocketCenter(ri, ni, r)
    return CGRect(x: c.x - Self.rocket.width / 2, y: c.y - Self.rocket.height / 2, width: Self.rocket.width, height: Self.rocket.height)
  }
  func decor(_ ri: Int, angle: Double, radius: CGFloat) -> CGPoint {
    let c = center(ri), s = islandSize(ri)
    return CGPoint(x: c.x + CGFloat(cos(angle)) * s.width / 2 * radius, y: c.y + CGFloat(sin(angle)) * s.height / 2 * radius)
  }
  func banner(_ ri: Int) -> CGPoint { let c = center(ri); return CGPoint(x: c.x, y: c.y + band(ri) * 0.5) }
  func nodeIfAny(_ ri: Int, _ ni: Int, _ rs: [Region]) -> CGPoint? {
    guard let r = rs[safe: ri], r.nodes.indices.contains(ni) else { return nil }
    return node(ri, ni, count: r.nodes.count)
  }
  /// Island outline: an ellipse with a few soft bumps (seeded per region so it never changes).
  func island(_ ri: Int, inset: CGFloat = 0) -> Path {
    let c = center(ri), s = islandSize(ri), rx = s.width / 2 - inset, ry = s.height / 2 - inset
    var p = Path()
    let k = Double(ri) * 1.7
    for i in 0...72 {
      let a = Double(i) / 72 * 2 * .pi
      let wob = 1 + 0.06 * sin(a * 3 + k) + 0.04 * sin(a * 5 - k * 0.6)
      let pt = CGPoint(x: c.x + CGFloat(cos(a) * wob) * rx, y: c.y + CGFloat(sin(a) * wob) * ry)
      i == 0 ? p.move(to: pt) : p.addLine(to: pt)
    }
    p.closeSubpath()
    return p
  }
}

/// The sea, the islands, the trail. Redrawn only when stars/lessons change.
struct MapCanvas: View, Equatable {
  let layout: MapLayout
  let regions: [Region]
  let state: KidsState
  let content: KidsContent
  static func == (a: MapCanvas, b: MapCanvas) -> Bool { a.layout.width == b.layout.width && a.state == b.state && a.regions == b.regions }

  var body: some View {
    Canvas { g, size in
      // Sea: deep at the top (the far lands), bright near the coast, with soft wave lines.
      g.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(Gradient(colors: [Color(hex: 0x3A5BC7), Color(hex: 0x4E9FDB), Color(hex: 0x86D3E8)]), startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
      for row in stride(from: 40.0, to: Double(size.height), by: 46) {
        var w = Path()
        for x in stride(from: 0.0, through: Double(size.width), by: 12) {
          let y = row + sin(x / 26 + row) * 3
          x == 0 ? w.move(to: CGPoint(x: x, y: y)) : w.addLine(to: CGPoint(x: x, y: y))
        }
        g.stroke(w, with: .color(.white.opacity(0.12)), lineWidth: 1.2)
      }
      // Islands
      for (ri, r) in regions.enumerated() {
        let open = World.regionOpen(ri, regions, state, content)
        let won = World.conquered(r, state, content)
        let hue = Hue.named(r.hue)
        let shore = layout.island(ri)
        var shadow = g; shadow.translateBy(x: 0, y: 10)
        shadow.fill(shore, with: .color(Color(hex: 0x1D3E8A).opacity(0.28)))
        g.fill(shore, with: .color(Color(hex: 0xF6E7BF)))                    // sand
        let land = layout.island(ri, inset: 14)
        let tone = open ? hue.light : Color(hex: 0xB9C2D6)
        g.fill(land, with: .linearGradient(Gradient(colors: [tone, open ? hue.color.opacity(won ? 0.95 : 0.7) : Color(hex: 0x98A2BA)]),
                                           startPoint: CGPoint(x: 0, y: layout.center(ri).y - layout.islandSize(ri).height / 2),
                                           endPoint: CGPoint(x: 0, y: layout.center(ri).y + layout.islandSize(ri).height / 2)))
        g.stroke(land, with: .color(.white.opacity(0.35)), lineWidth: 2)
      }
      // The trail: dashed where you haven't been, solid gold where you have.
      let pts = regions.enumerated().flatMap { ri, r in r.nodes.indices.map { (layout.node(ri, $0, count: r.nodes.count), World.stars(r.nodes[$0], state, content) > 0) } }
      for i in 1..<max(pts.count, 1) {
        let (a, _) = pts[i - 1], (b, done) = pts[i]
        var p = Path(); p.move(to: a)
        let mid = CGPoint(x: (a.x + b.x) / 2 + (b.y - a.y) * 0.18, y: (a.y + b.y) / 2)
        p.addQuadCurve(to: b, control: mid)
        let walked = done && pts[i - 1].1
        g.stroke(p, with: .color(walked ? Hue.gold.color : .white.opacity(0.85)), style: .init(lineWidth: walked ? 6 : 4, lineCap: .round, dash: walked ? [] : [2, 10]))
      }
    }
    .drawingGroup()
    .accessibilityHidden(true)
  }
}

struct RegionBanner: View {
  let region: Region, open: Bool, conquered: Bool
  var body: some View {
    HStack(spacing: 8) {
      Glyph(region.art, size: 26)
      VStack(alignment: .leading, spacing: 0) {
        Text(region.name).font(.subheadline.weight(.heavy)).lineLimit(1)
        Text(open ? region.blurb : "Win the land below to open it").font(.caption2).foregroundStyle(.secondary).lineLimit(1)
      }
      if conquered { Image(systemName: "flag.checkered").font(.caption.weight(.bold)).foregroundStyle(Palette.good) }
    }
    .padding(.horizontal, 12).padding(.vertical, 7)
    .background(.regularMaterial, in: Capsule())
    .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
    .fixedSize()
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(region.name). \(conquered ? "Conquered." : open ? region.blurb : "Locked.")")
  }
}

struct NodeButton: View {
  let node: WorldNode, stars: Int, open: Bool, current: Bool, hue: Hue
  let tap: () -> Void
  var info: () -> Void = {}
  @State private var held = false
  @Environment(\.accessibilityReduceMotion) private var rm
  @State private var pulse = false
  var body: some View {
    let d = MapLayout.diameter(node)
    Button { if held { held = false } else { tap() } } label: {
      // The circle IS the stop's frame (placed at its center); the star pill hangs below as an overlay,
      // at exactly the spot MapLayout.pillFrame reserves for it.
      ZStack {
          if current && !rm {
            Circle().stroke(Hue.gold.color, lineWidth: 3).frame(width: d + 16, height: d + 16).scaleEffect(pulse ? 1.12 : 0.96).opacity(pulse ? 0 : 0.9)
          }
          Circle().fill(current ? AnyShapeStyle(LinearGradient(colors: [.white, hue.light], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(.white)).frame(width: d, height: d).shadow(color: (current ? hue.color : .black).opacity(current ? 0.45 : 0.18), radius: current ? 12 : 6, y: 4)
          Circle().strokeBorder(stars > 0 ? Hue.gold.color : current ? Palette.accent : Palette.line, lineWidth: stars > 0 || current ? 4 : 2).frame(width: d, height: d)
          if open {
            Glyph(node.art, size: d * 0.66)
          } else {
            Image(systemName: "lock.fill").font(.system(size: d * 0.3, weight: .bold)).foregroundStyle(Palette.ink2.opacity(0.5))
          }
          if node.isBoss && stars > 0 {
            Image(systemName: "flag.fill").font(.system(size: 22, weight: .bold)).foregroundStyle(hue.color).offset(x: d * 0.42, y: -d * 0.46)
              .transition(.move(edge: .top).combined(with: .scale))
          }
      }
      .frame(width: d, height: d)
      .overlay(alignment: .bottom) {
        // The current stop says PLAY in the star pill's slot (it has no stars yet), so nothing overlaps.
        Group {
          if current && open && stars == 0 {
            Label("PLAY", systemImage: "play.fill").font(.system(size: 11, weight: .black, design: .rounded)).labelStyle(.titleAndIcon)
              .foregroundStyle(.white)
              .frame(width: MapLayout.pill.width + 10, height: MapLayout.pill.height + 4)
              .background(Palette.accent, in: Capsule())
              .scaleEffect(pulse && !rm ? 1.08 : 1)
          } else {
            StarRow(stars: stars, size: 11)
              .frame(width: MapLayout.pill.width, height: MapLayout.pill.height)
              .background(.white.opacity(0.9), in: Capsule())
          }
        }
        .offset(y: MapLayout.pillGap + MapLayout.pill.height)
      }
      .contentShape(Circle().inset(by: -10))
    }
    .buttonStyle(PressStyle())
    .simultaneousGesture(LongPressGesture(minimumDuration: 0.45).onEnded { _ in held = true; info() })
    .sensoryFeedback(.impact(weight: .light), trigger: held)
    .accessibilityLabel("\(node.title). \(open ? "\(stars) of 3 stars" : "Locked")\(current ? ". You are here. Double tap to play" : "")")
    .accessibilityAction(named: "About this stop") { info() }
    .onAppear { guard current, !rm, !pulse else { return }; withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) { pulse = true } }
  }
}

/// Luna in her rocket, floating over the node you're on.
struct RocketLuna: View {
  var skin: RocketSkin = Skins.all[0]
  @Environment(\.accessibilityReduceMotion) private var rm
  @State private var bob = false
  var body: some View {
    ZStack {
      // flame
      Capsule().fill(LinearGradient(colors: [Hue.lemon.color, Color(hex: skin.flame), Color(hex: skin.flame).opacity(0)], startPoint: .top, endPoint: .bottom))
        .frame(width: 14, height: bob ? 26 : 20).offset(y: 30)
      // body
      RocketShape().fill(LinearGradient(colors: [Color(hex: skin.body), Color(hex: skin.body).blend(with: Color(hex: 0x9AA6C8), by: 0.25)], startPoint: .leading, endPoint: .trailing))
        .overlay(RocketShape().stroke(Palette.midnight.opacity(0.25), lineWidth: 1))
        .frame(width: 40, height: 58)
      // fins
      HStack(spacing: 30) { Fin().fill(Color(hex: skin.fin)).frame(width: 12, height: 18).scaleEffect(x: -1); Fin().fill(Color(hex: skin.fin)).frame(width: 12, height: 18) }.offset(y: 20)
      // window with Luna
      Circle().fill(Color(hex: 0x1C2350)).frame(width: 30, height: 30).overlay(Luna(size: 26, mood: .happy)).offset(y: -4)
    }
    .frame(width: 70, height: 90)
    .offset(y: bob ? -5 : 0)
    .shadow(color: .black.opacity(0.2), radius: 6, y: 6)
    .onAppear { guard !rm, !bob else { return }; withAnimation(Motion.gentle.repeatForever()) { bob = true } }
    .accessibilityHidden(true)
  }
}
struct RocketShape: Shape {
  func path(in r: CGRect) -> Path {
    var p = Path()
    p.move(to: CGPoint(x: r.midX, y: r.minY))
    p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY + r.height * 0.55), control: CGPoint(x: r.maxX, y: r.minY + r.height * 0.12))
    p.addLine(to: CGPoint(x: r.maxX - r.width * 0.12, y: r.maxY))
    p.addLine(to: CGPoint(x: r.minX + r.width * 0.12, y: r.maxY))
    p.addLine(to: CGPoint(x: r.minX, y: r.minY + r.height * 0.55))
    p.addQuadCurve(to: CGPoint(x: r.midX, y: r.minY), control: CGPoint(x: r.minX, y: r.minY + r.height * 0.12))
    return p
  }
}
struct Fin: Shape {
  func path(in r: CGRect) -> Path { var p = Path(); p.move(to: .init(x: r.minX, y: r.minY)); p.addLine(to: .init(x: r.maxX, y: r.maxY)); p.addLine(to: .init(x: r.minX, y: r.maxY)); p.closeSubpath(); return p }
}

/// A big flag planted on a conquered land, in the land's color.
struct PlantedFlag: View {
  let hue: Hue
  @Environment(\.accessibilityReduceMotion) private var rm
  @State private var wave = false
  var body: some View {
    ZStack(alignment: .topLeading) {
      Capsule().fill(Palette.midnight.opacity(0.75)).frame(width: 4, height: 64).offset(x: 0, y: 0)
      Image(systemName: "flag.fill").font(.system(size: 34, weight: .heavy)).foregroundStyle(hue.color)
        .overlay(Image(systemName: "star.fill").font(.system(size: 10, weight: .black)).foregroundStyle(.white).offset(x: 2, y: -4))
        .rotationEffect(.degrees(wave && !rm ? 4 : -2), anchor: .leading)
        .offset(x: 1, y: -2)
      Ellipse().fill(.black.opacity(0.18)).frame(width: 22, height: 7).offset(x: -9, y: 60)
    }
    .frame(width: 44, height: 70)
    .shadow(color: hue.color.opacity(0.4), radius: 8)
    .onAppear { guard !rm else { return }; withAnimation(Motion.gentle.repeatForever()) { wave = true } }
    .accessibilityHidden(true)
  }
}

/// The rocket hangar: skins earned from mission chests (cosmetic only, never bought).
struct Hangar: View {
  @Environment(AppModel.self) private var app
  @Environment(\.dismiss) private var dismiss
  var body: some View {
    let have = Set(Skins.unlocked(app.state).map(\.id))
    let current = Skins.current(app.state).id
    VStack(spacing: 14) {
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text("Rocket hangar").font(.kTitle)
          Text("Open a mission chest to unlock the next rocket.").font(.callout).foregroundStyle(Palette.ink2)
        }
        Spacer()
        Button { dismiss() } label: { Image(systemName: "xmark").font(.headline.weight(.heavy)).frame(width: 40, height: 40).background(.thinMaterial, in: Circle()) }
          .buttonStyle(PressStyle()).accessibilityLabel("Close")
      }
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 10)], spacing: 10) {
        ForEach(Skins.all) { s in
          let unlocked = have.contains(s.id)
          Button { if unlocked { app.mutate { $0.pickSkin(s.id, nowMillis: Int(Date().timeIntervalSince1970 * 1000)) } } } label: {
            VStack(spacing: 6) {
              ZStack {
                RocketMark(skin: s, size: 54).opacity(unlocked ? 1 : 0.25)
                if !unlocked { Image(systemName: "lock.fill").font(.headline).foregroundStyle(Palette.ink2) }
              }
              Text(s.name).font(.caption.weight(.bold)).lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 10)
            .background(current == s.id ? Palette.accent.opacity(0.15) : Palette.card.opacity(0.6), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(current == s.id ? Palette.accent : Palette.line, lineWidth: current == s.id ? 2.5 : 1))
          }
          .buttonStyle(PressStyle())
          .disabled(!unlocked)
          .accessibilityLabel("\(s.name). \(unlocked ? (current == s.id ? "Flying now" : "Tap to fly it") : "Locked")")
        }
      }
      Spacer(minLength: 0)
    }
    .padding(20)
  }
}

/// Fog over a land you haven't reached: soft, layered clouds.
struct Fog: View {
  let region: Region
  var body: some View {
    ZStack {
      Ellipse().fill(.white.opacity(0.78)).blur(radius: 26)
      ForEach(0..<6, id: \.self) { i in
        Image(systemName: "cloud.fill").font(.system(size: 64 + CGFloat(i % 3) * 18)).foregroundStyle(.white.opacity(0.92))
          .offset(x: CGFloat([-90, 70, -30, 100, -110, 20][i]), y: CGFloat([-80, -40, 10, 60, 70, 110][i]))
      }
      Label("Locked", systemImage: "lock.fill").font(.caption.weight(.bold)).foregroundStyle(Palette.ink2).padding(.horizontal, 10).padding(.vertical, 5).background(.white, in: Capsule())
    }
    .accessibilityHidden(true)
  }
}

/// High clouds drifting over the map (parallax: they move slower than the map as you scroll).
struct Clouds: View {
  let size: CGSize
  var body: some View {
    ZStack {
      ForEach(0..<Int(max(4, size.height / 260)), id: \.self) { i in
        Image(systemName: "cloud.fill").font(.system(size: 44 + CGFloat(i % 3) * 16)).foregroundStyle(.white.opacity(0.55))
          .position(x: size.width * [0.15, 0.82, 0.4, 0.92, 0.08, 0.6][i % 6], y: CGFloat(i) * 260 + 80)
      }
    }
    .frame(width: size.width, height: size.height)
    .accessibilityHidden(true)
  }
}

struct WorldHeader: View {
  let regions: [Region]
  @Environment(AppModel.self) private var app
  @State private var hangar = false
  var body: some View {
    let t = World.totalStars(app.state, app.content)
    let won = regions.filter { World.conquered($0, app.state, app.content) }.count
    let streak = Streak.play(app.state, today: app.today)
    // The land you're on is named up here, so its banner on the map is never the only place to read it
    // (it can sit under the tab bar while you scroll).
    let here = regions.isEmpty ? nil : regions[safe: World.current(regions, app.state, app.content).region]
    HStack(spacing: 8) {
      VStack(alignment: .leading, spacing: 0) {
        Text(here?.name ?? "Market World").font(.system(.title3, design: .rounded).weight(.heavy)).lineLimit(1).minimumScaleFactor(0.7)
        Label("\(won) of \(regions.count) lands won", systemImage: "flag.fill").font(.caption.weight(.semibold)).foregroundStyle(Palette.ink2)
          .lineLimit(1).minimumScaleFactor(0.8)
      }
      .accessibilityElement(children: .combine)
      Spacer()
      Label("\(streak)", systemImage: "flame.fill").font(.subheadline.weight(.heavy)).monospacedDigit()
        .foregroundStyle(streak > 0 ? Hue.orange.color : Palette.ink2).padding(.horizontal, 10).padding(.vertical, 6).background(.white.opacity(0.9), in: Capsule())
        .accessibilityLabel("\(streak) day streak")
      Label("\(t.have)", systemImage: "star.fill").font(.subheadline.weight(.heavy)).monospacedDigit()
        .foregroundStyle(Hue.gold.color).padding(.horizontal, 10).padding(.vertical, 6).background(.white.opacity(0.9), in: Capsule())
        .contentTransition(.numericText(value: Double(t.have)))
        .accessibilityLabel("\(t.have) stars")
      Button { hangar = true } label: {
        RocketMark(skin: Skins.current(app.state), size: 30).frame(width: 44, height: 44).background(.white.opacity(0.9), in: Circle())
      }
      .accessibilityLabel("Rocket hangar")
      .sheet(isPresented: $hangar) { Hangar().presentationDetents([.medium]).presentationCornerRadius(32) }
      NavigationLink { SchoolView() } label: {
        Image(systemName: "books.vertical.fill").font(.headline).frame(width: 44, height: 44).background(.white.opacity(0.9), in: Circle())
      }
      .accessibilityLabel("All lessons")
    }
    .padding(.horizontal, 16).padding(.vertical, 8)
    // Solid, not glass: the map's stops and stars slide cleanly *under* the header instead of showing
    // through it (which read as overlapping).
    .background {
      LinearGradient(colors: [Color(hex: 0xD8ECFA), Color(hex: 0xBFDDF4)], startPoint: .top, endPoint: .bottom)
        .ignoresSafeArea(edges: .top)
        .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
    }
  }
}

/// The level preview: what this node is, your stars, and Play. Fits without scrolling (sheet or Duo page).
struct NodePanel: View {
  let node: WorldNode?
  let regions: [Region]
  let play: (WorldNode) -> Void
  @Environment(AppModel.self) private var app
  var body: some View {
    if let node, let ri = regions.firstIndex(where: { $0.nodes.contains(node) }) {
      let r = regions[ri]
      let open = World.nodeOpen(node, in: r, regionOpen: World.regionOpen(ri, regions, app.state, app.content), app.state, app.content)
      let stars = World.stars(node, app.state, app.content)
      VStack(spacing: 14) {
        Glyph(node.art, size: 72)
        VStack(spacing: 4) {
          Eyebrow(text: r.name)
          Text(node.title).font(.kTitle).multilineTextAlignment(.center)
          Text(kindLine(node)).font(.callout).foregroundStyle(Palette.ink2).multilineTextAlignment(.center).lineLimit(2)
        }
        StarRow(stars: stars, size: 24)
        if open {
          Button(stars > 0 ? "Play again" : node.isBoss ? "Take on the boss" : "Play") { play(node) }.buttonStyle(ChunkyPrimary())
        } else {
          Label(node.isBoss ? "Win a star on every spot in \(r.name) first." : "Win a star on the spot before this one.", systemImage: "lock.fill")
            .font(.callout.weight(.semibold)).foregroundStyle(Palette.ink2).multilineTextAlignment(.center)
        }
      }
      .padding(22)
      .frame(maxWidth: 460)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else {
      Luna(size: 90, wave: true)
    }
  }
  private func kindLine(_ n: WorldNode) -> String {
    switch n.kind {
    case let .unit(u): let c = app.content.lessons.filter { $0.unit == u }.count; return "A trail of \(c) one-minute lessons."
    case .lesson: return "A one-minute lesson."
    case .quest: return "A Luna quest: learn by playing."
    case .game: return "A chart game: a few quick rounds."
    case .guess: return "Guess a real company's report card."
    case .review: return "Boss! Five questions to plant your flag."
    case .timeMachine: return "Boss! Read a real chart, then travel forward in time."
    }
  }
}

/// Plays a game or boss node and records its stars.
struct NodePlayer: View {
  let node: WorldNode
  let regions: [Region]
  @Environment(AppModel.self) private var app
  var body: some View {
    let kind = node.isBoss ? "boss" : { if case .game = node.kind { return "game" }; return "node" }()
    let finish: (Int) -> Void = { s in app.mutate { $0.earn(node.id, stars: s); $0.play(kind, node.id, today: app.today) } }
    let rounds = Rounds(series: Array(app.candles.values).sorted { $0.s < $1.s }, seed: node.id.hashValueStable &+ app.today.hashValueStable)
    switch node.kind {
    case let .game(k):
      switch k {
      case .buildCandle: BuildCandleGame(node: node, onFinish: finish)
      case .readDay: ReadDayGame(node: node, rounds: rounds, onFinish: finish)
      case .candleMatch: CandleMatchGame(node: node, onFinish: finish)
      case .spotTrend: SpotTrendGame(node: node, rounds: rounds, onFinish: finish)
      case .drawTrend: DrawTrendGame(node: node, rounds: rounds, onFinish: finish)
      case .findFloor: FindFloorGame(node: node, onFinish: finish)
      case .patternDetective: PatternDetectiveGame(node: node, onFinish: finish)
      case .busyDay: BusyDayGame(node: node, rounds: rounds, onFinish: finish)
      case .smoothLine: SmoothLineGame(node: node, onFinish: finish)
      }
    case let .timeMachine(s): TimeMachineBoss(node: node, symbol: s, onFinish: finish)
    case let .review(rid): if let r = regions.first(where: { $0.id == rid }) { ReviewBoss(node: node, region: r, onFinish: finish) }
    case .guess: GuessView()
    default: EmptyView()
    }
  }
}

extension String {
  /// Stable across launches (Swift's hashValue is seeded per process).
  var hashValueStable: Int { unicodeScalars.reduce(5381) { ($0 &* 33) &+ Int($1.value) } }
}
