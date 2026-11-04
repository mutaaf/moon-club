import SwiftUI
import MoonClubCore

/// Game Night 2.0: the Market Race, a two-player board game for a phone lying flat between two kids.
/// Each player answers on their own half (the far half turns to face its player), and both rockets race
/// along a shared track that sits on the fold line in the middle. Questions are real candles ("did this
/// day go up or down?", "which way are these days going?"); a right answer moves you one space, the first
/// right answer gets a boost of one more. Rules are pure in MoonClubCore `MarketRace` (tested). Nothing
/// is saved: it's a party game, not progress. Works on every device; on iPhone Duo it's the tabletop game.
struct MarketRaceView: View {
  @Binding var race: MarketRace?
  let players: [Int]
  @Environment(AppModel.self) private var app
  @Environment(DuoModel.self) private var duo: DuoModel?
  @Environment(\.accessibilityReduceMotion) private var rm
  @State private var burst = 0
  @State private var seed = Int.random(in: 1...999_999)

  var body: some View {
    Group {
      if let r = race, !r.asks.isEmpty {
        if r.isOver { finale(r) } else { board(r) }
      } else {
        VStack(spacing: 14) { Luna(size: 80, wave: true); Text("Getting the charts ready…").font(.kTitle) }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .overlay(Celebrate(trigger: burst, tier: race?.isOver == true ? .large : .small).ignoresSafeArea())
    .onAppear { if race == nil { start() } }
    .onChange(of: app.candles.count) { _, _ in if race?.asks.isEmpty ?? true { start() } }
  }

  private func start() {
    race = MarketRace(series: Array(app.candles.values), seed: seed)
  }

  // MARK: The board: two pads and the track on the fold line

  private func board(_ r: MarketRace) -> some View {
    GeometryReader { g in
      let stacked = g.size.height >= g.size.width
      let track = trackThickness(g)
      if stacked {
        VStack(spacing: 0) {
          pad(0, r).rotationEffect(.degrees(180))          // the far player reads their half right way up
            .frame(maxHeight: .infinity)
          RaceTrack(spots: r.spots, skins: skins, vertical: false).frame(height: track)
          pad(1, r).frame(maxHeight: .infinity)
        }
      } else {
        HStack(spacing: 0) {
          pad(0, r).frame(maxWidth: .infinity)
          RaceTrack(spots: r.spots, skins: skins, vertical: true).frame(width: track)
          pad(1, r).frame(maxWidth: .infinity)
        }
      }
    }
    .padding(8)
  }

  /// The track is at least as thick as the fold's division region (it sits on the fold line).
  private func trackThickness(_ g: GeometryProxy) -> CGFloat {
    if #available(iOS 27.1, *), let f = g.reservedRegions(kind: .division, options: [.includeInactive]).first {
      return max(84, min(f.frame.width, f.frame.height) + 44)
    }
    return 84
  }

  private var skins: [RocketSkin] { [Skins.current(app.state), Skins.all[min(3, Skins.all.count - 1)]] }

  private func pad(_ p: Int, _ r: MarketRace) -> some View {
    VStack(spacing: 10) {
      HStack(spacing: 10) {
        Glyph(app.content.players[safe: players[p]] ?? "⭐", size: 30)
          .frame(width: 46, height: 46).background(Palette.lavender.opacity(0.8), in: Circle())
          .accessibilityHidden(true)
        VStack(alignment: .leading, spacing: 0) {
          Text(app.content.playerNames[safe: players[p]] ?? "Player \(p + 1)").font(.kHeadline).lineLimit(1)
          Text("Space \(r.spots[p]) of \(MarketRace.finish)").font(.caption).foregroundStyle(Palette.ink2)
        }
        Spacer(minLength: 0)
        RocketMark(skin: skins[p], size: 34)
      }
      if let a = r.ask {
        let co = app.company(a.symbol)
        HStack(spacing: 6) {
          Glyph(co.emoji, size: 24)
          Text(a.question).font(.kHeadline).lineLimit(2).minimumScaleFactor(0.8)
          Spacer(minLength: 0)
        }
        askChart(a).frame(maxWidth: .infinity, maxHeight: .infinity).frame(minHeight: 60)
        if r.revealed {
          let got = r.gained[p]
          Label(got == 2 ? "Right and first! Boost: 2 spaces" : got == 1 ? "Right! 1 space" : "Not this time. It went \(a.answerUp ? "up" : "down").",
                systemImage: got > 0 ? "checkmark.circle.fill" : "arrow.uturn.left.circle.fill")
            .font(.callout.weight(.bold)).foregroundStyle(got > 0 ? Palette.goodInk : Palette.ink)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(got > 0 ? Palette.mint : Palette.peach, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
          Button("Next question") { withAnimation(Motion.safe(Motion.card, rm)) { race?.next() } }.buttonStyle(ChunkyPrimary())
        } else if r.picks[p] != nil {
          Label("Locked in! Waiting…", systemImage: "lock.fill").font(.kHeadline)
            .frame(maxWidth: .infinity, minHeight: 56).moonGlass(radius: 18, weight: .thin)
        } else {
          HStack(spacing: 10) {
            AnswerButton(text: "Up", icon: "arrow.up.right", index: 0, compact: true) { pick(p, up: true) }
            AnswerButton(text: "Down", icon: "arrow.down.right", index: 1, compact: true) { pick(p, up: false) }
          }
        }
      }
    }
    .padding(14)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .moonGlass(radius: 26)
    .animation(Motion.safe(Motion.card, rm), value: r)
  }

  @ViewBuilder private func askChart(_ a: MarketRace.Ask) -> some View {
    switch a {
    case let .day(c, _):
      BigCandle(o: c.o, h: c.h, l: c.l, c: c.c, domain: (c.l - (c.h - c.l) * 0.1)...(c.h + (c.h - c.l) * 0.1), labels: false)
    case let .trend(cs, _):
      CandleChart(candles: cs.map { Candle(d: "", o: $0, h: $0, l: $0, c: $0) }, line: true)
    }
  }

  private func pick(_ p: Int, up: Bool) {
    race?.pick(p, up: up)
    if race?.revealed == true, (race?.gained.max() ?? 0) > 0 { burst += 1 }
    if race?.isOver == true { finish() }
  }

  private func finish() {
    burst += 1; Chime.rising()
    if duo?.hasHinge == true { app.mutate { $0.useDuo(.race) } }
  }

  private func finale(_ r: MarketRace) -> some View {
    VStack(spacing: 16) {
      RaceTrack(spots: r.spots, skins: skins, vertical: false).frame(height: 84)
      if let w = r.winner {
        Glyph(app.content.players[safe: players[w]] ?? "⭐", size: 80, style: .halo)
        Text("\(app.content.playerNames[safe: players[w]] ?? "Player \(w + 1)") wins the race!").font(.kHero).lineLimit(2).minimumScaleFactor(0.6).multilineTextAlignment(.center)
      } else {
        Text("A photo finish! It's a tie!").font(.kHero).lineLimit(2).minimumScaleFactor(0.6).multilineTextAlignment(.center)
      }
      Text("Reading candles is a skill. Every race makes you faster!").font(.kRead).multilineTextAlignment(.center)
      Button("Race again") { seed &+= 1; start() }.buttonStyle(PrimaryButtonStyle()).frame(maxWidth: 320)
    }
    .padding(28).frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

/// The shared track: nine spaces from the start to the finish flag, one rocket per player.
struct RaceTrack: View {
  let spots: [Int]
  let skins: [RocketSkin]
  var vertical = false
  @Environment(\.accessibilityReduceMotion) private var rm

  /// Where space `i` sits for a lane (0 above/left of the line, 1 below/right), in a track of `size`.
  struct Geo {
    let size: CGSize, vertical: Bool
    var len: CGFloat { vertical ? size.height : size.width }
    var cross: CGFloat { vertical ? size.width : size.height }
    func at(_ i: Int, lane: Int) -> CGPoint {
      let step = (len - 48) / CGFloat(MarketRace.finish)
      let a = 24 + step * CGFloat(i)
      let b = cross / 2 + (lane == 0 ? -cross * 0.22 : cross * 0.22)
      return vertical ? CGPoint(x: b, y: len - a) : CGPoint(x: a, y: b)
    }
    func mid(_ i: Int) -> CGPoint {
      let p = at(i, lane: 0), q = at(i, lane: 1)
      return CGPoint(x: (p.x + q.x) / 2, y: (p.y + q.y) / 2)
    }
  }

  var body: some View {
    GeometryReader { g in
      track(Geo(size: g.size, vertical: vertical))
    }
    .accessibilityElement()
    .accessibilityLabel("Race track. Player 1 on space \(spots[0]), player 2 on space \(spots[1]), of \(MarketRace.finish).")
  }

  private func track(_ geo: Geo) -> some View {
    let n = MarketRace.finish
    return ZStack {
      RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Palette.midnight.opacity(0.85))
      Canvas { ctx, _ in
        for i in 0...n {
          let c = geo.mid(i)
          let r: CGFloat = i == n ? 12 : 6
          ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)), with: .color(i == n ? Hue.gold.color : .white.opacity(0.35)))
        }
      }
      Image(systemName: "flag.checkered").font(.title3.weight(.heavy)).foregroundStyle(.white)
        .shimmer()
        .position(geo.mid(n))
      rocket(0, geo)
      rocket(1, geo)
    }
  }

  private func rocket(_ lane: Int, _ geo: Geo) -> some View {
    RocketMark(skin: skins[lane], size: min(30, geo.cross * 0.36))
      .rotationEffect(.degrees(vertical ? 0 : 90))
      .position(geo.at(spots[lane], lane: lane))
      .animation(Motion.safe(.spring(response: 0.6, dampingFraction: 0.7), rm), value: spots[lane])
  }
}

/// The race on a TV (non-interactive): the track, big, for the family to watch.
struct RaceTVBoard: View {
  let race: MarketRace?
  let players: [Int]
  @Environment(AppModel.self) private var app
  var body: some View {
    ZStack {
      LinearGradient(colors: [Palette.midnight, Color(hex: 0x2A2467)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
      VStack(spacing: 24) {
        Text("MARKET RACE").font(.system(size: 48, weight: .black, design: .rounded)).foregroundStyle(.white)
        if let r = race {
          RaceTrack(spots: r.spots, skins: [Skins.current(app.state), Skins.all[min(3, Skins.all.count - 1)]]).frame(height: 160)
          HStack {
            ForEach(0..<2, id: \.self) { p in
              VStack {
                Glyph(app.content.players[safe: players[p]] ?? "⭐", size: 70, style: .halo)
                Text(app.content.playerNames[safe: players[p]] ?? "").font(.title.weight(.bold)).foregroundStyle(.white)
                Text("\(r.spots[p])").font(.system(size: 64, weight: .black, design: .rounded)).foregroundStyle(Palette.moon)
              }
              .frame(maxWidth: .infinity)
            }
          }
          if let a = r.ask { Text(a.question).font(.largeTitle.weight(.bold)).foregroundStyle(.white.opacity(0.9)) }
        }
      }
      .padding(48)
    }
  }
}
