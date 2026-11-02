import SwiftUI
import MoonClubCore

/// Ask Luna: the free, kid-safe AI helper. Never sends a key, never asks for personal details,
/// answers cached on device. The kid's typed words are never sent to a voice provider.
struct AskLunaView: View {
  @Environment(AppModel.self) private var app
  @State private var q = ""
  @State private var asked = ""
  @State private var answer = ""
  @State private var busy = false
  @State private var err: String?
  @State private var task: Task<Void, Never>?
  @FocusState private var focus: Bool

  static let chips = ["What is a share?", "Why do prices go up and down?", "What is a company's report card?", "What does Disney sell?", "Is the market sunny today?", "Why shouldn't I put all my eggs in one basket?"]

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        Hero(eyebrow: "Your money helper", title: "Ask", accent: "Luna")
        Text("Luna knows about money, companies and the market. Tap a question!").font(.kRead)
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
              .padding(.horizontal, 16).frame(minHeight: 52).background(.thinMaterial, in: Capsule())
              .onChange(of: q) { _, v in if v.count > 200 { q = String(v.prefix(200)) } }
            Button("Ask") { ask(q, typed: true) }.buttonStyle(PrimaryButtonStyle()).frame(width: 90).disabled(busy || q.trimmingCharacters(in: .whitespaces).isEmpty)
          }
          Text("Please don't type your name, school or where you live.").font(.caption).foregroundStyle(.secondary)
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
      .padding(20).readable()
      .animation(.spring(response: 0.45, dampingFraction: 0.85), value: asked)
    }
    .scrollDismissesKeyboard(.interactively)
    .background(AuroraField(surface: .luna))
    .onDisappear { task?.cancel() }
  }

  @State private var typedQuestion: String?

  func ask(_ question: String, typed: Bool) {
    let text = String(question.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200))
    guard !text.isEmpty, !busy else { return }
    task?.cancel(); focus = false
    asked = text; answer = ""; err = nil; busy = true; q = ""
    typedQuestion = typed ? text : nil
    let w = app.mood.map(weatherFor)
    var next: [String: EarningsEvent] = [:]
    for e in app.upcoming where next[e.s] == nil { next[e.s] = e }
    let ctx = LunaContext(weather: w.map { "\($0.title): \($0.line)" }, companies: app.content.companies.map { k in
      LunaContext.Co(s: k.s, nick: k.nick, hook: k.hook, when: next[k.s].map { kidWhen($0.d, $0.h, today: app.today) })
    })
    task = Task {
      do { for try await t in app.luna.ask(text, context: ctx) { answer += t } }
      catch { err = (error as? KidError)?.message ?? KidError.resting.message }
      busy = false
    }
  }
}
