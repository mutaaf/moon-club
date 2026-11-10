import SwiftUI
import MoonClubCore

// Points that matter (0.11). Moon points are earned only (lessons, games, bosses, quests, guesses, daily
// visits, mission chests, badges) and spent only on looks: rockets, Luna's hats, map flags and trails,
// app colors, Luna frames and streak savers. Never real money, never a purchase, never an ad.
// The rules live in MoonClubCore/Rewards.swift; this file is the kid-facing side:
//   • the Moon Locker (from the header pill): Badges · Shop · Points
//   • the rank-up ceremony, the reward toast, and Luna wearing what you picked

// MARK: - Looks the kid has on

/// What Luna wears, read by every `Luna` view (set once at the root from the equipped items).
struct LunaLook: Equatable {
  var hat: ShopItem?
  var frame: ShopItem?
  static let none = LunaLook()
}
private struct LunaLookKey: EnvironmentKey { static let defaultValue = LunaLook.none }
extension EnvironmentValues { var lunaLook: LunaLook { get { self[LunaLookKey.self] } set { self[LunaLookKey.self] = newValue } } }

/// Whether a full-screen play screen is up (toasts move to the top so they never cover an answer, and
/// the rank ceremony waits for the results screen to close).
@MainActor @Observable final class PlayActivity {
  static let shared = PlayActivity()
  var active = 0
  var playing: Bool { active > 0 }
}

/// Luna's hat, drawn on top of her (a symbol, never an emoji picture).
struct LunaHat: View {
  let item: ShopItem
  let size: CGFloat
  var body: some View {
    Image(systemName: item.symbol)
      .font(.system(size: size * 0.42, weight: .bold))
      .foregroundStyle(Color(hex: item.color))
      .shadow(color: .white.opacity(0.9), radius: 1)
      .rotationEffect(.degrees(item.id == "hat.cap" || item.id == "hat.party" ? -12 : 0))
      .offset(y: item.id == "hat.glasses" ? -size * 0.02 : -size * 0.44)
      .accessibilityHidden(true)
  }
}

/// A sticker frame around a small Luna (HUD, Ask Luna).
struct LunaFrame: View {
  let item: ShopItem?
  let size: CGFloat
  var body: some View {
    if let item, item.id != "frame.none" {
      ZStack {
        Circle().strokeBorder(Color(hex: item.color), lineWidth: max(2, size * 0.07))
        ForEach(0..<4, id: \.self) { i in
          Image(systemName: item.symbol).font(.system(size: size * 0.22, weight: .bold)).foregroundStyle(Color(hex: item.color))
            .background(Circle().fill(Palette.card).padding(-1))
            .offset(y: -size * 0.56).rotationEffect(.degrees(Double(i) * 90 + 45))
        }
      }
      .frame(width: size * 1.12, height: size * 1.12)
      .accessibilityHidden(true)
    }
  }
}

// MARK: - The points mark (a drawn moon coin; "Moon points", never pretend money)

struct PointsMark: View {
  var size: CGFloat = 18
  var body: some View { CoinMark(size: size) }
}

// MARK: - Header pill: rank, wallet, a ring to the next rank

struct RankBadge: View {
  let index: Int
  let progress: Double
  var size: CGFloat = 26
  @Environment(\.accessibilityReduceMotion) private var rm
  var body: some View {
    ZStack {
      Circle().stroke(Palette.line, lineWidth: 3)
      Circle().trim(from: 0, to: max(0.02, progress))
        .stroke(Hue.gold.color, style: .init(lineWidth: 3, lineCap: .round)).rotationEffect(.degrees(-90))
      MoonPhase(phase: min(index, 4), size: size - 8)
      if index > 4 {
        Image(systemName: "sparkle").font(.system(size: size * 0.3, weight: .black)).foregroundStyle(Hue.gold.color)
          .offset(x: size * 0.36, y: -size * 0.36)
      }
    }
    .frame(width: size, height: size)
    .animation(Motion.safe(Motion.card, rm), value: progress)
    .accessibilityHidden(true)
  }
}

// MARK: - The Moon Locker (Badges · Shop · Points)

enum LockerTab: String, CaseIterable, Identifiable { case badges, stickers, shop, points; var id: String { rawValue }
  var title: String { ["Badges", "Stickers", "Shop", "Points"][LockerTab.allCases.firstIndex(of: self) ?? 0] }
}
struct OpenLocker { let open: (LockerTab) -> Void; func callAsFunction(_ t: LockerTab = .badges) { open(t) } }
private struct OpenLockerKey: EnvironmentKey { static let defaultValue = OpenLocker { _ in } }
extension EnvironmentValues { var openLocker: OpenLocker { get { self[OpenLockerKey.self] } set { self[OpenLockerKey.self] = newValue } } }

struct MoonLocker: View {
  @State var tab: LockerTab
  /// The Moon Shop shelf to open on (tests and screenshots).
  var slot: ShopSlot = .rocket
  @Environment(AppModel.self) private var app
  @Environment(\.dismiss) private var dismiss
  @Environment(\.accessibilityReduceMotion) private var rm

  var body: some View {
    VStack(spacing: 12) {
      header
      Picker("Section", selection: $tab) { ForEach(LockerTab.allCases) { Text($0.title).tag($0) } }
        .pickerStyle(.segmented)
      Group {
        switch tab {
        // Opened like a book (iPhone Duo, iPad): the trophy shelf on one page, the sticker book on the other.
        case .badges: Storybook(minPage: 300, fill: true) { TrophyShelf() } first: { TrophyShelf() } second: { StickerBook() }
        case .stickers: StickerBook()
        case .shop: MoonShop(slot: slot)
        case .points: PointsBook()
        }
      }
      .frame(maxHeight: .infinity, alignment: .top)
      .transition(.opacity)
    }
    .padding(.horizontal, 18).padding(.top, 16)
    .readable(640)
    // Sideways on iPhone Duo's outer display the header (and its close button) was pushed off the top.
    .scrollsWhenShort(minHeight: 600)
    .background(AuroraField(surface: .story).ignoresSafeArea())
    .animation(Motion.safe(Motion.card, rm), value: tab)
  }

  private var header: some View {
    let l = app.level
    let next = app.nextRankName
    return HStack(spacing: 12) {
      Luna(size: 54, wave: true, mood: .happy)
      VStack(alignment: .leading, spacing: 3) {
        Text(l.name).font(.system(.title3, design: .rounded).weight(.heavy)).lineLimit(1).minimumScaleFactor(0.6)
        ProgressBar(value: l.progress)
        Text(l.next.map { "\($0 - app.points) points to \(next ?? "the next moon")" } ?? "The biggest moon of all!")
          .font(.caption.weight(.semibold)).foregroundStyle(Palette.ink2).lineLimit(1).minimumScaleFactor(0.65)
      }
      Spacer(minLength: 4)
      VStack(spacing: 2) {
        HStack(spacing: 4) {
          PointsMark(size: 20)
          Text("\(app.wallet)").font(.system(.title3, design: .rounded).weight(.black)).monospacedDigit()
            .contentTransition(.numericText(value: Double(app.wallet)))
        }
        Text("to spend").font(.caption2.weight(.semibold)).foregroundStyle(Palette.ink2)
      }
      .accessibilityElement(children: .combine)
      .accessibilityLabel("\(app.wallet) Moon points to spend")
      Button { dismiss() } label: {
        Image(systemName: "xmark").font(.headline.weight(.heavy)).frame(width: 40, height: 40).moonGlass(Circle(), interactive: true, weight: .thin)
      }
      .buttonStyle(PressStyle()).accessibilityLabel("Close")
    }
  }
}

struct ProgressBar: View {
  let value: Double
  var tint: Color = Hue.gold.color
  var height: CGFloat = 8
  var body: some View {
    GeometryReader { g in
      ZStack(alignment: .leading) {
        Capsule().fill(Palette.line)
        Capsule().fill(tint).frame(width: max(height, g.size.width * min(1, max(0, value))))
      }
    }
    .frame(height: height)
    .accessibilityHidden(true)
  }
}

// MARK: Badges: a trophy shelf, six to a page (no scrolling)

struct TrophyShelf: View {
  @Environment(AppModel.self) private var app
  @Environment(DuoModel.self) private var duo: DuoModel?
  @State private var picked: String?
  @State private var page = 0
  static let perPage = 6

  var body: some View {
    // iPhone Duo-only trophies show only where there's a hinge (or once earned on a Duo).
    let shown = Set(Trophies.visible(hinge: duo?.hasHinge ?? false, app.state).map(\.id))
    let all = app.trophies.filter { shown.contains($0.id) }
    let pages = stride(from: 0, to: all.count, by: Self.perPage).map { Array(all[$0..<min($0 + Self.perPage, all.count)]) }
    let earned = all.filter { $0.tier > 0 }.count + app.badges.count
    VStack(spacing: 10) {
      HStack {
        Text("\(earned) earned").font(.kHeadline)
        Spacer()
        Text("Bronze, silver, gold").font(.caption.weight(.semibold)).foregroundStyle(Palette.ink2)
      }
      TabView(selection: $page) {
        ForEach(Array(pages.enumerated()), id: \.offset) { i, p in
          LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
            ForEach(p) { t in TrophyCell(p: t, picked: picked == t.id) { picked = picked == t.id ? nil : t.id } }
          }
          .frame(maxHeight: .infinity, alignment: .top)
          .tag(i)
        }
        SpecialBadges().tag(pages.count)
      }
      .tabViewStyle(.page(indexDisplayMode: .always))
      .indexViewStyle(.page(backgroundDisplayMode: .always))
      .frame(height: 330)
      detail(all.first { $0.id == picked })
      Spacer(minLength: 0)
    }
  }

  @ViewBuilder private func detail(_ p: TrophyProgress?) -> some View {
    Group {
      if let p {
        VStack(alignment: .leading, spacing: 4) {
          Text("\(p.trophy.name) · \(p.tierName)").font(.kHeadline)
          Text(p.tier == 0 ? p.trophy.hint : p.progressLine).font(.callout).foregroundStyle(Palette.ink2)
          if p.tier < 3 { Text("Next tier is worth \(Rewards.tierPoints[p.tier]) Moon points.").font(.caption.weight(.semibold)).foregroundStyle(Hue.gold.color) }
        }
      } else {
        Text("Tap a badge to see how to earn its next tier. Each tier is worth Moon points.").font(.callout).foregroundStyle(Palette.ink2)
      }
    }
    .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
    .padding(12)
    .background(Palette.card.opacity(0.8), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
  }
}

enum Tier {
  static func color(_ t: Int) -> Color { [Palette.line, Color(hex: 0xC27C46), Color(hex: 0xA9B4C8), Hue.gold.color][max(0, min(3, t))] }
}

struct TrophyCell: View {
  let p: TrophyProgress
  let picked: Bool
  let tap: () -> Void
  var body: some View {
    Button(action: tap) {
      VStack(spacing: 6) {
        ZStack {
          Circle().fill(p.tier == 0 ? Palette.line.opacity(0.4) : Tier.color(p.tier).opacity(0.18))
          Circle().strokeBorder(Tier.color(p.tier), style: .init(lineWidth: p.tier == 0 ? 2 : 4, dash: p.tier == 0 ? [4, 4] : []))
          Glyph(symbol: p.trophy.symbol, hue: p.tier == 0 ? .slate : Hue.named(p.trophy.hue), size: 44, style: .plain)
            .opacity(p.tier == 0 ? 0.35 : 1)
            .shimmer(p.tier == 3, holo: true)          // gold badges shine (Metal) and tilt like a hologram
          if p.tier > 0 {
            HStack(spacing: 1) { ForEach(0..<p.tier, id: \.self) { _ in Image(systemName: "star.fill").font(.system(size: 8, weight: .black)) } }
              .foregroundStyle(.white).padding(.horizontal, 5).padding(.vertical, 2).background(Tier.color(p.tier), in: Capsule())
              .offset(y: 30)
          }
        }
        .frame(width: 64, height: 64)
        Text(p.trophy.name).font(.caption.weight(.bold)).multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.8)
          .frame(height: 30)
        ProgressBar(value: p.next.map { Double(p.count) / Double($0) } ?? 1, tint: Tier.color(max(1, p.tier + (p.tier < 3 ? 1 : 0))), height: 5)
          .padding(.horizontal, 6)
      }
      .padding(.vertical, 8)
      .frame(maxWidth: .infinity)
      .background(Palette.card.opacity(picked ? 0.95 : 0.65), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
      .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(picked ? Palette.accent : .clear, lineWidth: 2))
    }
    .buttonStyle(PressStyle())
    .accessibilityLabel("\(p.trophy.name), \(p.tierName). \(p.tier == 0 ? p.trophy.hint : p.progressLine)")
  }
}

/// The web's story badges (lemonade, first guess…): one tier each.
struct SpecialBadges: View {
  @Environment(AppModel.self) private var app
  var body: some View {
    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
      ForEach(app.content.badges) { b in
        let have = app.badges.contains(b.id)
        VStack(spacing: 4) {
          MoonPhase(phase: b.phase, size: 36, dim: !have).opacity(have ? 1 : 0.35)
          Text(b.name).font(.caption2.weight(.bold)).multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.75).frame(height: 26)
        }
        .padding(.vertical, 6).frame(maxWidth: .infinity)
        .background(Palette.card.opacity(have ? 0.8 : 0.4), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(b.name), \(have ? "earned. \(b.why)" : "not yet")")
      }
    }
    .frame(maxHeight: .infinity, alignment: .top)
  }
}

// MARK: Moon Shop

struct MoonShop: View {
  @Environment(AppModel.self) private var app
  @Environment(DuoModel.self) private var duo: DuoModel?
  @Environment(\.accessibilityReduceMotion) private var rm
  @State private var slot: ShopSlot
  init(slot: ShopSlot = .rocket) { _slot = State(initialValue: slot) }
  @State private var picked: String?
  @State private var confirm = false
  @State private var burst = 0

  var body: some View {
    VStack(spacing: 10) {
      HStack(spacing: 6) {
        ForEach(ShopSlot.allCases, id: \.self) { s in
          Button { withAnimation(Motion.safe(Motion.tap, rm)) { slot = s; picked = nil; confirm = false } } label: {
            Image(systemName: Self.icon(s)).font(.system(size: 17, weight: .bold))
              .frame(maxWidth: .infinity, minHeight: 40)
              .foregroundStyle(slot == s ? .white : Palette.ink)
              .background(slot == s ? AnyShapeStyle(Palette.accent) : AnyShapeStyle(Palette.card.opacity(0.7)), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
          }
          .buttonStyle(PressStyle())
          .accessibilityLabel(s.title)
          .accessibilityAddTraits(slot == s ? .isSelected : [])
        }
      }
      Text(slot.title).font(.kHeadline).frame(maxWidth: .infinity, alignment: .leading)
      let items = Shop.visible(hinge: duo?.hasHinge ?? false, app.state).filter { $0.slot == slot }
      // Up to six items: three across. More (the rockets): four across, so a shelf is always two rows.
      // If the fold crosses the shelf (a wide sheet on iPhone Duo), the count goes even and the gutter sits on it.
      FoldColumns(minimum: 60, spacing: 8, count: items.count > 6 ? 4 : 3, rowSpacing: 10) {
        ForEach(items) { it in
          ShopCell(item: it, state: cellState(it), picked: picked == it.id) {
            withAnimation(Motion.safe(Motion.tap, rm)) { picked = it.id; confirm = false }
          }
        }
      }
      Spacer(minLength: 0)
      action
    }
    .overlay(Celebrate(trigger: burst))
    .sensoryFeedback(.success, trigger: burst)
  }

  static func icon(_ s: ShopSlot) -> String {
    switch s { case .rocket: return "airplane"; case .hat: return "crown.fill"; case .flag: return "flag.fill"; case .trail: return "point.topleft.down.to.point.bottomright.curvepath.fill"
    case .theme: return "paintpalette.fill"; case .frame: return "circle.circle.fill"; case .freeze: return "snowflake" }
  }

  enum CellState: Equatable { case wearing, owned, buyable, locked(String) }
  private func cellState(_ it: ShopItem) -> CellState {
    if it.slot != .freeze, Shop.owned(app.state).contains(it.id) { return Shop.equipped(it.slot, app.state)?.id == it.id ? .wearing : .owned }
    switch Shop.lock(it, app.state, app.content, wallet: app.wallet, level: app.level.index, trophies: app.trophies) {
    case nil: return .buyable
    case let .rank(r): return .locked("Reach \(r)")
    case let .trophy(t): return .locked("Earn \(t)")
    case let .points(n): return .locked("\(n) more")
    }
  }

  /// One action bar for the picked item: wear, buy (with an in-page "are you sure"), or why it's locked.
  @ViewBuilder private var action: some View {
    let it = picked.flatMap(Shop.item)
    VStack(spacing: 8) {
      if let it {
        let st = cellState(it)
        HStack {
          VStack(alignment: .leading, spacing: 2) {
            Text(it.name).font(.kHeadline)
            Text(line(it, st)).font(.caption).foregroundStyle(Palette.ink2).lineLimit(2)
          }
          Spacer(minLength: 6)
          switch st {
          case .wearing: Label("On", systemImage: "checkmark.circle.fill").font(.subheadline.weight(.bold)).foregroundStyle(Palette.goodInk)
          case .owned:
            Button("Wear it") { app.mutate { $0.equip(it.id, nowMillis: Self.now) } }.buttonStyle(ChunkyPrimary()).frame(width: 120)
          case .buyable:
            Button(confirm ? "Yes, spend \(it.price)" : "Get it") {
              if confirm { buy(it) } else { withAnimation(Motion.safe(Motion.tap, rm)) { confirm = true } }
            }
            .buttonStyle(ChunkyPrimary(tint: confirm ? Hue.gold.color.blend(with: .black, by: 0.15) : nil)).frame(width: confirm ? 160 : 110)
          case .locked: Image(systemName: "lock.fill").font(.title3).foregroundStyle(Palette.ink2)
          }
        }
      } else {
        Text("Pick something to see it. Everything here is just for fun: you earn Moon points by learning, and nothing costs real money.")
          .font(.callout).foregroundStyle(Palette.ink2).frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .frame(minHeight: 64)
    .padding(12)
    .background(Palette.card.opacity(0.85), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
  }

  private func line(_ it: ShopItem, _ st: CellState) -> String {
    switch st {
    case .wearing: return "You have this on."
    case .owned: return "Yours! Tap to wear it."
    case .buyable: return it.slot == .freeze ? "Saves your streak if you miss one day. You have \(Shop.freezes(app.state))." : "\(it.price) Moon points. You have \(app.wallet)."
    case let .locked(why): return "\(why) to unlock it. Costs \(it.price)."
    }
  }

  private func buy(_ it: ShopItem) {
    var ok = false
    app.mutate { ok = $0.buy(it.id, app.content, nowMillis: Self.now) }
    confirm = false
    if ok { GameSound.play(.chest); burst += 1 }
  }

  static var now: Int { Int(Date().timeIntervalSince1970 * 1000) }
}

struct ShopCell: View {
  let item: ShopItem
  let state: MoonShop.CellState
  let picked: Bool
  let tap: () -> Void
  var body: some View {
    Button(action: tap) {
      VStack(spacing: 6) {
        ZStack {
          RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(hex: item.color).opacity(0.14))
          art.opacity(locked ? 0.35 : 1)
            .shimmer(!locked && (item.price >= 300 || Shop.duoOnly.contains(item.id)), holo: Shop.duoOnly.contains(item.id))
          if locked { Image(systemName: "lock.fill").font(.caption.weight(.bold)).foregroundStyle(Palette.ink2).offset(x: 26, y: -24) }
        }
        .frame(height: 64)
        Text(item.name).font(.caption.weight(.bold)).lineLimit(1).minimumScaleFactor(0.7)
        tag
      }
      .padding(8)
      .frame(maxWidth: .infinity)
      .background(Palette.card.opacity(picked ? 0.98 : 0.7), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
      .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(picked ? Palette.accent : state == .wearing ? Palette.good : .clear, lineWidth: 2))
    }
    .buttonStyle(PressStyle())
    .accessibilityLabel("\(item.name). \(accessibility)")
  }
  private var locked: Bool { if case .locked = state { return true }; return false }
  @ViewBuilder private var art: some View {
    switch item.slot {
    case .rocket: RocketMark(skin: Skins.every.first { "rocket.\($0.id)" == item.id } ?? Skins.all[0], size: 48)
    case .hat: ZStack { Luna(size: 40, dressed: false); LunaHat(item: item, size: 40) }.offset(y: 6)
    case .frame: ZStack { Luna(size: 34, dressed: false); LunaFrame(item: item, size: 34) }
    case .trail: Capsule().fill(Color(hex: item.color)).frame(width: 52, height: 8).rotationEffect(.degrees(-20))
        .overlay(Image(systemName: item.symbol).font(.system(size: 16, weight: .bold)).foregroundStyle(Color(hex: item.color)).offset(y: -16))
    case .theme: Circle().fill(Color(hex: item.color)).frame(width: 40, height: 40).overlay(Image(systemName: item.symbol).font(.system(size: 16, weight: .bold)).foregroundStyle(.white))
    default: Image(systemName: item.symbol).font(.system(size: 30, weight: .bold)).foregroundStyle(Color(hex: item.color))
    }
  }
  @ViewBuilder private var tag: some View {
    switch state {
    case .wearing: Text("On").font(.caption2.weight(.heavy)).foregroundStyle(Palette.goodInk)
    case .owned: Text("Yours").font(.caption2.weight(.heavy)).foregroundStyle(Palette.ink2)
    case .buyable, .locked:
      HStack(spacing: 3) { PointsMark(size: 12); Text("\(item.price)").font(.caption2.weight(.heavy)).monospacedDigit() }
        .foregroundStyle(locked ? Palette.ink2 : Palette.ink)
    }
  }
  private var accessibility: String {
    switch state { case .wearing: return "You have it on"; case .owned: return "Yours"; case .buyable: return "\(item.price) Moon points"; case let .locked(w): return "Locked. \(w)" }
  }
}

// MARK: My points

struct PointsBook: View {
  @Environment(AppModel.self) private var app
  var body: some View {
    let lines = Rewards.breakdown(app.state, app.content)
    VStack(spacing: 8) {
      HStack(alignment: .top) {
        PointsLedger()
        Spacer(minLength: 8)
        Label("\(Streak.play(app.state, today: app.today)) days", systemImage: "flame.fill").font(.subheadline.weight(.heavy)).foregroundStyle(Hue.orange.color)
      }
      VStack(spacing: 0) {
        ForEach(lines) { l in
          HStack(spacing: 10) {
            Image(systemName: l.source.symbol).font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.accent).frame(width: 26)
            Text(l.source.label).font(.subheadline.weight(.semibold))
            Spacer()
            Text("+\(l.points)").font(.subheadline.weight(.heavy)).monospacedDigit()
          }
          .padding(.vertical, 7)
          if l.id != lines.last?.id { Divider() }
        }
        if lines.isEmpty { Text("Play a lesson or a game to earn your first Moon points!").font(.callout).foregroundStyle(Palette.ink2).padding(.vertical, 10) }
      }
      .padding(.horizontal, 12).padding(.vertical, 4)
      .background(Palette.card.opacity(0.8), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
      Text("Come back every day: your visit bonus grows with your streak (up to 25).").font(.caption).foregroundStyle(Palette.ink2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

/// The wallet, line by line (MoonClubCore `Garden.balance`):
/// earned + harvest gains − Moon Shop − planted now = to spend.
struct PointsLedger: View {
  @Environment(AppModel.self) private var app
  var body: some View {
    let d = app.derived, spent = Shop.spent(app.state)
    VStack(alignment: .leading, spacing: 1) {
      row("Earned", "\(d.points)", bold: false)
      if !d.garden.harvests.isEmpty { row("Garden harvests", d.garden.gains >= 0 ? "+\(d.garden.gains)" : "−\(abs(d.garden.gains))", bold: false) }
      if spent > 0 { row("Moon Shop", "−\(spent)", bold: false) }
      if d.garden.principal > 0 { row("Growing in the garden", "−\(d.garden.principal)", bold: false) }
      row("To spend", "\(d.wallet)", bold: true)
    }
    .accessibilityElement(children: .combine)
  }
  private func row(_ label: String, _ value: String, bold: Bool) -> some View {
    HStack(spacing: 8) {
      Text(label).font(bold ? .kHeadline : .caption).foregroundStyle(bold ? Palette.ink : Palette.ink2)
      Spacer(minLength: 4)
      Text(value).font(bold ? .kHeadline : .caption.weight(.bold)).monospacedDigit()
    }
    .frame(maxWidth: 230)
  }
}

// MARK: - Rank-up ceremony

struct RankCeremony: View {
  let index: Int
  let done: (Bool) -> Void
  @Environment(AppModel.self) private var app
  @Environment(\.accessibilityReduceMotion) private var rm
  @State private var grow = false
  @State private var burst = 0
  var body: some View {
    let ls = Ranks.levels(app.content)
    let name = index < ls.count ? ls[index].name : "a new moon"
    let unlocks = Ranks.unlocks(index)
    VStack(spacing: 12) {
      Spacer(minLength: 0)
      // iPhone Duo: the new moon waits behind "Open me wide!" until the hinge opens flat.
      OpenWideReveal(what: "your new moon", dark: true) {
      VStack(spacing: 12) {
      ZStack {
        Circle().fill(RadialGradient(colors: [Hue.gold.color.opacity(0.5), .clear], center: .center, startRadius: 4, endRadius: 110)).frame(width: 220, height: 220)
          .scaleEffect(grow && !rm ? 1.08 : 0.9)
        Circle().strokeBorder(LinearGradient(colors: [Hue.lemon.color, Hue.gold.color], startPoint: .top, endPoint: .bottom), lineWidth: 6)
          .frame(width: 150, height: 150)
          .scaleEffect(grow ? 1 : 0.3)
        Luna(size: 116, wave: true, mood: .cheering)
          .scaleEffect(grow ? 1 : 0.3)
        RankBadge(index: index, progress: 1, size: 50)
          .background(Circle().fill(Palette.midnight).padding(-4))
          .offset(x: 58, y: 56)
          .scaleEffect(grow ? 1 : 0.1)
      }
      Text("NEW RANK").font(.kEyebrow).tracking(2).foregroundStyle(Hue.lemon.color)
      Text("You're a \(name)!").font(.system(.largeTitle, design: .rounded).weight(.black)).multilineTextAlignment(.center).foregroundStyle(.white)
        .lineLimit(2).minimumScaleFactor(0.7).fixedSize(horizontal: false, vertical: true)
      if !unlocks.isEmpty {
        VStack(spacing: 8) {
          Text("New in the Moon Shop").font(.kHeadline).foregroundStyle(.white.opacity(0.85))
          HStack(spacing: 10) {
            ForEach(unlocks.prefix(3)) { it in
              VStack(spacing: 4) {
                Image(systemName: it.slot == .rocket ? "airplane" : it.symbol).font(.system(size: 26, weight: .bold)).foregroundStyle(Color(hex: it.color))
                  .frame(width: 56, height: 56).background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                Text(it.name).font(.caption2.weight(.bold)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
              }
              .frame(width: 92)
            }
          }
        }
      }
      }
      .onAppear {
        GameSound.play(.win); Chime.rising()
        withAnimation(rm ? Motion.fade : .spring(response: 0.6, dampingFraction: 0.55)) { grow = true }
        burst += 1
      }
      }
      Spacer(minLength: 0)
      Button("Let's go!") { done(false) }.buttonStyle(ChunkyPrimary(tint: Hue.gold.color.blend(with: .black, by: 0.1)))
      Button("See the Moon Shop") { done(true) }.buttonStyle(ChunkyStyle(face: .white.opacity(0.14), edge: .black.opacity(0.4), ink: .white))
    }
    .padding(24)
    .readable(520)
    // Sideways on iPhone Duo's outer display the art ran off the top and the buttons off the bottom.
    .scrollsWhenShort(minHeight: 600)
    .background(BossBackdrop())
    .modifier(Shake(amount: rm ? 0 : 7, tick: burst))
    .animation(.linear(duration: 0.45), value: burst)
    .overlay(Celebrate(trigger: burst, tier: .large).ignoresSafeArea())
    .sensoryFeedback(.success, trigger: burst)
    .accessibilityElement(children: .contain)
  }
}

// MARK: - Reward toast (web badges and trophy tiers)

enum RewardNews: Identifiable, Equatable {
  case badge(Badge)
  case trophy(TrophyProgress, Int)
  var id: String {
    switch self { case let .badge(b): return b.id; case let .trophy(p, t): return Trophies.key(p, tier: t) }
  }
  var title: String {
    switch self {
    case let .badge(b): return "New badge: **\(b.name)**"
    case let .trophy(p, t): return "\(["", "Bronze", "Silver", "Gold"][t]) **\(p.trophy.name)** · +\(Rewards.tierPoints[t - 1])"
    }
  }
  var spoken: String {
    switch self {
    case let .badge(b): return "New badge: \(b.name). \(b.why)"
    case let .trophy(p, t): return "\(["", "Bronze", "Silver", "Gold"][t]) \(p.trophy.name) badge. \(Rewards.tierPoints[t - 1]) Moon points."
    }
  }
}

/// New-badge celebration: a compact pill. Above the tab bar normally; at the top under the HUD while
/// playing, so it never covers an answer. Each one is marked seen the moment it appears (so it shows
/// exactly once, even if the app is killed mid-toast) and leaves by itself after 4 s. Tap opens the shelf.
struct BadgeToast: View {
  @Environment(AppModel.self) private var app
  @Environment(\.accessibilityReduceMotion) private var rm
  @Environment(\.openLocker) private var openLocker
  @State private var burst = 0
  @State private var showing: RewardNews?
  @State private var busy = false
  /// Space for the tab bar (or the bottom of the sidebar layout) under the pill.
  static let tabBarClearance: CGFloat = 92

  var body: some View {
    let top = PlayActivity.shared.playing
    ZStack(alignment: top ? .top : .bottom) {
      Celebrate(trigger: burst).frame(height: 420)
      if let n = showing {
        HStack(spacing: 10) {
          switch n {
          case let .badge(b): MoonPhase(phase: b.phase, size: 28)
          case let .trophy(p, t):
            ZStack { Circle().fill(Tier.color(t)); Image(systemName: p.trophy.symbol).font(.system(size: 13, weight: .bold)).foregroundStyle(.white) }.frame(width: 28, height: 28)
          }
          Text(.init(n.title)).font(.subheadline).lineLimit(1).minimumScaleFactor(0.8)
        }
        .padding(.leading, 10).padding(.trailing, 16).padding(.vertical, 8)
        .moonGlass(Capsule(), interactive: true)
        .overlay(Capsule().strokeBorder(Hue.gold.color.opacity(0.6), lineWidth: 1))
        .shadow(color: .black.opacity(0.14), radius: 14, y: 6)
        .padding(top ? .top : .bottom, top ? 118 : Self.tabBarClearance)
        .onTapGesture {
          withAnimation(Motion.safe(Motion.card, rm)) { showing = nil }
          if !top { openLocker(.badges) }
        }
        .transition(.move(edge: top ? .top : .bottom).combined(with: .opacity))
        .sensoryFeedback(.success, trigger: n.id)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(n.spoken)
        .accessibilityAddTraits(.isButton)
      }
    }
    .frame(maxHeight: .infinity, alignment: top ? .top : .bottom)
    .allowsHitTesting(showing != nil)
    // Not `.task(id:)`: marking the badge seen changes that id, which would cancel the 4 s wait at once.
    .onChange(of: app.freshRewards.first?.id, initial: true) { _, id in
      guard id != nil, !busy else { return }
      busy = true
      Task { await present(); busy = false }
    }
  }

  /// Takes the next fresh reward, marks it seen at once, shows it for ~4 s, then looks for the next.
  private func present() async {
    guard showing == nil, let n = app.freshRewards.first else { return }
    app.mutate { $0.seeBadges([n.id]) }
    withAnimation(Motion.safe(Motion.celebrate, rm)) { showing = n }
    burst += 1
    PartyCenter.shared.fire(.badgeTier)
    try? await Task.sleep(for: .seconds(4))
    withAnimation(Motion.safe(Motion.card, rm)) { showing = nil }
    try? await Task.sleep(for: .milliseconds(400))
    if app.freshRewards.first != nil { await present() }
  }
}

// MARK: - Results: what this run earned

/// Banks the run's points (best run per game per day) and shows what you earned, with a way to spend it.
struct RunEarnings: View {
  let run: RunModel
  let source: PointSource
  let earnId: String
  var dark = false
  @Environment(AppModel.self) private var app
  @Environment(\.openLocker) private var openLocker
  @Environment(\.dismiss) private var dismiss
  @State private var gained: Int?
  var body: some View {
    HStack(spacing: 10) {
      PointsMark(size: 26)
      VStack(alignment: .leading, spacing: 0) {
        Text("+\(gained ?? 0) Moon points").font(.system(.headline, design: .rounded).weight(.heavy)).monospacedDigit()
          .contentTransition(.numericText(value: Double(gained ?? 0)))
        Text("\(app.wallet) to spend").font(.caption.weight(.semibold)).foregroundStyle(Palette.ink2)
      }
      Spacer(minLength: 6)
      Button { dismiss(); openLocker(.shop) } label: {
        Label("Moon Shop", systemImage: "bag.fill").font(.subheadline.weight(.heavy))
      }
      .buttonStyle(ChunkyStyle(face: Hue.gold.light, edge: Hue.gold.color, ink: Palette.ink, depth: 3, radius: 14))
      .frame(width: 150)
    }
    .padding(10)
    .moonGlass(radius: 18, weight: .thin)
    .accessibilityElement(children: .combine)
    .task {
      let before = run.startPoints ?? app.points
      app.mutate { $0.bank(source, earnId, points: Rewards.runPoints(run.coins), today: app.today) }
      withAnimation(Motion.celebrate) { gained = max(0, app.points - before) }
    }
  }
}
