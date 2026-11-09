import SwiftUI
import MoonClubCore

/// Moon School: units → one-minute micro-lessons (say / check / sort steps).
struct SchoolView: View {
  @Environment(AppModel.self) private var app
  @Namespace private var zoom
  @State private var deep: Lesson?
  @Environment(\.displayScale) private var scale

  var body: some View {
    let done = Set(app.state.lessons)
    let next = app.content.lessons.first { !done.contains($0.id) }
    let _ = Perf.body("School")
    ScrollViewReader { proxy in
    // iPhone Duo opened like a book: the left page is the cover (where you are, Luna's quest, Up Next's
    // living scene, your badges), the right page is every unit and lesson. Each page scrolls on its own,
    // so the lessons never run under the fold and the Up Next card stays in view. One column elsewhere.
    FoldPages {
    ScrollView {
      // Lazy, so a row (and its living scene) exists only while it is on screen or about to be: offscreen
      // scenes run nothing and cost nothing (LessonScenes.swift, ClockHold).
      LazyVStack(alignment: .leading, spacing: 10) {
        cover(done: done, next: next)
        units(done: done, next: next)
        BadgesGrid().id("badges").padding(.top, 12)
      }
      .padding(20).readable()
    }
    .modifier(ScenesWakeOnScroll())
    } first: {
      ScrollView {
        VStack(alignment: .leading, spacing: 10) {
          cover(done: done, next: next)
          BadgesGrid().id("badges").padding(.top, 12)
        }
        .padding(.horizontal, 16).padding(.vertical, 20)
      }
      .modifier(ScenesWakeOnScroll())
    } second: {
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 10) { units(done: done, next: next) }
          .padding(.horizontal, 16).padding(.vertical, 20)
      }
      .modifier(ScenesWakeOnScroll())
    }
    // Draw every card's still picture a few at a time as Moon School opens, so scrolling only shows images.
    .task(id: done.count) {
      let frames = app.content.lessons.map { l in
        SceneTile.frame(lesson: l, scene: Scenes.scene(for: l), status: done.contains(l.id) ? .done : l.id == next?.id ? .next : .open, side: SceneTile.side)
      }
      try? await Task.sleep(for: .milliseconds(300))
      await SceneStill.prewarm(frames, scale: scale)
    }
    #if DEBUG
    .task { await benchScroll(proxy) }
    #endif
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

  /// Where you are: the title, Luna's quest, a refresh, and the Up Next card.
  @ViewBuilder private func cover(done: Set<String>, next: Lesson?) -> some View {
        Hero(eyebrow: "\(done.count) of \(app.content.lessons.count) done · about a minute each", title: "Moon", accent: "School", emoji: "🎓").id("top")
          .padding(.bottom, 12)
        QuestRow()
        RefreshCard()
        if let next {
          NavigationLink(value: next) {
            UpNextHero(lesson: next, unitTitle: app.content.unit(of: next)?.title ?? "")
              .modifier(ZoomSource(id: next.id, ns: zoom))
          }
          .buttonStyle(.plain)
          .padding(.vertical, 12)
        }
  }

  /// Every unit and its lessons (living scene cards).
  @ViewBuilder private func units(done: Set<String>, next: Lesson?) -> some View {
        ForEach(app.content.units) { u in
          let ls = app.content.lessons.filter { $0.unit == u.id }
          let n = ls.filter { done.contains($0.id) }.count
          HStack(spacing: 12) {
            Glyph(u.emoji, size: 40)
            VStack(alignment: .leading) { Text(u.title).font(.kTitle); Text(u.blurb).font(.caption).foregroundStyle(.secondary) }
            Spacer()
            Text(n == ls.count ? "Done" : "\(n)/\(ls.count)").font(.caption.monospaced().weight(.semibold)).padding(.horizontal, 10).padding(.vertical, 4).moonGlass(Capsule(), interactive: true, weight: .thin)
          }
          .padding(.top, 12)
          .id("unit-\(u.id)")
          ForEach(ls) { l in
            let finished = done.contains(l.id)
            NavigationLink(value: l) {
              HStack(spacing: 12) {
                if SceneClock.forced == "off" { Glyph(l.emoji, size: 40).frame(width: 44) } // debug A/B: the old icon square
                else { SceneTile(lesson: l, scene: Scenes.scene(for: l), status: finished ? .done : l.id == next?.id ? .next : .open) }
                VStack(alignment: .leading, spacing: 2) {
                  Text(l.title).font(.kHeadline).foregroundStyle(Palette.ink)
                  HStack(spacing: 6) {
                    Text("\(l.steps.count) steps · 1 min").font(.caption).foregroundStyle(.secondary)
                    if l.since != nil && l.since == app.baseContent.pack?.version { LessonTag(text: "New", fill: Palette.moon) }
                    if app.content.isOptional(l) { LessonTag(text: "Challenge", fill: Palette.lavender) }
                  }
                }
                Spacer()
                MoonPhase(phase: finished ? 4 : 0, size: 24)
              }
              .padding(12).moonGlass(radius: 20, weight: .thin)
              .modifier(ZoomSource(id: l.id, ns: zoom))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(l.title). \(app.content.isOptional(l) ? "Challenge. " : "")\(finished ? "Finished" : "Not started")")
          }
        }
  }
}

extension SchoolView {
  #if DEBUG
  /// Debug `-bench school` (`-demo -world mid -tab school -library -bench school`): 3 s idle at the top, then
  /// scroll the whole list unit by unit and back to the top, then 3 s after everything has settled. Prints
  /// `BENCH school… frames=… mainCPU=…ms/frame` plus body counts (see Design/Perf.swift).
  func benchScroll(_ proxy: ScrollViewProxy) async {
    // Screenshots: `-unit <id>` scrolls Moon School to that unit.
    let a = ProcessInfo.processInfo.arguments
    if let i = a.firstIndex(of: "-unit"), i + 1 < a.count {
      try? await Task.sleep(for: .milliseconds(600))
      proxy.scrollTo("unit-\(a[i + 1])", anchor: .top)
    }
    guard Perf.mode == "school" else { return }
    let mon = FrameMonitor()
    try? await Task.sleep(for: .seconds(4))
    Perf.reset(); mon.start(); try? await Task.sleep(for: .seconds(3)); mon.stop()
    print(Perf.report("schoolIdle") + " " + mon.summary); fflush(stdout)
    Perf.reset(); mon.start()
    let ids = app.content.units.map { "unit-\($0.id)" } + ["badges"]
    for id in ids { withAnimation(.easeInOut(duration: 0.5)) { proxy.scrollTo(id, anchor: .top) }; try? await Task.sleep(for: .milliseconds(650)) }
    for id in ids.reversed().enumerated().filter({ $0.offset % 3 == 0 }).map(\.element) { withAnimation(.easeInOut(duration: 0.5)) { proxy.scrollTo(id, anchor: .top) }; try? await Task.sleep(for: .milliseconds(650)) }
    withAnimation(.easeInOut(duration: 0.5)) { proxy.scrollTo("top", anchor: .top) }; try? await Task.sleep(for: .milliseconds(800))
    mon.stop()
    print(Perf.report("schoolScroll") + " " + mon.summary); fflush(stdout)
    try? await Task.sleep(for: .seconds(15))
    Perf.reset(); mon.start(); try? await Task.sleep(for: .seconds(3)); mon.stop()
    print(Perf.report("schoolSettled") + " " + mon.summary); fflush(stdout)
    print("BENCH done"); fflush(stdout)
  }
  #endif
  /// A widget or Live Activity asked for a lesson: open it once.
  func openPending() {
    guard let id = app.pendingLesson else { return }
    app.pendingLesson = nil
    deep = app.content.lessons.first { $0.id == id }
  }
}

/// Scrolling pauses the lesson scenes (the scroll gets the main thread) and wakes them when it settles,
/// so the cards the kid scrolled to come alive. iOS 18+ (scroll phases); on 17 they wake as rows appear.
struct ScenesWakeOnScroll: ViewModifier {
  func body(content: Content) -> some View {
    if #available(iOS 18, *) {
      content.onScrollPhaseChange { _, phase in
        SceneClock.tiles.setScrolling(phase.isScrolling)
        SceneClock.hero.setScrolling(phase.isScrolling)
      }
    } else { content }
  }
}

/// A small pill on a lesson row: "New" (added in this version) or "Challenge" (the optional Full Moons track).
struct LessonTag: View {
  let text: String; let fill: Color
  var body: some View {
    Text(text).font(.caption2.weight(.bold)).foregroundStyle(Palette.midnight)
      .padding(.horizontal, 7).padding(.vertical, 2).background(fill, in: Capsule())
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
          .moonGlass(radius: 18, weight: .thin)
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
  /// Worked-example lines revealed / growth years grown, per step (one tap each).
  @State private var reveals: [Int: Int] = [:]
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
    case .example, .grow: return (reveals[step] ?? 0) >= lesson.steps[step].reveals
    }
  }
  /// One more line of a worked example, or one more year of growth.
  func reveal() {
    guard !done, (reveals[step] ?? 0) < lesson.steps[step].reveals else { return }
    withAnimation(Motion.safe(Motion.card, rm)) { reveals[step, default: 0] += 1 }
  }
  /// The primary button's words while a worked example or a growth picture still has taps left.
  var revealLabel: String? {
    guard !done, !ready else { return nil }
    let n = reveals[step] ?? 0
    switch lesson.steps[step] {
    case let .example(x): return "Show step \(n + 1) of \(x.lines.count)"
    case let .grow(g): return "Grow a year (\(n + 1) of \(g.years))"
    default: return nil
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
    .glassStage()
    .playChrome()
    #if DEBUG
    .onAppear { let a = ProcessInfo.processInfo.arguments; if let i = a.firstIndex(of: "-step"), i + 1 < a.count, let n = Int(a[i + 1]) { step = min(n, lesson.steps.count - 1) } } // screenshots
    .onAppear { // screenshots: -reveal k shows k lines of a worked example / k years of growth on the -step step
      let a = ProcessInfo.processInfo.arguments
      let k = a.firstIndex(of: "-step").flatMap { $0 + 1 < a.count ? Int(a[$0 + 1]) : nil }.map { min($0, lesson.steps.count - 1) } ?? 0
      if let i = a.firstIndex(of: "-reveal"), i + 1 < a.count, let n = Int(a[i + 1]) { reveals[k] = min(n, lesson.steps[k].reveals) }
    }
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
      // On the fold the HUD and its callout keep to the story page, the buttons to the play page.
      VStack(spacing: 12) {
        GameHUD(run: run, title: lesson.title, done: min(step, lesson.steps.count), total: lesson.steps.count) { dismiss() }
        if bookOpen { DuoCallout(text: "Storybook mode: one page each side", symbol: "book.pages.fill") }
      }
      .foldSide(.first)
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
        if let label = revealLabel {
          Button(label) { reveal() }.buttonStyle(ChunkyPrimary()).sensoryFeedback(.increase, trigger: reveals[step] ?? 0)
        } else {
          Button(step == lesson.steps.count - 1 ? "Finish" : "Next") { go(1) }.buttonStyle(ChunkyPrimary()).disabled(!ready).opacity(ready ? 1 : 0.55)
        }
      }
    }
    .foldSide(.second)
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
            Text("Goodnight, Luna!").font(.kHero).lineLimit(2).minimumScaleFactor(0.6).multilineTextAlignment(.center)
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
      } else if step == 0, case .say = lesson.steps[step] {
        SceneStage(lesson: lesson, maxHeight: 300, minHeight: 200)
      } else if case let .say(emoji, _) = lesson.steps[step] {
        Glyph(emoji, size: 156, style: .halo).enterOnce("say-\(lesson.id)-\(step)")
        Luna(size: 64, wave: true)
      } else if case let .example(x) = lesson.steps[step] {
        Eyebrow(text: "Let's work it out")
        Glyph(x.emoji, size: 120, style: .halo)
        Luna(size: 64, wave: true, mood: .thinking)
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

  /// The iPhone Duo is open (book pose or flat), so the lesson is a two-page storybook on the inner display.
  var bookOpen: Bool { duo?.reading.map { $0.status != .closed } ?? false }

  func isQuiz(_ i: Int) -> Bool { lesson.steps[i].isQuiz }
  func go(_ d: Int) {
    withAnimation(Motion.safe(Motion.card, rm)) { step = max(0, step + d) }
    run.nextRound()
    if step >= lesson.steps.count {
      app.mutate { $0.finishLesson(lesson.id, today: app.today); $0.play("lesson", lesson.id, today: app.today) }
      // iPhone Duo: a lesson read open, as a two-page storybook, counts toward Storybook Reader.
      if bookOpen { app.mutate { $0.useDuo(.book) } }
      burst += 1; LiveActivities.lessonDone(lesson)
    } else { LiveActivities.lesson(lesson, step: step) }
  }
  func retry() {
    withAnimation(Motion.safe(Motion.card, rm)) { run.reset(); step = 0; answers = [:]; sorts = [:]; reveals = [:]; attempt += 1; tucked = false }
  }

  func stepView(_ s: Step, art: Bool = true) -> some View {
    StepContent(step: s, art: art, seed: step + lesson.id.count,
                picked: Binding(get: { answers[step] }, set: { if answers[step] == nil { answers[step] = $0 } }),
                picks: Binding(get: { sorts[step] ?? [:] }, set: { sorts[step] = $0 }), stageKey: lastSay?.emoji,
                progress: reveals[step] ?? 0, advance: { reveal() }, intro: step == 0 ? lesson : nil)
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
  /// Lines revealed (worked example) or years grown (grow step).
  var progress = 0
  /// Tapping the growth picture grows a year too.
  var advance: (() -> Void)? = nil
  /// The lesson's first step: its Moon School scene, big, in place of the picture (card → lesson feels like
  /// one picture growing). Same spare-room sizing as the art panel.
  var intro: Lesson? = nil
  var body: some View {
    switch step {
    case let .say(emoji, text):
      VStack(spacing: 18) {
        if art { if let intro { SceneStage(lesson: intro, maxHeight: artMax) } else { ArtPanel(key: emoji, maxHeight: artMax) } }
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
    case let .example(x):
      ExampleView(example: x, shown: progress, art: art)
    case let .grow(g):
      GrowView(grow: g, grown: progress, advance: advance)
    }
  }
}

/// A worked example ("Let's work it out"): the setup, then each line of working, revealed one tap at a time.
/// Hidden lines keep their room (a soft bar), so the card never jumps and always fits.
struct ExampleView: View {
  let example: Example
  let shown: Int
  var art = true
  @Environment(\.accessibilityReduceMotion) private var rm
  var body: some View {
    VStack(spacing: 10) {
      // The picture rides next to the eyebrow (a full art stage made the card too tall on iPhone SE).
      HStack(spacing: 10) {
        if art { Glyph(example.emoji, size: 40) }
        Eyebrow(text: "Let's work it out")
      }
      Text(example.text).font(.system(.title3, design: .rounded).weight(.bold)).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
      VStack(spacing: 8) {
        ForEach(example.lines.indices, id: \.self) { i in
          let on = i < shown
          HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(i + 1)").font(.caption.weight(.heavy).monospacedDigit())
              .frame(width: 26, height: 26).background(Circle().fill(on ? Palette.mint : Palette.line.opacity(0.6))).foregroundStyle(Palette.midnight)
            Text(example.lines[i]).font(.system(.headline, design: .rounded).monospacedDigit()).foregroundStyle(Palette.ink)
              .fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
              .opacity(on ? 1 : 0)
              .overlay(alignment: .leading) { if !on { Capsule().fill(Palette.line.opacity(0.7)).frame(width: 90, height: 10) } }
          }
          .padding(.horizontal, 12).padding(.vertical, 7)
          .background(on ? Palette.mint.opacity(0.45) : Palette.line.opacity(0.18), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
          .scaleEffect(on || rm ? 1 : 0.98)
          .accessibilityHidden(!on)
        }
      }
      ReadAloud(source: .appCopy(([example.text] + example.lines.prefix(shown)).joined(separator: ". ")))
    }
  }
}

/// Year-by-year growth the child grows with a tap: a Moon Garden plant (savings), a price tag (prices going
/// up) or an IOU (money owed), with an optional faint comparison row. Pretend whole numbers from `Growth`.
struct GrowView: View {
  let grow: Grow
  let grown: Int
  var advance: (() -> Void)? = nil
  @Environment(\.accessibilityReduceMotion) private var rm
  var ink: Color { grow.show == "price" ? Hue.orange.color : grow.show == "owe" ? Hue.berry.color : Hue.mint.color }
  var icon: String { grow.show == "price" ? "tag.fill" : grow.show == "owe" ? "doc.plaintext.fill" : "leaf.fill" }
  func money(_ v: Int) -> String { "$" + v.formatted(.number.grouping(.automatic)) }
  var body: some View {
    let rows = Growth.rows(grow)
    let top = Double(max(rows.main.max() ?? 1, rows.vs?.max() ?? 1, 1))
    let y = min(grown, grow.years)
    VStack(spacing: 10) {
      Eyebrow(text: "Pretend numbers · tap to grow")
      Text(grow.text).font(.system(.title3, design: .rounded).weight(.bold)).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
      HStack(alignment: .bottom, spacing: 3) {
        ForEach(0...grow.years, id: \.self) { i in
          let on = i <= y
          VStack(spacing: 3) {
            Image(systemName: icon).font(.caption2.weight(.bold)).foregroundStyle(ink).opacity(i == y ? 1 : 0)
            HStack(alignment: .bottom, spacing: 1.5) {
              if let vs = rows.vs { RoundedRectangle(cornerRadius: 3).fill(Palette.ink2.opacity(0.25)).frame(height: on ? max(3, 82 * Double(vs[i]) / top) : 3) }
              RoundedRectangle(cornerRadius: 4).fill(LinearGradient(colors: [ink.opacity(0.75), ink], startPoint: .top, endPoint: .bottom))
                .frame(height: on ? max(3, 82 * Double(rows.main[i]) / top) : 3).opacity(on ? 1 : 0.35)
            }
            .frame(height: 84, alignment: .bottom)
            Text(i == 0 ? "Now" : "\(i)").font(.system(size: 10, weight: .semibold).monospacedDigit()).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.6)
          }
          .frame(maxWidth: .infinity)
        }
      }
      .padding(10)
      .background(Palette.line.opacity(0.18), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
      .contentShape(Rectangle())
      .onTapGesture { advance?() }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("\(grow.label): \(money(rows.main[0])) now, \(money(rows.main[y])) after \(y) year\(y == 1 ? "" : "s").\(rows.vs.map { " \(grow.vs?.label ?? ""): \(money($0[y]))." } ?? "")")
      .accessibilityAddTraits(.isButton)
      .accessibilityAction { advance?() }
      VStack(alignment: .leading, spacing: 4) {
        legend(color: ink, label: grow.label, value: rows.main[y])
        if let vs = rows.vs, let v = grow.vs { legend(color: Palette.ink2.opacity(0.35), label: v.label, value: vs[y]) }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .animation(rm ? nil : Motion.tap, value: y)
    }
  }
  private func legend(color: Color, label: String, value: Int) -> some View {
    HStack(spacing: 8) {
      RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 14, height: 14)
      Text(label).font(.subheadline.weight(.semibold))
      Spacer(minLength: 4)
      Text(money(value)).font(.system(.headline, design: .rounded).monospacedDigit()).contentTransition(.numericText())
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
