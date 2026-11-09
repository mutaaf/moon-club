import SwiftUI
import MoonClubCore

/// Ask Luna: the kid-safe AI helper. Which brain answers (on-device Apple Intelligence, free Luna, or a
/// grown-up's own key after consent) is chosen in the grown-up corner; every answer passes LunaGuard.
/// The kid's typed words are never sent to a voice provider.
struct AskLunaView: View {
  @Environment(AppModel.self) private var app
  @State private var q = ""
  @State private var asked = ""
  @State private var answer = ""
  @State private var busy = false
  @State private var err: String?
  @State private var task: Task<Void, Never>?
  /// Earlier turns of this chat (only kept and sent when the brain has memory).
  @State private var turns: [LunaTurn] = []
  @FocusState private var focus: Bool

  static let chips = ["What is a share?", "Why do prices go up and down?", "What is a company's report card?", "What does Disney sell?", "Is the market sunny today?", "Why shouldn't I put all my eggs in one basket?"]

  var body: some View {
    let _ = Perf.body("AskLunaView")
    // iPhone Duo opened like a book: the questions on the left page, Luna's answer on the right.
    FoldPages {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        askPage
        answerPage
      }
      .padding(20).readable()
      .animation(.spring(response: 0.45, dampingFraction: 0.85), value: asked)
    }
    } first: {
      BookPage { askPage }
    } second: {
      BookPage {
        if asked.isEmpty { answerWaits }
        answerPage
      }
      .animation(.spring(response: 0.45, dampingFraction: 0.85), value: asked)
    }
    .scrollDismissesKeyboard(.interactively)
    .background(AuroraField(surface: .luna))
    .onDisappear { task?.cancel() }
  }

  /// The right page before the first question: Luna, waiting to answer.
  private var answerWaits: some View {
    VStack(spacing: 14) {
      Luna(size: 96, wave: true)
      Text("Tap a question, and Luna answers right here.").font(.kRead).multilineTextAlignment(.center).foregroundStyle(Palette.ink2)
    }
    .frame(maxWidth: .infinity).padding(.vertical, 40)
  }

  /// Who Luna is, the question chips and the typed question.
  @ViewBuilder private var askPage: some View {
        Hero(eyebrow: "Your money helper", title: "Ask", accent: "Luna")
        HStack { BrainBadge(); Spacer()
          if !turns.isEmpty { Button { turns = []; asked = ""; answer = "" } label: { Label("New chat", systemImage: "sparkles") }.font(.subheadline.weight(.semibold)).accessibilityIdentifier("new-chat") }
        }
        Text(app.brainCaps.memoryTurns > 0 ? "Luna knows about money, companies and the market, and she remembers this chat. Ask a follow-up!" : "Luna knows about money, companies and the market. Tap a question!").font(.kRead)
        FlowLayout(spacing: 8) {
          ForEach(Self.chips, id: \.self) { c in
            Button(c) { ask(c, typed: false) }.buttonStyle(SoftButtonStyle()).disabled(busy)
          }
        }
        VStack(alignment: .leading, spacing: 8) {
          Text("Or type your own money question").font(.caption).foregroundStyle(.secondary)
          HStack(spacing: 10) {
            TextField("Why do companies sell shares?", text: $q)
              .textInputAutocapitalization(.sentences).autocorrectionDisabled(false).submitLabel(.send)
              .focused($focus).onSubmit { ask(q, typed: true) }
              .padding(.horizontal, 16).frame(minHeight: 52).moonGlass(Capsule(), interactive: true, weight: .thin)
              .onChange(of: q) { _, v in if v.count > 200 { q = String(v.prefix(200)) } }
            Button("Ask") { ask(q, typed: true) }.buttonStyle(PrimaryButtonStyle()).frame(width: 90).disabled(busy || q.trimmingCharacters(in: .whitespaces).isEmpty)
          }
          Text("Please don't type your name, school or where you live.").font(.caption).foregroundStyle(.secondary)
        }
  }

  /// The chat so far, Luna's answer and the reminder that she can make mistakes.
  @ViewBuilder private var answerPage: some View {
        if app.brainCaps.memoryTurns > 0, turns.count > 2 {
          VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(turns.dropLast(2).suffix(6).enumerated()), id: \.offset) { _, t in
              Text(t.role == .kid ? "You: \(t.text)" : "Luna: \(t.text)").font(.callout).foregroundStyle(t.role == .kid ? Palette.ink2 : .primary).lineLimit(3)
            }
          }.padding(14).moonGlass(radius: 18, weight: .thin)
        }
        if !asked.isEmpty {
          Card {
            Text("You asked: **\(asked)**").font(.subheadline).foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: 12) {
              Luna(size: 44)
              VStack(alignment: .leading, spacing: 10) {
                if !answer.isEmpty { Text(LocalizedStringKey(answer)).font(.kRead).textSelection(.enabled).animation(.easeOut(duration: 0.15), value: answer) }
                else if err == nil { HStack(spacing: 6) { Text("Luna is thinking"); ProgressView() }.foregroundStyle(.secondary) }
                if let err { Text(err).foregroundStyle(Palette.bad) }
                if !answer.isEmpty && !busy { ReadAloud(source: .luna(answer: answer, kidTyped: typedQuestion), label: "Read Luna's answer") }
              }
            }
          }
          .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        Text("Luna is a computer helper, so she can make mistakes. For real money questions, ask a grown-up you trust.").font(.footnote).foregroundStyle(.secondary).frame(maxWidth: .infinity)
  }

  @State private var typedQuestion: String?

  func ask(_ question: String, typed: Bool) {
    let text = String(question.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200))
    guard !text.isEmpty, !busy else { return }
    task?.cancel(); focus = false
    asked = text; answer = ""; err = nil; busy = true; q = ""
    app.mutate { $0.askLuna(today: app.today) } // a count for the Curious badge, never the words
    typedQuestion = typed ? text : nil
    let w = app.mood.map(weatherFor)
    var next: [String: EarningsEvent] = [:]
    for e in app.upcoming where next[e.s] == nil { next[e.s] = e }
    let ctx = LunaContext(weather: w.map { "\($0.title): \($0.line)" }, companies: app.content.companies.map { k in
      LunaContext.Co(s: k.s, nick: k.nick, hook: k.hook, when: next[k.s].map { kidWhen($0.d, $0.h, today: app.today) })
    })
    task = Task {
      app.refreshBrain()
      let history = app.brainCaps.memoryTurns > 0 ? turns : []
      do {
        for try await snap in app.luna.ask(text, context: ctx, history: history) { answer = snap }
        if app.brainCaps.memoryTurns > 0 { turns += [LunaTurn(.kid, text), LunaTurn(.luna, answer)] }
      }
      catch { err = (error as? KidError)?.message ?? KidError.resting.message }
      busy = false
    }
  }
}

/// Which brain is answering: a moon with sparkles (on this device), a key (a grown-up's key), or the moon (free).
struct BrainBadge: View {
  @Environment(AppModel.self) private var app
  var body: some View {
    Label(app.brain.badge, systemImage: app.brain.symbol)
      .font(.caption.weight(.semibold))
      .padding(.horizontal, 10).padding(.vertical, 5)
      .background(Palette.lavender.opacity(0.8), in: Capsule())
      .foregroundStyle(Palette.midnight)
      .accessibilityIdentifier("brain-badge")
      .accessibilityLabel("Luna's brain: \(app.brain.badge)")
  }
}

/// "Explain more" on story and report cards: a tap-generated question (never kid-typed), answered by an
/// on-device or grown-up-key brain. Hidden for the free brain.
struct ExplainMore: View {
  let question: String
  @Environment(AppModel.self) private var app
  @State private var open = false
  var body: some View {
    if app.brainCaps.deepExplain {
      Button { open = true } label: {
        Label("Explain more", systemImage: app.brain.symbol).font(.subheadline.weight(.semibold))
          .padding(.horizontal, 14).frame(minHeight: 44)
          .moonGlass(Capsule(), interactive: true, weight: .thin)
      }
      .buttonStyle(.plain)
      .sheet(isPresented: $open) { ExplainSheet(question: question).presentationDetents([.medium, .large]) }
    }
  }
}

struct ExplainSheet: View {
  let question: String
  @Environment(AppModel.self) private var app
  @State private var answer = ""
  @State private var err: String?
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        HStack { Luna(size: 44); BrainBadge(); Spacer() }
        if !answer.isEmpty { Text(LocalizedStringKey(answer)).font(.kRead).animation(.easeOut(duration: 0.15), value: answer) }
        else if err == nil { HStack(spacing: 6) { Text("Luna is thinking"); ProgressView() }.foregroundStyle(.secondary) }
        if let err { Text(err).foregroundStyle(Palette.bad) }
        if !answer.isEmpty { ReadAloud(source: .luna(answer: answer, kidTyped: nil), label: "Read it to me") }
      }.padding(24)
    }
    .task {
      let ctx = LunaContext(weather: app.mood.map { let w = weatherFor($0); return "\(w.title): \(w.line)" }, companies: app.content.companies.map { LunaContext.Co(s: $0.s, nick: $0.nick, hook: $0.hook, when: nil) })
      do { for try await s in app.luna.ask(question, context: ctx, history: []) { answer = s } }
      catch { err = (error as? KidError)?.message ?? KidError.resting.message }
    }
  }
}
