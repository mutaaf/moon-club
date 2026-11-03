import SwiftUI
import MoonClubCore

// The curriculum overhaul's app pieces (docs/CURRICULUM.md, docs/PACKS.md). Pure rules live in MoonClubCore:
// Review.swift (spaced review), Why.swift ("Why did it move?"), Coach.swift (Guess / Piggy courses), Packs.swift.

// MARK: Review stop (a map node): spaced retrieval of missed and older questions

struct ReviewStopView: View {
  let node: WorldNode
  let region: Region
  let regions: [Region]
  let onFinish: (Int) -> Void
  @Environment(AppModel.self) private var app
  @Environment(\.dismiss) private var dismiss
  /// Frozen when the stop opens: answering changes what's due, and the run must not shift under the kid.
  @State private var items: [ReviewItem]?

  var body: some View {
    Group {
      if let items, !items.isEmpty {
        GameShell(node: node, rounds: items.count, intro: "Questions you met before, mixed up. Each one you get makes it stick!",
                  timed: false, onFinish: onFinish) { i, answer, answered in
          ReviewRound(check: items[i].check, seed: i, answer: { r in
            if answered == nil { record(items[i], r.right) }
            answer(r)
          }, answered: answered)
        }
      } else if items != nil {
        caughtUp
      } else {
        Color.clear
      }
    }
    .onAppear {
      guard items == nil else { return }
      items = Review.due(app.state, app.content, today: app.today, lessons: World.reviewScope(region, regions, app.content))
    }
  }

  private func record(_ it: ReviewItem, _ right: Bool) {
    guard let k = Int(it.id.split(separator: "#").last ?? "") else { return }
    app.answered(lesson: it.lesson, step: k, right: right, review: true)
  }

  private var caughtUp: some View {
    VStack(spacing: 16) {
      Spacer()
      Glyph("🔁", size: 96, style: .halo)
      Text("All caught up!").font(.kHero).lineLimit(2).minimumScaleFactor(0.6).multilineTextAlignment(.center)
      Text("Questions you missed, and lessons from a few days ago, come back here. Play a lesson, then visit tomorrow.")
        .font(.kRead).multilineTextAlignment(.center).foregroundStyle(Palette.ink2)
      Spacer()
      Button("Back to the map") { dismiss() }.buttonStyle(ChunkyPrimary())
    }
    .padding(24).readable(560)
    .background(AuroraField(surface: .school))
    .playChrome()
  }
}

// MARK: "Why did it move?" card (Story, Guess, Piggy)

struct WhyCard: View {
  let symbol: String
  var range: WhyRange = .day
  var title = "Why did it move?"
  @Environment(AppModel.self) private var app
  @State private var picked: WhyRange?
  @State private var input: WhyInput?
  @State private var failed = false

  var body: some View {
    let r = picked ?? range
    let co = app.company(symbol)
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Eyebrow(text: title)
        Spacer()
        Picker("How long", selection: Binding(get: { r }, set: { picked = $0 })) { Text("Day").tag(WhyRange.day); Text("Week").tag(WhyRange.week) }
          .pickerStyle(.segmented).frame(maxWidth: 150)
      }
      if let input {
        let why = Why.explain(WhyInput(s: input.s, nick: co.nick, range: input.range, move: input.move, market: input.market, sector: input.sector, report: input.report, dividend: input.dividend, normal: input.normal, asOf: input.asOf), today: app.today)
        HStack(alignment: .top, spacing: 12) {
          Glyph(co.emoji, size: 44)
          VStack(alignment: .leading, spacing: 2) { Text(why.headline).font(.kHeadline); Text(why.sizeLine).font(.callout).foregroundStyle(Palette.ink2) }
        }
        ForEach(Array(why.causes.enumerated()), id: \.element.id) { i, c in
          HStack(alignment: .top, spacing: 10) {
            Glyph(Self.art[c.id] ?? "🔍", size: 32)
            VStack(alignment: .leading, spacing: 2) {
              Text(i == 0 && c.id != "unknown" ? "Biggest clue: \(c.title)" : c.title).font(.subheadline.weight(.bold))
              Text(c.line).font(.callout).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
          }
          .padding(12)
          .background(i == 0 ? Palette.moon.opacity(0.55) : Color.clear, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
          .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Palette.line, lineWidth: 1))
          .accessibilityElement(children: .combine)
        }
        Text(why.honest).font(.caption).foregroundStyle(.secondary)
        HStack { ReadAloud(source: .appCopy(([why.headline] + why.causes.map { "\($0.title). \($0.line)" } + [why.honest]).joined(separator: " "))); Spacer() }
      } else if failed {
        Text("We can't see \(co.nick)'s clues right now. Try again in a little while!").font(.callout).foregroundStyle(.secondary)
      } else {
        RoundedRectangle(cornerRadius: 16).fill(.thinMaterial).frame(height: 120).overlay(ProgressView())
      }
    }
    .task(id: "\(symbol)|\(r.rawValue)") {
      failed = false
      do { input = try await app.market.why(symbol, range: r); failed = input == nil } catch { input = nil; failed = true }
    }
  }
  static let art: [String: String] = ["report": "📝", "market": "🌍", "company": "🏪", "sector": "👥", "dividend": "🍰", "wiggle": "〰️", "unknown": "🤷"]
}

// MARK: Courses: the next lesson on the Guess / Piggy ladder, played in place

struct CourseCard: View {
  enum Kind { case guess, piggy }
  let kind: Kind
  @Environment(AppModel.self) private var app
  @State private var lesson: Lesson?

  var body: some View {
    let ladder = kind == .guess ? app.content.guessCourse?.ladder ?? [] : app.content.piggyCourse?.ladder ?? []
    if let next = Coach.next(ladder, done: app.state.lessons), let l = app.content.lessons.first(where: { $0.id == next.id }) {
      Button { lesson = l } label: {
        HStack(spacing: 14) {
          Glyph(l.emoji, size: 50)
          VStack(alignment: .leading, spacing: 3) {
            Text("\(kind == .guess ? "GUESS SCHOOL" : "PIGGY SCHOOL") · STEP \(next.index + 1) OF \(next.of)").font(.kEyebrow).foregroundStyle(Palette.accent)
            Text(l.title).font(.kTitle).foregroundStyle(Palette.ink)
            if kind == .guess, let tip = app.content.guessCourse?.tips[l.id] { Text(tip).font(.callout).foregroundStyle(Palette.ink2).fixedSize(horizontal: false, vertical: true) }
          }
          Spacer(minLength: 0)
          Image(systemName: "play.circle.fill").font(.title).foregroundStyle(Palette.accent)
        }
        .padding(16)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Palette.line, lineWidth: 1))
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Next lesson: \(l.title). Step \(next.index + 1) of \(next.of).")
      .fullScreenCover(item: $lesson) { l in NavigationStack { LessonPlayer(lesson: l) } }
    }
  }
}

/// Luna's one piggy-bank tip, from the Piggy course (big moves, too many peeks, baskets, time).
struct PiggyCoachTip: View {
  let piggy: Piggy
  let value: Double?
  let peeks: Int
  @Environment(AppModel.self) private var app
  var body: some View {
    if let course = app.content.piggyCourse {
      let tip = Coach.piggyTip(course, .init(holdings: piggy.holdings.count, started: piggy.started, today: app.today, value: value ?? app.content.startCoins, start: app.content.startCoins, peeks: peeks))
      Text(tip.text).font(.callout).fixedSize(horizontal: false, vertical: true)
    } else {
      Text(basketTip(piggy.holdings.count)).font(.callout)
    }
  }
}

// MARK: Grown-up corner: lesson packs + what your child is learning

struct PackSettings: View {
  @Environment(AppModel.self) private var app
  var body: some View {
    let core = app.baseContent.pack
    VStack(alignment: .leading, spacing: 4) {
      Text(core?.title ?? "Moon Club Core").font(.headline)
      Text("Always on · v\(core?.version ?? "1") · \(app.baseContent.lessons.count) lessons, ages \(core?.ages.min ?? 6)–\(core?.ages.max ?? 11)").font(.caption).foregroundStyle(.secondary)
      Text("Reviewed by \(reviewers(core?.reviewers ?? [])).").font(.caption).foregroundStyle(.secondary)
    }
    ForEach(app.packs) { p in
      Toggle(isOn: Binding(get: { app.packOn(p.id) }, set: { app.setPack(p.id, on: $0) })) {
        VStack(alignment: .leading, spacing: 3) {
          Text(p.title).font(.headline)
          if let badge = p.hostBadge, let c = p.creator { Text("\(badge): \(c.name). \(c.bio)").font(.caption) }
          Text("Adds \(p.lessonCount) lessons and a new island on the map. Reviewed by \(reviewers(p.reviewers)).").font(.caption).foregroundStyle(.secondary)
        }
      }
    }
  }
  func reviewers(_ rs: [PackPerson]) -> String {
    let names = rs.filter { !($0.signedOff ?? "").isEmpty }.map { "\($0.name) (\($0.role == "teacher" ? "teacher" : $0.role == "markets" ? "markets expert" : "grown-up"))" }
    return names.isEmpty ? "nobody yet" : ListFormatter.localizedString(byJoining: names)
  }
}

/// Mastery per unit, worked out on this device from finished lessons and review answers. Nothing is sent.
struct LearningReport: View {
  @Environment(AppModel.self) private var app
  var body: some View {
    let tracks = app.baseContent.pack?.tracks ?? []
    ForEach(app.content.units) { u in
      let m = Review.mastery(u.id, app.state, app.content)
      HStack {
        Glyph(u.emoji, size: 30)
        VStack(alignment: .leading, spacing: 1) {
          Text(u.title).font(.subheadline.weight(.semibold))
          if let t = tracks.first(where: { $0.id == u.track }) { Text(t.title).font(.caption2).foregroundStyle(.secondary) }
        }
        Spacer()
        Text(m.label).font(.caption.weight(.semibold))
          .padding(.horizontal, 8).padding(.vertical, 3)
          .background(m == .mastered ? Palette.mint : m == .practicing ? Palette.moon : m == .learning ? Palette.sky : Palette.line.opacity(0.4), in: Capsule())
      }
      .accessibilityElement(children: .combine)
    }
    let due = Review.due(app.state, app.content, today: app.today, limit: 99).count
    Text(due == 0 ? "No questions waiting at a Review stop." : "\(due) question\(due == 1 ? "" : "s") waiting at a Review stop on the map.").font(.caption).foregroundStyle(.secondary)
  }
}
