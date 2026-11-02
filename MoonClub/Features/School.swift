import SwiftUI
import MoonClubCore

/// Moon School: units → one-minute micro-lessons (say / check / sort steps).
struct SchoolView: View {
  @Environment(AppModel.self) private var app
  @Namespace private var zoom
  @State private var deep: Lesson?

  var body: some View {
    let done = Set(app.state.lessons)
    let next = app.content.lessons.first { !done.contains($0.id) }
    ScrollView {
      VStack(alignment: .leading, spacing: 22) {
        Hero(eyebrow: "\(done.count) of \(app.content.lessons.count) done · about a minute each", title: "Moon", accent: "School", emoji: "🎓")
        StartHere()
        if let next {
          NavigationLink(value: next) {
            HStack(spacing: 14) {
              Text(next.emoji).font(.system(size: 34)).frame(width: 60, height: 60).background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 18))
              VStack(alignment: .leading, spacing: 2) {
                Text("UP NEXT · \(app.content.unit(of: next)?.title.uppercased() ?? "")").font(.kEyebrow).opacity(0.8)
                Text(next.title).font(.kTitle)
                Text("\(next.steps.count) tiny steps").font(.caption).opacity(0.8)
              }
              Spacer(); Image(systemName: "arrow.right").font(.title2.weight(.bold))
            }
            .foregroundStyle(.white).padding(18)
            .background(Palette.accent, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .shadow(color: Palette.accent.opacity(0.35), radius: 18, y: 10)
            .modifier(ZoomSource(id: next.id, ns: zoom))
          }.buttonStyle(.plain)
        }
        ForEach(app.content.units) { u in
          let ls = app.content.lessons.filter { $0.unit == u.id }
          let n = ls.filter { done.contains($0.id) }.count
          VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
              Text(u.emoji).font(.system(size: 30))
              VStack(alignment: .leading) { Text(u.title).font(.kTitle); Text(u.blurb).font(.caption).foregroundStyle(.secondary) }
              Spacer()
              Text(n == ls.count ? "🌕" : "\(n)/\(ls.count)").font(n == ls.count ? .title2 : .caption.monospaced()).padding(.horizontal, 10).padding(.vertical, 4).background(.thinMaterial, in: Capsule())
            }
            ForEach(ls) { l in
              NavigationLink(value: l) {
                HStack(spacing: 12) {
                  Text(l.emoji).font(.system(size: 26)).frame(width: 44)
                  VStack(alignment: .leading, spacing: 2) { Text(l.title).font(.kHeadline).foregroundStyle(Palette.ink); Text("\(l.steps.count) steps · 1 min").font(.caption).foregroundStyle(.secondary) }
                  Spacer()
                  MoonPhase(phase: done.contains(l.id) ? 4 : 0, size: 24)
                }
                .padding(14).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .modifier(ZoomSource(id: l.id, ns: zoom))
              }
              .buttonStyle(.plain)
              .accessibilityLabel("\(l.title). \(done.contains(l.id) ? "Finished" : "Not started")")
            }
          }
        }
        BadgesGrid()
      }
      .padding(20).readable()
    }
    .background(AuroraField(surface: .school))
    .navigationDestination(for: Lesson.self) { l in LessonPlayer(lesson: l).modifier(ZoomDestination(id: l.id, ns: zoom)) }
    .navigationDestination(item: $deep) { LessonPlayer(lesson: $0) }
    .onAppear {
      let a = ProcessInfo.processInfo.arguments
      if deep == nil, let i = a.firstIndex(of: "-lesson"), i + 1 < a.count { deep = app.content.lessons.first { $0.id == a[i + 1] } }
    }
  }
}

/// iOS 18's zoom transition from a lesson card into the player; plain push on iOS 17.
struct ZoomSource: ViewModifier {
  let id: String; let ns: Namespace.ID
  func body(content: Content) -> some View { if #available(iOS 18, *) { content.matchedTransitionSource(id: id, in: ns) } else { content } }
}
struct ZoomDestination: ViewModifier {
  let id: String; let ns: Namespace.ID
  func body(content: Content) -> some View { if #available(iOS 18, *) { content.navigationTransition(.zoom(sourceID: id, in: ns)) } else { content } }
}

struct BadgesGrid: View {
  @Environment(AppModel.self) private var app
  var body: some View {
    let have = app.badges
    VStack(alignment: .leading, spacing: 12) {
      Text("Your moon badges").font(.kTitle)
      // An even number of columns whenever the fold crosses the grid, so no badge sits on the crease.
      FoldColumns(minimum: 100) {
        ForEach(app.content.badges) { b in
          VStack(spacing: 6) {
            MoonPhase(phase: b.phase, size: 48, dim: !have.contains(b.id))
            Text(b.name).font(.caption.weight(.bold)).multilineTextAlignment(.center)
            Text(have.contains(b.id) ? b.why : "Not yet!").font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center).lineLimit(3)
          }
          .frame(maxWidth: .infinity, minHeight: 130).padding(10)
          .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
          .accessibilityElement(children: .combine)
        }
      }
    }
  }
}

/// One step at a time, with spring transitions, step dots, read-aloud and a celebration at the end.
struct LessonPlayer: View {
  let lesson: Lesson
  @Environment(AppModel.self) private var app
  @Environment(\.dismiss) private var dismiss
  @Environment(\.accessibilityReduceMotion) private var rm
  @State private var step = 0
  @State private var answers: [Int: Int] = [:]
  @State private var sorts: [Int: [Int: Int]] = [:]
  @State private var burst = 0

  var done: Bool { step >= lesson.steps.count }
  var ready: Bool {
    guard !done else { return true }
    switch lesson.steps[step] {
    case .say: return true
    case .check: return answers[step] != nil
    case let .sort(_, _, items, _): return items.indices.allSatisfy { sorts[step]?[$0] != nil }
    }
  }

  @Environment(DuoModel.self) private var duo: DuoModel?
  /// iPhone Duo: closing the phone on a finished lesson tucks Luna in for the night.
  @State private var tucked = false

  var body: some View {
    VStack(spacing: 18) {
      HStack(spacing: 5) {
        ForEach(lesson.steps.indices, id: \.self) { i in
          Capsule().fill(i < step ? (isQuiz(i) ? Palette.good : Palette.accent) : i == step ? Palette.accent.opacity(0.4) : Palette.line).frame(height: 6)
        }
      }
      .animation(.snappy, value: step)
      .accessibilityLabel(done ? "Finished" : "Step \(step + 1) of \(lesson.steps.count)")

      // One card on a phone; opened wide (iPhone Duo, iPad) it's a storybook spread — the story on the
      // left page, the play on the right, never across the fold.
      Storybook(minPage: 280, fill: true) {
        card(art: true)
      } first: {
        storyPage
      } second: {
        card(art: false)
      }

      HStack(spacing: 12) {
        if done {
          Button("All lessons") { dismiss() }.buttonStyle(SoftButtonStyle())
          if let next = nextLesson { NavigationLink("Next lesson →", value: next).buttonStyle(PrimaryButtonStyle()) }
        } else {
          Button("← Back") { go(-1) }.buttonStyle(SoftButtonStyle()).disabled(step == 0)
          Button(step == lesson.steps.count - 1 ? "Finish 🌕" : "Next →") { go(1) }.buttonStyle(PrimaryButtonStyle()).disabled(!ready)
        }
      }
    }
    .padding(20)
    .readable(720)
    .background(AuroraField(surface: .school))
    .navigationTitle(lesson.title)
    .navigationBarTitleDisplayMode(.inline)
    .sensoryFeedback(.selection, trigger: step)
    .modifier(TaskToolbar())
    .onChange(of: duo?.closedTick) { _, _ in if done { withAnimation(rm ? nil : .spring) { tucked = true } } }
    .sensoryFeedback(.impact(weight: .light, intensity: 0.7), trigger: tucked)
  }

  /// The single card (phone) or the right-hand "play" page (spread). `art` keeps the big picture on the
  /// card when there's no left page to hold it.
  private func card(art: Bool) -> some View {
    ZStack {
      if done {
        VStack(spacing: 14) {
          if art { doneArt }
          Text(tucked ? "Goodnight, Luna! 💤" : "Lesson done! 🎉").font(.kHero).multilineTextAlignment(.center)
          Text(tucked ? "Luna is tucked in. See you tomorrow for the next one!" : "You filled a moon and earned 10 points.").font(.kRead).multilineTextAlignment(.center)
        }
        .transition(.scale.combined(with: .opacity))
      } else {
        stepView(lesson.steps[step], art: art).id(step)
          .transition(rm ? .opacity : .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(24)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
    .overlay(Celebrate(trigger: burst))
  }

  @ViewBuilder private var doneArt: some View {
    if tucked { SleepyLuna(size: 110) } else { MoonPhase(phase: 4, size: 110) }
  }

  /// The left page of the spread: the picture for a "say" step, or — on a quiz step — the last thing
  /// Luna said, so the answer is right there on the facing page.
  private var storyPage: some View {
    VStack(spacing: 18) {
      Spacer(minLength: 0)
      if done {
        doneArt
      } else if case let .say(emoji, _) = lesson.steps[step] {
        Text(emoji).font(.system(size: 132)).accessibilityHidden(true)
          .phaseAnimator([0.92, 1.0]) { v, p in v.scaleEffect(rm ? 1 : p) } animation: { _ in .spring(response: 0.6, dampingFraction: 0.55) }
        Luna(size: 64, wave: true)
      } else if let said = lastSay {
        Eyebrow(text: "Luna said")
        Text(said.emoji).font(.system(size: 72)).accessibilityHidden(true)
        Text(said.text).font(.kRead).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
      } else {
        Luna(size: 96, wave: true)
      }
      Spacer(minLength: 0)
      Text(done ? lesson.title : "Page \(step + 1) of \(lesson.steps.count)").font(.kEyebrow).foregroundStyle(.secondary)
    }
    .id(done ? -1 : step)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(24)
    .background(Palette.moon.opacity(0.35), in: RoundedRectangle(cornerRadius: 32, style: .continuous))
    .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).strokeBorder(Palette.line.opacity(0.6), lineWidth: 0.5))
    .transition(.opacity)
  }

  private var lastSay: (emoji: String, text: String)? {
    for i in stride(from: min(step, lesson.steps.count) - 1, through: 0, by: -1) {
      if case let .say(e, t) = lesson.steps[i] { return (e, t) }
    }
    return nil
  }

  var nextLesson: Lesson? { let ls = app.content.lessons; return ls.firstIndex(of: lesson).flatMap { $0 + 1 < ls.count ? ls[$0 + 1] : nil } }
  func isQuiz(_ i: Int) -> Bool { if case .say = lesson.steps[i] { return false }; return true }
  func go(_ d: Int) {
    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { step = max(0, step + d) }
    if step >= lesson.steps.count { app.mutate { $0.finishLesson(lesson.id, today: app.today) }; burst += 1 }
  }

  @ViewBuilder func stepView(_ s: Step, art: Bool = true) -> some View {
    switch s {
    case let .say(emoji, text):
      VStack(spacing: 22) {
        if art {
          Text(emoji).font(.system(size: 96)).accessibilityHidden(true)
            .phaseAnimator([0.9, 1.0]) { v, p in v.scaleEffect(rm ? 1 : p) } animation: { _ in .spring(response: 0.5, dampingFraction: 0.55) }
        }
        Text(text).font(.system(.title2, design: .rounded).weight(.semibold)).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
        ReadAloud(source: .appCopy(text))
      }
    case let .check(c):
      ScrollView { CheckView(check: c, seed: step + lesson.id.count, picked: Binding(get: { answers[step] }, set: { answers[step] = $0 })) }
    case let .sort(q, buckets, items, why):
      ScrollView { SortView(q: q, buckets: buckets, items: items, why: why, picks: Binding(get: { sorts[step] ?? [:] }, set: { sorts[step] = $0 })) }
    }
  }
}

/// A quick check: shuffled options (stable per seed), gentle feedback, read-aloud.
struct CheckView: View {
  let check: Check
  var seed: Int
  @Binding var picked: Int?
  var standalone = false
  @State private var local: Int?
  var chosen: Int? { standalone ? local : picked }
  var body: some View {
    let opts = check.options.enumerated().map { ($0.offset, $0.element) }
    let k = (seed * 7 + check.q.count) % max(1, opts.count)
    let shuffled = Array(opts[k...] + opts[..<k])
    VStack(alignment: .leading, spacing: 14) {
      if !standalone { Eyebrow(text: "Quick check") }
      Text(check.q).font(.kTitle).fixedSize(horizontal: false, vertical: true)
      ForEach(shuffled, id: \.0) { i, text in
        let isPick = chosen == i, right = i == check.answer
        Button { withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { if standalone { local = i } else { picked = i } } } label: {
          HStack { Text(text).font(.kHeadline).multilineTextAlignment(.leading); Spacer(); if isPick { Image(systemName: right ? "checkmark.circle.fill" : "arrow.uturn.left.circle.fill") } }
            .padding(16).frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .foregroundStyle(Palette.midnight)
            .background(isPick ? (right ? Palette.mint : Palette.peach) : Color.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(isPick ? (right ? Palette.good : Palette.bad).opacity(0.5) : Palette.line, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isPick ? .isSelected : [])
        .sensoryFeedback(trigger: chosen) { _, n in n == i ? (right ? .success : .warning) : nil }
      }
      if let c = chosen { Text((c == check.answer ? "🎉 Yes! " : "Good try! ") + check.why).font(.body).transition(.opacity) }
      ReadAloud(source: .appCopy("\(check.q) \(check.options.joined(separator: ". Or, ")).") )
    }
  }
}

/// A two-bucket sorting game with gentle corrections.
struct SortView: View {
  let q: String; let buckets: [String]; let items: [SortItem]; let why: String
  @Binding var picks: [Int: Int]
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Eyebrow(text: "Sorting game")
      Text(q).font(.kTitle)
      ForEach(items.indices, id: \.self) { i in
        let it = items[i], p = picks[i]
        VStack(alignment: .leading, spacing: 8) {
          HStack { Text(it.emoji); Text(it.text).font(.kHeadline); Spacer(); if let p { Text(p == it.b ? "✅" : "↩︎ \(buckets[it.b])").font(.subheadline.weight(.semibold)) } }
          HStack(spacing: 8) {
            ForEach(buckets.indices, id: \.self) { b in
              Button(buckets[b]) { withAnimation(.spring(response: 0.3)) { picks[i] = b } }.buttonStyle(SoftButtonStyle(selected: p == b))
            }
          }
          .accessibilityElement(children: .contain).accessibilityLabel(it.text)
        }
        .padding(12)
        .background(p == nil ? AnyShapeStyle(.thinMaterial) : AnyShapeStyle(p == it.b ? Palette.mint : Palette.peach), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .sensoryFeedback(trigger: p) { _, n in n == nil ? nil : n == it.b ? .success : .warning }
      }
      if items.indices.allSatisfy({ picks[$0] != nil }) {
        let right = items.indices.filter { picks[$0] == items[$0].b }.count
        Text((right == items.count ? "🎉 All right! " : "\(right) of \(items.count) right. ") + why).font(.body)
      }
      ReadAloud(source: .appCopy("\(q) \(items.map(\.text).joined(separator: ". "))."))
    }
  }
}
