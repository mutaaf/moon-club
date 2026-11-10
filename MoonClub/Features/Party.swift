import SwiftUI
import MoonClubCore

// Party Moon (0.12): the views behind iPhone Duo call-outs and onboarding, "open wide to reveal",
// the sticker book, the gentle goodnight and the Mystery Stop marker. Rules live in MoonClubCore
// `Party.swift`; every iPhone Duo piece here appears only where a hinge exists (capability, never model).

// MARK: - "Made for iPhone Duo" call-out

/// A small glass label shown wherever an iPhone Duo-only feature is active. On every other device the
/// feature doesn't exist, so neither does the label.
struct DuoCallout: View {
  let text: String
  var symbol = "rectangle.portrait.on.rectangle.portrait.angled.fill"
  var dark = false
  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: symbol).font(.caption.weight(.heavy))
      VStack(alignment: .leading, spacing: 0) {
        Text("MADE FOR IPHONE DUO").font(.system(size: 9, weight: .heavy, design: .rounded)).tracking(0.8).opacity(0.8)
        Text(text).font(.caption.weight(.bold)).lineLimit(1).minimumScaleFactor(0.8)
      }
    }
    .foregroundStyle(dark ? Color.white : Palette.ink)
    .padding(.horizontal, 10).padding(.vertical, 6)
    .moonGlass(Capsule(), tint: dark ? Color.black.opacity(0.3) : Hue.sky.light.opacity(0.6))
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Made for iPhone Duo: \(text)")
  }
}

extension DuoModel {
  /// A hinge exists on this device (the only test for iPhone Duo features — never a model name).
  var hasHinge: Bool { reading != nil || pinned != nil }
}

// MARK: - First-open iPhone Duo coach

/// The iPhone Duo tour (0.14): shown once, the first time a hinge is seen, and again from What's New. Every
/// pose, each with what it does in Moon Club, as an animated phone drawn in-app (no screenshots or stock
/// art). It can be skipped at any time.
struct DuoCoach: View {
  let done: () -> Void
  @Environment(\.accessibilityReduceMotion) private var rm
  @Environment(\.cameraTopTrailing) private var cameraTopTrailing
  @State private var page = 0
  enum Art { case closed, book, tent, tabletop, flat, hinge }
  struct Pose { let title: String; let body: String; let art: Art }
  static let poses = [
    Pose(title: "Close me: Luna's pocket", body: "Luna naps on the little screen. Pick me up to see your missions and your garden.", art: .closed),
    Pose(title: "Fold me like a book!", body: "Lessons become a storybook. The World becomes an atlas. Flick the fold to turn the page.", art: .book),
    Pose(title: "Stand me up like a tent", body: "Luna puts on a puppet show of today's story for your family.", art: .tent),
    Pose(title: "Set me down like a laptop", body: "Tabletop mode: the chart sits on top, and the bottom is your game pad.", art: .tabletop),
    Pose(title: "Lay me flat for a race!", body: "Market Race: one half each, and the track runs along the fold. Open me wide to launch chests too!", art: .flat),
    Pose(title: "Open me slowly", body: "Watch the sun rise over Market World and the fog part. Close me to plant in the Moon Garden.", art: .hinge),
  ]
  private var poses: [Pose] { Self.poses }
  var body: some View {
    VStack(spacing: 18) {
      // iPhone Duo closed: the camera sits top-trailing, right beside a trailing Skip; there it goes leading.
      HStack {
        if !cameraTopTrailing { Spacer() }
        Button("Skip") { done() }.font(.kHeadline).foregroundStyle(Palette.ink2)
        if cameraTopTrailing { Spacer() }
      }
      DuoCallout(text: "\(poses.count) ways to play")
      TabView(selection: $page) {
        ForEach(poses.indices, id: \.self) { i in
          VStack(spacing: 18) {
            // 140 pt tall; scales down only in a short room (sideways on the outer display).
            GeometryReader { g in
              PoseArt(art: poses[i].art).frame(height: 140).scaleEffect(min(1, g.size.height / 140))
                .frame(width: g.size.width, height: g.size.height)
            }
            .frame(minHeight: 56, maxHeight: 140)
            Text(poses[i].title).font(.kTitle).multilineTextAlignment(.center).minimumScaleFactor(0.8)
            Text(poses[i].body).font(.kRead).multilineTextAlignment(.center).foregroundStyle(Palette.ink2).fixedSize(horizontal: false, vertical: true)
          }
          .padding(.horizontal, 8).padding(.bottom, 40)
          .tag(i)
        }
      }
      .tabViewStyle(.page(indexDisplayMode: .always))
      .indexViewStyle(.page(backgroundDisplayMode: .always))
      Button(page < poses.count - 1 ? "Next" : "Let's play!") {
        if page < poses.count - 1 { withAnimation(Motion.safe(Motion.page, rm)) { page += 1 } } else { done() }
      }
      .buttonStyle(ChunkyPrimary())
    }
    .padding(24)
    .readable(560)
    // Sideways on iPhone Duo's outer display the page dots sat on the words: scroll instead.
    .scrollsWhenShort(minHeight: 420)
    .background(AuroraField(surface: .school))
  }
}

/// A drawn iPhone Duo in a pose: two panels and a hinge. `tabletop` lays it like a laptop.
struct FoldArt: View {
  let angle: Double
  var tabletop = false
  @Environment(\.accessibilityReduceMotion) private var rm
  @State private var t = 0.0
  var body: some View {
    let open = rm ? 1 : t
    let a = 180 - (180 - angle) * open
    ZStack {
      RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.midnight)
        .frame(width: 84, height: 140)
        .overlay(RoundedRectangle(cornerRadius: 10).fill(Hue.sky.light).padding(6))
        .rotation3DEffect(.degrees(tabletop ? 0 : -(180 - a) / 2), axis: tabletop ? (1, 0, 0) : (0, 1, 0), anchor: tabletop ? .bottom : .trailing, perspective: 0.5)
        .offset(x: tabletop ? 0 : -42, y: tabletop ? -70 : 0)
        .rotation3DEffect(.degrees(tabletop ? (180 - a) : 0), axis: (1, 0, 0), anchor: .bottom, perspective: 0.5)
      RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.midnight)
        .frame(width: 84, height: 140)
        .overlay(RoundedRectangle(cornerRadius: 10).fill(Hue.lemon.light).padding(6))
        .rotation3DEffect(.degrees(tabletop ? 0 : (180 - a) / 2), axis: (0, 1, 0), anchor: .leading, perspective: 0.5)
        .offset(x: tabletop ? 0 : 42, y: tabletop ? 70 : 0)
    }
    .frame(maxWidth: .infinity)
    .accessibilityHidden(true)
    .task { guard !rm else { return }; withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { t = 1 } }
  }
}

/// The drawn phone for each tour page.
struct PoseArt: View {
  let art: DuoCoach.Art
  @Environment(\.accessibilityReduceMotion) private var rm
  @State private var on = false
  var body: some View {
    Group {
      switch art {
      case .closed:
        // One small closed phone with Luna asleep on the outer screen; it bobs as if picked up.
        RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.midnight)
          .frame(width: 86, height: 132)
          .overlay(RoundedRectangle(cornerRadius: 11).fill(Color(hex: 0x231B52)).padding(6)
            .overlay(Luna(size: 44, mood: on ? .happy : .sleepy)))
          .offset(y: on && !rm ? -8 : 0)
          .rotationEffect(.degrees(on && !rm ? -6 : 0))
      case .book: FoldArt(angle: 110)
      case .tent: FoldArt(angle: 70).overlay(alignment: .bottom) { Capsule().fill(Palette.ink2.opacity(0.3)).frame(width: 150, height: 4) }
      case .tabletop: FoldArt(angle: 100, tabletop: true)
      case .flat: FoldArt(angle: 180)
      case .hinge:
        ZStack {
          FoldArt(angle: 40)
          Image(systemName: "sun.max.fill").font(.system(size: 34, weight: .bold)).foregroundStyle(Hue.lemon.color)
            .offset(x: 0, y: on && !rm ? -70 : -20).opacity(on || rm ? 1 : 0.4)
        }
      }
    }
    .frame(maxWidth: .infinity)
    .accessibilityHidden(true)
    .task { guard !rm else { return }; withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { on = true } }
  }
}

enum DuoCoachStore {
  static let key = "duo.coachSeen"
  static var seen: Bool { UserDefaults.standard.bool(forKey: key) }
  static func markSeen() { UserDefaults.standard.set(true, forKey: key) }
}

// MARK: - Open wide to reveal (iPhone Duo)

/// On an iPhone Duo that isn't fully open, a big moment (a chest, a new moon) waits behind
/// "Open me wide!" and plays when the hinge opens flat — the hinge as the button. A tap always works too,
/// and on devices without a hinge the content simply shows.
struct OpenWideReveal<Content: View>: View {
  let what: String
  var dark = false
  var onReveal: () -> Void = {}
  @ViewBuilder var content: Content
  @Environment(DuoModel.self) private var duo: DuoModel?
  @Environment(AppModel.self) private var app
  @Environment(\.accessibilityReduceMotion) private var rm
  @State private var revealed: Bool?
  @State private var last: HingeReading?

  var body: some View {
    Group {
      if revealed ?? true { content.transition(.scale(scale: 0.6).combined(with: .opacity)) }
      else { waiting.transition(.opacity) }
    }
    .onAppear {
      guard revealed == nil else { return }
      let waits = duo?.hasHinge == true && duo?.reading?.status != .fullyOpen
      revealed = !waits
      last = duo?.reading
    }
    .onChange(of: duo?.reading) { _, new in
      guard revealed == false else { last = new; return }
      if HingeLaunch.launches(from: last, to: new) { reveal(byHinge: true) }
      last = new
    }
  }

  private var waiting: some View {
    VStack(spacing: 16) {
      FoldArt(angle: 180).frame(height: 160)
      Text("Open me wide!").font(.kHero).lineLimit(2).minimumScaleFactor(0.6).foregroundStyle(dark ? Color.white : Palette.ink)
      Text("Open your iPhone Duo all the way to see \(what).").font(.kRead).multilineTextAlignment(.center).foregroundStyle(dark ? Color.white.opacity(0.8) : Palette.ink2)
      DuoCallout(text: "Open wide to launch", dark: dark)
      Button("Or tap here") { reveal(byHinge: false) }.font(.kHeadline).foregroundStyle(dark ? Color.white : Palette.accent)
    }
    .padding(24)
  }

  private func reveal(byHinge: Bool) {
    if byHinge { app.mutate { $0.useDuo(.hinge) } }
    withAnimation(Motion.safe(Motion.celebrate, rm)) { revealed = true }
    onReveal()
  }
}

// MARK: - Sticker book

/// Every Market World stop and land is a sticker: earned with a star, shiny with three. Paged, so it
/// never scrolls; a fold-aware even grid on iPhone Duo and iPad.
struct StickerBook: View {
  @Environment(AppModel.self) private var app
  @State private var page = 0
  private let perPage = 12
  var body: some View {
    let all = Stickers.all(app.state, app.content)
    let pages = stride(from: 0, to: all.count, by: perPage).map { Array(all[$0..<min($0 + perPage, all.count)]) }
    let c = Stickers.count(app.state, app.content)
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text("\(c.have) of \(c.of) stickers").font(.kHeadline)
        Spacer()
        Text("Shiny = 3 stars").font(.caption.weight(.semibold)).foregroundStyle(Palette.ink2)
      }
      TabView(selection: $page) {
        ForEach(pages.indices, id: \.self) { i in
          LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
            ForEach(pages[i]) { StickerCell(sticker: $0) }
          }
          .frame(maxHeight: .infinity, alignment: .top)
          .tag(i)
        }
      }
      .tabViewStyle(.page(indexDisplayMode: .always))
      .indexViewStyle(.page(backgroundDisplayMode: .always))
      .frame(height: 350)
      Spacer(minLength: 0)
    }
  }
}

struct StickerCell: View {
  let sticker: Sticker
  @Environment(\.accessibilityReduceMotion) private var rm
  @State private var shine = false
  var body: some View {
    VStack(spacing: 4) {
      ZStack {
        Circle().fill(sticker.earned ? Hue.named(sticker.hue).light : Palette.line.opacity(0.4))
        if sticker.earned { Glyph(sticker.art, size: 34, style: .plain) }
        else { Image(systemName: "questionmark").font(.system(size: 18, weight: .heavy)).foregroundStyle(Palette.ink2.opacity(0.5)) }
      }
      .frame(width: 58, height: 58)
      .overlay(Circle().strokeBorder(.white, lineWidth: 3))
      .overlay {
        if sticker.shiny {
          Circle().fill(LinearGradient(colors: [.clear, .white.opacity(0.7), .clear], startPoint: .topLeading, endPoint: .bottomTrailing))
            .offset(x: shine ? 58 : -58).mask(Circle())
        }
      }
      .shadow(color: sticker.shiny ? Hue.gold.color.opacity(0.6) : .black.opacity(0.08), radius: sticker.shiny ? 8 : 3, y: 2)
      .rotationEffect(.degrees(sticker.earned ? Double(Int(Seed.of(sticker.id) % 9) - 4) : 0))
      Text(sticker.earned ? sticker.title : "???").font(.system(size: 10, weight: .bold, design: .rounded)).lineLimit(2).multilineTextAlignment(.center).foregroundStyle(Palette.ink2)
        .frame(height: 26, alignment: .top)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(sticker.earned ? "\(sticker.title) sticker\(sticker.shiny ? ", shiny" : "")" : "A sticker you haven't found yet")
    .task { guard sticker.shiny, !rm else { return }; withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: false).delay(Double(Seed.of(sticker.id) % 20) / 10)) { shine = true } }
  }
}

// MARK: - Goodnight

/// After ~20 minutes, between games, Luna gets sleepy. Healthy screen time, gently: "Goodnight, Luna"
/// or "One more game" (which snoozes it). Never interrupts play and never takes anything away.
struct GoodnightSheet: View {
  let goodnight: () -> Void
  let oneMore: () -> Void
  @State private var tucked = false
  var body: some View {
    VStack(spacing: 14) {
      if tucked { SleepyLuna(size: 96).transition(.scale.combined(with: .opacity)) }
      else { Luna(size: 96, mood: .sleepy) }
      Text(tucked ? "Goodnight, Luna!" : "Luna's getting sleepy").font(.kTitle).multilineTextAlignment(.center)
      Text(tucked ? "Great playing today. Your stars are safe. See you tomorrow!" : "You played a lot today. Rest your eyes? Your stars stay safe.").font(.kRead).multilineTextAlignment(.center).foregroundStyle(Palette.ink2).fixedSize(horizontal: false, vertical: true)
      if !tucked {
        Button("Goodnight, Luna") { withAnimation(Motion.celebrate) { tucked = true }; Task { try? await Task.sleep(for: .seconds(1.8)); goodnight() } }.buttonStyle(ChunkyPrimary(tint: Hue.grape.color))
        Button("One more game", action: oneMore).buttonStyle(ChunkyStyle())
      }
    }
    .padding(24)
    .sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: tucked)
  }
}

@MainActor @Observable final class BedtimeClock {
  static let shared = BedtimeClock()
  var sessionStart = Date()
  var lastAsked: Date?
  func newSession() { sessionStart = Date(); lastAsked = nil }
  func sleepy(_ now: Date = Date()) -> Bool { Bedtime.sleepy(sessionStart: sessionStart, lastAsked: lastAsked, now: now) }
}

// MARK: - Mystery Stop marker

/// The sparkle on today's Mystery Stop: a bonus game, same pick on every device, worth bonus points.
struct MysteryTag: View {
  @Environment(\.accessibilityReduceMotion) private var rm
  @State private var spin = false
  var body: some View {
    HStack(spacing: 3) {
      Image(systemName: "sparkles").font(.system(size: 10, weight: .heavy)).rotationEffect(.degrees(spin ? 20 : -20))
      Text("MYSTERY +\(Mystery.points)").font(.system(size: 10, weight: .heavy, design: .rounded))
    }
    .foregroundStyle(Palette.midnight)
    .padding(.horizontal, 7).padding(.vertical, 3)
    .background(LinearGradient(colors: [Hue.lemon.color, Hue.gold.color], startPoint: .top, endPoint: .bottom), in: Capsule())
    .shadow(color: Hue.gold.color.opacity(0.7), radius: spin ? 8 : 3)
    .accessibilityLabel("Mystery stop, \(Mystery.points) bonus points today")
    // A few wiggles, then it rests (an endless loop with an animated shadow kept the whole map redrawing).
    .task { guard !rm else { return }; withAnimation(.easeInOut(duration: 0.9).repeatCount(6)) { spin = true } }
  }
}
