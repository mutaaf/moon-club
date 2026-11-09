import Charts
import SwiftUI
import MoonClubCore

/// Pretend Piggy Bank: 🌙 $1,000 pretend coins across up to 5 companies, following real prices.
struct PiggyView: View {
  @Environment(AppModel.self) private var app
  @AppStorage(PiggySide.key) private var side: PiggySide = {
    #if DEBUG
    if ProcessInfo.processInfo.arguments.contains("-coins") { return .coins }
    #endif
    return .garden
  }()
  /// One piggy's prices and peeks, shared by both pages of the book spread (so they load once).
  @State private var quotes = PiggyQuotes()

  var body: some View {
    let _ = Perf.body("PiggyView")
    // iPhone Duo opened like a book: the jar (what you have, its line, what's growing) on the left page,
    // the controls and tips on the right. Phone, iPad and closed keep one column.
    FoldPages {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        header
        switch side {
        case .garden: MoonGarden()
        case .coins: if app.state.piggy == nil { PiggySetup() } else { PiggyBank(quotes: quotes) }
        }
      }
      .padding(20).readable()
    }
    } first: {
      BookPage(spacing: 20) {
        header
        switch side {
        case .garden: MoonGarden(part: .first)
        case .coins: if app.state.piggy != nil { PiggyBank(part: .first, quotes: quotes) }
        }
      }
    } second: {
      BookPage(spacing: 20) {
        switch side {
        case .garden: MoonGarden(part: .second)
        case .coins: if app.state.piggy == nil { PiggySetup() } else { PiggyBank(part: .second, quotes: quotes) }
        }
      }
    }
    .background(AuroraField(surface: .piggy))
  }

  @ViewBuilder private var header: some View {
    Hero(eyebrow: side == .garden ? "Grow your Moon points" : "Practice with pretend coins", title: side == .garden ? "Moon" : "Pretend", accent: side == .garden ? "Garden" : "Piggy Bank", emoji: side == .garden ? "🌱" : nil, piggy: side == .coins)
    // Two things live here, kept apart so the currencies never mix: Moon points grow in the garden,
    // pretend coins stay in the practice piggy.
    Picker("Show", selection: $side) {
      ForEach(PiggySide.allCases) { s in Label(s.title, systemImage: s.icon).tag(s) }
    }
    .pickerStyle(.segmented)
  }
}

/// Which part of a screen to draw: all of it (one column, or its own two-page spread), or one page of
/// the iPhone Duo book spread.
enum PagePart { case all, first, second }

/// The pretend piggy's prices, kept above the bank so both pages of a book spread share one load.
@MainActor @Observable
final class PiggyQuotes {
  var prices: [String: Double] = [:]
  var loaded = false
  var confirm = false
  /// Times the bank was opened today (device-only count) for Luna's "don't peek every minute" tip.
  var peeks = 0
}

struct PiggySetup: View {
  @Environment(AppModel.self) private var app
  @State private var picks: [String] = []
  @State private var split: [String: Int] = [:]
  @State private var busy = false
  @State private var err: String?
  var left: Int { Int(app.content.startCoins) - split.values.reduce(0, +) }
  let cols = [GridItem(.adaptive(minimum: 104), spacing: 10)]

  var body: some View {
    Text("You have **$1,000 pretend coins**. Pick up to 5 companies you know. Your coins buy pretend **shares** that follow their **real prices**, but it's all pretend. Nothing is bought for real.").font(.kRead)
    HStack { ReadAloud(source: .appCopy("You have one thousand pretend coins. Pick up to five companies you know. Your coins will follow their real prices, but it's all pretend. Nothing is bought for real.")); Spacer() }
    LazyVGrid(columns: cols, spacing: 10) {
      ForEach(app.content.companies, id: \.s) { c in
        let on = picks.contains(c.s)
        Button { toggle(c.s) } label: {
          VStack(spacing: 6) { Glyph(c.emoji, size: 44); Text(c.nick).font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8) }
            .frame(maxWidth: .infinity, minHeight: 92)
            .background(on ? Palette.lavender : Color.clear, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .moonGlass(radius: 20, weight: .thin)
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(on ? Palette.accent : Palette.line, lineWidth: on ? 2 : 1))
            .scaleEffect(on ? 1.03 : 1)
        }
        .buttonStyle(.plain)
        .disabled(!on && picks.count >= app.content.maxPicks)
        .opacity(!on && picks.count >= app.content.maxPicks ? 0.4 : 1)
        .accessibilityAddTraits(on ? .isSelected : [])
        .sensoryFeedback(.selection, trigger: on)
      }
    }
    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: picks)
    if !picks.isEmpty {
      Card {
        HStack { Text("Split your coins").font(.kTitle); Spacer(); PretendPill() }
        ForEach(picks, id: \.self) { s in
          HStack {
            Glyph(app.company(s).emoji, size: 30); Text(app.company(s).nick).font(.kHeadline).lineLimit(1).minimumScaleFactor(0.7)
            Spacer()
            Button { bump(s, -100) } label: { Image(systemName: "minus.circle.fill").font(.title) }.accessibilityLabel("100 fewer coins for \(app.company(s).nick)")
            Ticker(value: Double(split[s] ?? 0), format: { coins($0) }, font: .kHeadline).frame(minWidth: 70)
            Button { bump(s, 100) } label: { Image(systemName: "plus.circle.fill").font(.title) }.disabled(left < 100).accessibilityLabel("100 more coins for \(app.company(s).nick)")
          }
        }
        HStack { Text(left > 0 ? "\(coins(Double(left))) left to place." : "All your coins are placed!").font(.subheadline); Spacer(); Button("Split evenly") { split = evenSplit(picks) }.font(.subheadline) }
        Text("\(Image(systemName: "basket.fill")) \(basketTip(picks.count))").font(.callout).padding(12).frame(maxWidth: .infinity, alignment: .leading).background(Palette.moon.opacity(0.6), in: RoundedRectangle(cornerRadius: 14))
        Button(busy ? "Filling your piggy bank…" : "Start my pretend piggy bank 🐷") { Task { await start() } }
          .buttonStyle(PrimaryButtonStyle()).disabled(left != 0 || busy)
        if let err { Text(err).font(.callout).foregroundStyle(Palette.bad) }
      }
      .transition(.move(edge: .bottom).combined(with: .opacity))
    }
  }
  func toggle(_ s: String) {
    picks = picks.contains(s) ? picks.filter { $0 != s } : picks.count < app.content.maxPicks ? picks + [s] : picks
    split = evenSplit(picks)
  }
  func bump(_ s: String, _ d: Int) { let v = (split[s] ?? 0) + d; if v < 0 || (d > 0 && left < d) { return }; split[s] = v }
  func start() async {
    busy = true; err = nil; defer { busy = false }
    do {
      let prices = try await app.market.quotes(picks)
      let h = buyPretend(picks.map { ($0, Double(split[$0] ?? 0)) }, prices: prices)
      guard !h.isEmpty else { throw KidError.offline }
      withAnimation(.spring) { app.mutate { $0.startPiggy(h, today: app.today, value: piggyValue(h, prices: prices)) } }
    } catch { err = "Hmm, we couldn't get prices right now. Try again in a minute!" }
  }
}

struct PiggyBank: View {
  var part: PagePart = .all
  var quotes: PiggyQuotes? = nil
  @Environment(AppModel.self) private var app
  @State private var own = PiggyQuotes()
  private var q: PiggyQuotes { quotes ?? own }
  private var prices: [String: Double] { q.prices }
  private var loaded: Bool { q.loaded }
  private var peeks: Int { q.peeks }
  var body: some View {
    let _ = Perf.body("PiggyBank")
    // The piggy can disappear while this view is still on screen (start over, reset, an iCloud merge):
    // never force-unwrap it. That was the 0.8.0 TestFlight crash (EXC_BREAKPOINT in PiggyBank.body).
    if let p = app.state.piggy { bank(p) } else { PiggySetup() }
  }

  @ViewBuilder private func bank(_ p: Piggy) -> some View {
    let value = loaded ? piggyValue(p.holdings, prices: prices) : piggyValue(p.holdings, prices: [:])
    let change = value - app.content.startCoins
    let hist = p.history.sorted { $0.key < $1.key }
    // Open wide (iPhone Duo, iPad): the money and its line on one page, what's inside on the other.
    switch part {
    case .all: TwoPage { money(p, value, change, hist) } second: { inside(p, value) }
    case .first: money(p, value, change, hist)
    case .second: inside(p, value)
    }
  }

  @ViewBuilder private func money(_ p: Piggy, _ value: Double, _ change: Double, _ hist: [(key: String, value: Double)]) -> some View {
    Card {
      HStack { Eyebrow(text: "Your pretend money today"); Spacer(); PretendPill() }
      Ticker(value: value, format: { coins($0) }, font: .system(size: 48, weight: .heavy, design: .rounded))
      if loaded && abs(change) >= 0.5 {
        Label("\(change >= 0 ? "Up" : "Down") \(coins(abs(change))) since you started", systemImage: change >= 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill").font(.kHeadline).foregroundStyle(change >= 0 ? Palette.goodInk : Palette.badInk)
      }
      if hist.count >= 2 {
        Chart(Array(hist.enumerated()), id: \.offset) { i, e in
          LineMark(x: .value("Day", i), y: .value("Coins", e.value)).interpolationMethod(.catmullRom).foregroundStyle(Palette.accent).lineStyle(.init(lineWidth: 3, lineCap: .round))
          PointMark(x: .value("Day", i), y: .value("Coins", e.value)).foregroundStyle(Palette.accent).symbolSize(i == hist.count - 1 ? 60 : 0)
        }
        .chartXAxis(.hidden).chartYAxis(.hidden).chartYScale(domain: .automatic(includesZero: false)).frame(height: 90)
        .accessibilityLabel("Your pretend money over \(hist.count) days")
      } else {
        Text("Come back tomorrow to watch your line grow.").font(.callout).foregroundStyle(.secondary)
      }
      ReadAloud(source: .appCopy("Your pretend money today is \(Int(value)) coins. You started with one thousand."))
    }
    if loaded, let m = biggestMover(p.holdings, prices: prices), abs(m.change) >= 0.05, let co = app.companies[m.s] {
      Text("**\(co.nick)** moved the most: \(m.change >= 0 ? "up" : "down") \(toFixed(abs(m.change), 1))% since you started. \(m.change >= 0 ? "Lots of people wanted its shares, so the price went up." : "More people were selling its shares, so the price went down. That's normal!")")
        .font(.callout).padding(14).background(Palette.moon.opacity(0.6), in: RoundedRectangle(cornerRadius: 16))
    }
  }

  @ViewBuilder private func inside(_ p: Piggy, _ value: Double) -> some View {
    VStack(spacing: 10) {
      ForEach(p.holdings, id: \.s) { h in
        let c = holdingChange(h, price: prices[h.s])
        HStack(spacing: 12) {
          Glyph(app.companies[h.s]?.emoji ?? "", size: 40)
          VStack(alignment: .leading) { Text(app.companies[h.s]?.nick ?? h.s).font(.kHeadline); Text("You put in \(coins(h.coins))").font(.caption).foregroundStyle(.secondary) }
          Spacer()
          if !loaded || abs(c) < 0.05 { Text("New!").font(.subheadline).foregroundStyle(.secondary) }
          else { Text("\(c >= 0 ? "+" : "")\(toFixed(c, 1))%").font(.kHeadline).monospacedDigit().foregroundStyle(c >= 0 ? Palette.good : Palette.bad) }
        }
        .padding(14).moonGlass(radius: 18, weight: .thin)
      }
    }
    Card {
      HStack(spacing: 6) { ForEach(p.holdings, id: \.s) { h in Glyph(app.companies[h.s]?.emoji ?? "", size: 36) } }
      PiggyCoachTip(piggy: p, value: loaded ? value : nil, peeks: peeks)
    }
    if loaded, let m = biggestMover(p.holdings, prices: prices), abs(m.change) >= 0.05 { Card { WhyCard(symbol: m.s, title: "Why did \(app.company(m.s).nick) move?") } }
    CourseCard(kind: .piggy)
    Button(q.confirm ? "Yes, empty it and start over" : "Start over with new pretend coins") {
      if q.confirm { withAnimation { app.mutate { $0.resetPiggy() } } } else { q.confirm = true }
    }.font(.footnote).frame(maxWidth: .infinity)
    .task {
      let q = self.q
      if q.peeks == 0 { q.peeks = app.peekPiggy() }
      if let quotes = try? await app.market.quotes(p.holdings.map(\.s)) {
        q.prices = quotes; withAnimation(.snappy) { q.loaded = true }
        app.mutate { $0.recordValue(today: app.today, value: piggyValue(p.holdings, prices: quotes)) }
      }
    }
  }
}
