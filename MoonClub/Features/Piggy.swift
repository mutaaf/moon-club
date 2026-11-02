import Charts
import SwiftUI
import MoonClubCore

/// Pretend Piggy Bank: 🌙 $1,000 pretend coins across up to 5 companies, following real prices.
struct PiggyView: View {
  @Environment(AppModel.self) private var app
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        Hero(eyebrow: "Practice with pretend coins", title: "Pretend", accent: "Piggy Bank", piggy: true)
        if app.state.piggy == nil { PiggySetup() } else { PiggyBank() }
      }
      .padding(20).readable()
    }
    .background(AuroraField(surface: .piggy))
  }
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
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
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
            Glyph(app.company(s).emoji, size: 30); Text(app.company(s).nick).font(.kHeadline)
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
  @Environment(AppModel.self) private var app
  @State private var prices: [String: Double] = [:]
  @State private var loaded = false
  @State private var confirm = false
  var body: some View {
    // The piggy can disappear while this view is still on screen (start over, reset, an iCloud merge):
    // never force-unwrap it. That was the 0.8.0 TestFlight crash (EXC_BREAKPOINT in PiggyBank.body).
    if let p = app.state.piggy { bank(p) } else { PiggySetup() }
  }

  @ViewBuilder private func bank(_ p: Piggy) -> some View {
    let value = loaded ? piggyValue(p.holdings, prices: prices) : piggyValue(p.holdings, prices: [:])
    let change = value - app.content.startCoins
    let hist = p.history.sorted { $0.key < $1.key }
    // Open wide (iPhone Duo, iPad): the money and its line on one page, what's inside on the other.
    TwoPage {
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
    } second: {
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
        .padding(14).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
      }
    }
    Card {
      HStack(spacing: 6) { ForEach(p.holdings, id: \.s) { h in Glyph(app.companies[h.s]?.emoji ?? "", size: 36) } }
      Text(basketTip(p.holdings.count)).font(.callout)
    }
    Button(confirm ? "Yes, empty it and start over" : "Start over with new pretend coins") {
      if confirm { withAnimation { app.mutate { $0.resetPiggy() } } } else { confirm = true }
    }.font(.footnote).frame(maxWidth: .infinity)
    .task {
      if let q = try? await app.market.quotes(p.holdings.map(\.s)) {
        prices = q; withAnimation(.snappy) { loaded = true }
        app.mutate { $0.recordValue(today: app.today, value: piggyValue(p.holdings, prices: q)) }
      }
    }
    }
  }
}
