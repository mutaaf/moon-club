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
  @State private var run = RunModel()
  @State private var results = false
  /// iPhone Duo tabletop mode is on (counts toward the Tabletop Trader trophy when the boss is done).
  @State private var tabletop = false
  /// The trip forward in time (Metal chromatic sweep + film grain on the chart).
  @State private var warpStart: Date?

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

    VStack(spacing: 12) {
      GameHUD(run: run, title: node.title, done: min(3, phase.rawValue), total: 3, boss: BossInfo(name: "\(name) · \(Day.en("MMM yyyy", pastC.last?.d ?? app.today))", art: "⏳"), dark: true) { dismiss() }
      if results {
        RunResults(stars: 1 + right, run: run, boss: true, subtitle: "Clues help, but they're never promises.", source: .boss, earnId: node.id, node: node,
                   again: { withAnimation(Motion.safe(Motion.card, rm)) { run.reset(); right = 0; feedback = nil; call = nil; shown = 0; phase = .trend; results = false } },
                   map: { dismiss() })
          .padding(20)
          .background(Palette.card.opacity(0.94), in: RoundedRectangle(cornerRadius: 32, style: .continuous))
          .frame(maxHeight: .infinity)
          .transition(.scale(scale: 0.92).combined(with: .opacity))
      } else {
      // iPhone Duo tabletop: the chart stands up on the top half, the clues become a game pad below.
      TabletopStage(active: $tabletop) {
      ChartCard(caption: phase == .reveal || phase == .done ? "What happened next" : "The chart, up to that day") {
        CandleChart(candles: all,
                    level: phase == .floor && feedback == nil ? nil : (phase.rawValue >= Phase.floor.rawValue ? floor : nil),
                    levelColor: Hue.grape.color, levelLabel: phase.rawValue >= Phase.floor.rawValue && (phase != .floor || feedback != nil) ? "Floor" : nil,
                    reveal: phase.rawValue >= Phase.reveal.rawValue ? past + shown : past,
                    cut: past - 1,
                    domain: domain(all))
      }
      .timeWarp(start: warpStart, duration: Double(future) * 0.14 + 0.35)
      } bottom: {
      Group {
        switch phase {
        case .trend: question("Clue 1: what's the trend so far?", Trend.allCases.map { $0 == .up ? "Up" : $0 == .down ? "Down" : "Sideways" }, correct: Trend.allCases.firstIndex(of: trend) ?? 0) { ok in
            RoundResult(right: ok, why: "Over these 40 days it was going \(trend == .sideways ? "sideways" : trend.rawValue).") }
        case .floor: question("Clue 2: where is the floor?", floorOpts.map { coins($0) }, correct: floorOpts.firstIndex(of: floor) ?? 0) { ok in
            RoundResult(right: ok, why: "Near \(coins(floor)) the price kept bouncing up.") }
        case .call: callPicker
        case .reveal, .done: revealCard(trend: trend, after: after, name: name)
        }
      }
      .frame(maxWidth: .infinity)
      .padding(16)
      .background(Palette.card.opacity(0.94), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
      }
      .onChange(of: tabletop) { _, on in if on { run.lunaSays(.duoTabletop) } }
      }
    }
    .padding(.horizontal, 20).padding(.bottom, 12)
    .readable(760)
    .background(BossBackdrop(shock: burst))
    .overlay(CoinBurst(tick: run.coinTick, target: run.coinTarget))
    .overlay(Celebrate(trigger: burst))
    .environment(\.chartBloom, run.right)
    #if DEBUG
    // Recordings: `-warp` makes a pretend call after 2 s, so the time-travel effect plays without taps.
    .task { if ProcessInfo.processInfo.arguments.contains("-warp") { try? await Task.sleep(for: .seconds(2)); phase = .call; call = .up; travel() } }
    #endif
    .glassStage()
    .playChrome()
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
        run.record(r.right, bossHit: 0.34)
        withAnimation(Motion.safe(Motion.card, rm)) { feedback = r }
      }
      if let f = feedback {
        Text((f.right ? "Yes! " : "Good try. ") + f.why).font(.callout.weight(.medium)).frame(maxWidth: .infinity, alignment: .leading)
        Button("Next clue") { run.nextRound(); withAnimation(Motion.safe(Motion.card, rm)) { feedback = nil; phase = Phase(rawValue: phase.rawValue + 1) ?? .call } }.buttonStyle(ChunkyPrimary())
      }
    }
  }

  private var callPicker: some View {
    VStack(spacing: 10) {
      Text("Your pretend call: the next two weeks will go…").font(.kTitle).frame(maxWidth: .infinity, alignment: .leading)
      HStack(spacing: 10) {
        ForEach(Array([Trend.up, .sideways, .down].enumerated()), id: \.element) { i, t in
          AnswerButton(text: t == .up ? "Up" : t == .down ? "Down" : "Sideways", icon: t == .up ? "arrow.up.right" : t == .down ? "arrow.down.right" : "arrow.right", index: i, compact: true) { call = t; travel() }
        }
      }
      Text("Just pretend. No points for the call: only for reading the clues.").font(.footnote).foregroundStyle(.secondary)
    }
  }

  private func travel() {
    withAnimation(Motion.safe(Motion.card, rm)) { phase = .reveal }
    warpStart = Date()
    Task {
      for k in 1...future {
        try? await Task.sleep(for: .milliseconds(rm ? 0 : 140))
        withAnimation(Motion.safe(.easeOut(duration: 0.14), rm)) { shown = k }
      }
      withAnimation(Motion.safe(Motion.card, rm)) { phase = .done; run.bossHP = 0 }
      warpStart = nil
      onFinish(1 + right)
      if tabletop { app.mutate { $0.useDuo(.tabletop) } }
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
        Button("See my stars") { withAnimation(Motion.safe(Motion.celebrate, rm)) { results = true } }.buttonStyle(ChunkyPrimary())
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
    // Challenge (optional-track) lessons join the quiz only once the child has played them.
    let ls = World.lessons(of: region, app.content).filter { !app.content.isOptional($0) || app.state.lessons.contains($0.id) }
    let checks = Self.pick(ls, seed: region.id.count)
    GameShell(node: node, rounds: checks.count, intro: "Five quick questions from this land. Win them to plant your flag!",
              boss: BossInfo(name: node.title, art: node.art), timed: false, arena: true, onFinish: onFinish) { i, answer, answered in
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
    return VStack(spacing: 14) {
      Text(check.q).font(.kTitle).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
      VStack(spacing: 6) {
        ForEach(Array(order.enumerated()), id: \.element) { k, i in
          AnswerButton(text: check.options[i], index: k, state: answered == nil ? .idle : i == check.answer ? .right : i == picked ? .wrong : .dim) {
            picked = i; answer(RoundResult(right: i == check.answer, why: check.why))
          }
          .disabled(answered != nil)
        }
      }
    }
  }
}
