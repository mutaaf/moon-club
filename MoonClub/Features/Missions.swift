import SwiftUI
import MoonClubCore

/// Opens a tab from anywhere (Today's missions sends you to Guess).
struct OpenTab { let open: (Tab) -> Void; func callAsFunction(_ t: Tab) { open(t) } }
private struct OpenTabKey: EnvironmentKey { static let defaultValue = OpenTab { _ in } }
extension EnvironmentValues { var openTab: OpenTab { get { self[OpenTabKey.self] } set { self[OpenTabKey.self] = newValue } } }

/// Today's 3 missions: one lesson, one chart game, one guess. Each has a ring that fills when it's done;
/// all three open the day's chest, which unlocks the next rocket skin (cosmetic only, never bought).
/// The missions come from MoonClubCore `Missions.today` (pure: same day + state → same missions).
struct TodaysMissions: View {
  @Environment(AppModel.self) private var app
  @Environment(\.openTab) private var openTab
  @Environment(\.openLocker) private var openLocker
  @Environment(\.accessibilityReduceMotion) private var rm
  @State private var lesson: Lesson?
  @State private var node: WorldNode?
  @State private var opened = 0
  @State private var reward: RocketSkin?
  @Environment(DuoModel.self) private var duo: DuoModel?
  @State private var lastHinge: HingeReading?

  var body: some View {
    let ms = Missions.today(app.today, app.state, app.content)
    let done = ms.filter(\.done).count
    let ready = Missions.chestReady(app.today, app.state, app.content)
    let wasOpened = Missions.chestOpened(app.today, app.state)
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .firstTextBaseline) {
        VStack(alignment: .leading, spacing: 2) {
          Eyebrow(text: "Today's missions")
          Text(done == ms.count ? "All done. Nice!" : "\(done) of \(ms.count) done").font(.kTitle)
        }
        Spacer()
        Label("\(Streak.play(app.state, today: app.today))", systemImage: "flame.fill").font(.headline.weight(.heavy)).monospacedDigit()
          .foregroundStyle(Hue.orange.color)
          .accessibilityLabel("\(Streak.play(app.state, today: app.today)) day streak")
      }
      ForEach(ms) { m in
        Button { go(m) } label: { row(m) }
          .buttonStyle(PressStyle())
          .accessibilityLabel("\(m.detail): \(m.title). \(m.done ? "Done" : "Not done yet")")
      }
      chest(ready: ready, opened: wasOpened)
    }
    .padding(18)
    .moonGlass(radius: 28)
    .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(Palette.line.opacity(0.7), lineWidth: 0.5))
    .shadow(color: Palette.midnight.opacity(0.06), radius: 24, y: 10)
    .overlay(Celebrate(trigger: opened, tier: .medium))
    .sensoryFeedback(.success, trigger: opened)
    // iPhone Duo: opening the phone wide opens a ready chest (the hinge is the lid).
    .onChange(of: duo?.reading) { _, new in
      if Missions.chestReady(app.today, app.state, app.content), HingeLaunch.launches(from: lastHinge, to: new) {
        app.mutate { $0.useDuo(.hinge) }
        openChest()
      }
      lastHinge = new
    }
    .navigationDestination(item: $lesson) { LessonPlayer(lesson: $0) }
    .navigationDestination(item: $node) { NodePlayer(node: $0, regions: World.regions(app.content)) }
  }

  private func row(_ m: Mission) -> some View {
    HStack(spacing: 12) {
      ZStack {
        Circle().stroke(Palette.line, lineWidth: 4)
        Circle().trim(from: 0, to: m.done ? 1 : 0).stroke(Palette.good, style: .init(lineWidth: 4, lineCap: .round)).rotationEffect(.degrees(-90))
          .animation(Motion.safe(Motion.celebrate, rm), value: m.done)
        if m.done { Image(systemName: "checkmark").font(.system(size: 18, weight: .black)).foregroundStyle(Palette.good).transition(.scale) }
        else { Glyph(m.art, size: 30, style: .plain) }
      }
      .frame(width: 46, height: 46)
      VStack(alignment: .leading, spacing: 1) {
        Text(m.detail.uppercased()).font(.kEyebrow).tracking(1).foregroundStyle(Palette.ink2)
        Text(m.title).font(.kHeadline).foregroundStyle(Palette.ink).lineLimit(2).strikethrough(m.done, color: Palette.ink2)
      }
      Spacer(minLength: 0)
      Image(systemName: m.done ? "arrow.counterclockwise" : "play.fill").font(.subheadline.weight(.heavy))
        .foregroundStyle(m.done ? Palette.ink2 : .white)
        .frame(width: 36, height: 36)
        .background(m.done ? AnyShapeStyle(.thinMaterial) : AnyShapeStyle(Palette.accent), in: Circle())
    }
    .padding(10)
    .background(Palette.card.opacity(m.done ? 0.4 : 0.75), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
  }

  @ViewBuilder private func chest(ready: Bool, opened wasOpened: Bool) -> some View {
    let next = Skins.next(app.state)
    HStack(spacing: 12) {
      ZStack {
        Circle().fill(ready ? Hue.gold.light : Palette.line.opacity(0.5)).frame(width: 52, height: 52)
        Image(systemName: wasOpened ? "shippingbox.and.arrow.backward.fill" : "shippingbox.fill").font(.system(size: 24, weight: .bold))
          .foregroundStyle(ready ? Hue.gold.color : wasOpened ? Palette.good : Palette.ink2)
          .symbolEffect(.bounce, options: .repeating, isActive: ready && !rm)
      }
      VStack(alignment: .leading, spacing: 1) {
        if reward != nil {
          Text("+\(Rewards.chestPoints) Moon points!").font(.kHeadline)
          Text("Spend them in the Moon Shop.").font(.caption).foregroundStyle(Palette.ink2)
        } else if wasOpened {
          Text("Chest opened today").font(.kHeadline)
          Text("Come back tomorrow for new missions.").font(.caption).foregroundStyle(Palette.ink2)
        } else {
          Text(ready ? "Your chest is ready!" : "Mission chest").font(.kHeadline)
          if ready, duo?.hasHinge == true, duo?.reading?.status != .fullyOpen {
            Text("Open your iPhone Duo wide to open it!").font(.caption.weight(.semibold)).foregroundStyle(Palette.ink2)
          } else {
            Text("Finish all 3 for \(Rewards.chestPoints) Moon points\(next.map { ", closer to the \($0.name) rocket" } ?? "").").font(.caption).foregroundStyle(Palette.ink2)
          }
        }
      }
      Spacer(minLength: 0)
      if ready {
        Button("Open") { openChest() }.buttonStyle(ChunkyStyle(face: Hue.gold.color, edge: Color(hex: 0x9A6A0C), ink: .white, radius: 16)).frame(width: 96)
      } else if reward != nil || wasOpened {
        Button { openLocker(.shop) } label: { Label("Shop", systemImage: "bag.fill").font(.subheadline.weight(.heavy)) }
          .buttonStyle(ChunkyStyle(face: Hue.gold.light, edge: Hue.gold.color, ink: Palette.ink, depth: 3, radius: 14)).frame(width: 96)
      }
    }
    .padding(10)
    .background(ready ? Hue.gold.light.opacity(0.35) : Color.clear, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    .accessibilityElement(children: .combine)
  }

  private func openChest() {
    app.mutate { $0.openChest(today: app.today) }
    GameSound.play(.chest)
    withAnimation(Motion.safe(Motion.celebrate, rm)) { reward = Skins.current(app.state); opened += 1 }
    PartyCenter.shared.fire(.chest, title: "Chest open! +\(Rewards.chestPoints)")
  }

  private func go(_ m: Mission) {
    switch m.target {
    case let .lesson(id): lesson = app.content.lessons.first { $0.id == id }
    case let .node(id): node = World.regions(app.content).flatMap(\.nodes).first { $0.id == id }
    case .guess: openTab(.guess)
    }
  }
}
