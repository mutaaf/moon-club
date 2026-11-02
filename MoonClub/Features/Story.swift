import SwiftUI
import MoonClubCore

/// Today's Market Story: swipeable cards (recap · weather · report cards · word · quiz · what's next).
struct StoryView: View {
  @Environment(AppModel.self) private var app
  @Environment(\.openQuest) private var openQuest
  @State private var page = 0
  @State private var fold = FoldInfo()

  enum Card: Hashable { case recap, weather(Double), report(EarningsEvent), word, quiz, next }

  var cards: [Card] {
    var out: [Card] = []
    let fresh = (app.recap?.active ?? false) && app.state.recapSeen != app.recap?.from
    if fresh { out.append(.recap) }
    if let m = app.mood { out.append(.weather(m)) }
    var seen = Set<String>()
    for e in app.upcoming where e.d <= Day.add(app.today, 10) && !seen.contains(e.s) && seen.count < 3 { seen.insert(e.s); out.append(.report(e)) }
    out += [.word, .quiz]
    if !fresh, app.recap?.active == true { out.append(.recap) }
    out.append(.next)
    return out
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        Hero(eyebrow: Day.en("EEEE, MMMM d", app.today), title: "Today's", accent: "Market Story")
        StartHere()
        if app.loadingMarket && app.events.isEmpty && app.mood == nil {
          RoundedRectangle(cornerRadius: 28).fill(.thinMaterial).frame(height: 460).overlay(ProgressView())
        } else {
          let cs = cards
          // Opened wide (iPhone Duo, iPad) the story reads like a book: two cards per spread, one on
          // each side of the fold. On a phone it's one card per swipe.
          let sp = fold.split(minPage: 280)
          let per = sp == nil ? 1 : 2
          TabView(selection: $page) {
            ForEach(Array(stride(from: 0, to: cs.count, by: per).enumerated()), id: \.offset) { p, start in
              Group {
                if let sp {
                  PageSplit(split: sp, fill: true) {
                    StoryCard(card: cs[start])
                    if start + 1 < cs.count { StoryCard(card: cs[start + 1]) } else { TheEndPage() }
                  }
                } else {
                  StoryCard(card: cs[start]).padding(.horizontal, 2)
                }
              }
              .padding(.bottom, 44).tag(p)
            }
          }
          .tabViewStyle(.page(indexDisplayMode: .always))
          .indexViewStyle(.page(backgroundDisplayMode: .always))
          .frame(height: 560)
          .foldProbe($fold)
          .onChange(of: per) { old, new in page = page * old / new }
          .sensoryFeedback(.selection, trigger: page)
          if let e = app.marketError { Text(e.message).font(.footnote).foregroundStyle(.secondary) }
        }
      }
      .padding(20)
      .readable()
    }
    .background(AuroraField(surface: .story))
    .refreshable { await app.loadMarket() }
    .onDisappear { if cards.contains(.recap), let r = app.recap { app.mutate { $0.closeRecap(r.from) } } }
  }
}

/// The facing page when today's story has an odd number of cards (two-card spreads only).
struct TheEndPage: View {
  var body: some View {
    Card {
      VStack(spacing: 14) {
        Luna(size: 88, wave: true)
        Text("That's today's story!").font(.kTitle)
        Text("Come back tomorrow for a new page. 🌙").font(.kRead).multilineTextAlignment(.center)
      }
      .frame(maxWidth: .infinity, minHeight: 300)
    }
  }
}

struct StoryCard: View {
  let card: StoryView.Card
  @Environment(AppModel.self) private var app
  var body: some View {
    ScrollView(showsIndicators: false) { Card {
      switch card {
      case .recap: if let r = app.recap { RecapCard(recap: r) }
      case let .weather(score): WeatherCard(score: score)
      case let .report(e): ReportCard(event: e)
      case .word: WordOfDay()
      case .quiz: QuizOfDay()
      case .next: NextAdventures()
      }
    } }
    .scrollBounceBehavior(.basedOnSize)
  }
}

struct WeatherCard: View {
  let score: Double
  var body: some View {
    let w = weatherFor(score)
    Eyebrow(text: "Market weather")
    HStack { Spacer(); WeatherArt(icon: w.icon); Spacer() }
    Text("\(w.title) \(w.emoji)").font(.kHero)
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
    let co = app.companies[event.s]!
    let when = kidWhen(event.d, event.h, today: app.today)
    Eyebrow(text: "Report card day!")
    HStack(spacing: 14) {
      Text(co.emoji).font(.system(size: 56)).accessibilityHidden(true)
      VStack(alignment: .leading) { Text(co.nick).font(.kHero); Text(co.hook.prefix(1).uppercased() + co.hook.dropFirst() + ".").foregroundStyle(.secondary) }
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
    Text(w.word).font(.system(size: 54, weight: .heavy, design: .rounded)).foregroundStyle(Palette.accent)
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
      HStack(spacing: 14) { Text(e).font(.system(size: 34)); VStack(alignment: .leading) { Text(t).font(.kHeadline); Text(s).font(.caption).foregroundStyle(.secondary) }; Spacer(); Image(systemName: "chevron.right").foregroundStyle(.tertiary) }
        .padding(14).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }.buttonStyle(.plain)
  }
}

/// "New here? Start here!" until every quest chapter is done.
struct StartHere: View {
  @Environment(AppModel.self) private var app
  @Environment(\.openQuest) private var openQuest
  var body: some View {
    let chapters = app.content.questChapters?.CHAPTERS ?? []
    if let next = chapters.first(where: { !app.chaptersDone.contains($0.id) }) ?? (app.state.questDone ? nil : chapters.first) {
      Button { openQuest(next.id) } label: {
        HStack(spacing: 14) {
          Text(next.emoji).font(.system(size: 40)).phaseAnimator([0, 1]) { v, p in v.rotationEffect(.degrees(p == 1 ? -6 : 4)) } animation: { _ in .easeInOut(duration: 1.6) }
          VStack(alignment: .leading, spacing: 3) {
            Eyebrow(text: app.chaptersDone.isEmpty ? "New here? Start here!" : "Next chapter")
            Text(next.title).font(.kTitle).foregroundStyle(Palette.midnight)
            Text(next.blurb).font(.subheadline).foregroundStyle(Palette.midnight.opacity(0.7))
          }
          Spacer(minLength: 0)
          Image(systemName: "arrow.right.circle.fill").font(.title).foregroundStyle(Palette.accent)
        }
        .padding(18)
        .background(LinearGradient(colors: [Palette.moon, Color(hex: 0xFFE2A8)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: Color(hex: 0xC9A33A).opacity(0.25), radius: 18, y: 8)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Start here: \(next.title). \(next.blurb)")
    }
  }
}
