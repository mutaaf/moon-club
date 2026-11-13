import SwiftUI
import AVFoundation
import MoonClubCore

/// The Play button on an Arcade level card (Candle Academy, Line Lab, Moon Tower), with Moon Club Pass rules:
/// free levels play at once; past today's new levels it opens `PlayLimitSheet` instead. Rules: `PlayPlan`.
struct PassPlayButton: View {
  let title: String
  let climb: Climb
  let number: Int
  let id: String
  let won: Bool
  let play: () -> Void
  @Environment(AppModel.self) private var app
  @State private var limit = false

  var body: some View {
    let _ = Perf.body("PassPlayButton")
    let d = app.pass.decision(climb, number: number, id: id, won: won, today: app.today)
    VStack(spacing: 6) {
      Button(title) {
        if app.pass.request(climb, number: number, id: id, won: won, today: app.today) { play() } else { limit = true }
      }
      .buttonStyle(ChunkyPrimary())
      .accessibilityIdentifier("level-play")
      if let chip = PlayPlan.chip(d) {
        Label(chip, systemImage: "sparkles").font(.caption.weight(.bold)).foregroundStyle(Palette.ink2)
      } else if !d.allowed {
        Label("Today's new levels are used", systemImage: "moon.zzz.fill").font(.caption.weight(.bold)).foregroundStyle(Palette.ink2)
      }
    }
    .sheet(isPresented: $limit) {
      PlayLimitSheet(climb: climb) { limit = false; Task { try? await Task.sleep(for: .milliseconds(350)); if app.pass.request(climb, number: number, id: id, won: won, today: app.today) { play() } } }
        .presentationDetents([.large])
        .presentationCornerRadius(32)
    }
    #if DEBUG
    .onAppear { if ProcessInfo.processInfo.arguments.contains("-limit") && !d.allowed { limit = true } }
    #endif
  }
}

/// "That's today's new levels!": take a short break (a sponsor's, or Luna's) for more, or ask a grown-up about
/// Moon Club Pass (the gate first; buying only happens in `PassOffer`). Never punitive: replays stay free.
struct PlayLimitSheet: View {
  let climb: Climb
  /// A break finished and opened more levels: play the one the kid picked.
  let more: () -> Void
  @Environment(AppModel.self) private var app
  @Environment(\.dismiss) private var dismiss
  @State private var breakOn = false
  @State private var gate = false
  @State private var passed = false
  @State private var offer = false

  var body: some View {
    let d = app.pass.decision(climb, number: Int.max, id: "next", won: false, today: app.today)
    VStack(spacing: 18) {
      HStack {
        Spacer()
        Button { dismiss() } label: { Image(systemName: "xmark").font(.headline.weight(.bold)).frame(width: 44, height: 44) }
          .buttonStyle(.plain).moonGlass(Circle(), weight: .thin).accessibilityLabel("Close")
      }
      Spacer(minLength: 0)
      Luna(size: 110, mood: .cheering)
      VStack(spacing: 8) {
        Text(PlayPlan.limitTitle).font(.kHero).multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.6)
        Text(PlayPlan.limitLine(d)).font(.body).multilineTextAlignment(.center).foregroundStyle(Palette.ink2)
          .fixedSize(horizontal: false, vertical: true)
      }
      Spacer(minLength: 0)
      VStack(spacing: 12) {
        if app.pass.canBreak(today: app.today) {
          Button { breakOn = true } label: { Label(PlayPlan.breakButton, systemImage: "play.circle.fill") }
            .buttonStyle(ChunkyPrimary()).accessibilityIdentifier("take-break")
          Text("\(PlayPlan.breakSeconds) seconds, then \(PlayPlan.perBreak) more new levels").font(.caption.weight(.semibold)).foregroundStyle(Palette.ink2)
        }
        Button { gate = true } label: { Label(PlayPlan.askButton, systemImage: "lock.shield").frame(maxWidth: .infinity) }
          .buttonStyle(SoftButtonStyle())
        Text(PlayPlan.askLine).font(.caption).foregroundStyle(Palette.ink2).multilineTextAlignment(.center)
      }
    }
    .padding(22)
    .readable(560)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(AuroraField(surface: .quest).ignoresSafeArea())
    .scrollsWhenShort(minHeight: 560)
    .fullScreenCover(isPresented: $breakOn) {
      LunaBreak(climb: climb) { app.pass.finishBreak(today: app.today); breakOn = false; more() }
    }
    .sheet(isPresented: $gate, onDismiss: { if passed { passed = false; offer = true } }) { ParentGate { passed = true } }
    .sheet(isPresented: $offer, onDismiss: { if app.pass.active { more() } }) { PassOffer() }
    #if DEBUG
    .onAppear { if ProcessInfo.processInfo.arguments.contains("-break") { breakOn = true } }
    #endif
  }
}

/// A short break: a kid-safe sponsor's picture or video from Marquee when there is one, otherwise Luna with a
/// chart fact. A ring counts down while the app is in front; then "Collect". Nothing to tap out to.
struct LunaBreak: View {
  let climb: Climb
  let collect: () -> Void
  @Environment(AppModel.self) private var app
  @Environment(\.dismiss) private var dismiss
  @Environment(\.scenePhase) private var phase
  @Environment(\.accessibilityReduceMotion) private var rm
  @State private var sponsor: Sponsor?
  @State private var loaded = false
  @State private var left = PlayPlan.breakSeconds
  @State private var image: UIImage?

  var body: some View {
    let fact = PlayPlan.fact(day: app.today, n: app.pass.ledger.on(app.today).breaks)
    VStack(spacing: 18) {
      HStack {
        Text(sponsor.map { $0.label.isEmpty ? "Sponsor break" : "Sponsor break: \($0.label)" } ?? "A short break with Luna")
          .font(.footnote.weight(.heavy)).padding(.horizontal, 12).padding(.vertical, 6).moonGlass(Capsule(), weight: .thin)
          .accessibilityIdentifier("break-label")
        Spacer()
        Button { dismiss() } label: { Image(systemName: "xmark").font(.headline.weight(.bold)).frame(width: 44, height: 44) }
          .buttonStyle(.plain).moonGlass(Circle(), weight: .thin).accessibilityLabel("Leave the break")
      }
      Spacer(minLength: 0)
      Group {
        if let s = sponsor, s.media == .video { LoopingVideo(url: s.url).aspectRatio(16 / 9, contentMode: .fit) }
        else if sponsor != nil, let image { Image(uiImage: image).resizable().scaledToFit() }
        else {
          VStack(spacing: 18) {
            Luna(size: 120, wave: true, mood: .happy)
            Image(systemName: fact.symbol).font(.system(size: 34, weight: .bold)).foregroundStyle(Palette.accentInk)
            Text(fact.line).font(.kTitle).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
          }
          .padding(24).frame(maxWidth: .infinity).moonGlass(radius: 28)
        }
      }
      .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
      .frame(maxHeight: 420)
      Spacer(minLength: 0)
      if left > 0 {
        ZStack {
          Circle().stroke(Palette.line, lineWidth: 8)
          Circle().trim(from: 0, to: CGFloat(left) / CGFloat(PlayPlan.breakSeconds))
            .stroke(Palette.accent, style: StrokeStyle(lineWidth: 8, lineCap: .round)).rotationEffect(.degrees(-90))
            .animation(rm ? nil : .linear(duration: 1), value: left)
          Text("\(left)").font(.system(.title, design: .rounded).weight(.heavy)).monospacedDigit()
        }
        .frame(width: 72, height: 72)
        .accessibilityLabel("\(left) seconds left")
      } else {
        Button { collect() } label: { Label("Collect \(PlayPlan.perBreak) new levels", systemImage: "star.fill") }
          .buttonStyle(ChunkyPrimary()).accessibilityIdentifier("collect")
      }
    }
    .padding(22)
    .readable(640)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(AuroraField(surface: .luna).ignoresSafeArea())
    .readsCameraCorner()
    .task {
      if let s = await SponsorFeed.next() {
        if s.media == .image, let (d, _) = try? await URLSession.shared.data(from: s.url), let img = UIImage(data: d) { image = img; sponsor = s }
        else if s.media == .video { sponsor = s }
      }
      loaded = true
      #if DEBUG
      let fast = ProcessInfo.processInfo.arguments.contains("-fastBreak")
      #else
      let fast = false
      #endif
      while left > 0 {
        try? await Task.sleep(for: .seconds(fast ? 0.1 : 1))
        if Task.isCancelled { return }
        if phase == .active { left -= 1 }
      }
      if let s = sponsor { SponsorFeed.counted(s) }
    }
  }
}

/// A muted, looping sponsor video (no controls, nothing to tap).
private struct LoopingVideo: UIViewRepresentable {
  let url: URL
  final class PlayerView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }
    var looper: AVPlayerLooper?
  }
  func makeUIView(context: Context) -> PlayerView {
    let v = PlayerView()
    let player = AVQueuePlayer()
    player.isMuted = true
    v.looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
    (v.layer as? AVPlayerLayer)?.player = player
    (v.layer as? AVPlayerLayer)?.videoGravity = .resizeAspect
    player.play()
    return v
  }
  func updateUIView(_ v: PlayerView, context: Context) {}
  static func dismantleUIView(_ v: PlayerView, coordinator: ()) { ((v.layer as? AVPlayerLayer)?.player)?.pause() }
}
