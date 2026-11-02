import SwiftUI
import MoonClubCore

/// 🌙 Game Night: two players, one phone. Each player gets their own half: left and right when an iPhone
/// Duo is open like a book, top and bottom when it's set down like a laptop or held closed. Rounds are
/// report cards that already came out, so the reveal is instant. Picks stay hidden until both are in.
/// Nothing is saved: it's a party game, not progress (no KidsState, no league codes).
struct GameNightView: View {
  @Environment(AppModel.self) private var app
  @Environment(DuoModel.self) private var duo: DuoModel?
  @Environment(\.dismiss) private var dismiss
  @Environment(\.accessibilityReduceMotion) private var rm
  @State private var game: GameNight?
  @State private var players = [0, 1]
  @State private var burst = 0
  @State private var onTV = false

  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        if let hint { Text(hint).font(.footnote.weight(.semibold)).foregroundStyle(Palette.ink2).padding(.top, 6).transition(.opacity) }
        Group {
          if let game, !game.isOver { board(game) }
          else if let game, !game.rounds.isEmpty { finale(game) }
          else { empty }
        }
      }
      .background(AuroraField(surface: .guess))
      .overlay(Celebrate(trigger: burst))
      .navigationTitle("Game Night")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button { dismiss() } label: { Label("Close", systemImage: "xmark") }
        }
      }
      .modifier(TaskToolbar())
    }
    .onAppear(perform: setup)
    .onChange(of: app.events) { _, _ in if game?.rounds.isEmpty ?? true { game = nil; setup() } }   // data arrived
    .task { if app.events.isEmpty { await app.loadMarket() } }
    .modifier(GameNightOnTV(game: game, players: players, app: app, onTV: $onTV))
  }

  /// One line that says what this pose is good for.
  private var hint: String? {
    if onTV { return "📺 The scoreboard is on the TV too!" }
    switch duo?.pose {
    case .closed?: return "Tip: open the phone like a book — one half each!"
    case .tabletop?: return "Tabletop mode: one half each!"
    case .book?, .flat?: return "Book mode: left player, right player."
    default: return nil
    }
  }

  private func setup() {
    guard game == nil else { return }
    game = GameNight(events: app.kidEvents.map { (s: $0.s, d: $0.d, report: $0.report) }, today: app.today)
    if let me = app.state.me { players = [me, app.state.league.first?.emoji ?? (me == 0 ? 1 : 0)] }
  }

  // MARK: Board — one pad per player, split across the fold by the system's arrangement view.
  @ViewBuilder private func board(_ g: GameNight) -> some View {
    if #available(iOS 27.1, *) {
      ArrangementView { pad(0, g) } secondary: { pad(1, g) }
        .arrangementViewStyle(.split)
        .padding(12)
    } else {
      ViewThatFits(in: .horizontal) {
        HStack(spacing: 12) { pad(0, g).frame(minWidth: 300); pad(1, g).frame(minWidth: 300) }
        VStack(spacing: 12) { pad(0, g); pad(1, g) }
      }
      .padding(12)
    }
  }

  private func pad(_ p: Int, _ g: GameNight) -> some View {
    let round = g.round!
    let co = app.companies[round.s]
    let mine = g.picks[p]
    return VStack(spacing: 14) {
      HStack {
        Button { cycle(p) } label: {
          Text(app.content.players[players[p]]).font(.system(size: 40))
            .frame(minWidth: 56, minHeight: 56)
            .background(Palette.lavender.opacity(0.8), in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(g.picks.contains { $0 != nil })
        .accessibilityLabel("Player \(p + 1): \(app.content.playerNames[players[p]]). Tap to change.")
        VStack(alignment: .leading, spacing: 0) {
          Text(app.content.playerNames[players[p]]).font(.kHeadline)
          Text("Round \(g.index + 1) of \(g.rounds.count)").font(.caption).foregroundStyle(.secondary)
        }
        Spacer()
        Ticker(value: Double(g.scores[p]), font: .system(size: 40, weight: .heavy, design: .rounded))
          .accessibilityLabel("\(g.scores[p]) points")
      }
      HStack(spacing: 10) {
        Text(co?.emoji ?? "").font(.system(size: 34)).accessibilityHidden(true)
        VStack(alignment: .leading, spacing: 2) {
          Text(co?.nick ?? round.s).font(.kTitle)
          Text(expectLine(round.report.eE)).font(.caption).foregroundStyle(.secondary).lineLimit(2)
        }
        Spacer(minLength: 0)
      }
      if g.revealed, let a = g.answer {
        let right = mine == a
        VStack(spacing: 6) {
          Text(right ? "🎉 You got it!" : "Good try!").font(.kTitle)
          Text("It was a **\(a == .beat ? "BEAT" : "MISS")**. You said \(mine == .beat ? "beat" : "miss").").font(.callout).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(14)
        .background(right ? Palette.mint : Palette.peach, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .transition(.scale.combined(with: .opacity))
      } else if mine != nil {
        Label("Locked in! Waiting for \(app.content.playerNames[players[1 - p]])…", systemImage: "lock.fill")
          .font(.kHeadline).frame(maxWidth: .infinity, minHeight: 64)
          .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
          .transition(.opacity)
      } else {
        HStack(spacing: 10) {
          ForEach(Pick.allCases, id: \.self) { k in
            Button(k == .beat ? "Beat ⬆️" : "Miss ⬇️") { lock(p, k) }
              .buttonStyle(PrimaryButtonStyle(tint: k == .beat ? Palette.good : Palette.bad))
              .frame(minHeight: 64)
          }
        }
      }
      Spacer(minLength: 0)
      if g.revealed {
        Text(whyLine(co?.nick ?? round.s, round.report)).font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        Button(g.index + 1 < g.rounds.count ? "Next round →" : "See who won 🏆") { advance() }.buttonStyle(SoftButtonStyle())
      }
    }
    .padding(18)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    .animation(rm ? nil : .spring(response: 0.4, dampingFraction: 0.8), value: g)
  }

  private var empty: some View {
    VStack(spacing: 16) {
      Luna(size: 90, wave: true)
      Text("No report cards to play yet").font(.kTitle)
      Text("Game Night uses report cards that already came out. Check back after the next one!").font(.kRead).multilineTextAlignment(.center)
    }.padding(32).frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private func finale(_ g: GameNight) -> some View {
    VStack(spacing: 18) {
      if let w = g.winner {
        Text(app.content.players[players[w]]).font(.system(size: 90))
        Text("\(app.content.playerNames[players[w]]) wins!").font(.kHero)
      } else {
        Text("🤝").font(.system(size: 90))
        Text("It's a tie!").font(.kHero)
      }
      Text("\(g.scores[0]) to \(g.scores[1]). Even experts miss a lot, so everyone did great.").font(.kRead).multilineTextAlignment(.center)
      Button("Play again") { game = nil; setup() }.buttonStyle(PrimaryButtonStyle()).frame(maxWidth: 320)
    }
    .padding(32).frame(maxWidth: .infinity, maxHeight: .infinity)
    .onAppear { burst += 1 }
  }

  private func cycle(_ p: Int) {
    var n = (players[p] + 1) % app.content.players.count
    if n == players[1 - p] { n = (n + 1) % app.content.players.count }
    players[p] = n
  }
  private func lock(_ p: Int, _ k: Pick) {
    game?.pick(p, k)
    if game?.revealed == true { burst += 1 }
  }
  private func advance() { withAnimation { game?.next() } }
}

/// 📺 Game Night on the big screen: when a TV or display is connected (AirPlay or cable), the system may
/// show this scoreboard there. Non-interactive by design — the players keep their own halves of the
/// phone, the whole family watches the TV. The system decides when it's available.
struct GameNightOnTV: ViewModifier {
  let game: GameNight?
  let players: [Int]
  let app: AppModel
  @Binding var onTV: Bool
  func body(content: Content) -> some View {
    if #available(iOS 27.0, *) {
      content.sceneAccessory {
        ExternalNonInteractiveAccessory { TVBoard(game: game, players: players).environment(app) }
          .onAvailabilityChange { onTV = $0 }
      }
    } else {
      content
    }
  }
}

struct TVBoard: View {
  let game: GameNight?
  let players: [Int]
  @Environment(AppModel.self) private var app
  var body: some View {
    ZStack {
      LinearGradient(colors: [Palette.midnight, Color(hex: 0x2A2467)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
      if let g = game, let r = g.round {
        let co = app.companies[r.s]
        HStack(spacing: 0) {
          player(0, g)
          VStack(spacing: 10) {
            Text("ROUND \(g.index + 1) OF \(g.rounds.count)").font(.kEyebrow).foregroundStyle(.white.opacity(0.7))
            Text(co?.emoji ?? "").font(.system(size: 120))
            Text(co?.nick ?? r.s).font(.system(size: 44, weight: .heavy, design: .rounded)).foregroundStyle(.white)
            if g.revealed, let a = g.answer {
              Text(a == .beat ? "BEAT! ⬆️" : "MISS! ⬇️").font(.system(size: 56, weight: .black, design: .rounded))
                .foregroundStyle(a == .beat ? Palette.mint : Palette.peach)
            } else {
              Text(g.picks.compactMap { $0 }.count == 1 ? "One player is locked in…" : "Beat or miss?").font(.title).foregroundStyle(.white.opacity(0.85))
            }
          }
          .frame(maxWidth: .infinity)
          player(1, g)
        }
        .padding(40)
      } else {
        VStack(spacing: 16) {
          Luna(size: 140, wave: true)
          Text("Moon Club Game Night").font(.system(size: 48, weight: .heavy, design: .rounded)).foregroundStyle(.white)
          if let g = game, g.isOver, !g.rounds.isEmpty {
            Text(g.winner.map { "\(app.content.playerNames[players[$0]]) wins! 🏆" } ?? "It's a tie! 🤝").font(.largeTitle).foregroundStyle(Palette.moon)
          }
        }
      }
    }
  }
  private func player(_ p: Int, _ g: GameNight) -> some View {
    VStack(spacing: 8) {
      Text(app.content.players[players[p]]).font(.system(size: 90))
      Text(app.content.playerNames[players[p]]).font(.title.weight(.bold)).foregroundStyle(.white)
      Text("\(g.scores[p])").font(.system(size: 72, weight: .black, design: .rounded)).foregroundStyle(Palette.moon).monospacedDigit()
      Text(g.revealed ? (g.picks[p] == g.answer ? "✅" : "↩︎") : g.picks[p] == nil ? "thinking…" : "🔒").font(.title2).foregroundStyle(.white.opacity(0.85))
    }
    .frame(width: 240)
  }
}

/// Task-oriented screens keep their toolbar actions and let the tab bar minimize when the bars go
/// vertical on iPhone Duo (Apple's "task-oriented" compression behavior).
struct TaskToolbar: ViewModifier {
  func body(content: Content) -> some View {
    if #available(iOS 27.1, *) { content.toolbarVerticalCompressionBehavior(.prefersToolbarItems) } else { content }
  }
}
