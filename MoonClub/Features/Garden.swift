import SwiftUI
import MoonClubCore

// Moon Garden (0.13): plant Moon points in kid-known companies, watch them grow or shrink with real daily
// closing prices, harvest them back any time. Rules are pure in MoonClubCore `Garden.swift`; this file is
// only the screens. Copy rules: "plant", "grow", "harvest"; never "bet", never money, never advice.

extension AppModel {
  /// Companies that can be planted: kid-known content companies with a daily price series.
  var gardenCompanies: [KidCo] { content.companies.filter { candles[$0.s] != nil } }
  /// Today's price for a company: the latest daily close (prices never tick).
  func gardenPrice(_ s: String) -> (d: String, c: Double)? { Garden.close(candles[s], onOrBefore: today) }
  var gardenAllowance: Int { Garden.allowance(balance: wallet, plantedToday: derived.garden.plantedOn[today] ?? 0, limit: state.gardenLimitPct) }
  /// What everything growing is worth now.
  var gardenValue: Int { derived.garden.growing.reduce(0) { $0 + $1.value(gardenPrice($1.s)?.c) } }
  static func newEventId() -> String { Garden.eventId(nowMillis: Int(Date().timeIntervalSince1970 * 1000), salt: UInt16.random(in: 0...UInt16.max)) }

  @discardableResult func plant(_ s: String, points: Int) -> Bool {
    guard let p = gardenPrice(s) else { return false }
    var ok = false
    mutate { ok = $0.plant(s, points: points, price: p.c, today: today, id: AppModel.newEventId(), content) }
    return ok
  }
  @discardableResult func harvest(_ s: String, points: Int) -> Bool {
    guard let p = gardenPrice(s) else { return false }
    var ok = false
    mutate { ok = $0.harvest(s, points: points, price: p.c, today: today, id: AppModel.newEventId()) }
    return ok
  }
  /// "The market is sleeping…" in New York time.
  var marketNote: String {
    var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "America/New_York") ?? .current
    let now = Date()
    return Garden.marketNote(weekday: cal.component(.weekday, from: now), hour: cal.component(.hour, from: now))
  }
}

/// Which side of the Piggy Bank tab is showing. Two currencies, kept apart on purpose: Moon points (earned in
/// the app) grow in the Moon Garden; the pretend coins (a $1,000 practice piggy) stay in the Piggy Bank.
enum PiggySide: String, CaseIterable, Identifiable {
  case garden, coins
  var id: String { rawValue }
  var title: String { self == .garden ? "Moon Garden" : "Pretend coins" }
  var icon: String { self == .garden ? "leaf.fill" : "banknote.fill" }
}

/// The Moon Garden page section.
struct MoonGarden: View {
  @Environment(AppModel.self) private var app
  @State private var planting = false
  @State private var plot: String?
  var body: some View {
    let _ = Perf.body("MoonGarden")
    let book = app.derived.garden
    VStack(alignment: .leading, spacing: 16) {
      GardenSummary(book: book) { planting = true }
      if book.growing.isEmpty {
        EmptyGarden { planting = true }
      } else {
        VStack(spacing: 10) {
          ForEach(book.growing) { p in PlotRow(plot: p) { plot = p.s } }
        }
      }
      if let nudge = Garden.basketNudge(book) {
        TipCard(symbol: "basket.fill", hue: .orange, title: "One basket?", text: nudge)
      }
      TipCard(symbol: "moon.zzz.fill", hue: .sky, title: "Check less often", text: Garden.wisdom(today: app.today))
      if !book.harvests.isEmpty { HarvestHistory(lines: Array(book.harvests.suffix(3).reversed())) }
    }
    .sheet(isPresented: $planting) { PlantSheet().presentationDetents([.large]).presentationCornerRadius(32) }
    .sheet(item: Binding(get: { plot.map(PlotRoute.init) }, set: { plot = $0?.id })) { r in
      PlotSheet(symbol: r.id).presentationDetents([.large]).presentationCornerRadius(32)
    }
    .onAppear {
      #if DEBUG
      let a = ProcessInfo.processInfo.arguments
      if a.contains("-plant") { planting = true }
      if let i = a.firstIndex(of: "-plot"), i + 1 < a.count { plot = a[i + 1] }
      #endif
    }
  }
}

struct PlotRoute: Identifiable { let id: String }

/// Points to spend, what's growing, today's planting room, and the market's sleep note.
struct GardenSummary: View {
  let book: GardenBook
  let plant: () -> Void
  @Environment(AppModel.self) private var app
  var body: some View {
    let value = app.gardenValue, change = value - book.principal
    Card {
      HStack(alignment: .firstTextBaseline) { Eyebrow(text: "Your Moon Garden"); Spacer(); PointsPill() }
      ViewThatFits(in: .horizontal) {
        HStack(alignment: .top, spacing: 18) { growing(value, change); Divider().frame(height: 64); spend }
        VStack(alignment: .leading, spacing: 12) { growing(value, change); spend }
      }
      Label(app.marketNote, systemImage: "moon.zzz.fill").font(.callout).foregroundStyle(Palette.ink2)
      Button(action: plant) {
        Label(app.gardenAllowance >= Garden.minPlant ? "Plant points" : "Planting rests until tomorrow", systemImage: "leaf.arrow.triangle.circlepath")
      }
      .buttonStyle(PrimaryButtonStyle(tint: Hue.mint.color.blend(with: .black, by: 0.25)))
      .disabled(app.gardenAllowance < Garden.minPlant)
      .accessibilityHint("You can plant up to \(app.gardenAllowance) more points today.")
    }
  }
  private func growing(_ value: Int, _ change: Int) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("Growing").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink2)
      Ticker(value: Double(value), format: { "\(Int($0)) pts" }, font: .system(size: 40, weight: .heavy, design: .rounded))
        .lineLimit(1).minimumScaleFactor(0.6)
      if book.principal > 0 { UpDown(change: change, suffix: "since planting") }
    }
  }
  private var spend: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("To spend or plant").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink2)
      HStack(spacing: 6) { PointsMark(size: 22); Text("\(app.wallet)").font(.system(size: 32, weight: .heavy, design: .rounded)).monospacedDigit() }
      Text("Plant up to \(app.gardenAllowance) more today").font(.caption).foregroundStyle(Palette.ink2)
    }
  }
}

/// "Moon points are pretend" — on every garden surface (they are never money).
struct PointsPill: View {
  var body: some View {
    Label("Just for fun", systemImage: "moon.fill")
      .font(.caption.weight(.bold)).textCase(.uppercase).tracking(1)
      .padding(.horizontal, 10).padding(.vertical, 5)
      .background(Palette.moon, in: Capsule()).foregroundStyle(Palette.midnight)
      .accessibilityLabel("Moon points are pretend. They are not money.")
  }
}

/// Up or down with an arrow AND a word, never colour alone.
struct UpDown: View {
  let change: Int
  var suffix = ""
  var body: some View {
    let up = change >= 0
    Label(change == 0 ? "No change \(suffix)" : "\(up ? "Up" : "Down") \(abs(change)) \(suffix)", systemImage: change == 0 ? "equal.circle.fill" : up ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
      .font(.subheadline.weight(.semibold)).foregroundStyle(change == 0 ? Palette.ink2 : up ? Palette.goodInk : Palette.badInk)
      .lineLimit(1).minimumScaleFactor(0.8)
  }
}

struct EmptyGarden: View {
  let plant: () -> Void
  var body: some View {
    Card {
      HStack(spacing: 14) {
        Glyph("🌱", size: 56)
        VStack(alignment: .leading, spacing: 4) {
          Text("Nothing is growing yet").font(.kTitle)
          Text("Plant some Moon points in a company you know. They grow or shrink with its real price, one day at a time.").font(.callout)
        }
      }
      Button("Plant my first points", action: plant).buttonStyle(SoftButtonStyle())
    }
  }
}

struct TipCard: View {
  let symbol: String, hue: Hue, title: String, text: String
  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: symbol).font(.title2).foregroundStyle(hue.color).frame(width: 34)
      VStack(alignment: .leading, spacing: 3) { Text(title).font(.kHeadline); Text(text).font(.callout).fixedSize(horizontal: false, vertical: true) }
      Spacer(minLength: 0)
    }
    .padding(16).moonGlass(radius: 20, weight: .thin)
    .accessibilityElement(children: .combine)
  }
}

/// One company's patch: a sparkline from the planting day, its value, and up/down since planting.
struct PlotRow: View {
  let plot: Plot
  let open: () -> Void
  @Environment(AppModel.self) private var app
  var body: some View {
    let co = app.company(plot.s), price = app.gardenPrice(plot.s)
    let value = plot.value(price?.c)
    Button(action: open) {
      HStack(spacing: 12) {
        Glyph(co.emoji, size: 44)
        VStack(alignment: .leading, spacing: 2) {
          Text(co.nick).font(.kHeadline).lineLimit(1).minimumScaleFactor(0.7)
          Text("Planted \(plot.principal) pts").font(.caption).foregroundStyle(Palette.ink2).lineLimit(1)
        }
        .layoutPriority(1)
        Spacer(minLength: 4)
        GardenSpark(values: Garden.spark(app.candles[plot.s], from: plot.since, upTo: app.today))
          .frame(minWidth: 40, maxWidth: 160, minHeight: 34, maxHeight: 34)
        VStack(alignment: .trailing, spacing: 2) {
          Text("\(value) pts").font(.kHeadline).monospacedDigit()
          UpDown(change: value - plot.principal).font(.caption)
        }
        .fixedSize()
        Image(systemName: "chevron.right").foregroundStyle(.tertiary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(14).moonGlass(radius: 20, weight: .thin)
    }
    .buttonStyle(.plain)
    .accessibilityHint("Shows why it moved and lets you harvest.")
  }
}

/// A calm sparkline: a line plus an end mark that points the way it went (colour-blind safe).
struct GardenSpark: View {
  let values: [Double]
  var body: some View {
    Canvas { g, size in
      guard values.count > 1, let lo = values.min(), let hi = values.max(), let first = values.first, let last = values.last else { return }
      let span = max(hi - lo, 0.0001)
      func pt(_ i: Int, _ v: Double) -> CGPoint {
        CGPoint(x: (size.width - 8) * CGFloat(i) / CGFloat(values.count - 1), y: 4 + (size.height - 8) * (1 - CGFloat((v - lo) / span)))
      }
      let up = last >= first, col = up ? Palette.goodInk : Palette.badInk
      g.stroke(Path { p in p.move(to: pt(0, first)); p.addLine(to: .init(x: size.width, y: pt(0, first).y)) }, with: .color(Palette.ink2.opacity(0.3)), style: .init(lineWidth: 1, dash: [3, 3]))
      var line = Path()
      for (i, v) in values.enumerated() { i == 0 ? line.move(to: pt(i, v)) : line.addLine(to: pt(i, v)) }
      g.stroke(line, with: .color(col), style: .init(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
      let e = pt(values.count - 1, last), t: CGFloat = 4
      var tri = Path()
      if up { tri.move(to: .init(x: e.x - t, y: e.y + t * 0.4)); tri.addLine(to: .init(x: e.x, y: e.y - t)); tri.addLine(to: .init(x: e.x + t, y: e.y + t * 0.4)) }
      else { tri.move(to: .init(x: e.x - t, y: e.y - t * 0.4)); tri.addLine(to: .init(x: e.x, y: e.y + t)); tri.addLine(to: .init(x: e.x + t, y: e.y - t * 0.4)) }
      tri.closeSubpath()
      g.fill(tri, with: .color(col))
    }
    .accessibilityHidden(true)
  }
}

struct HarvestHistory: View {
  let lines: [HarvestLine]
  @Environment(AppModel.self) private var app
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Recent harvests").font(.kHeadline)
      ForEach(lines) { l in
        HStack {
          Glyph(app.company(l.s).emoji, size: 28)
          Text("\(app.company(l.s).nick): \(l.paid) pts back").font(.subheadline).lineLimit(1).minimumScaleFactor(0.8)
          Spacer()
          UpDown(change: l.gain).font(.caption)
        }
      }
    }
    .padding(16).moonGlass(radius: 20, weight: .thin)
  }
}

// MARK: - Planting

/// Pick a company, slide how many points, confirm. Fits iPhone SE without scrolling.
struct PlantSheet: View {
  @Environment(AppModel.self) private var app
  @Environment(\.dismiss) private var dismiss
  @State private var pick: String?
  @State private var amount: Double = 10
  @State private var asking = false
  @State private var burst = 0
  let cols = [GridItem(.adaptive(minimum: 76), spacing: 8)]

  var body: some View {
    let room = app.gardenAllowance
    let cos = app.gardenCompanies
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        Text("Plant points").font(.kTitle)
        Spacer()
        Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").font(.title2).foregroundStyle(Palette.ink2) }
          .accessibilityLabel("Close")
      }
      Text("Pick a company you know. Your points will grow or shrink with its real price.").font(.callout).fixedSize(horizontal: false, vertical: true)
      LazyVGrid(columns: cols, spacing: 8) {
        ForEach(cos, id: \.s) { c in
          let on = pick == c.s
          Button { withAnimation(Motion.tap) { pick = c.s } } label: {
            VStack(spacing: 4) { Glyph(c.emoji, size: 34); Text(c.nick).font(.caption.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7) }
              .frame(maxWidth: .infinity, minHeight: 70)
              .background(on ? Palette.mint : Color.clear, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
              .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(on ? Hue.mint.color : Palette.line, lineWidth: on ? 2.5 : 1))
          }
          .buttonStyle(.plain)
          .accessibilityAddTraits(on ? .isSelected : [])
        }
      }
      VStack(alignment: .leading, spacing: 6) {
        HStack(alignment: .firstTextBaseline) {
          Text("\(Int(amount))").font(.system(size: 44, weight: .heavy, design: .rounded)).monospacedDigit().contentTransition(.numericText(value: amount)).lineLimit(1).minimumScaleFactor(0.6)
          Text("points").font(.kHeadline).foregroundStyle(Palette.ink2)
          Spacer()
          Text("up to \(room) today").font(.caption).foregroundStyle(Palette.ink2)
        }
        if room >= Garden.minPlant {
          Slider(value: $amount, in: Double(Garden.minPlant)...Double(max(room, Garden.minPlant + 1)), step: 1)
            .tint(Hue.mint.color.blend(with: .black, by: 0.2))
            .accessibilityLabel("Points to plant")
            .accessibilityValue("\(Int(amount)) points")
        } else {
          Text("You've planted all you can for today. Your shop points stay safe. Come back tomorrow!").font(.callout)
        }
      }
      .padding(14).moonGlass(radius: 20, weight: .thin)
      Text("Half your points (or what a grown-up picked) is today's limit, so your shop points stay safe.").font(.caption).foregroundStyle(Palette.ink2)
      Spacer(minLength: 0)
      Button(pick.map { "Plant \(Int(amount)) points in \(app.company($0).nick)?" } ?? "Pick a company first") { asking = true }
        .buttonStyle(PrimaryButtonStyle(tint: Hue.mint.color.blend(with: .black, by: 0.25)))
        .disabled(pick == nil || room < Garden.minPlant)
    }
    .padding(20)
    .overlay { Celebrate(trigger: burst, tier: .small).allowsHitTesting(false) }
    .onAppear { amount = Double(min(max(Garden.minPlant, room / 2), max(room, Garden.minPlant))) }
    .confirmationDialog(pick.map { "Plant \(Int(amount)) points in \(app.company($0).nick)?" } ?? "", isPresented: $asking, titleVisibility: .visible) {
      Button("Yes, plant them") {
        guard let pick, app.plant(pick, points: min(Int(amount), app.gardenAllowance)) else { return }
        burst += 1
        Task { try? await Task.sleep(for: .milliseconds(700)); dismiss() }
      }
      Button("Not now", role: .cancel) {}
    } message: {
      Text("They can grow or shrink. You can harvest them back any time.")
    }
    .sensoryFeedback(.success, trigger: burst)
  }
}

// MARK: - One patch: why it moved, and harvesting

struct PlotSheet: View {
  let symbol: String
  @Environment(AppModel.self) private var app
  @Environment(\.dismiss) private var dismiss
  @State private var amount: Double = 0
  @State private var asking = false
  var body: some View {
    let co = app.company(symbol)
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        HStack {
          Glyph(co.emoji, size: 48)
          Text(co.nick).font(.kTitle).lineLimit(1).minimumScaleFactor(0.6)
          Spacer()
          Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").font(.title2).foregroundStyle(Palette.ink2) }.accessibilityLabel("Close")
        }
        if let p = app.derived.garden.plots[symbol] {
          let price = app.gardenPrice(symbol), value = p.value(price?.c)
          Card {
            HStack(alignment: .firstTextBaseline) {
              Text("\(value) pts").font(.system(size: 40, weight: .heavy, design: .rounded)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
              Spacer()
              UpDown(change: value - p.principal, suffix: "since planting")
            }
            GardenSpark(values: Garden.spark(app.candles[symbol], from: p.since, upTo: app.today)).frame(height: 70)
            Text("Planted \(p.principal) points on \(Day.en("MMMM d", p.since)).").font(.callout).foregroundStyle(Palette.ink2)
            VStack(alignment: .leading, spacing: 6) {
              Text("Harvest \(Int(amount)) of \(value) points").font(.kHeadline).monospacedDigit()
              if value > 1 { Slider(value: $amount, in: 1...Double(value), step: 1).accessibilityLabel("Points to harvest").accessibilityValue("\(Int(amount)) points") }
              Button(Int(amount) >= value ? "Harvest it all" : "Harvest \(Int(amount)) points") { asking = true }
                .buttonStyle(SoftButtonStyle()).disabled(value < 1)
            }
            .onAppear { amount = Double(value) }
          }
        }
        Card { WhyCard(symbol: symbol, title: "Why did \(co.nick) move?") }
      }
      .padding(20)
    }
    .confirmationDialog("Harvest \(Int(amount)) points from \(co.nick)?", isPresented: $asking, titleVisibility: .visible) {
      Button("Yes, harvest") { if app.harvest(symbol, points: Int(amount)) { dismiss() } }
      Button("Not now", role: .cancel) {}
    } message: { Text("They go back to your points to spend or plant again.") }
  }
}
