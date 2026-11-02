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
      if let i = a.firstIndex(of: "-play"), i + 1 < a.count, playing == nil { playing = regions.flatMap(\.nodes).first { $0.id == a[i + 1] } }
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
                Fog(region: r).frame(width: layout.islandSize.width * 1.1, height: layout.islandSize.height * 1.08)
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
                  NodeButton(node: n, stars: World.stars(n, app.state, app.content), open: World.nodeOpen(n, in: r, regionOpen: true, app.state, app.content),
                             current: current.region == ri && current.node == ni, hue: hue(r)) { selected = n }
                    .id(n.id)
                    .place(layout.node(ri, ni, count: r.nodes.count))
                }
              }
            }
            if let p = layout.nodeIfAny(current.region, current.node, regions) {
              RocketLuna().allowsHitTesting(false).place(CGPoint(x: p.x, y: p.y - 64))
            }
          }
        }
        .frame(width: layout.size.width, height: layout.size.height)
        .animation(Motion.safe(Motion.page, rm), value: app.state.stars)
      }
      .defaultScrollAnchor(.bottom)
      .background(Color(hex: 0x6FB7E8))
      .simultaneousGesture(MagnifyGesture().updating($pinch) { v, s, _ in s = v.magnification }.onEnded { v in zoom = min(1.7, max(1, zoom * v.magnification)) })
      .safeAreaInset(edge: .top) { WorldHeader(regions: regions) }
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
    case "coast": symbols = ["sun.max.fill", "beach.umbrella.fill", "sailboat.fill", "drop.circle.fill"]
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
  var bandHeight: CGFloat { max(width * 0.98, 360) }
  var size: CGSize { CGSize(width: width, height: bandHeight * CGFloat(regions.count) + 180) }
  var islandSize: CGSize { CGSize(width: width * 0.86, height: bandHeight * 0.86) }
  func center(_ ri: Int) -> CGPoint {
    let y = size.height - 90 - bandHeight * (CGFloat(ri) + 0.5)
    return CGPoint(x: width * (ri % 2 == 0 ? 0.47 : 0.53), y: y)
  }
  func node(_ ri: Int, _ ni: Int, count: Int) -> CGPoint {
    let c = center(ri)
    let t = count > 1 ? CGFloat(ni) / CGFloat(count - 1) : 0
    let dir: CGFloat = ri % 2 == 0 ? 1 : -1
    let x = c.x + dir * sin(t * .pi * 1.6 - 0.6) * width * 0.25
    let y = c.y + bandHeight * 0.32 - t * bandHeight * 0.64
    return CGPoint(x: x, y: y)
  }
  func decor(_ ri: Int, angle: Double, radius: CGFloat) -> CGPoint {
    let c = center(ri)
    return CGPoint(x: c.x + CGFloat(cos(angle)) * islandSize.width / 2 * radius, y: c.y + CGFloat(sin(angle)) * islandSize.height / 2 * radius)
  }
  func banner(_ ri: Int) -> CGPoint { let c = center(ri); return CGPoint(x: c.x, y: c.y + bandHeight * 0.5) }
  func nodeIfAny(_ ri: Int, _ ni: Int, _ rs: [Region]) -> CGPoint? {
    guard let r = rs[safe: ri], r.nodes.indices.contains(ni) else { return nil }
    return node(ri, ni, count: r.nodes.count)
  }
  /// Island outline: an ellipse with a few soft bumps (seeded per region so it never changes).
  func island(_ ri: Int, inset: CGFloat = 0) -> Path {
    let c = center(ri), rx = islandSize.width / 2 - inset, ry = islandSize.height / 2 - inset
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
                                           startPoint: CGPoint(x: 0, y: layout.center(ri).y - layout.islandSize.height / 2),
                                           endPoint: CGPoint(x: 0, y: layout.center(ri).y + layout.islandSize.height / 2)))
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
  @Environment(\.accessibilityReduceMotion) private var rm
  @State private var pulse = false
  var body: some View {
    let d: CGFloat = node.isBoss ? 76 : 60
    Button(action: tap) {
      VStack(spacing: 4) {
        ZStack {
          if current && !rm {
            Circle().stroke(Hue.gold.color, lineWidth: 3).frame(width: d + 16, height: d + 16).scaleEffect(pulse ? 1.12 : 0.96).opacity(pulse ? 0 : 0.9)
          }
          Circle().fill(.white).frame(width: d, height: d).shadow(color: .black.opacity(0.18), radius: 6, y: 4)
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
        StarRow(stars: stars, size: 11)
          .padding(.horizontal, 6).padding(.vertical, 2).background(.white.opacity(0.9), in: Capsule())
      }
      .contentShape(Circle().inset(by: -10))
    }
    .buttonStyle(PressStyle())
    .accessibilityLabel("\(node.title). \(open ? "\(stars) of 3 stars" : "Locked")\(current ? ". You are here" : "")")
    .onAppear { guard current, !rm, !pulse else { return }; withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) { pulse = true } }
  }
}

/// Luna in her rocket, floating over the node you're on.
struct RocketLuna: View {
  @Environment(\.accessibilityReduceMotion) private var rm
  @State private var bob = false
  var body: some View {
    ZStack {
      // flame
      Capsule().fill(LinearGradient(colors: [Hue.lemon.color, Hue.orange.color, Hue.coral.color.opacity(0)], startPoint: .top, endPoint: .bottom))
        .frame(width: 14, height: bob ? 26 : 20).offset(y: 30)
      // body
      RocketShape().fill(LinearGradient(colors: [.white, Color(hex: 0xDCE3F5)], startPoint: .leading, endPoint: .trailing))
        .overlay(RocketShape().stroke(Palette.midnight.opacity(0.25), lineWidth: 1))
        .frame(width: 40, height: 58)
      // fins
      HStack(spacing: 30) { Fin().fill(Hue.coral.color).frame(width: 12, height: 18).scaleEffect(x: -1); Fin().fill(Hue.coral.color).frame(width: 12, height: 18) }.offset(y: 20)
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
  var body: some View {
    let t = World.totalStars(app.state, app.content)
    let won = regions.filter { World.conquered($0, app.state, app.content) }.count
    HStack(spacing: 10) {
      VStack(alignment: .leading, spacing: 0) {
        Text("Market World").font(.system(.title3, design: .rounded).weight(.heavy))
        Text("\(won) of \(regions.count) lands won").font(.caption).foregroundStyle(.secondary)
      }
      Spacer()
      Label("\(t.have)", systemImage: "star.fill").font(.subheadline.weight(.bold)).monospacedDigit()
        .foregroundStyle(Hue.gold.color).padding(.horizontal, 10).padding(.vertical, 6).background(.white.opacity(0.9), in: Capsule())
        .contentTransition(.numericText(value: Double(t.have)))
        .accessibilityLabel("\(t.have) stars")
      NavigationLink { SchoolView() } label: {
        Image(systemName: "books.vertical.fill").font(.headline).frame(width: 44, height: 44).background(.white.opacity(0.9), in: Circle())
      }
      .accessibilityLabel("All lessons")
    }
    .padding(.horizontal, 16).padding(.vertical, 8)
    .background(.ultraThinMaterial)
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
          Button(stars > 0 ? "Play again" : node.isBoss ? "Take on the boss" : "Play") { play(node) }.buttonStyle(PrimaryButtonStyle())
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
    let finish: (Int) -> Void = { s in app.mutate { $0.earn(node.id, stars: s) } }
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
