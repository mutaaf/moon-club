import SwiftUI
import MoonClubCore

/// Today's Market Story: swipeable cards (recap · weather · report cards · word · quiz · what's next).
struct StoryView: View {
  @Environment(AppModel.self) private var app
  @Environment(\.openQuest) private var openQuest
  @State var page = 0
  @State var fold = FoldInfo()
  /// Each page's own height: the pager is as tall as the card on screen (never the tallest card).
  @State var heights: [Int: CGFloat] = [:]
  @State var puppet = false
  @State var more = StoryView.startMore
  @State var lesson: Lesson?
  @State var node: WorldNode?
  @Environment(\.openTab) var openTab
  @Environment(\.accessibilityReduceMotion) var rm
  @Environment(DuoModel.self) var duo: DuoModel?

  enum Card: Hashable { case recap, weather(Double), report(EarningsEvent), why(String), word, quiz, next }

  var cards: [Card] {
    var out: [Card] = []
    let fresh = (app.recap?.active ?? false) && app.state.recapSeen != app.recap?.from
    if fresh { out.append(.recap) }
    if let m = app.mood { out.append(.weather(m)) }
    var seen = Set<String>()
    for e in app.upcoming where e.d <= Day.add(app.today, 10) && !seen.contains(e.s) && seen.count < 3 { seen.insert(e.s); out.append(.report(e)) }
    // "Why did it move?" for a company the kid cares about: their piggy bank, their latest guess, else Disney.
    let whySym = app.state.piggy?.holdings.first?.s ?? app.state.guesses.max { $0.d < $1.d }?.s ?? "DIS"
    out += [.why(whySym), .word, .quiz]
    if !fresh, app.recap?.active == true { out.append(.recap) }
    out.append(.next)
    return out
  }

  /// Debug `-more` opens the "Today's story" section (screenshots).
  static var startMore: Bool {
    #if DEBUG
    return ProcessInfo.processInfo.arguments.contains("-more")
    #else
    return false
    #endif
  }

  var body: some View {
    let _ = Perf.body("StoryView")
    // One primary action (CLAUDE.md "Story: one thing to tap"): the Start here button is the only bright,
    // glowing thing here. Missions shrink to a "Then" strip; the day's story cards wait under "Today's story".
    let step = NextUp.step(app.today, app.state, app.content)
    let wide = fold.fold == nil && fold.width >= 600
    // iPhone Duo opened like a book: Start here gets the left page to itself (the one thing to tap), and
    // Then + Today's story (open, every card in one column) fill the right page. Nothing on the fold.
    FoldPages {
    ScrollView {
      Group {
        if wide {
          // iPad, Stage Manager: Start here on the left, Then + Today's story on the right.
          let left = min(460, max(280, (fold.width - 24) * 0.46)).rounded(.down)
          HStack(alignment: .top, spacing: 24) {
            hero(step).frame(width: left)
            VStack(alignment: .leading, spacing: 16) {
              MissionStrip(hero: step, go: go)
              more(width: fold.width - left - 24)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
          }
        } else {
          VStack(alignment: .leading, spacing: 16) {
            hero(step)
            MissionStrip(hero: step, go: go)
            more(width: fold.width)
          }
        }
      }
      .frame(maxWidth: .infinity, alignment: .topLeading)
      .foldProbe($fold)
      .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 20)
      .readable(wide ? 1040 : 640)
    }
    } first: {
      BookPage(center: true) { hero(step, tall: true) }
    } second: {
      BookPage(spacing: 16) {
        MissionStrip(hero: step, go: go)
        more(width: 0, book: true)
      }
      .onAppear { if !more { more = true } }
    }
    .background(AuroraField(surface: .story))
    .navigationDestination(item: $lesson) { LessonPlayer(lesson: $0) }
    .navigationDestination(item: $node) { NodePlayer(node: $0, regions: World.regions(app.content)) }
    .fullScreenCover(isPresented: $puppet) { PuppetShow() }
    .onChange(of: duo?.isTent ?? false, initial: true) { _, tent in if tent, !puppet { puppet = true } }
    .refreshable { await app.loadMarket() }
    // The weekly recap counts as seen only once the kid opened Today's story.
    .onDisappear { if more, cards.contains(.recap), let r = app.recap { app.mutate { $0.closeRecap(r.from) } } }
    #if DEBUG
    // Screenshots: -whyCard SYM shows the real WhyCard on its own (the story pager sits below the fold on a phone).
    .sheet(isPresented: .constant(ProcessInfo.processInfo.arguments.contains("-whyCard"))) {
      let a = ProcessInfo.processInfo.arguments
      let s = a.firstIndex(of: "-whyCard").flatMap { $0 + 1 < a.count ? a[$0 + 1] : nil } ?? "DIS"
      WhyCard(symbol: s).padding(20)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .padding(20).frame(maxHeight: .infinity, alignment: .top).background(AuroraField(surface: .story))
    }
    // Screenshots: -storyWhy opens the pager on the "Why did it move?" card.
    .task { if ProcessInfo.processInfo.arguments.contains("-storyWhy") { try? await Task.sleep(for: .seconds(1.5)); if let i = cards.firstIndex(where: { if case .why = $0 { return true }; return false }) { page = i } } }
    #endif
  }
}

extension StoryView {
  @ViewBuilder func hero(_ step: NextStep, tall: Bool = false) -> some View {
    StartHereHero(step: step, greeting: NextUp.greeting(step, app.today, app.state, app.content), go: { go(step.target) }, tall: tall)
  }

  /// Plays a step right here (lessons and map stops open on top of Story; Guess and Piggy switch tabs).
  func go(_ t: NextTarget) {
    switch t {
    case let .lesson(id): lesson = app.content.lessons.first { $0.id == id }
    case let .quest(id): openQuest(id)
    case .guess: openTab(.guess)
    case .piggy: openTab(.piggy)
    case .chest: ChestOpener.open(app)
    case let .node(id):
      guard let n = World.regions(app.content).flatMap(\.nodes).first(where: { $0.id == id }) else { return }
      // The same as a tap on the map (WorldView.play).
      switch n.kind {
      case let .quest(q): openQuest(q)
      case let .lesson(l): lesson = app.content.lessons.first { $0.id == l }
      case let .unit(u):
        let ls = app.content.lessons.filter { $0.unit == u }
        lesson = ls.first { !app.state.lessons.contains($0.id) } ?? ls.first
      case .guess: openTab(.guess)
      default: node = n
      }
    }
  }

  /// "Today's story": the day's cards (weather, report cards, a word, a quiz, the weekly recap), closed until
  /// the kid opens it.
  @ViewBuilder func more(width: CGFloat, book: Bool = false) -> some View {
    let cs = cards
    MoreHeader(open: more, date: Day.en("EEEE, MMMM d", app.today), count: cs.count) {
      withAnimation(Motion.safe(Motion.card, rm)) { more.toggle() }
    }
    if more {
      VStack(alignment: .leading, spacing: 16) {
        if duo?.hasHinge == true {
          // iPhone Duo: stand it up like a tent and Luna puts on a puppet show of this story (0.14).
          Button { puppet = true } label: {
            DuoCallout(text: duo?.isTent == true ? "Tent mode! Start the puppet show" : "Stand me up like a tent for a puppet show", symbol: "theatermasks.fill")
          }
          .buttonStyle(PressStyle())
        }
        QuestRow()
        if app.loadingMarket && app.events.isEmpty && app.mood == nil {
          RoundedRectangle(cornerRadius: 28).fill(.thinMaterial).frame(height: 460).overlay(ProgressView())
        } else {
          // Three layouts, chosen by the room we have (never by device):
          //  • a fold (iPhone Duo open): a book, two cards per spread, one each side of the fold
          //  • wide, no fold (iPad, Stage Manager): every card at once in balanced columns
          //  • narrow (iPhone): one card per swipe, the pager as tall as the card on screen
          if book {
            // A book page: every card, one under another (a pager would hide all but one).
            VStack(spacing: 16) {
              ForEach(Array(cs.enumerated()), id: \.offset) { _, c in StoryCard(card: c).fixedSize(horizontal: false, vertical: true) }
            }
          } else if fold.fold == nil, fold.width >= 600 {
            // iPad: the right-hand column (one card under another when it's narrow).
            StoryColumns(cards: cs, width: max(0, width))
          } else {
            pager(cs)
          }
          if let e = app.marketError { Text(e.message).font(.footnote).foregroundStyle(.secondary) }
        }
      }
      .transition(rm ? .opacity : .opacity.combined(with: .move(edge: .top)))
    }
  }

  @ViewBuilder private func pager(_ cs: [Card]) -> some View {
          // Opened wide (iPhone Duo, iPad) the story reads like a book: two cards per spread, one on
          // each side of the fold. On a phone it's one card per swipe.
          let sp = fold.split(minPage: 280)
          let per = sp == nil ? 1 : 2
          // A horizontal pager as tall as the card you're on (each card sizes to its content, the pager
          // eases between heights as you swipe). No card scrolls inside itself; the page scrolls if needed.
          let pages = Array(stride(from: 0, to: cs.count, by: per))
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 0) {
              ForEach(Array(pages.enumerated()), id: \.offset) { p, start in
                Group {
                  if let sp {
                    PageSplit(split: sp) {
                      StoryCard(card: cs[start])
                      if start + 1 < cs.count { StoryCard(card: cs[start + 1]) } else { TheEndPage() }
                    }
                  } else {
                    StoryCard(card: cs[start])
                  }
                }
                .padding(.horizontal, 2)
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGFloat.self) { $0.size.height.rounded() } action: { h in
                  // Whole points, and only real changes: the pager's height follows this, never a loop.
                  if abs((heights[p] ?? -1) - h) >= 1 { heights[p] = h }
                }
                .frame(maxHeight: .infinity, alignment: .top)
                .containerRelativeFrame(.horizontal)
                .id(p)
              }
            }
            .scrollTargetLayout()
          }
          .frame(height: heights[page] ?? heights.values.min() ?? 360, alignment: .top)
          .animation(Motion.page, value: heights[page])
          .scrollTargetBehavior(.paging)
          .scrollPosition(id: Binding(get: { page }, set: { if let v = $0 { page = v } }))
          .scrollClipDisabled()
          PageDots(count: pages.count, page: page) { p in withAnimation(Motion.page) { page = p } }
          .onChange(of: per) { old, new in page = page * old / new }
          .sensoryFeedback(.selection, trigger: page)
  }
}

/// Story cards in balanced columns for wide windows: as many 300+ pt columns as fit (max 3), cards dealt
/// round-robin so reading order runs left to right, each card only as tall as its own content.
struct StoryColumns: View {
  let cards: [StoryView.Card]
  let width: CGFloat
  var body: some View {
    let n = max(1, min(3, Int((width + 18) / (300 + 18))))
    // Exact column widths: flexible columns let SwiftUI measure a card's text at one width and place it at
    // another, which truncated lines ("Makes Disney movies, Pix…").
    let colW = max(0, (width - 18 * CGFloat(n - 1)) / CGFloat(n)).rounded(.down)
    HStack(alignment: .top, spacing: 18) {
      ForEach(0..<n, id: \.self) { col in
        VStack(spacing: 18) {
          ForEach(Array(cards.enumerated()).filter { $0.offset % n == col }, id: \.offset) { _, c in
            StoryCard(card: c).fixedSize(horizontal: false, vertical: true)
          }
        }
        .frame(width: colW, alignment: .top)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

/// Tappable page dots under the story pager (44 pt touch targets, VoiceOver adjustable).
struct PageDots: View {
  let count: Int, page: Int
  let go: (Int) -> Void
  var body: some View {
    HStack(spacing: 8) {
      ForEach(0..<count, id: \.self) { i in
        Capsule().fill(i == page ? Palette.accent : Palette.ink2.opacity(0.25))
          .frame(width: i == page ? 22 : 8, height: 8)
          .frame(minWidth: 16, minHeight: 32).contentShape(Rectangle())
          .onTapGesture { go(i) }
      }
    }
    .frame(maxWidth: .infinity)
    .animation(Motion.card, value: page)
    .accessibilityElement()
    .accessibilityLabel("Card \(page + 1) of \(count)")
    .accessibilityAdjustableAction { d in go(max(0, min(count - 1, page + (d == .increment ? 1 : -1)))) }
  }
}

/// The facing page when today's story has an odd number of cards (two-card spreads only).
struct TheEndPage: View {
  var body: some View {
    Card {
      VStack(spacing: 14) {
        Luna(size: 88, wave: true)
        Text("That's today's story!").font(.kTitle)
        Text("Come back tomorrow for a new page.").font(.kRead).multilineTextAlignment(.center)
      }
      .frame(maxWidth: .infinity, minHeight: 300)
    }
  }
}

struct StoryCard: View {
  let card: StoryView.Card
  @Environment(AppModel.self) private var app
  var body: some View {
    let _ = Perf.body("StoryCard")
    Card {
      switch card {
      case .recap: if let r = app.recap { RecapCard(recap: r) }
      case let .weather(score): WeatherCard(score: score)
      case let .report(e): ReportCard(event: e)
      case let .why(s): WhyCard(symbol: s)
      case .word: WordOfDay()
      case .quiz: QuizOfDay()
      case .next: NextAdventures()
      }
    }
  }
}

struct WeatherCard: View {
  let score: Double
  var body: some View {
    let w = weatherFor(score)
    Eyebrow(text: "Market weather")
    HStack { Spacer(); WeatherArt(icon: w.icon); Spacer() }
    Text(w.title).font(.kHero).lineLimit(2).minimumScaleFactor(0.6)
    Text(w.line).font(.kRead)
    Text("Grown-ups check a “mood meter” for the market. Today it says \(Int(score)) out of 100. 0 is very scared, 100 is very brave.").font(.callout).foregroundStyle(.secondary)
    HStack { ReadAloud(source: .appCopy("Market weather: \(w.title). \(w.line)")); ExplainMore(question: LunaPrompts.explain(weather: w.title)) }
    WordChips(keys: ["mood", "stock", "share"])
  }
}

/// Luna with weather around her: sun rays, drifting clouds, rain — all springy, still under Reduce Motion.
struct WeatherArt: View {
  let icon: String
  @Environment(\.accessibilityReduceMotion) private var rm
  @State private var drift = false
  var body: some View {
    ZStack {
      if ["sun", "bright", "partly"].contains(icon) {
        Circle().fill(RadialGradient(colors: [Color(hex: 0xFFE27A).opacity(0.9), .clear], center: .center, startRadius: 10, endRadius: 90))
          .frame(width: 180).scaleEffect(drift ? 1.08 : 0.94)
      }
      Luna(size: 96)
      if ["cloud", "partly", "storm"].contains(icon) {
        cloud.offset(x: drift ? -50 : -40, y: 28)
        cloud.scaleEffect(0.8).offset(x: drift ? 62 : 50, y: -26)
      }
      if icon == "storm" { Image(systemName: "cloud.rain.fill").font(.system(size: 34)).foregroundStyle(Palette.accent).offset(x: 34, y: 40) }
    }
    .frame(height: 170)
    .onAppear { guard !rm else { return }; withAnimation(.easeInOut(duration: 3.2).repeatForever()) { drift = true } }
    .accessibilityHidden(true)
  }
  var cloud: some View { Image(systemName: "cloud.fill").font(.system(size: 64)).foregroundStyle(.white).shadow(color: .black.opacity(0.08), radius: 8, y: 4) }
}

struct ReportCard: View {
  let event: EarningsEvent
  @Environment(AppModel.self) private var app
  @State private var lastMove: Double??
  var body: some View {
    let co = app.company(event.s)
    let when = kidWhen(event.d, event.h, today: app.today)
    Eyebrow(text: "Report card day!")
    HStack(spacing: 14) {
      Glyph(co.emoji, size: 60)
      VStack(alignment: .leading) { Text(co.nick).font(.kHero).lineLimit(1).minimumScaleFactor(0.5).allowsTightening(true); Text(co.hook.prefix(1).uppercased() + co.hook.dropFirst() + ".").foregroundStyle(.secondary) }
    }
    HStack(spacing: 10) { MoonPhase(phase: event.h == .dmh ? 4 : event.h == .bmo ? 1 : event.h == .amc ? 3 : 0, size: 26); Text("Shares its report card **\(when)**.") }.font(.kRead)
    Text(expectLine(event.eE)).font(.body)
    Group {
      if let lastMove { Text(lastTimeLine(lastMove)) } else { Text("Checking last time…").redacted(reason: .placeholder) }
    }.font(.body).foregroundStyle(Palette.ink2)
    HStack { ReadAloud(source: .appCopy("\(co.nick) \(co.hook). It shares its report card \(when). \(expectLine(event.eE))")); ExplainMore(question: LunaPrompts.explain(reportFor: co.nick, when: when)); Spacer() }
    WordChips(keys: ["company", "report", "guess", "profit"])
    .task { lastMove = .some((try? await app.market.lastMove(event.s))?.history.first { $0.move != nil }?.move) }
  }
}

struct WordOfDay: View {
  @Environment(AppModel.self) private var app
  var body: some View {
    let w = ofTheDay(app.content.words, today: app.today)
    Eyebrow(text: "Big word of the day")
    Text(w.word).font(.system(size: 54, weight: .heavy, design: .rounded)).lineLimit(1).minimumScaleFactor(0.4).foregroundStyle(Palette.accent)
    Text(w.means).font(.kRead)
    Text("Example: \(w.example)").font(.system(.title3, design: .serif).italic()).foregroundStyle(Palette.ink2)
    FlowLayout(spacing: 8) { ReadAloud(source: .appCopy("\(w.word). \(w.means) For example: \(w.example)")); ExplainMore(question: LunaPrompts.explain(word: w.word)) }
  }
}

struct QuizOfDay: View {
  @Environment(AppModel.self) private var app
  var body: some View {
    let q = ofTheDay(app.content.allChecks, today: app.today, salt: 3)
    Eyebrow(text: "Quick quiz")
    CheckView(check: q, seed: 1, picked: .constant(nil), standalone: true)
  }
}

struct NextAdventures: View {
  @Environment(\.openQuest) private var openQuest
  var body: some View {
    Eyebrow(text: "What's next?")
    Text("Pick an adventure").font(.kTitle)
    VStack(spacing: 10) {
      adv("🍋", "Luna's quests", "Learn by playing") { openQuest("lemonade") }
      adv("🎯", "Guess the Report Card", "Will a company beat or miss?") {}
      adv("🎓", "Moon School", "One-minute lessons") {}
    }
  }
  func adv(_ e: String, _ t: String, _ s: String, _ go: @escaping () -> Void) -> some View {
    Button(action: go) {
      HStack(spacing: 14) { Glyph(e, size: 44); VStack(alignment: .leading) { Text(t).font(.kHeadline); Text(s).font(.caption).foregroundStyle(.secondary) }; Spacer(); Image(systemName: "chevron.right").foregroundStyle(.tertiary) }
        .padding(14).moonGlass(radius: 20, weight: .thin)
    }.buttonStyle(.plain)
  }
}

