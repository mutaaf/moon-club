import SwiftUI
import MoonClubCore

/// Guess the Report Card: beat or miss, a bonus up/down, reveal with a why, and the Family League board.
struct GuessView: View {
  @Environment(AppModel.self) private var app
  @Namespace private var ns
  @State private var bonus: [String: Direction] = [:]
  @State private var word: String?
  @State private var gameNight = false
  @State private var showWords = false

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 22) {
        Hero(eyebrow: "A guessing game", title: "Guess the", accent: "Report Card", emoji: "🎯")
        intro
        gameNightCard
        LeagueBoard()
        let mine = app.state.guesses.sorted { $0.d < $1.d }
        if !mine.isEmpty {
          Text("Your guesses").font(.kTitle)
          ForEach(mine, id: \.self) { g in RevealRow(guess: g).matchedGeometryEffect(id: "\(g.s):\(g.d)", in: ns) }
        }
        Text("Coming up").font(.kTitle)
        let guessed = Set(app.state.guesses.map { "\($0.s):\($0.d)" })
        let open = app.upcoming.filter { !guessed.contains($0.id) }.prefix(8)
        if app.loadingMarket && app.events.isEmpty { ProgressView().frame(maxWidth: .infinity, minHeight: 120) }
        else if open.isEmpty { Card { Text("No new report cards from companies you know in the next three weeks. Explore Market World while you wait!").font(.kRead) } }
        else {
          ForEach(Array(open)) { e in upcomingCard(e).matchedGeometryEffect(id: e.id, in: ns) }
        }
      }
      .padding(20).readable()
      .animation(.spring(response: 0.5, dampingFraction: 0.82), value: app.state.guesses)
    }
    .background(AuroraField(surface: .guess))
    .refreshable { await app.loadMarket() }
    .sheet(item: Binding(get: { word.map(Ident.init) }, set: { word = $0?.id })) { WordSheet(key: $0.id) }
    .fullScreenCover(isPresented: $gameNight) { GameNightView() }
    #if DEBUG
    .onAppear { if ProcessInfo.processInfo.arguments.contains("-gamenight") { gameNight = true } }   // screenshots
    #endif
  }

  /// Two players, one phone. Best on iPhone Duo, where each player gets their own half of the screen.
  private var gameNightCard: some View {
    Button { gameNight = true } label: {
      HStack(spacing: 14) {
        Glyph("🚀", size: 48)
        VStack(alignment: .leading, spacing: 2) {
          Text("GAME NIGHT · 2 PLAYERS").font(.kEyebrow).opacity(0.8)
          Text("Play head to head").font(.kTitle)
          Text("Open the phone wide: one half each!").font(.caption).opacity(0.85)
        }
        Spacer(minLength: 0)
        Image(systemName: "arrow.right").font(.title3.weight(.bold))
      }
      .foregroundStyle(.white).padding(18)
      .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
      .background(Palette.midnight, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Game Night: play head to head with two players")
  }

  /// How it works in three pictures (not a paragraph). The words live behind one button.
  private var intro: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 10) {
        step("🔮", "Grown-ups guess the profit")
        step("🎯", "You pick beat or miss")
        step("📝", "Come back for the result")
      }
      HStack(spacing: 10) {
        ReadAloud(source: .appCopy("Before a company shares its report card, grown-ups guess its profit. Will the company beat that guess, or miss? Make your guess, then come back to see."))
        Button { withAnimation(Motion.card) { showWords.toggle() } } label: {
          Label(showWords ? "Hide words" : "Words", systemImage: "character.book.closed.fill").font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14).frame(minHeight: 44).background(.thinMaterial, in: Capsule())
        }
        .buttonStyle(PressStyle())
        Spacer(minLength: 0)
      }
      if showWords { WordChips(keys: ["company", "report", "profit", "beat", "miss"]).transition(.opacity.combined(with: .move(edge: .top))) }
    }
  }
  private func step(_ art: String, _ text: String) -> some View {
    VStack(spacing: 8) {
      Glyph(art, size: 46)
      Text(text).font(.footnote.weight(.semibold)).multilineTextAlignment(.center).foregroundStyle(Palette.ink).fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 12).padding(.horizontal, 6)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    .accessibilityElement(children: .combine)
  }

  private func upcomingCard(_ e: EarningsEvent) -> some View {
    let co = app.companies[e.s]!
    return Card {
      HStack(spacing: 14) {
        Glyph(co.emoji, size: 52)
        VStack(alignment: .leading, spacing: 2) { Text(co.nick).font(.kTitle); Text("\(co.hook) · report card \(kidWhen(e.d, e.h, today: app.today))").font(.caption).foregroundStyle(.secondary) }
      }
      Text(expectLine(e.eE)).font(.callout)
      HStack(spacing: 8) {
        Text("Bonus: price up or down?").font(.caption).foregroundStyle(.secondary)
        Spacer()
        ForEach([Direction.up, .down], id: \.self) { d in
          Button(d == .up ? "Up ⬆️" : "Down ⬇️") { bonus[e.id] = bonus[e.id] == d ? nil : d }
            .buttonStyle(SoftButtonStyle(selected: bonus[e.id] == d))
            .accessibilityAddTraits(bonus[e.id] == d ? .isSelected : [])
        }
      }
      HStack(spacing: 12) {
        pick("Beat 👍", Palette.mint, .beat, e, co)
        pick("Miss 👎", Palette.peach, .miss, e, co)
      }
    }
  }
  private func pick(_ label: String, _ bg: Color, _ p: Pick, _ e: EarningsEvent, _ co: KidCo) -> some View {
    Button {
      app.mutate { $0.guess(Guess(s: e.s, d: e.d, pick: p, price: bonus[e.id], at: app.today)) }
    } label: {
      Text(label).font(.kTitle).foregroundStyle(Palette.midnight).frame(maxWidth: .infinity, minHeight: 64)
        .background(bg, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
    .buttonStyle(.plain)
    .sensoryFeedback(.impact(weight: .medium), trigger: app.state.guesses.count)
    .accessibilityLabel("Guess \(co.nick) will \(p.rawValue)")
  }
}

struct RevealRow: View {
  let guess: Guess
  @Environment(AppModel.self) private var app
  @State private var move: Double?
  @State private var burst = 0
  var body: some View {
    let co = app.companies[guess.s]
    let e = app.events.first { $0.s == guess.s && $0.d == guess.d }
    let res = resolveGuess(guess.pick, e?.report)
    Card(padding: 16) {
      HStack(alignment: .top, spacing: 12) {
        Glyph(co?.emoji ?? "🏪", size: 44)
        VStack(alignment: .leading, spacing: 6) {
          Text(co?.nick ?? guess.s).font(.kHeadline)
          Text("You guessed **\(guess.pick == .beat ? "BEAT 👍" : "MISS 👎")**\(guess.price.map { " and price \($0 == .up ? "UP ⬆️" : "DOWN ⬇️")" } ?? "").").font(.subheadline)
          if let result = guess.result, let e {
            Text(result == .right ? "🎉 You got it right! +10" : "🌧️ Markets surprise everyone!").font(.kHeadline).foregroundStyle(result == .right ? Palette.good : Palette.ink)
            Text(whyLine(co?.nick ?? guess.s, e.report)).font(.subheadline)
            if guess.price != nil {
              if let pr = guess.priceResult { Text("The price went \((move ?? 0) >= 0 ? "up" : "down"): \(pr == .right ? "you were right! +5" : "not this time.")").font(.subheadline) }
              else { Text("We'll know the price part soon.").font(.caption).foregroundStyle(.secondary) }
            }
            if result == .wrong { Text("Even grown-up experts guess wrong a lot. That's why spreading out is smart.").font(.caption).foregroundStyle(.secondary) }
          } else {
            switch res {
            case .pending: Text("⏳ Waiting for the report card \(e.map { kidWhen($0.d, $0.h, today: app.today) } ?? "").").font(.subheadline).foregroundStyle(.secondary)
            case .unknown: Text("This report card didn't have a grown-up guess, so nobody wins this one.").font(.subheadline).foregroundStyle(.secondary)
            case .right, .wrong:
              Button("The report card is out! Reveal 🎁") { reveal(res) }.buttonStyle(PrimaryButtonStyle())
            }
          }
        }
      }
    }
    .overlay(Celebrate(trigger: burst))
    .sensoryFeedback(trigger: guess.result) { _, r in r == .right ? .success : r == .wrong ? .warning : nil }
    .task(id: guess.result) {
      guard guess.price != nil, guess.result != nil, guess.priceResult == nil else { return }
      let m = (try? await app.market.lastMove(guess.s))?.history.first { $0.date == guess.d }?.move
      move = m
      let pr = resolvePrice(guess.price, m)
      if pr == .right || pr == .wrong { app.mutate { $0.resolve(s: guess.s, d: guess.d, result: nil, priceResult: pr == .right ? .right : .wrong) } }
    }
  }
  private func reveal(_ res: Resolution) {
    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { app.mutate { $0.resolve(s: guess.s, d: guess.d, result: res == .right ? .right : .wrong, priceResult: nil) } }
    if res == .right { burst += 1 }
  }
}

/// Family League scoreboard: this device + players imported from codes (emoji only, no names).
struct LeagueBoard: View {
  @Environment(AppModel.self) private var app
  var body: some View {
    if !app.state.leaguePlayers.isEmpty {
      let me = LeaguePlayer(emoji: app.state.me ?? 0, guesses: app.state.guesses.map { LeagueGuess(s: $0.s, d: $0.d, pick: $0.pick, price: $0.price) })
      let players = [me] + app.state.leaguePlayers
      let rows = League.rows(players, limit: 8)
      let byKey = Dictionary(app.events.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
      let res: (LeagueGuess) -> Resolution = { g in
        let r = resolveGuess(g.pick, byKey["\(g.s):\(g.d)"]?.report)
        if r == .pending, let own = app.state.guesses.first(where: { $0.s == g.s && $0.d == g.d && $0.pick == g.pick })?.result { return own == .right ? .right : .wrong }
        return r
      }
      let score = players.map { p in p.guesses.filter { res($0) == .right }.count }
      Card {
        Text("Family league 🏆").font(.kTitle)
        Grid(alignment: .center, horizontalSpacing: 10, verticalSpacing: 10) {
          GridRow {
            Text("Report card").font(.caption.weight(.semibold)).foregroundStyle(.secondary).gridColumnAlignment(.leading)
            ForEach(players.indices, id: \.self) { i in
              VStack(spacing: 0) { Glyph(app.content.players[players[i].emoji], size: 32); if i == 0 { Text("YOU").font(.kEyebrow).foregroundStyle(.secondary) } }
                .accessibilityLabel(i == 0 ? "You" : app.content.playerNames[players[i].emoji])
            }
          }
          ForEach(rows) { r in
            GridRow {
              HStack(spacing: 6) { Glyph(app.companies[r.s]?.emoji ?? "", size: 28); VStack(alignment: .leading, spacing: 0) { Text(app.companies[r.s]?.nick ?? r.s).font(.subheadline.weight(.semibold)); Text(Day.en("MMM d", r.d)).font(.caption2.monospaced()).foregroundStyle(.secondary) } }
              ForEach(r.picks.indices, id: \.self) { i in
                if let g = r.picks[i] {
                  let x = res(g)
                  Text((g.pick == .beat ? "👍" : "👎") + (x == .right ? "✅" : x == .wrong ? "❌" : "⏳")).accessibilityLabel("\(g.pick.rawValue), \(x == .right || x == .wrong ? x.rawValue : "waiting")")
                } else { Text("·").foregroundStyle(.tertiary).accessibilityLabel("No guess") }
              }
            }
          }
          Divider().gridCellUnsizedAxes(.horizontal)
          GridRow {
            Text("Right").font(.kHeadline)
            ForEach(score.indices, id: \.self) { i in Text("\(score[i])\(score[i] == score.max() && score[i] > 0 ? " 🌕" : "")").font(.kHeadline).foregroundStyle(score[i] == score.max() && score[i] > 0 ? Palette.good : Palette.ink) }
          }
        }
        Text("👍 beat · 👎 miss · ✅ right · ❌ not this time · ⏳ waiting. Everyone is learning!").font(.caption).foregroundStyle(.secondary)
      }
    }
  }
}

/// Weekly recap: "Look what you did!" — built from this device's progress only.
struct RecapCard: View {
  let recap: Recap
  @Environment(AppModel.self) private var app
  var body: some View {
    let lines = recapLines(recap, levels: app.content.levels)
    Eyebrow(text: "\(recap.label) in the Moon Club")
    HStack(spacing: 14) { MoonPhase(phase: recap.level, size: 64); Text("Look what you did!").font(.kHero) }
    HStack(spacing: 8) {
      stat("\(recap.guesses)", recap.guesses == 1 ? "guess" : "guesses", Palette.lavender)
      stat("\(recap.right)", "right", Palette.mint)
      stat("\(recap.lessons)", recap.lessons == 1 ? "lesson" : "lessons", Palette.sky)
      if let p = recap.piggyPct { stat((p > 0 ? "+" : "") + toFixed(p, 1) + "%", "piggy bank", Palette.peach) }
    }
    VStack(alignment: .leading, spacing: 6) { ForEach(lines, id: \.self) { Text("• " + $0).font(.body) } }
    ReadAloud(source: .appCopy(lines.joined(separator: " ")))
  }
  func stat(_ v: String, _ l: String, _ bg: Color) -> some View {
    VStack(spacing: 2) { Text(v).font(.system(.title, design: .rounded).weight(.heavy)).minimumScaleFactor(0.6).lineLimit(1); Text(l).font(.caption) }
      .foregroundStyle(Palette.midnight)
      .frame(maxWidth: .infinity, minHeight: 72).background(bg, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
  }
}
