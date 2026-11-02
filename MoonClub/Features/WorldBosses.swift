import SwiftUI
import MoonClubCore

/// Boss: the Chart Time Machine. A real company's chart up to "today" in the past. Read the clues (trend,
/// floor), make a pretend call, then travel forward and watch what really happened. Stars come from reading
/// the clues, never from the call: a good read can still be surprised, and that's the lesson.
struct TimeMachineBoss: View {
  let node: WorldNode
  let symbol: String
  let onFinish: (Int) -> Void
  @Environment(AppModel.self) private var app
  @Environment(\.dismiss) private var dismiss
  @Environment(\.accessibilityReduceMotion) private var rm

  enum Phase: Int { case trend, floor, call, reveal, done }
  @State private var phase: Phase = .trend
  @State private var right = 0
  @State private var feedback: RoundResult?
  @State private var call: Trend?
  @State private var shown = 0
  @State private var burst = 0

  private let past = 40, future = 12

  var body: some View {
    let s = app.candles[symbol] ?? app.candles.values.first
    let start = startIndex(s)
    let all = s?.window(start, past + future) ?? Practice.chart(.bounce, seed: 1, n: past + future)
    let pastC = Array(all.prefix(past))
    let trend = ChartMath.trend(pastC.map(\.c))
    let floor = ChartMath.floor(Array(pastC.suffix(20)))
    let after = ChartMath.trend(Array(all.suffix(future + 1)).map(\.c), threshold: 0.03)
    let name = companyName(s?.s ?? "Practice", app)
    let floorOpts = floorOptions(floor, pastC)

    VStack(spacing: 14) {
      HStack(spacing: 10) {
        Glyph("⏳", size: 36)
        VStack(alignment: .leading, spacing: 0) {
          Text("Chart Time Machine").font(.kHeadline)
          Text("\(name) · \(Day.en("MMMM yyyy", pastC.last?.d ?? app.today))").font(.caption).foregroundStyle(.secondary)
        }
        Spacer()
        PretendPill()
      }
      .padding(.top, 8)

      ChartCard(caption: phase == .reveal || phase == .done ? "What happened next" : "The chart, up to that day") {
        CandleChart(candles: all,
                    level: phase == .floor && feedback == nil ? nil : (phase.rawValue >= Phase.floor.rawValue ? floor : nil),
                    levelColor: Hue.grape.color, levelLabel: phase.rawValue >= Phase.floor.rawValue && (phase != .floor || feedback != nil) ? "Floor" : nil,
                    reveal: phase.rawValue >= Phase.reveal.rawValue ? past + shown : past,
                    cut: past - 1,
                    domain: domain(all))
      }

      Group {
        switch phase {
        case .trend: question("Clue 1: what's the trend so far?", Trend.allCases.map(\.word), correct: Trend.allCases.firstIndex(of: trend)!) { ok in
            RoundResult(right: ok, why: "Over these 40 days it was going \(trend == .sideways ? "sideways" : trend.rawValue).") }
        case .floor: question("Clue 2: where is the floor?", floorOpts.map { coins($0) }, correct: floorOpts.firstIndex(of: floor)!) { ok in
            RoundResult(right: ok, why: "Near \(coins(floor)) the price kept bouncing up.") }
        case .call: callPicker
        case .reveal, .done: revealCard(trend: trend, after: after, name: name)
        }
      }
      .frame(maxWidth: .infinity)
    }
    .padding(.horizontal, 20).padding(.bottom, 12)
    .readable(760)
    .background(AuroraField(surface: .luna))
    .overlay(Celebrate(trigger: burst))
    .navigationTitle(node.title)
    .navigationBarTitleDisplayMode(.inline)
  }

  private func startIndex(_ s: CandleSeries?) -> Int {
    guard let s, s.candles.count > past + future else { return 0 }
    var g = Seeded(symbol.unicodeScalars.reduce(7) { $0 &* 31 &+ Int($1.value) })
    return Int.random(in: 0...(s.candles.count - past - future), using: &g)
  }
  private func domain(_ cs: [Candle]) -> ClosedRange<Double> {
    let lo = cs.map(\.l).min() ?? 0, hi = cs.map(\.h).max() ?? 1, pad = (hi - lo) * 0.08
    return (lo - pad)...(hi + pad)
  }
  private func floorOptions(_ f: Double, _ cs: [Candle]) -> [Double] {
    let hi = ChartMath.ceiling(cs), mid = (f + hi) / 2
    var o = [f, mid, hi]; o.rotate(by: Int(f) % 3); return o
  }

  @ViewBuilder private func question(_ q: String, _ opts: [String], correct: Int, why: @escaping (Bool) -> RoundResult) -> some View {
    VStack(spacing: 10) {
      Text(q).font(.kTitle).frame(maxWidth: .infinity, alignment: .leading)
      Choices(options: opts, correct: correct, answered: feedback, picked: nil) { i in
        let r = why(i == correct); if r.right { right += 1 }
        withAnimation(Motion.safe(Motion.card, rm)) { feedback = r }
      }
      if let f = feedback {
        Text((f.right ? "Yes! " : "Good try. ") + f.why).font(.callout.weight(.medium)).frame(maxWidth: .infinity, alignment: .leading)
        Button("Next clue") { withAnimation(Motion.safe(Motion.card, rm)) { feedback = nil; phase = Phase(rawValue: phase.rawValue + 1)! } }.buttonStyle(PrimaryButtonStyle())
      }
    }
  }

  private var callPicker: some View {
    VStack(spacing: 10) {
      Text("Your pretend call: the next two weeks will go…").font(.kTitle).frame(maxWidth: .infinity, alignment: .leading)
      HStack(spacing: 10) {
        ForEach([Trend.up, .sideways, .down], id: \.self) { t in
          Button { call = t; travel() } label: {
            Label(t.word, systemImage: t == .up ? "arrow.up.right" : t == .down ? "arrow.down.right" : "arrow.right").font(.kHeadline).lineLimit(1).minimumScaleFactor(0.7)
              .frame(maxWidth: .infinity, minHeight: 52).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
          }.buttonStyle(PressStyle())
        }
      }
      Text("Just pretend. No points for the call: only for reading the clues.").font(.footnote).foregroundStyle(.secondary)
    }
  }

  private func travel() {
    withAnimation(Motion.safe(Motion.card, rm)) { phase = .reveal }
    Task {
      for k in 1...future {
        try? await Task.sleep(for: .milliseconds(rm ? 0 : 140))
        withAnimation(Motion.safe(.easeOut(duration: 0.14), rm)) { shown = k }
      }
      withAnimation(Motion.safe(Motion.card, rm)) { phase = .done }
      onFinish(1 + right)
      burst += 1
    }
  }

  @ViewBuilder private func revealCard(trend: Trend, after: Trend, name: String) -> some View {
    VStack(spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        Luna(size: 56, mood: phase == .done ? (call == after ? .cheering : .thinking) : .thinking)
        VStack(alignment: .leading, spacing: 6) {
          if phase == .done {
            Text("It went \(after == .sideways ? "sideways" : after.rawValue).").font(.kTitle)
            Text(after == call ? "Your call matched this time. Clues helped, but it could have gone the other way." : "Surprise! The clues said one thing, and the price did another. That happens to experts too. Clues are not promises.")
              .font(.callout).fixedSize(horizontal: false, vertical: true)
          } else {
            Text("Traveling forward in time…").font(.kTitle)
          }
        }
        Spacer(minLength: 0)
      }
      if phase == .done {
        StarRow(stars: 1 + right, size: 30, animated: true)
        Button("Back to the map") { dismiss() }.buttonStyle(PrimaryButtonStyle())
      }
    }
  }
}

/// Boss for the lesson regions: a short captain's quiz from the region's own lessons.
struct ReviewBoss: View {
  let node: WorldNode
  let region: Region
  let onFinish: (Int) -> Void
  @Environment(AppModel.self) private var app
  var body: some View {
    let checks = Self.pick(World.lessons(of: region, app.content), seed: region.id.count)
    GameShell(node: node, rounds: checks.count, intro: "Five quick questions from this land. Win them to plant your flag!", onFinish: onFinish) { i, answer, answered in
      ReviewRound(check: checks[i], seed: i, answer: answer, answered: answered)
    }
  }
  static func pick(_ ls: [Lesson], seed: Int) -> [Check] {
    let all = ls.flatMap { $0.steps.compactMap { if case let .check(c) = $0 { return c } else { return nil } } }
    guard !all.isEmpty else { return [Check(q: "Ready to plant your flag?", options: ["Yes!"], answer: 0, why: "Onward!")] }
    var g = Seeded(seed)
    return Array(all.shuffled(using: &g).prefix(5))
  }
}

struct ReviewRound: View {
  let check: Check, seed: Int
  let answer: (RoundResult) -> Void; let answered: RoundResult?
  @State private var picked: Int?
  var body: some View {
    var g = Seeded(seed &+ check.q.count)
    let order = Array(check.options.indices).shuffled(using: &g)
    return VStack(spacing: 16) {
      Spacer(minLength: 0)
      Text(check.q).font(.kTitle).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
      VStack(spacing: 8) {
        ForEach(order, id: \.self) { i in
          Button { picked = i; answer(RoundResult(right: i == check.answer, why: check.why)) } label: {
            Text(check.options[i]).font(.kHeadline).multilineTextAlignment(.center).frame(maxWidth: .infinity, minHeight: 52).padding(.horizontal, 12)
              .background(fill(i), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
              .foregroundStyle(answered != nil && (i == check.answer || i == picked) ? Color.white : Palette.ink)
          }.buttonStyle(PressStyle()).disabled(answered != nil)
        }
      }
      Spacer(minLength: 0)
    }
  }
  private func fill(_ i: Int) -> AnyShapeStyle {
    guard answered != nil else { return AnyShapeStyle(.thinMaterial) }
    return i == check.answer ? AnyShapeStyle(Palette.good) : i == picked ? AnyShapeStyle(Hue.coral.color) : AnyShapeStyle(.thinMaterial)
  }
}
