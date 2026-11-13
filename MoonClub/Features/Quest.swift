import Charts
import SwiftUI
import MoonClubCore

/// Luna's quests — learn by doing. Chapter 1 Lemonade Stand (company → shares → price → report card),
/// Chapter 2 Save or Grow? (jar → tree → choose → check), Chapter 3 Your Slice Pays You (payout →
/// snowball → real → check). `start` is a chapter id ("lemonade", "save", "dividends") or a stage
/// ("shares", "save:tree", "dividends:payout") from a tap-a-word "Play it".
struct QuestView: View {
  let start: String
  /// Tests measure the page without its ScrollView (a ScrollView reports no height of its own).
  var scrolls = true
  init(start: String, scrolls: Bool = true) {
    self.start = start; self.scrolls = scrolls
    let r = Self.routed(start)
    _chapter = State(initialValue: r.chapter); _stage = State(initialValue: r.stage)
  }
  /// "lemonade" → (lemonade, intro); "shares" → (lemonade, shares); "save:tree" → (save, tree).
  static func routed(_ start: String) -> (chapter: String, stage: String) {
    let parts = start.split(separator: ":").map(String.init)
    if parts.count == 2 { return (parts[0], parts[1]) }
    if lemonade.contains(start) { return ("lemonade", start) }
    return (start, "intro")
  }
  @Environment(AppModel.self) private var app
  @Environment(\.dismiss) private var dismiss
  @State private var chapter = "lemonade"
  @State private var stage = "intro"
  @State private var burst = 0
  /// Game On HUD for the quest: each stage you finish earns coins and grows the combo.
  @State private var run = RunModel()

  static let lemonade = ["company", "shares", "price", "report"]
  var stages: [String] { chapter == "lemonade" ? Self.lemonade : app.content.questChapters?.CH_STAGES[chapter] ?? [] }
  var chapters: [ChapterMeta] { app.content.questChapters?.CHAPTERS ?? [ChapterMeta(id: "lemonade", emoji: "🍋", title: "Luna's Lemonade Stand", blurb: "", badge: "lemonade")] }
  var meta: ChapterMeta? { chapters.first { $0.id == chapter } }

  var body: some View {
    if !scrolls {
      // What CardFitTests measures: the HUD plus the page, at their natural height (no NavigationStack
      // or ScrollView, which would just report the size they're offered).
      VStack(spacing: 0) { hud; page }
    } else {
      screen
    }
  }

  private var hud: some View {
    HStack(alignment: .top, spacing: 10) {
      GameHUD(run: run, title: meta?.title ?? "Quest", done: stageIndex, total: max(stages.count, 1)) { dismiss() }
      Menu { ForEach(chapters) { c in Button(c.title) { go(c.id, "intro") } } } label: {
        Image(systemName: "books.vertical.fill").font(.system(size: 16, weight: .heavy)).frame(width: 40, height: 40).moonGlass(Circle(), interactive: true, weight: .thin)
      }
      .padding(.top, 6)
      .accessibilityLabel("Chapters")
    }
    .padding(.horizontal, 20).padding(.bottom, 6)
    .readable(820)
  }

  private var screen: some View {
    NavigationStack {
      // The page only scrolls if a reader's big text needs it; CardFitTests checks every stage fits an
      // iPhone SE and 17 at standard text.
      ScrollView { page }
      .scrollBounceBehavior(.basedOnSize)
      .safeAreaInset(edge: .top) { hud }
      .background(AuroraField(surface: .quest))
      .overlay(CoinBurst(tick: run.coinTick, target: run.coinTarget))
      .overlay(Celebrate(trigger: burst))
      .toolbar(.hidden, for: .navigationBar)
    }
    .onAppear(perform: route)
  }

  private var page: some View {
    // Opened wide (iPhone Duo, iPad): the chapter's story and progress on the left page, the thing
    // you play on the right — a picture book, never across the fold. One column on a phone.
    Storybook(minPage: 300) {
      // A phone is a play screen: one title line, the stepper, the stage (no big hero eating the room).
      VStack(alignment: .leading, spacing: 10) { stepper; stageCard }
    } first: {
      hero; stepper
      HStack(alignment: .top, spacing: 12) {
        Luna(size: 54, wave: true)
        Text(meta?.blurb ?? "").font(.kRead).foregroundStyle(Palette.ink2).fixedSize(horizontal: false, vertical: true)
      }
      .padding(16).background(Palette.moon.opacity(0.35), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    } second: {
      stageCard
    }
    .padding(.horizontal, 20).padding(.top, 2).padding(.bottom, 8).readable(820)
    .animation(.spring(response: 0.5, dampingFraction: 0.86), value: "\(chapter):\(stage)")
  }

  private var compactTitle: some View {
    HStack(spacing: 10) {
      Glyph(meta?.emoji ?? "🍋", size: 36)
      VStack(alignment: .leading, spacing: 0) {
        Text("Chapter \((chapters.firstIndex { $0.id == chapter } ?? 0) + 1)".uppercased()).font(.kEyebrow).foregroundStyle(Palette.accentInk)
        Text(meta?.title ?? "").font(.system(.title3, design: .rounded).weight(.heavy)).lineLimit(1).minimumScaleFactor(0.75)
      }
    }
    .accessibilityElement(children: .combine)
  }

  private var hero: some View {
    Hero(eyebrow: "Learn by doing · Chapter \((chapters.firstIndex { $0.id == chapter } ?? 0) + 1)", title: meta?.title ?? "", emoji: meta?.emoji)
  }
  private var stageCard: some View {
    VStack(alignment: .leading, spacing: 12) { content }
      .padding(16)
      .moonGlass(radius: 32)
      .id("\(chapter):\(stage)")
      .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
  }

  private func route() { let r = Self.routed(start); chapter = r.chapter; stage = r.stage }
  private func go(_ c: String, _ s: String) { chapter = c; stage = s }
  private var stageIndex: Int { stage == "done" ? stages.count : stages.firstIndex(of: stage) ?? 0 }
  private func finish(_ s: String) {
    run.record(true)
    app.mutate { $0.questStage(chapter == "lemonade" ? s : "\(chapter):\(s)"); $0.play("quest", chapter, today: app.today) }
    if let i = stages.firstIndex(of: s), i + 1 < stages.count { stage = stages[i + 1] }
    else { if chapter == "lemonade" { app.mutate { $0.finishLemonade() } }; stage = "done"; burst += 1 }
  }

  /// Numbered stops joined by a line (one row at any width), with the current stop's name underneath —
  /// instead of four word-chips that wrapped to two lines on a phone.
  private var stepper: some View {
    let cur = stages.firstIndex(of: stage) ?? (stage == "done" ? stages.count : -1)
    return VStack(alignment: .leading, spacing: 2) {
      HStack(spacing: 0) {
        ForEach(Array(stages.enumerated()), id: \.element) { i, s in
          let did = app.state.quest.contains(chapter == "lemonade" ? s : "\(chapter):\(s)")
          if i > 0 { Capsule().fill(i <= cur || did ? Palette.accent : Palette.line).frame(height: 3) }
          Button { withAnimation(Motion.card) { stage = s } } label: {
            ZStack {
              Circle().fill(i == cur ? Palette.accent : did ? Palette.good : Palette.card).frame(width: 34, height: 34)
              Circle().strokeBorder(i == cur ? Palette.accent : did ? Palette.good : Palette.line, lineWidth: 2).frame(width: 34, height: 34)
              if did && i != cur { Image(systemName: "checkmark").font(.caption.weight(.heavy)).foregroundStyle(.white) }
              else { Text("\(i + 1)").font(.subheadline.weight(.bold)).monospacedDigit().foregroundStyle(i == cur ? .white : Palette.ink) }
            }
            .frame(width: 44, height: 40).contentShape(Rectangle())
          }
          .buttonStyle(PressStyle())
          .accessibilityLabel("Step \(i + 1): \(title(s))\(did ? ", done" : "")")
        }
      }
      // One caption line names the chapter and the step (the phone has no big title above it).
      HStack(spacing: 6) {
        Glyph(meta?.emoji ?? "🍋", size: 20, style: .plain)
        Text(cur >= 0 && cur < stages.count ? "\(meta?.title ?? "") · Step \(cur + 1): \(title(stages[cur]))" : meta?.title ?? "")
          .font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink2).lineLimit(1).minimumScaleFactor(0.7)
      }
    }
  }
  private func title(_ s: String) -> String {
    if chapter == "lemonade" { return [app.content.quest.company, app.content.quest.shares, app.content.quest.price, app.content.quest.report][Self.lemonade.firstIndex(of: s) ?? 0].title ?? s }
    return text[s].title ?? s.capitalized
  }
  var text: ChapterText { chapter == "save" ? app.content.questChapters!.SAVE : app.content.questChapters!.DIV }

  @ViewBuilder private var content: some View {
    let q = app.content.quest
    switch (chapter, stage) {
    case (_, "intro"):
      Speech(text: chapter == "lemonade" ? q.intro : text.intro)
      Button("Let's go!") { stage = stages.first ?? "done" }.buttonStyle(ChunkyPrimary())
    case (_, "done"):
      VStack(spacing: 14) {
        MoonPhase(phase: chapter == "lemonade" ? 2 : 3, size: 96)
        Text(app.content.badges.first { $0.id == meta?.badge }?.name ?? "Done!").font(.kHero).lineLimit(2).minimumScaleFactor(0.6)
        Text(chapter == "lemonade" ? q.finish : text.finish).font(.kRead).multilineTextAlignment(.center)
        ReadAloud(source: .appCopy(chapter == "lemonade" ? q.finish : text.finish))
        if let next = chapters.first(where: { !app.chaptersDone.contains($0.id) && $0.id != chapter }) {
          Button("Next: \(next.title)") { go(next.id, "intro") }.buttonStyle(ChunkyPrimary())
        }
        Button("Back to the club") { dismiss() }.buttonStyle(SoftButtonStyle())
      }.frame(maxWidth: .infinity)
    case ("lemonade", "company"): CompanyStage(t: q.company) { finish("company") }
    case ("lemonade", "shares"): SharesStage(t: q.shares) { finish("shares") }
    case ("lemonade", "price"): PriceStage(t: q.price) { finish("price") }
    case ("lemonade", "report"): ReportStage(t: q.report) { finish("report") }
    case ("save", "jar"): GrowStage(t: text["jar"], tree: false) { finish("jar") }
    case ("save", "tree"): GrowStage(t: text["tree"], tree: true) { finish("tree") }
    case ("save", "choose"): ChooseStage(t: text["choose"]) { finish("choose") }
    case ("save", "check"): ChecksStage(t: text["check"], checks: app.content.questChapters!.SAVE_CHECK) { finish("check") }
    case ("dividends", "payout"): PayoutStage(t: text["payout"]) { finish("payout") }
    case ("dividends", "snowball"): SnowballStage(t: text["snowball"]) { finish("snowball") }
    case ("dividends", "real"): RealStage(t: text["real"]) { finish("real") }
    case ("dividends", "check"): ChecksStage(t: text["check"], checks: app.content.questChapters!.DIV_CHECK) { finish("check") }
    default: Text("Pick a chapter to start.").font(.kRead)
    }
  }
}

/// Luna talking: speech bubble + read-aloud.
struct Speech: View {
  let text: String
  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Luna(size: 40, wave: true)
      HStack(alignment: .top, spacing: 8) {
        Text(text).font(.kRead).fixedSize(horizontal: false, vertical: true)
        Spacer(minLength: 0)
        SpeakButton(source: .appCopy(text))
      }
      .padding(10)
      .background(Palette.lavender.opacity(0.8), in: UnevenRoundedRectangle(topLeadingRadius: 6, bottomLeadingRadius: 22, bottomTrailingRadius: 22, topTrailingRadius: 22, style: .continuous))
      .foregroundStyle(Palette.midnight)
    }
    .contentTransition(.opacity)
    .animation(.easeInOut, value: text)
  }
}

struct NextButton: View {
  let title: String; let action: () -> Void
  var body: some View { Button(title, action: action).buttonStyle(ChunkyPrimary()).transition(.move(edge: .bottom).combined(with: .opacity)) }
}

// MARK: Chapter 1 — Lemonade Stand
struct CompanyStage: View {
  let t: StageText; let next: () -> Void
  @State private var cups = 0
  @State private var pop = 0
  var done: Bool { cups >= 10 }
  var body: some View {
    Speech(text: (done ? t.done : t.ask) ?? "")
    VStack(spacing: 14) {
      Button { if !done { cups += 1; pop += 1 } } label: {
        ZStack(alignment: .topTrailing) {
          VStack(spacing: 6) { Glyph("🍋", size: 76, style: .halo); Text(done ? "Sold out!" : "Sell a cup").font(.kHeadline) }
            .frame(width: 140, height: 140)
            .background(RadialGradient(colors: [Color(hex: 0xFFF8C8), Color(hex: 0xFFD84D)], center: .init(x: 0.35, y: 0.3), startRadius: 4, endRadius: 120), in: Circle())
            .overlay(Circle().strokeBorder(Palette.midnight, lineWidth: 3))
            // The 3D edge is a circle drawn behind the face. A zero-blur .shadow on the whole stack also copied
            // the lemon and the "Sell a cup" text 7 pt lower, so the label looked doubled (seen on a phone, 0.11.0).
            .background(Circle().fill(Palette.midnight).offset(y: 7))
          Text("+$1").font(.kTitle).foregroundStyle(Palette.goodInk).keyframeAnimator(initialValue: 0.0, trigger: pop) { v, y in v.offset(y: -y * 60).opacity(pop == 0 ? 0 : 1 - y) } keyframes: { _ in LinearKeyframe(0, duration: 0); LinearKeyframe(1, duration: 0.8) }
        }
      }
      .buttonStyle(.plain).foregroundStyle(Palette.midnight)
      .disabled(done)
      .sensoryFeedback(.impact(flexibility: .soft), trigger: cups)
      .accessibilityLabel("Sell a cup of lemonade. \(cups) of 10 sold")
      HStack(spacing: 3) { ForEach(0..<10, id: \.self) { i in Glyph("🍋", size: 26, style: .plain).opacity(i < cups ? 1 : 0.2).scaleEffect(i < cups ? 1.1 : 0.9) } }.animation(.spring, value: cups)
    }.frame(maxWidth: .infinity)
    // Money in − lemons = profit, as one row of three tiles (a column of three rows didn't fit a phone).
    HStack(spacing: 6) {
      tile("Money in", Double(cups), Palette.lavender)
      tile("Lemons", -Double(cups) * 0.4, Palette.lavender)
      tile("Profit", Double(cups) * 0.6, Palette.mint)
    }
    if done { NextButton(title: "Next: cut it into shares", action: next) }
  }
  func tile(_ l: String, _ v: Double, _ bg: Color) -> some View {
    VStack(spacing: 2) {
      Text(l).font(.caption.weight(.bold)).lineLimit(1).minimumScaleFactor(0.8)
      Ticker(value: v, format: { ($0 < 0 ? "−$" : "$") + toFixed(abs($0), 2) }, font: .system(.headline, design: .rounded).weight(.heavy))
    }
    .frame(maxWidth: .infinity).padding(.vertical, 10)
    .foregroundStyle(Palette.midnight).background(bg, in: RoundedRectangle(cornerRadius: 14))
  }
}

struct SharesStage: View {
  let t: StageText; let next: () -> Void
  static let friends = [("🦊", "Fox"), ("🐢", "Turtle"), ("🦄", "Unicorn")]
  @State private var owners: [Int?] = [nil, nil, nil, nil]
  var sold: Int { owners.compactMap { $0 }.count }
  var body: some View {
    Speech(text: (sold >= 3 ? t.done : t.ask) ?? "")
    ZStack {
      ForEach(0..<4, id: \.self) { i in
        SliceShape(index: i).fill([Color(hex: 0xFFD84D), Color(hex: 0xFFB547), Color(hex: 0xFFE98A), Color(hex: 0xFFC970)][i])
          .overlay(SliceShape(index: i).stroke(Palette.midnight, lineWidth: 3))
          .scaleEffect(owners[i] != nil ? 0.94 : 1)
          .offset(x: owners[i] != nil ? cos(Double(i) * .pi / 2 - .pi / 4) * 10 : 0, y: owners[i] != nil ? sin(Double(i) * .pi / 2 - .pi / 4) * 10 : 0)
        Glyph(owners[i].map { Self.friends[$0].0 } ?? (i == 0 ? "🙋" : "🍋"), size: 28)
          .offset(x: cos(Double(i) * .pi / 2 - .pi / 4) * 30, y: sin(Double(i) * .pi / 2 - .pi / 4) * 30)
      }
    }
    .frame(width: 116, height: 116).frame(maxWidth: .infinity)
    .animation(.spring(response: 0.45, dampingFraction: 0.6), value: owners)
    .accessibilityElement().accessibilityLabel("Your stand, cut into 4 shares. You own \(4 - sold), friends own \(sold).")
    HStack(spacing: 10) {
      ForEach(Self.friends.indices, id: \.self) { f in
        let got = owners.contains(f)
        Button { if let i = owners.indices.first(where: { owners[$0] == nil && $0 > 0 }) { owners[i] = f } } label: {
          VStack(spacing: 2) { Glyph(Self.friends[f].0, size: 32); Text(Self.friends[f].1).font(.kHeadline); Text(got ? "owns a share!" : "pays $5").font(.caption) }
            .frame(maxWidth: .infinity, minHeight: 76).foregroundStyle(Palette.midnight)
            .background(got ? Palette.mint : Color.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 18))
        }.buttonStyle(.plain).disabled(got).sensoryFeedback(.success, trigger: got).accessibilityLabel("Sell \(Self.friends[f].1) a share for $5")
      }
    }
    Text("You own **\(4 - sold)** of 4 shares · you got **$\(sold * 5)**").font(.callout).frame(maxWidth: .infinity)
    if sold >= 3 { NextButton(title: "Next: watch the price", action: next) }
  }
}
struct SliceShape: Shape {
  let index: Int
  func path(in r: CGRect) -> Path {
    let c = CGPoint(x: r.midX, y: r.midY), rad = min(r.width, r.height) / 2 - 4
    var p = Path(); p.move(to: c)
    p.addArc(center: c, radius: rad, startAngle: .degrees(Double(index) * 90 - 90), endAngle: .degrees(Double(index) * 90), clockwise: false)
    p.closeSubpath(); return p
  }
}

struct PriceStage: View {
  let t: StageText; let next: () -> Void
  @State private var hist: [Double] = [5]
  @State private var up = false
  @State private var down = false
  var price: Double { hist.last ?? 5 }
  var body: some View {
    Speech(text: (up && down ? t.done : t.ask) ?? "")
    VStack(spacing: 4) {
      Text("Price of 1 share").font(.caption).foregroundStyle(.secondary)
      Ticker(value: price, format: { "$\(Int($0))" }, font: .system(size: 40, weight: .heavy, design: .rounded))
        .foregroundStyle(hist.count > 1 ? (price >= hist[hist.count - 2] ? Palette.good : Palette.bad) : Palette.ink)
    }.frame(maxWidth: .infinity)
    Chart {
      ForEach(Array(hist.enumerated()), id: \.offset) { i, v in LineMark(x: .value("t", i), y: .value("$", v)).interpolationMethod(.monotone).foregroundStyle(Palette.accentInk).lineStyle(.init(lineWidth: 4, lineCap: .round)) }
      RuleMark(y: .value("goal", 8)).foregroundStyle(Palette.line).lineStyle(.init(dash: [6, 6]))
      RuleMark(y: .value("goal", 4)).foregroundStyle(Palette.line).lineStyle(.init(dash: [6, 6]))
    }
    .chartYScale(domain: 0...12).chartXAxis(.hidden).chartYAxis(.hidden).frame(height: 56)
    .animation(.snappy, value: hist)
    HStack(spacing: 10) {
      Button { move(1) } label: { Label("Buyer", systemImage: "hand.raised.fill") }.buttonStyle(PrimaryButtonStyle(tint: Palette.good)).accessibilityLabel("A buyer wants it: price up")
      Button { move(-1) } label: { Label("Seller", systemImage: "hand.wave.fill") }.buttonStyle(PrimaryButtonStyle(tint: Palette.bad)).accessibilityLabel("A seller wants out: price down")
    }
    VStack(alignment: .leading, spacing: 2) {
      Label(t.up ?? "", systemImage: up ? "checkmark.circle.fill" : "circle").foregroundStyle(up ? Palette.good : Palette.ink)
      Label(t.down ?? "", systemImage: down ? "checkmark.circle.fill" : "circle").foregroundStyle(down ? Palette.good : Palette.ink)
    }.font(.kHeadline)
    if up && down { NextButton(title: "Next: report card day", action: next) }
  }
  func move(_ d: Double) {
    let n = max(1, min(12, price + d)); hist = Array((hist + [n]).suffix(20))
    if n >= 8 { up = true }; if up && n <= 4 { down = true }
  }
}

struct ReportStage: View {
  let t: StageText; let next: () -> Void
  @State private var pick: Pick?
  @State private var open = false
  var body: some View {
    Speech(text: open ? "\(t.result ?? "") \(t.done ?? "")" : t.ask ?? "")
    bar("🔮 Grown-ups' guess", "$6", Palette.sky)
    if pick == nil {
      HStack(spacing: 12) {
        Button("Beat 👍") { withAnimation(.spring) { pick = .beat } }.buttonStyle(PrimaryButtonStyle(tint: Palette.good))
        Button("Miss 👎") { withAnimation(.spring) { pick = .miss } }.buttonStyle(PrimaryButtonStyle(tint: Palette.bad))
      }
    } else if !open {
      Button { withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { open = true } } label: {
        VStack(spacing: 6) { Text("✉️").font(.system(size: 60)); Text(t.reveal ?? "Open").font(.kHeadline) }
          .frame(maxWidth: .infinity, minHeight: 140).moonGlass(radius: 22, weight: .thin)
          .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Palette.accent, style: .init(lineWidth: 2, dash: [8, 6])))
          .phaseAnimator([0, -3, 3, 0]) { v, a in v.rotationEffect(.degrees(a)) } animation: { _ in .easeInOut(duration: 0.12) }
      }.buttonStyle(.plain)
    } else {
      VStack(alignment: .leading, spacing: 10) {
        bar("Real profit", "$7", .white)
        Text("BEAT! \(pick == .beat ? "You guessed right!" : "Not this time, but now you know!")").font(.kTitle)
      }
      .padding(14).background(Palette.mint, in: RoundedRectangle(cornerRadius: 20)).transition(.scale.combined(with: .opacity))
      .sensoryFeedback(.success, trigger: open)
      NextButton(title: "Finish the chapter", action: next)
    }
  }
  func bar(_ l: String, _ v: String, _ bg: Color) -> some View {
    HStack { Text(l).font(.kHeadline); Spacer(); Text(v).font(.system(.title, design: .rounded).weight(.heavy)) }.foregroundStyle(Palette.midnight).padding(14).background(bg, in: RoundedRectangle(cornerRadius: 16))
  }
}

// MARK: Chapter 2 — Save or Grow?
struct GrowStage: View {
  let t: StageText; let tree: Bool; let next: () -> Void
  @Environment(AppModel.self) private var app
  @State private var years = 0
  var q: QuestChapters { app.content.questChapters! }
  var max: Int { tree ? q.TREE_YEARS.count : 5 }
  var body: some View {
    let jar = Chapters.jarPath(years, start: q.START, rate: q.JAR_RATE), treeP = Chapters.treePath(years, start: q.START, path: q.TREE_YEARS)
    let lastDown = tree && years > 0 && treeP[years] < treeP[years - 1]
    Speech(text: (years >= max ? t.done : years > 0 && tree ? (lastDown ? t.downYear : t.upYear) : t.ask) ?? "")
    HStack(spacing: 12) {
      box("🫙 Jar", (jar.last ?? 0), Palette.sky)
      if tree { box("🌳 Tree", (treeP.last ?? 0), lastDown ? Palette.peach : Palette.mint) }
    }
    Chart {
      ForEach(Array(jar.enumerated()), id: \.offset) { i, v in LineMark(x: .value("Year", i), y: .value("$", v), series: .value("k", "Jar")).foregroundStyle(Palette.accentInk) }
      if tree { ForEach(Array(treePart(treeP).enumerated()), id: \.offset) { i, v in LineMark(x: .value("Year", i), y: .value("$", v), series: .value("k", "Tree")).foregroundStyle(Palette.goodInk) } }
      PointMark(x: .value("Year", years), y: .value("$", (jar.last ?? 0))).foregroundStyle(Palette.accentInk).symbolSize(70)
      if tree { PointMark(x: .value("Year", years), y: .value("$", (treeP.last ?? 0))).foregroundStyle(Palette.goodInk).symbolSize(70) }
    }
    .chartYAxis(.hidden)
    .chartXAxis { AxisMarks(values: .stride(by: tree ? 5 : 1)) { v in AxisValueLabel { Text("Year \(v.as(Int.self) ?? 0)").font(.caption2) } } }
    .chartXScale(domain: 0...max).chartYScale(domain: .automatic(includesZero: false)).frame(height: 68)
    .chartLegend(.hidden).animation(.snappy, value: years)
    if years < max {
      Button(t.tap ?? "A year goes by") { years += 1 }.buttonStyle(ChunkyPrimary()).sensoryFeedback(lastDown ? .warning : .impact(flexibility: .soft), trigger: years)
    } else {
      if let r = t.remember { Text("\(Image(systemName: "lightbulb.fill")) \(r)").font(.callout).padding(12).background(Palette.moon.opacity(0.7), in: RoundedRectangle(cornerRadius: 14)) }
      NextButton(title: "Next →", action: next)
    }
  }
  func treePart(_ p: [Double]) -> [Double] { p }
  func box(_ l: String, _ v: Double, _ bg: Color) -> some View {
    VStack(spacing: 2) { Text(l).font(.kHeadline); Ticker(value: v, format: { "$" + toFixed($0, 2) }, font: .system(.title, design: .rounded).weight(.heavy)) }
      .foregroundStyle(Palette.midnight).frame(maxWidth: .infinity, minHeight: 56).background(bg, in: RoundedRectangle(cornerRadius: 18))
  }
}

struct ChooseStage: View {
  let t: StageText; let next: () -> Void
  @Environment(AppModel.self) private var app
  @State private var picks: [String: String] = [:]
  var items: [ChapterSortItem] { app.content.questChapters!.SORT_ITEMS }
  var body: some View {
    // A deck, one money goal at a time (a list of every goal was three screens tall on a phone). The
    // last answer's "why" stays up while you pick the next one.
    let all = items.allSatisfy { picks[$0.id] != nil }
    let cur = items.first { picks[$0.id] == nil }
    let last = items.last { picks[$0.id] != nil }
    Speech(text: (all ? t.done : t.ask) ?? "")
    if let it = cur {
      VStack(alignment: .leading, spacing: 10) {
        HStack(spacing: 10) {
          Glyph(it.emoji, size: 44); Text(it.text).font(.kHeadline).fixedSize(horizontal: false, vertical: true); Spacer(minLength: 0)
          Text("\(picks.count + 1)/\(items.count)").font(.caption.monospacedDigit().weight(.semibold)).foregroundStyle(.secondary)
        }
        HStack(spacing: 8) {
          Button { withAnimation(.spring) { picks[it.id] = "save" } } label: { Label("Save it", systemImage: "cylinder.fill") }.buttonStyle(PrimaryButtonStyle(tint: Hue.sky.color))
          Button { withAnimation(.spring) { picks[it.id] = "invest" } } label: { Label("Invest it", systemImage: "tree.fill") }.buttonStyle(PrimaryButtonStyle(tint: Palette.good))
        }
      }
      .padding(12).moonGlass(radius: 18, weight: .thin)
      .id(it.id).transition(.asymmetric(insertion: .scale(scale: 0.92).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
    }
    if let it = last, let p = picks[it.id] {
      Text((p == it.answer ? "Right! " : "Not quite: ") + it.why).font(.subheadline).fixedSize(horizontal: false, vertical: true)
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(p == it.answer ? Palette.mint : Palette.peach, in: RoundedRectangle(cornerRadius: 16)).foregroundStyle(Palette.midnight)
        .id("why-\(it.id)").transition(.opacity)
    }
    if all { NextButton(title: "Next", action: next) }
  }
}

struct ChecksStage: View {
  let t: StageText; let checks: [Check]; let next: () -> Void
  @State private var answers: [Int: Int] = [:]
  /// One question at a time (two stacked didn't fit a phone).
  @State private var shown = 0
  var body: some View {
    let i = min(shown, max(checks.count - 1, 0))
    Speech(text: answers.count == checks.count ? (t.done ?? "") : "Two quick questions. You've got this!")
    if checks.indices.contains(i) {
      CheckView(check: checks[i], seed: i + 2, picked: Binding(get: { answers[i] }, set: { answers[i] = $0 }))
        .id(i).transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
    }
    if answers[i] != nil && i + 1 < checks.count {
      NextButton(title: "Next question") { withAnimation(.spring) { shown = i + 1 } }
    } else if answers.count == checks.count {
      NextButton(title: "Finish the chapter", action: next)
    }
  }
}

// MARK: Chapter 3 — Your Slice Pays You
struct PayoutStage: View {
  let t: StageText; let next: () -> Void
  static let owners = [("😀", "You"), ("🐻", "Bear"), ("🐰", "Bunny"), ("🐸", "Frog")]
  @State private var paid: Set<Int> = []
  var body: some View {
    Speech(text: (paid.count == 4 ? t.done : t.ask) ?? "")
    HStack(spacing: 10) {
      ForEach(Self.owners.indices, id: \.self) { i in
        Button { _ = withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) { paid.insert(i) } } label: {
          VStack(spacing: 4) {
            Text(Self.owners[i].0).font(.system(size: 36))
            Text(Self.owners[i].1).font(.kHeadline)
            Text(paid.contains(i) ? "$1" : "tap").font(.caption.weight(.bold)).scaleEffect(paid.contains(i) ? 1.2 : 1)
          }
          .frame(maxWidth: .infinity, minHeight: 112).foregroundStyle(Palette.midnight)
          .background(paid.contains(i) ? Palette.moon : Color.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 18))
        }.buttonStyle(.plain).sensoryFeedback(.impact(weight: .light), trigger: paid.contains(i)).accessibilityLabel("Give \(Self.owners[i].1) a coin")
      }
    }
    if paid.count == 4 {
      if let r = t.remember { Text("\(Image(systemName: "lightbulb.fill")) \(r)").font(.callout).padding(12).background(Palette.moon.opacity(0.7), in: RoundedRectangle(cornerRadius: 14)) }
      NextButton(title: "Next →", action: next)
    }
  }
}

struct SnowballStage: View {
  let t: StageText; let next: () -> Void
  @Environment(AppModel.self) private var app
  @State private var season = 0
  var body: some View {
    let q = app.content.questChapters!
    let sb = Chapters.snowball(seasons: q.SEASONS, slices: q.SLICES, payPerSlice: q.PAY_PER_SLICE, slicePrice: q.SLICE_PRICE)
    Speech(text: (season >= q.SEASONS ? t.done : t.ask) ?? "")
    HStack(spacing: 12) {
      VStack(spacing: 4) { Text("Spend").font(.kHeadline); Ticker(value: sb.spend[season].spent, format: { "$\(Int($0)) spent" }, font: .kTitle); Text("\(Int(sb.spend[season].slices)) slices").font(.caption) }
        .frame(maxWidth: .infinity, minHeight: 88).background(Palette.peach, in: RoundedRectangle(cornerRadius: 18))
      VStack(spacing: 4) { Text("Replant").font(.kHeadline); Ticker(value: sb.replant[season].slices, format: { toFixed($0, 2) + " slices" }, font: .kTitle); Text("pays $\(toFixed(sb.replant[season].pay, 2))").font(.caption) }
        .frame(maxWidth: .infinity, minHeight: 88).background(Palette.mint, in: RoundedRectangle(cornerRadius: 18))
    }.foregroundStyle(Palette.midnight)
    if season < q.SEASONS { Button("⏭️ \(t.tap ?? "Next season") (\(season + 1) of \(q.SEASONS))") { season += 1 }.buttonStyle(ChunkyPrimary()).sensoryFeedback(.impact(flexibility: .soft), trigger: season) }
    else {
      if let r = t.remember { Text("\(Image(systemName: "lightbulb.fill")) \(r)").font(.callout).padding(12).background(Palette.moon.opacity(0.7), in: RoundedRectangle(cornerRadius: 14)) }
      NextButton(title: "Next →", action: next)
    }
  }
}

struct RealStage: View {
  let t: StageText; let next: () -> Void
  @Environment(AppModel.self) private var app
  @State private var guesses: [String: Bool] = [:]
  @State private var flipped: Set<String> = []
  @State private var at = 0
  var body: some View {
    // A deck: one company card at a time, guess, flip, then the next (a grid of every card was more than
    // two screens tall on a phone). A strip of dots shows the deck.
    let cards = app.content.questChapters?.DIV_CARDS ?? []
    let i = min(at, max(cards.count - 1, 0))
    Speech(text: (flipped.count == cards.count ? t.done : t.ask) ?? "")
    if cards.indices.contains(i) {
      let c = cards[i]
      let co = app.companies[c.s]
      let isFlipped = flipped.contains(c.s)
      VStack(spacing: 8) {
        HStack(spacing: 10) {
          Glyph(co?.emoji ?? "", size: 44); Text(co?.nick ?? c.s).font(.kTitle); Spacer(minLength: 0)
          Text("\(i + 1)/\(cards.count)").font(.caption.monospacedDigit().weight(.semibold)).foregroundStyle(.secondary)
        }
        if isFlipped {
          Text(c.pays ? "Pays dividends" : "Grows instead").font(.headline.weight(.heavy)).frame(maxWidth: .infinity, alignment: .leading)
          Text("\(co?.nick ?? c.s) \((c.pays ? t.yes : t.no) ?? "")").font(.callout).fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
          if let g = guesses[c.s] { Label(g == c.pays ? "You were right!" : "Now you know!", systemImage: g == c.pays ? "checkmark.circle.fill" : "lightbulb.fill").font(.callout.weight(.semibold)).frame(maxWidth: .infinity, alignment: .leading) }
        } else {
          HStack(spacing: 8) {
            Button { flip(c.s, true) } label: { Label("Pays", systemImage: "centsign.circle.fill") }.buttonStyle(PrimaryButtonStyle(tint: Hue.gold.color)).accessibilityLabel("\(co?.nick ?? c.s) pays dividends")
            Button { flip(c.s, false) } label: { Label("Grows", systemImage: "leaf.fill") }.buttonStyle(PrimaryButtonStyle(tint: Palette.good)).accessibilityLabel("\(co?.nick ?? c.s) grows instead")
          }.lineLimit(1)
        }
      }
      .padding(14).foregroundStyle(Palette.midnight)
      .background(isFlipped ? (c.pays ? Palette.moon : Palette.sky) : Color.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 18))
      .rotation3DEffect(.degrees(isFlipped ? 360 : 0), axis: (0, 1, 0))
      .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isFlipped)
      .id(c.s).transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
      HStack(spacing: 6) {
        ForEach(cards.indices, id: \.self) { k in Circle().fill(flipped.contains(cards[k].s) ? Palette.good : k == i ? Palette.accent : Palette.line).frame(width: 8, height: 8) }
      }
      .frame(maxWidth: .infinity).accessibilityHidden(true)
      if isFlipped && i + 1 < cards.count {
        NextButton(title: "Next company") { withAnimation(.spring) { at = i + 1 } }
      }
    }
    if !cards.isEmpty && flipped.count == cards.count { NextButton(title: "Next", action: next) }
  }
  func flip(_ s: String, _ g: Bool) { guesses[s] = g; flipped.insert(s) }
}
