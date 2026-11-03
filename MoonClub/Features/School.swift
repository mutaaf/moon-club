import SwiftUI
import MoonClubCore

/// Moon School: units → one-minute micro-lessons (say / check / sort steps).
struct SchoolView: View {
  @Environment(AppModel.self) private var app
  @Namespace private var zoom
  @State private var deep: Lesson?

  var body: some View {
    let done = Set(app.state.lessons)
    let next = app.content.lessons.first { !done.contains($0.id) }
    ScrollView {
      VStack(alignment: .leading, spacing: 22) {
        Hero(eyebrow: "\(done.count) of \(app.content.lessons.count) done · about a minute each", title: "Moon", accent: "School", emoji: "🎓")
        StartHere()
        if let next {
          NavigationLink(value: next) {
            HStack(spacing: 14) {
              Glyph(next.emoji, size: 56)
              VStack(alignment: .leading, spacing: 2) {
                Text("UP NEXT · \(app.content.unit(of: next)?.title.uppercased() ?? "")").font(.kEyebrow).opacity(0.8)
                Text(next.title).font(.kTitle)
                Text("\(next.steps.count) tiny steps").font(.caption).opacity(0.8)
              }
              Spacer(); Image(systemName: "arrow.right").font(.title2.weight(.bold))
            }
            .foregroundStyle(.white).padding(18)
            .background(Palette.accent, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .shadow(color: Palette.accent.opacity(0.35), radius: 18, y: 10)
            .modifier(ZoomSource(id: next.id, ns: zoom))
          }.buttonStyle(.plain)
        }
        ForEach(app.content.units) { u in
          let ls = app.content.lessons.filter { $0.unit == u.id }
          let n = ls.filter { done.contains($0.id) }.count
          VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
              Glyph(u.emoji, size: 40)
              VStack(alignment: .leading) { Text(u.title).font(.kTitle); Text(u.blurb).font(.caption).foregroundStyle(.secondary) }
              Spacer()
              Text(n == ls.count ? "Done" : "\(n)/\(ls.count)").font(.caption.monospaced().weight(.semibold)).padding(.horizontal, 10).padding(.vertical, 4).background(.thinMaterial, in: Capsule())
            }
            ForEach(ls) { l in
              NavigationLink(value: l) {
                HStack(spacing: 12) {
                  Glyph(l.emoji, size: 40).frame(width: 44)
                  VStack(alignment: .leading, spacing: 2) { Text(l.title).font(.kHeadline).foregroundStyle(Palette.ink); Text("\(l.steps.count) steps · 1 min").font(.caption).foregroundStyle(.secondary) }
                  Spacer()
                  MoonPhase(phase: done.contains(l.id) ? 4 : 0, size: 24)
                }
                .padding(14).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .modifier(ZoomSource(id: l.id, ns: zoom))
              }
              .buttonStyle(.plain)
              .accessibilityLabel("\(l.title). \(done.contains(l.id) ? "Finished" : "Not started")")
            }
          }
        }
        BadgesGrid()
      }
      .padding(20).readable()
    }
    .background(AuroraField(surface: .school))
    .navigationDestination(for: Lesson.self) { l in LessonPlayer(lesson: l).modifier(ZoomDestination(id: l.id, ns: zoom)) }
    .navigationDestination(item: $deep) { LessonPlayer(lesson: $0) }
    .onAppear {
      let a = ProcessInfo.processInfo.arguments
      if deep == nil, let i = a.firstIndex(of: "-lesson"), i + 1 < a.count { deep = app.content.lessons.first { $0.id == a[i + 1] } }
      openPending()
    }
    .onChange(of: app.pendingLesson) { openPending() }
  }
}

extension SchoolView {
  /// A widget or Live Activity asked for a lesson: open it once.
  func openPending() {
    guard let id = app.pendingLesson else { return }
    app.pendingLesson = nil
    deep = app.content.lessons.first { $0.id == id }
  }
}

/// iOS 18's zoom transition from a lesson card into the player; plain push on iOS 17.
struct ZoomSource: ViewModifier {
  let id: String; let ns: Namespace.ID
  func body(content: Content) -> some View { if #available(iOS 18, *) { content.matchedTransitionSource(id: id, in: ns) } else { content } }
}
struct ZoomDestination: ViewModifier {
  let id: String; let ns: Namespace.ID
  func body(content: Content) -> some View { if #available(iOS 18, *) { content.navigationTransition(.zoom(sourceID: id, in: ns)) } else { content } }
}

struct BadgesGrid: View {
  @Environment(AppModel.self) private var app
  var body: some View {
    let have = app.badges
    VStack(alignment: .leading, spacing: 12) {
      Text("Your moon badges").font(.kTitle)
      // An even number of columns whenever the fold crosses the grid, so no badge sits on the crease.
      FoldColumns(minimum: 100) {
        ForEach(app.content.badges) { b in
          VStack(spacing: 6) {
            MoonPhase(phase: b.phase, size: 48, dim: !have.contains(b.id))
            Text(b.name).font(.caption.weight(.bold)).multilineTextAlignment(.center)
            Text(have.contains(b.id) ? b.why : "Not yet!").font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center).lineLimit(3)
          }
          .frame(maxWidth: .infinity, minHeight: 130).padding(10)
          .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
          .accessibilityElement(children: .combine)
        }
      }
    }
  }
}

/// One step at a time inside the Game On HUD: hearts, combo, coins and Luna, one composed card (big art up
/// top, then the words, then the answers) that fills the screen exactly, and the buttons pinned below.
/// Nothing scrolls at standard text sizes; accessibility text sizes let the *page* scroll as a fallback.
struct LessonPlayer: View {
  let lesson: Lesson
  @Environment(AppModel.self) private var app
  @Environment(\.dismiss) private var dismiss
  @Environment(\.accessibilityReduceMotion) private var rm
  @Environment(\.dynamicTypeSize) private var type
  @State private var step = 0
  @State private var answers: [Int: Int] = [:]
  @State private var sorts: [Int: [Int: Int]] = [:]
  @State private var burst = 0
  @State private var run = RunModel()
  @State private var attempt = 0

  var done: Bool { step >= lesson.steps.count }
  var ready: Bool {
    guard !done else { return true }
    switch lesson.steps[step] {
    case .say: return true
    case .check: return answers[step] != nil
    case let .sort(_, _, items, _): return items.indices.allSatisfy { sorts[step]?[$0] != nil }
    }
  }

  @Environment(DuoModel.self) private var duo: DuoModel?
  /// iPhone Duo: closing the phone on a finished lesson tucks Luna in for the night.
  @State private var tucked = false

  var body: some View {
    Group {
      if type >= .xxxLarge {
        ScrollView { stage.frame(minHeight: 640) }.scrollBounceBehavior(.basedOnSize)
      } else {
        stage
      }
    }
    .safeAreaInset(edge: .bottom) { actions }
    .background(AuroraField(surface: .school))
    .overlay(CoinBurst(tick: run.coinTick, target: run.coinTarget))
    .playChrome()
    #if DEBUG
    .onAppear { let a = ProcessInfo.processInfo.arguments; if let i = a.firstIndex(of: "-step"), i + 1 < a.count, let n = Int(a[i + 1]) { step = min(n, lesson.steps.count - 1) } } // screenshots
    #endif
    .onAppear { LiveActivities.lesson(lesson, step: step) }
    .onDisappear { if !done { LiveActivities.lessonLeft(lesson) } }
    .sensoryFeedback(.selection, trigger: step)
    .onChange(of: duo?.closedTick) { _, _ in if done { withAnimation(rm ? nil : .spring) { tucked = true } } }
    .sensoryFeedback(.impact(weight: .light, intensity: 0.7), trigger: tucked)
    .onChange(of: answers) { old, new in
      // Score the first pick on a check (later taps are locked).
      for (k, v) in new where old[k] == nil {
        if case let .check(c) = lesson.steps[k] { run.record(v == c.answer); app.answered(lesson: lesson.id, step: k, right: v == c.answer, review: false) }
      }
    }
    .onChange(of: sorts) { old, new in
      // Each sorted card: right fills the combo; a wrong one only resets it (sorting never costs a heart).
      for (k, picks) in new {
        guard case let .sort(_, _, items, _) = lesson.steps[k] else { continue }
        for (i, b) in picks where old[k]?[i] == nil {
          if b == items[i].b { run.record(true) } else { run.combo = 0; run.mood = .thinking }
        }
      }
    }
  }

  private var stage: some View {
    VStack(spacing: 12) {
      GameHUD(run: run, title: lesson.title, done: min(step, lesson.steps.count), total: lesson.steps.count) { dismiss() }
      // One card on a phone; opened wide (iPhone Duo, iPad) it's a storybook spread: the story on the
      // left page, the play on the right, never across the fold.
      Storybook(minPage: 280, fill: true) {
        card(art: true)
      } first: {
        storyPage
      } second: {
        card(art: false)
      }
      .frame(maxHeight: .infinity)
    }
    .padding(.horizontal, 20).padding(.top, 4)
    .readable(720)
  }

  @ViewBuilder private var actions: some View {
    HStack(spacing: 12) {
      if run.outOfFuel && !done {
        EmptyView()
      } else if done {
        if !tucked { Button("Back to the map") { dismiss() }.buttonStyle(ChunkyPrimary()) }
      } else {
        Button { go(-1) } label: { Image(systemName: "chevron.left").font(.headline.weight(.heavy)).frame(width: 24) }
          .buttonStyle(ChunkyStyle(face: Palette.card, edge: Palette.line, ink: Palette.ink)).frame(width: 64)
          .disabled(step == 0).opacity(step == 0 ? 0.5 : 1).accessibilityLabel("Back")
        Button(step == lesson.steps.count - 1 ? "Finish" : "Next") { go(1) }.buttonStyle(ChunkyPrimary()).disabled(!ready).opacity(ready ? 1 : 0.55)
      }
    }
    .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 6)
    .readable(720)
  }

  /// The single card (phone) or the right-hand "play" page (spread). `art` keeps the big picture on the
  /// card when there's no left page to hold it.
  private func card(art: Bool) -> some View {
    ZStack {
      if run.outOfFuel && !done {
        OutOfFuel(retry: retry, leave: { dismiss() }).transition(.scale(scale: 0.92).combined(with: .opacity))
      } else if done {
        if tucked {
          VStack(spacing: 14) {
            SleepyLuna(size: 110)
            Text("Goodnight, Luna!").font(.kHero).multilineTextAlignment(.center)
            Text("Luna is tucked in. See you tomorrow for the next one!").font(.kRead).multilineTextAlignment(.center)
          }
          .transition(.scale.combined(with: .opacity))
        } else {
          RunResults(stars: stars, run: run, subtitle: "Lesson done! You filled a moon.", source: .lesson, earnId: lesson.id, again: retry, map: { dismiss() })
            .transition(.scale.combined(with: .opacity))
        }
      } else {
        stepView(lesson.steps[step], art: art).id("\(attempt)-\(step)")
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
          .transition(rm ? .opacity : .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(20)
    .background(Palette.card.opacity(0.9), in: RoundedRectangle(cornerRadius: 32, style: .continuous))
    .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).strokeBorder(.white.opacity(0.6), lineWidth: 1))
    .shadow(color: Palette.accent.opacity(0.12), radius: 18, y: 8)
    .overlay(Celebrate(trigger: burst))
  }

  private var stars: Int { run.answered == 0 ? 3 : World.starsFor(right: run.right, of: run.answered) }

  @ViewBuilder private var doneArt: some View {
    if tucked { SleepyLuna(size: 110) } else { MoonPhase(phase: 4, size: 110) }
  }

  /// The left page of the spread: the picture for a "say" step, or — on a quiz step — the last thing
  /// Luna said, so the answer is right there on the facing page.
  private var storyPage: some View {
    VStack(spacing: 18) {
      Spacer(minLength: 0)
      if done {
        doneArt
      } else if case let .say(emoji, _) = lesson.steps[step] {
        Glyph(emoji, size: 156, style: .halo).enterOnce("say-\(lesson.id)-\(step)")
        Luna(size: 64, wave: true)
      } else if let said = lastSay {
        Eyebrow(text: "Luna said")
        Glyph(said.emoji, size: 84, style: .halo)
        Text(said.text).font(.kRead).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
      } else {
        Luna(size: 96, wave: true)
      }
      Spacer(minLength: 0)
      Text(done ? lesson.title : "Page \(step + 1) of \(lesson.steps.count)").font(.kEyebrow).foregroundStyle(.secondary)
    }
    .id(done ? -1 : step)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(24)
    .background(Palette.moon.opacity(0.35), in: RoundedRectangle(cornerRadius: 32, style: .continuous))
    .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).strokeBorder(Palette.line.opacity(0.6), lineWidth: 0.5))
    .transition(.opacity)
  }

  private var lastSay: (emoji: String, text: String)? {
    for i in stride(from: min(step, lesson.steps.count) - 1, through: 0, by: -1) {
      if case let .say(e, t) = lesson.steps[i] { return (e, t) }
    }
    return nil
  }

  func isQuiz(_ i: Int) -> Bool { if case .say = lesson.steps[i] { return false }; return true }
  func go(_ d: Int) {
    withAnimation(Motion.safe(Motion.card, rm)) { step = max(0, step + d) }
    run.nextRound()
    if step >= lesson.steps.count {
      app.mutate { $0.finishLesson(lesson.id, today: app.today); $0.play("lesson", lesson.id, today: app.today) }
      burst += 1; LiveActivities.lessonDone(lesson)
    } else { LiveActivities.lesson(lesson, step: step) }
  }
  func retry() {
    withAnimation(Motion.safe(Motion.card, rm)) { run.reset(); step = 0; answers = [:]; sorts = [:]; attempt += 1; tucked = false }
  }

  func stepView(_ s: Step, art: Bool = true) -> some View {
    StepContent(step: s, art: art, seed: step + lesson.id.count,
                picked: Binding(get: { answers[step] }, set: { if answers[step] == nil { answers[step] = $0 } }),
                picks: Binding(get: { sorts[step] ?? [:] }, set: { sorts[step] = $0 }), stageKey: lastSay?.emoji)
  }
}

/// What one lesson step shows inside its card. A standalone view so CardFitTests can measure every step
/// of every lesson at every device size and text size (no card may need to scroll).
struct StepContent: View {
  let step: Step
  var art = true
  var seed = 0
  @Binding var picked: Int?
  @Binding var picks: [Int: Int]
  /// The art stage grows into spare room up to this height (CardFitTests measures at its minimum).
  var artMax: CGFloat = 420
  /// The picture a quiz step shows up top (the last thing Luna said); "❓" when there's none.
  var stageKey: String? = nil
  /// The quiz stage's biggest height (0 = none; CardFitTests measures quiz steps without it, since it
  /// only ever takes room the words and answers leave).
  var quizArtMax: CGFloat = 360
  var body: some View {
    switch step {
    case let .say(emoji, text):
      VStack(spacing: 18) {
        if art { ArtPanel(key: emoji, maxHeight: artMax) }
        Text(text).font(.system(.title2, design: .rounded).weight(.bold)).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
        ReadAloud(source: .appCopy(text))
      }
    // Quiz steps: the picture from what Luna just said takes the spare room up top (Luna thinking), so
    // the question and answers sit low, near the thumb, instead of floating over an empty card.
    // The stage is spare-room only: it collapses to nothing when big text needs the space.
    case let .check(c):
      VStack(spacing: 0) {
        if art && quizArtMax > 0 { ArtPanel(key: stageKey ?? "❓", maxHeight: quizArtMax, minHeight: 0, mood: .thinking).padding(.bottom, 16) }
        CheckView(check: c, seed: seed, picked: $picked)
      }
    case let .sort(q, buckets, items, why):
      VStack(spacing: 0) {
        if art && quizArtMax > 0 { ArtPanel(key: stageKey ?? "🤔", maxHeight: quizArtMax, minHeight: 0, mood: .thinking).padding(.bottom, 16) }
        SortView(q: q, buckets: buckets, items: items, why: why, picks: $picks)
      }
    }
  }
}

/// The picture at the top of a lesson card: the art on a soft color stage, with Luna peeking in. It takes
/// the room the words leave (between a minimum and a maximum), so the card always looks composed.
struct ArtPanel: View {
  let key: String
  var maxHeight: CGFloat = 420
  var minHeight: CGFloat = 150
  var mood: Luna.Mood = .happy
  @Environment(\.accessibilityReduceMotion) private var rm
  @State private var float = false
  /// Squeezed below this, the stage hides instead of showing a sliver.
  @State private var tooSmall = false
  var body: some View {
    let spec = Art.spec(key)
    ZStack(alignment: .bottomTrailing) {
      RoundedRectangle(cornerRadius: 26, style: .continuous)
        .fill(LinearGradient(colors: [spec.hue.light.opacity(0.55), spec.hue.light.opacity(0.18)], startPoint: .top, endPoint: .bottom))
      // A few soft dots so the stage isn't flat.
      Canvas { g, sz in
        for i in 0..<7 {
          let fi = CGFloat(i)
          let x = (fi * 0.17 + 0.07).truncatingRemainder(dividingBy: 1) * sz.width
          let y = (fi * 0.29 + 0.12).truncatingRemainder(dividingBy: 1) * sz.height
          let r = 4 + (fi * 3).truncatingRemainder(dividingBy: 7)
          g.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)), with: .color(spec.hue.color.opacity(0.18)))
        }
      }
      // The picture scales with its stage: big on a roomy card, smaller on a short one.
      ViewThatFits(in: .vertical) {
        Glyph(key, size: 132, style: .halo).frame(height: 190)
        Glyph(key, size: 96, style: .halo).frame(height: 140)
        Glyph(key, size: 56, style: .halo).frame(height: 80)
      }
      .offset(y: float && !rm ? -6 : 0)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      Luna(size: 46, wave: true, mood: mood).padding(12)
    }
    .opacity(tooSmall ? 0 : 1)
    .frame(minHeight: min(minHeight, maxHeight), maxHeight: maxHeight)
    .onGeometryChange(for: Bool.self) { $0.size.height < 72 } action: { tooSmall = $0 }
    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    .accessibilityHidden(true)
    .task { guard !rm else { return }; withAnimation(Motion.gentle.repeatForever()) { float = true } }
  }
}

/// A quick check: shuffled options (stable per seed), gentle feedback, read-aloud.
struct CheckView: View {
  let check: Check
  var seed: Int
  @Binding var picked: Int?
  var standalone = false
  @State private var local: Int?
  var chosen: Int? { standalone ? local : picked }
  var body: some View {
    let opts = check.options.enumerated().map { ($0.offset, $0.element) }
    let k = (seed * 7 + check.q.count) % max(1, opts.count)
    let shuffled = Array(opts[k...] + opts[..<k])
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .top, spacing: 10) {
        Text(check.q).font(.kTitle).fixedSize(horizontal: false, vertical: true)
        Spacer(minLength: 0)
        SpeakButton(source: .appCopy("\(check.q) \(check.options.joined(separator: ". Or, ")).") )
      }
      ForEach(Array(shuffled.enumerated()), id: \.element.0) { k, pair in
        let (i, text) = pair
        let right = i == check.answer
        // Once picked, the right answer glows and a wrong pick wobbles; the rest dim.
        let state: AnswerState = chosen == nil ? .idle : right ? .right : chosen == i ? .wrong : .dim
        AnswerButton(text: text, index: k, state: state) {
          guard chosen == nil else { return }
          withAnimation(Motion.tap) { if standalone { local = i } else { picked = i } }
        }
        .allowsHitTesting(chosen == nil)
        .sensoryFeedback(trigger: chosen) { _, n in n == i ? (right ? .success : .error) : nil }
      }
      if let c = chosen { Text((c == check.answer ? "Yes! " : "Good try! ") + check.why).font(.callout.weight(.medium)).fixedSize(horizontal: false, vertical: true).transition(.opacity) }
    }
  }
}

/// A round 44 pt speaker that reads app copy aloud: the compact form of "Read it to me".
struct SpeakButton: View {
  let source: SpeakSource
  @Environment(AppModel.self) private var app
  @State private var speaking = false
  var body: some View {
    Button { speaking = true; Task { await app.voice.speak(source); speaking = false } } label: {
      Image(systemName: speaking ? "waveform" : "speaker.wave.2.fill").font(.headline)
        .symbolEffect(.variableColor.iterative, isActive: speaking)
        .frame(width: 44, height: 44).background(Palette.lavender.opacity(0.85), in: Circle()).foregroundStyle(Palette.midnight)
    }
    .buttonStyle(PressStyle())
    .accessibilityLabel("Read it to me")
  }
}

/// The sorting game as a deck: one card at a time, two big buckets. Each sorted card drops into its
/// bucket's pile, so the whole game fits one card at any size — no list to scroll.
struct SortView: View {
  let q: String; let buckets: [String]; let items: [SortItem]; let why: String
  @Binding var picks: [Int: Int]
  @Environment(\.accessibilityReduceMotion) private var rm
  var next: Int? { items.indices.first { picks[$0] == nil } }
  var body: some View {
    let done = next == nil
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 10) {
        Text(q).font(.kTitle).fixedSize(horizontal: false, vertical: true)
        Spacer(minLength: 0)
        SpeakButton(source: .appCopy("\(q) \(items.map(\.text).joined(separator: ". "))."))
      }
      ZStack {
        if let i = next {
          HStack(spacing: 12) {
            Glyph(items[i].emoji, size: 48)
            Text(items[i].text).font(.kTitle).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Text("\(i + 1)/\(items.count)").font(.caption.monospacedDigit().weight(.semibold)).foregroundStyle(.secondary)
          }
          .padding(14)
          .frame(maxWidth: .infinity, minHeight: 76)
          .background(.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
          .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
          .id(i)
          .transition(rm ? .opacity : .asymmetric(insertion: .scale(scale: 0.9).combined(with: .opacity), removal: .move(edge: .bottom).combined(with: .opacity)))
        } else {
          let right = items.indices.filter { picks[$0] == items[$0].b }.count
          Text((right == items.count ? "All right! " : "\(right) of \(items.count) right. ") + why).font(.callout.weight(.medium))
            .fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading).transition(.opacity)
        }
      }
      HStack(spacing: 10) {
        ForEach(buckets.indices, id: \.self) { b in
          let pile = items.indices.filter { picks[$0] == b }
          let wrong = pile.filter { items[$0].b != b }.count
          Button { if let i = next { withAnimation(Motion.safe(Motion.card, rm)) { picks[i] = b } } } label: {
            VStack(spacing: 6) {
              Text(buckets[b]).font(.kHeadline)
              HStack(spacing: 3) {
                ForEach(pile, id: \.self) { i in Glyph(items[i].emoji, size: 18, style: .plain).opacity(items[i].b == b ? 1 : 0.45) }
              }
              .frame(minHeight: 18)
              if done && wrong > 0 { Text("\(wrong) belong\(wrong == 1 ? "s" : "") in the other one").font(.caption2.weight(.semibold)).foregroundStyle(Palette.badInk) }
            }
            .frame(maxWidth: .infinity, minHeight: 84)
            .background(b == 0 ? Palette.mint.opacity(0.8) : Palette.lavender.opacity(0.9), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Palette.line, lineWidth: 1))
            .foregroundStyle(Palette.midnight)
          }
          .buttonStyle(PressStyle())
          .disabled(done)
          .accessibilityLabel("Put it in \(buckets[b]). \(pile.count) so far.")
        }
      }
      .sensoryFeedback(trigger: picks.count) { _, _ in
        guard let last = picks.keys.max(), let p = picks[last] else { return nil }
        return p == items[last].b ? .success : .warning
      }
      if done {
        Button("Sort again") { withAnimation(Motion.safe(Motion.card, rm)) { picks = [:] } }.font(.subheadline.weight(.semibold))
      }
    }
  }
}
