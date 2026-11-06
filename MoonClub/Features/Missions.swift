import SwiftUI
import MoonClubCore

/// Opens a tab from anywhere (Today's missions sends you to Guess).
struct OpenTab { let open: (Tab) -> Void; func callAsFunction(_ t: Tab) { open(t) } }
private struct OpenTabKey: EnvironmentKey { static let defaultValue = OpenTab { _ in } }
extension EnvironmentValues { var openTab: OpenTab { get { self[OpenTabKey.self] } set { self[OpenTabKey.self] = newValue } } }

/// Today's 3 missions, small: the Story's Start here button plays the next one, so this strip only shows
/// what comes after it ("Then"), progress dots and the chest as a ring that fills 1/3 → 3/3. Every chip
/// still plays its mission. The missions come from MoonClubCore `Missions.today` (pure).
struct MissionStrip: View {
  /// The step on the Start here button (that mission isn't repeated here).
  let hero: NextStep
  let go: (NextTarget) -> Void
  @Environment(AppModel.self) private var app
  @Environment(\.openLocker) private var openLocker
  @Environment(\.accessibilityReduceMotion) private var rm
  @Environment(DuoModel.self) private var duo: DuoModel?
  @State private var lastHinge: HingeReading?

  var body: some View {
    let _ = Perf.body("MissionStrip")
    let ms = Missions.today(app.today, app.state, app.content)
    let done = ms.filter(\.done).count
    let rest = ms.filter { !(hero.reason == .mission && $0.target.nextTarget == hero.target) }
    let streak = Streak.play(app.state, today: app.today)
    let title = Text(hero.reason == .mission && rest.contains { !$0.done } ? "Then" : "Today's missions").font(.kHeadline).foregroundStyle(Palette.ink2)
    VStack(alignment: .leading, spacing: 10) {
      // One row; at the biggest text sizes the title stacks above the progress instead of breaking words.
      ViewThatFits(in: .horizontal) {
        HStack(spacing: 10) { title.fixedSize(); Spacer(minLength: 4); progress(done, ms.count, streak) }
        VStack(alignment: .leading, spacing: 6) { title; progress(done, ms.count, streak) }
      }
      FlowLayout(spacing: 8) {
        ForEach(rest) { m in
          Button { go(m.target.nextTarget) } label: { chip(m) }
            .buttonStyle(PressStyle())
            .accessibilityLabel("\(m.title). \(m.done ? "Done" : "Not done yet")")
        }
        chest(done: done, of: ms.count)
      }
    }
    .padding(14)
    .background(Palette.card.opacity(0.55), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Palette.line.opacity(0.8), lineWidth: 0.5))
    .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    // iPhone Duo: opening the phone wide opens a ready chest (the hinge is the lid).
    .onChange(of: duo?.reading) { _, new in
      if Missions.chestReady(app.today, app.state, app.content), HingeLaunch.launches(from: lastHinge, to: new) {
        app.mutate { $0.useDuo(.hinge) }
        ChestOpener.open(app)
      }
      lastHinge = new
    }
  }

  private func progress(_ done: Int, _ total: Int, _ streak: Int) -> some View {
    HStack(spacing: 10) {
      HStack(spacing: 5) {
        ForEach(0..<total, id: \.self) { i in
          Circle().fill(i < done ? Palette.goodInk : Palette.line).frame(width: 9, height: 9)
        }
        Text("\(done)/\(total)").font(.subheadline.weight(.bold)).monospacedDigit().foregroundStyle(Palette.ink2)
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("\(done) of \(total) missions done")
      if streak > 0 {
        Label("\(streak)", systemImage: "flame.fill").font(.subheadline.weight(.heavy)).monospacedDigit()
          .foregroundStyle(Hue.orange.color)
          .accessibilityLabel("\(streak) day streak")
      }
    }
    .fixedSize()
  }

  private func chip(_ m: Mission) -> some View {
    HStack(spacing: 8) {
      if m.done {
        Image(systemName: "checkmark.circle.fill").font(.body.weight(.bold)).foregroundStyle(Palette.goodInk)
      } else {
        Glyph(m.art, size: 24, style: .plain)
      }
      Text(m.title).font(.subheadline.weight(.semibold)).lineLimit(2)
        .foregroundStyle(m.done ? Palette.ink2 : Palette.ink)
        .strikethrough(m.done, color: Palette.ink2)
    }
    .padding(.horizontal, 12).frame(minHeight: 44)
    .background(Palette.card.opacity(m.done ? 0.35 : 0.9), in: Capsule())
    .overlay(Capsule().strokeBorder(Palette.line, lineWidth: 1))
  }

  /// The mission chest as a ring that fills with each mission. Ready: tap opens it (the Start here button
  /// opens it too). Opened: tap visits the Moon Shop.
  @ViewBuilder private func chest(done: Int, of total: Int) -> some View {
    let ready = Missions.chestReady(app.today, app.state, app.content)
    let opened = Missions.chestOpened(app.today, app.state)
    Button {
      if ready { ChestOpener.open(app) } else if opened { openLocker(.shop) }
    } label: {
      HStack(spacing: 8) {
        ZStack {
          Circle().stroke(Palette.line, lineWidth: 3.5)
          Circle().trim(from: 0, to: total == 0 ? 0 : CGFloat(done) / CGFloat(total))
            .stroke(ready ? Hue.gold.color : Palette.goodInk, style: .init(lineWidth: 3.5, lineCap: .round)).rotationEffect(.degrees(-90))
            .animation(Motion.safe(Motion.celebrate, rm), value: done)
          Image(systemName: opened ? "checkmark" : "shippingbox.fill").font(.system(size: 13, weight: .bold))
            .foregroundStyle(opened ? Palette.goodInk : ready ? Hue.gold.color : Palette.ink2)
            .symbolEffect(.bounce, options: .repeat(3), isActive: ready && !rm)
        }
        .frame(width: 30, height: 30)
        Text(opened ? "Chest opened" : ready ? "Chest ready!" : "Chest +\(Rewards.chestPoints)")
          .font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink).lineLimit(1)
        if opened { Image(systemName: "bag.fill").font(.caption.weight(.bold)).foregroundStyle(Palette.ink2) }
      }
      .padding(.leading, 7).padding(.trailing, 12).frame(minHeight: 44)
      .background(ready ? Hue.gold.light.opacity(0.45) : Palette.card.opacity(0.5), in: Capsule())
      .overlay(Capsule().strokeBorder(Palette.line, lineWidth: 1))
    }
    .buttonStyle(PressStyle())
    .accessibilityLabel(opened ? "Chest opened today. Opens the Moon Shop." : ready ? "Your chest is ready. Open it." : "Mission chest: \(done) of \(total). Finish all \(total) for \(Rewards.chestPoints) Moon points.")
  }
}

/// Opening today's chest: banks it, plays the chime and throws the party (from the strip, the Start here
/// button or the iPhone Duo hinge).
enum ChestOpener {
  @MainActor static func open(_ app: AppModel) {
    guard Missions.chestReady(app.today, app.state, app.content) else { return }
    app.mutate { $0.openChest(today: app.today) }
    GameSound.play(.chest)
    PartyCenter.shared.fire(.chest, title: "Chest open! +\(Rewards.chestPoints)")
  }
}

extension MissionTarget {
  var nextTarget: NextTarget {
    switch self {
    case let .lesson(id): return .lesson(id)
    case let .node(id): return .node(id)
    case .guess: return .guess
    }
  }
}
