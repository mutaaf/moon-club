import SwiftUI
import AVFoundation
import MoonClubCore

/// The Play button on an Arcade level card (Candle Academy, Line Lab, Moon Tower), with Moon Club Pass rules:
/// free levels play at once; past today's new levels it opens `PlayLimitSheet` instead. Rules: `PlayPlan`.
/// 0.22: today's new levels show as little moons under the button; the pass shows its seal.
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
    let plays = app.pass.plays(today: app.today)
    VStack(spacing: 8) {
      Button(title) { tapped() }
      .buttonStyle(ChunkyPrimary())
      .accessibilityIdentifier("level-play")
      if plays.pass && number > PlayPlan.freeRun(climb) {
        Label("Moon Club Pass", systemImage: "checkmark.seal.fill").font(.caption.weight(.heavy)).foregroundStyle(Hue.gold.text)
      } else if let chip = PlayPlan.chip(d) {
        HStack(spacing: 8) {
          TodayMoons(plays: plays, compact: true)
          Text(chip).font(.caption.weight(.bold)).foregroundStyle(Palette.ink2)
        }
        .accessibilityElement(children: .combine)
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
    .onAppear {
      let a = ProcessInfo.processInfo.arguments
      if a.contains("-limit") && !d.allowed { limit = true }
      // Repro / smoke test: press Play by itself (the same action as a tap).
      if a.contains("-tapPlay") { Task { try? await Task.sleep(for: .seconds(1.5)); tapped() } }
    }
    #endif
  }

  private func tapped() {
    if app.pass.request(climb, number: number, id: id, won: won, today: app.today) { play() } else { limit = true }
  }
}

/// Today's new levels as moons: glowing = still open, dim = played, a lock = behind a break.
/// Compact (the level card) shows only the open and played ones; full (limit sheet, grown-up corner) shows
/// the daily three and each break's three, labelled.
struct TodayMoons: View {
  let plays: PlayPlan.Today
  var compact = false
  @Environment(\.accessibilityReduceMotion) private var rm

  var body: some View {
    let slots = plays.slots
    Group {
      if compact {
        HStack(spacing: 3) {
          ForEach(Array(slots.prefix(plays.allowance).enumerated()), id: \.offset) { _, s in moon(s, size: 13) }
        }
      } else {
        HStack(alignment: .top, spacing: 8) {
          ForEach(0...PlayPlan.breaksPerDay, id: \.self) { g in
            let lo = g == 0 ? 0 : PlayPlan.dailyFree + (g - 1) * PlayPlan.perBreak
            let hi = g == 0 ? PlayPlan.dailyFree : lo + PlayPlan.perBreak
            VStack(spacing: 6) {
              HStack(spacing: 4) { ForEach(lo..<hi, id: \.self) { i in moon(slots[i], size: 18) } }
                .padding(.horizontal, 8).padding(.vertical, 7)
                .background(Capsule().fill(g == 0 ? Hue.lemon.color.opacity(0.18) : Palette.line.opacity(0.35)))
              Text(g == 0 ? "Daily" : "Break \(g)").font(.caption2.weight(.heavy)).foregroundStyle(Palette.ink2)
            }
            .frame(maxWidth: .infinity)
          }
        }
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(plays.left == 1 ? "1 new level left today" : "\(plays.left) new levels left today")
  }

  @ViewBuilder private func moon(_ s: PlayPlan.Today.Slot, size: CGFloat) -> some View {
    switch s {
    case .open:
      Image(systemName: "moon.stars.fill").font(.system(size: size, weight: .bold)).foregroundStyle(Hue.gold.color)
        .shadow(color: Hue.lemon.color.opacity(0.7), radius: rm ? 0 : 4)
    case .used:
      Image(systemName: "moon.fill").font(.system(size: size, weight: .bold)).foregroundStyle(Palette.ink2.opacity(0.35))
    case .locked:
      Image(systemName: "lock.fill").font(.system(size: size * 0.7, weight: .bold)).foregroundStyle(Palette.ink2.opacity(0.45))
        .frame(width: size, height: size)
    }
  }
}

/// "That's today's new levels!": today's moons, when new ones open, a short break (a sponsor's, or Luna's quiz)
/// for more, replays, or ask a grown-up about Moon Club Pass (the gate first; buying only happens in `PassOffer`).
/// Never punitive: replays stay free.
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
    let plays = app.pass.plays(today: app.today)
    VStack(spacing: 16) {
      HStack {
        Spacer()
        Button { dismiss() } label: { Image(systemName: "xmark").font(.headline.weight(.bold)).frame(width: 44, height: 44) }
          .buttonStyle(.plain).moonGlass(Circle(), weight: .thin).accessibilityLabel("Close")
      }
      Spacer(minLength: 0)
      Luna(size: 96, mood: d == .doneForToday ? .sleepy : .cheering)
      VStack(spacing: 8) {
        Text(PlayPlan.limitTitle).font(.kHero).multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.6)
        Text(PlayPlan.limitLine(d)).font(.body).multilineTextAlignment(.center).foregroundStyle(Palette.ink2)
          .fixedSize(horizontal: false, vertical: true)
      }
      VStack(spacing: 12) {
        TodayMoons(plays: plays)
        TimelineView(.periodic(from: .now, by: 30)) { ctx in
          Label(PlayPlan.resetLine(minutes: PlayPlan.minutesToTomorrow(ctx.date)), systemImage: "moon.zzz.fill")
            .font(.footnote.weight(.bold)).foregroundStyle(Palette.ink2).monospacedDigit()
        }
      }
      .padding(16).frame(maxWidth: .infinity).moonGlass(radius: 24, weight: .thin)
      Spacer(minLength: 0)
      VStack(spacing: 10) {
        if app.pass.canBreak(today: app.today) {
          Button { breakOn = true } label: { Label(PlayPlan.breakButton(left: plays.breaksLeft), systemImage: "play.circle.fill") }
            .buttonStyle(ChunkyPrimary()).accessibilityIdentifier("take-break")
          Text("\(PlayPlan.breakSeconds) seconds, then \(PlayPlan.perBreak) more new levels · \(plays.breaksLeft == 1 ? "1 break" : "\(plays.breaksLeft) breaks") left today")
            .font(.caption.weight(.semibold)).foregroundStyle(Palette.ink2).multilineTextAlignment(.center)
        }
        HStack(spacing: 10) {
          Button { dismiss() } label: { Label("Replay", systemImage: "arrow.counterclockwise").frame(maxWidth: .infinity) }
            .buttonStyle(SoftButtonStyle()).accessibilityLabel(PlayPlan.replayButton)
          Button { gate = true } label: { Label(PlayPlan.askButton, systemImage: "lock.shield").frame(maxWidth: .infinity) }
            .buttonStyle(SoftButtonStyle()).accessibilityIdentifier("ask-grownup")
        }
        Text(PlayPlan.askLine).font(.caption).foregroundStyle(Palette.ink2).multilineTextAlignment(.center)
      }
    }
    .padding(22)
    .readable(560)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(AuroraField(surface: .quest).ignoresSafeArea())
    .scrollsWhenShort(minHeight: 640)
    .fullScreenCover(isPresented: $breakOn) {
      LunaBreak(climb: climb) { source in app.pass.finishBreak(today: app.today, source: source); breakOn = false; more() }
    }
    .sheet(isPresented: $gate, onDismiss: { if passed { passed = false; offer = true } }) { ParentGate { passed = true } }
    .sheet(isPresented: $offer, onDismiss: { if app.pass.active { more() } }) { PassOffer() }
    #if DEBUG
    .onAppear { if ProcessInfo.processInfo.arguments.contains("-break") { breakOn = true } }
    #endif
  }
}

/// A short break: a kid-safe sponsor's picture or video from Marquee when there is one, otherwise Luna's
/// one-question chart quiz (0.22). A ring counts down while the app is in front; then "Collect", which pops the
/// three new moons with a party. Nothing to tap out to.
struct LunaBreak: View {
  let climb: Climb
  /// "sponsor" or "luna" (for the device's event log).
  let collect: (String) -> Void
  @Environment(AppModel.self) private var app
  @Environment(\.dismiss) private var dismiss
  @Environment(\.scenePhase) private var phase
  @Environment(\.accessibilityReduceMotion) private var rm
  @State private var sponsor: Sponsor?
  @State private var loaded = false
  @State private var left = PlayPlan.breakSeconds
  @State private var image: UIImage?
  @State private var picked: Int?
  @State private var collecting = false
  @State private var party = 0

  var body: some View {
    let n = app.pass.ledger.on(app.today).breaks
    let quiz = PlayPlan.quiz(day: app.today, n: n)
    ZStack {
      VStack(spacing: 16) {
        HStack {
          Text(sponsor.map { $0.label.isEmpty ? "Sponsor break" : "Sponsor break: \($0.label)" } ?? "A short break with Luna")
            .font(.footnote.weight(.heavy)).padding(.horizontal, 12).padding(.vertical, 6).moonGlass(Capsule(), weight: .thin)
            .accessibilityIdentifier("break-label")
          Spacer()
          Button { dismiss() } label: { Image(systemName: "xmark").font(.headline.weight(.bold)).frame(width: 44, height: 44) }
            .buttonStyle(.plain).moonGlass(Circle(), weight: .thin).accessibilityLabel("Leave the break")
            .disabled(collecting)
        }
        Spacer(minLength: 0)
        Group {
          if let s = sponsor, s.media == .video {
            // A video that can't play falls back to Luna's quiz (0.23).
            LoopingVideo(url: s.url) { EventLog.shared.add("sponsor.videoFailed", s.id); sponsor = nil }.aspectRatio(16 / 9, contentMode: .fit)
          }
          else if sponsor != nil, let image { Image(uiImage: image).resizable().scaledToFit() }
          else if loaded { QuizCard(quiz: quiz, picked: $picked) }
          else { ProgressView().controlSize(.large).frame(height: 200) }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .frame(maxHeight: 520)
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
          Button {
            guard !collecting else { return }
            collecting = true; party &+= 1
            let source = sponsor == nil ? "luna" : "sponsor"
            Task { try? await Task.sleep(for: .milliseconds(rm ? 400 : 1300)); collect(source) }
          } label: { Label(collecting ? PlayPlan.collected : PlayPlan.collectButton, systemImage: "star.fill") }
            .buttonStyle(ChunkyPrimary()).accessibilityIdentifier("collect")
            .transition(.scale.combined(with: .opacity))
        }
      }
      .padding(22)
      .readable(640)
      if collecting { CollectMoons().allowsHitTesting(false) }
      Celebrate(trigger: party, tier: .medium).allowsHitTesting(false).accessibilityHidden(true)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(AuroraField(surface: .luna).ignoresSafeArea())
    .readsCameraCorner()
    .sensoryFeedback(.success, trigger: party)
    .animation(rm ? nil : .spring(response: 0.4, dampingFraction: 0.7), value: left == 0)
    .task {
      if let s = await SponsorFeed.next() {
        if s.media == .image, let img = await SponsorFeed.image(s) { image = img; sponsor = s }
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
    #if DEBUG
    .onAppear { if ProcessInfo.processInfo.arguments.contains("-quizPick") { picked = 0 } }
    #endif
  }
}

/// Luna's break: one chart fact, then a two-choice question. A pick shows why, right or not (never scolds).
private struct QuizCard: View {
  let quiz: PlayPlan.Quiz
  @Binding var picked: Int?
  @Environment(\.accessibilityReduceMotion) private var rm
  @State private var spark = 0

  var body: some View {
    let right = picked == quiz.answer
    VStack(spacing: 16) {
      HStack(alignment: .center, spacing: 14) {
        Luna(size: 72, wave: picked == nil, mood: picked == nil ? .happy : right ? .cheering : .thinking)
        Image(systemName: quiz.symbol).font(.system(size: 30, weight: .bold)).foregroundStyle(Palette.accentInk)
          .frame(width: 60, height: 60).moonGlass(Circle(), weight: .thin)
      }
      Text(quiz.fact).font(.kHeadline).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
      Divider().overlay(Palette.line)
      Text(quiz.question).font(.kTitle).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
      HStack(spacing: 10) {
        ForEach(quiz.choices.indices, id: \.self) { i in
          Button {
            guard picked == nil else { return }
            withAnimation(rm ? nil : .spring(response: 0.35, dampingFraction: 0.7)) { picked = i }
            if i == quiz.answer { spark &+= 1 }
          } label: {
            HStack(spacing: 6) {
              if picked != nil, i == quiz.answer { Image(systemName: "checkmark.circle.fill") }
              else if picked == i { Image(systemName: "circle.dotted") }
              Text(quiz.choices[i]).lineLimit(2).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
          }
          .buttonStyle(SoftButtonStyle(selected: picked != nil && i == quiz.answer))
          .opacity(picked != nil && i != quiz.answer ? 0.55 : 1)
          .accessibilityIdentifier("quiz-\(i)")
        }
      }
      if picked != nil {
        VStack(spacing: 4) {
          Text(right ? PlayPlan.rightLine : PlayPlan.missLine).font(.headline.weight(.heavy)).foregroundStyle(right ? Palette.goodInk : Palette.accentInk)
          Text(quiz.why).font(.callout).foregroundStyle(Palette.ink2).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
      }
    }
    .padding(22).frame(maxWidth: .infinity).moonGlass(radius: 28)
    .overlay { Celebrate(trigger: spark, tier: .small).allowsHitTesting(false).accessibilityHidden(true) }
    .sensoryFeedback(.impact(weight: .light), trigger: spark)
  }
}

/// The collect moment: three moons pop up from the button and float to the top.
private struct CollectMoons: View {
  @Environment(\.accessibilityReduceMotion) private var rm
  @State private var up = false
  var body: some View {
    GeometryReader { g in
      ForEach(0..<PlayPlan.perBreak, id: \.self) { i in
        let x = g.size.width / 2 + CGFloat(i - 1) * 70
        Image(systemName: "moon.stars.fill").font(.system(size: 44, weight: .bold)).foregroundStyle(Hue.gold.color)
          .shadow(color: Hue.lemon.color.opacity(0.8), radius: 12)
          .scaleEffect(up ? 1.15 : 0.2)
          .opacity(up ? 1 : 0)
          .position(x: x, y: up ? g.size.height * 0.28 : g.size.height * 0.86)
          .animation(rm ? nil : .spring(response: 0.6, dampingFraction: 0.62).delay(Double(i) * 0.12), value: up)
      }
    }
    .onAppear { up = true }
    .accessibilityHidden(true)
  }
}

/// A muted, looping sponsor video (no controls, nothing to tap). Calls `failed` once if it can't play.
private struct LoopingVideo: UIViewRepresentable {
  let url: URL
  var failed: () -> Void = {}
  final class PlayerView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }
    var looper: AVPlayerLooper?
    var watch: NSKeyValueObservation?
  }
  func makeUIView(context: Context) -> PlayerView {
    let v = PlayerView()
    let player = AVQueuePlayer()
    player.isMuted = true
    player.preventsDisplaySleepDuringVideoPlayback = false
    let looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
    v.looper = looper
    let failed = self.failed
    v.watch = looper.observe(\.status, options: [.new]) { l, _ in
      if l.status == .failed { Task { @MainActor in failed() } }
    }
    (v.layer as? AVPlayerLayer)?.player = player
    (v.layer as? AVPlayerLayer)?.videoGravity = .resizeAspect
    player.play()
    return v
  }
  func updateUIView(_ v: PlayerView, context: Context) {}
  static func dismantleUIView(_ v: PlayerView, coordinator: ()) {
    v.watch?.invalidate()
    ((v.layer as? AVPlayerLayer)?.player)?.pause()
    v.looper?.disableLooping()
  }
}
