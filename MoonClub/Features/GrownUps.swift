import SwiftUI
import MoonClubCore

// The ONLY module allowed to hold links out of the app or settings (scripts/check-rules.sh enforces it).
// Everything here sits behind the parental multiplication gate.

struct ParentGate: View {
  let onPass: () -> Void
  @Environment(\.dismiss) private var dismiss
  @State private var a = Int.random(in: 6...9)
  @State private var b = Int.random(in: 6...9)
  @State private var v = ""
  @State private var wrong = false
  @FocusState private var focus: Bool
  var body: some View {
    VStack(spacing: 18) {
      Image(systemName: "lock.shield").font(.system(size: 44)).foregroundStyle(Palette.accent)
      Text("For grown-ups").font(.kHero).lineLimit(1).minimumScaleFactor(0.6)
      Text("Please answer to continue:").foregroundStyle(.secondary)
      Text("What is \(a) × \(b)?").font(.kTitle).accessibilityIdentifier("gate-question")
      TextField("", text: $v).keyboardType(.numberPad).multilineTextAlignment(.center).font(.system(size: 34, weight: .bold, design: .rounded))
        .frame(height: 64).moonGlass(radius: 18, weight: .thin).focused($focus)
        .accessibilityLabel("Answer").accessibilityIdentifier("gate-answer")
        .onChange(of: v) { _, x in v = String(x.filter(\.isNumber).prefix(3)) }
      if wrong { Text("That's not it. Ask a grown-up for help!").foregroundStyle(Palette.bad) }
      HStack(spacing: 12) {
        Button("Back to kids") { dismiss() }.buttonStyle(SoftButtonStyle())
        Button("Continue") {
          if Int(v) == a * b { dismiss(); onPass() } else { wrong = true; v = ""; a = Int.random(in: 6...9); b = Int.random(in: 6...9) }
        }.buttonStyle(PrimaryButtonStyle())
      }
    }
    .padding(28)
    .presentationDetents([.medium, .large])
    .onAppear { focus = true }
    .sensoryFeedback(.error, trigger: wrong)
  }
}

struct GrownUpsView: View {
  @Environment(AppModel.self) private var app
  @Environment(\.dismiss) private var dismiss
  var body: some View {
    NavigationStack {
      ScrollViewReader { proxy in
      List {
        Section {
          HStack(spacing: 14) { Luna(size: 54); VStack(alignment: .leading) { Text("Moon Club").font(.kTitle); Text("Metaphases Kids · prototype").font(.caption).foregroundStyle(.secondary) } }
        }
        WhatsNewSection()
        Section("What kids learn") {
          bullet("What a company, a share and a profit are, in plain words.")
          bullet("How prices move when more people want to buy or sell.")
          bullet("What an earnings “report card” is, and what beat and miss mean, with companies they know.")
          bullet("Saving vs investing, dividends, and why spreading money out is safer.")
          bullet("Patience, and the difference between hype and facts.")
          bullet("Why prices move: report cards, the whole market, groups of companies, or a normal wiggle. And that \"we're not sure\" is an honest answer.")
          bullet("Two tracks: Little Moons (6–8) and Big Moons (9–11). Questions a child misses come back at Review stops on the map.")
        }
        Section { LearningReport().id("packs") } header: { Text("What your child is learning") } footer: {
          Text("Worked out on this device from finished lessons and Review stop answers. Nothing is sent anywhere.")
        }
        Section { PackSettings() } header: { Text("Lesson packs") } footer: {
          Text("Every pack is checked by a teacher and a markets expert, and follows the same rules: pretend money, no links, no ads, no advice. Guest hosts are always shown as guests, and never ask kids to follow or buy anything.")
        }
        Section("Our promises") {
          bullet("**Pretend money only.** Nothing can be bought, sold or paid for. No broker, no buy button.")
          bullet("**No data collected.** No accounts, no sign-up, no analytics, no ads. Progress lives only on this device.")
          bullet("**Read-only market data** (prices, report dates, market mood) comes from mutaafaziz.com/metaphases. Nothing about your child is sent.")
          if Distribution.allowsOwnKeys {
            bullet("**Luna** thinks on this device with Apple Intelligence when it's available, or uses our free kid-safe model. Only if you add your own key and say OK are questions sent to that company. Same rules everywhere: simple words, money topics only, never advice, never asks for personal details. Stay nearby — she can make mistakes.")
          } else {
            bullet("**Luna** thinks on this device with Apple Intelligence when it's available, or uses our free kid-safe model, which keeps nothing and never sees a name or account. Questions never go to any other company. Same rules everywhere: simple words, money topics only, never advice, never asks for personal details. Stay nearby — she can make mistakes.")
          }
          bullet("Nothing here is investment advice.")
        }
        Section { BrainPicker().id("brain") } header: { Text("Luna's brain") } footer: {
          Text("Every brain gets the same kid-safe rules, and every answer is checked on this device before your child sees it.")
        }
        if Distribution.allowsOwnKeys {
          Section { VoiceSettingsView() } header: { Text("Luna's voice") } footer: {
            Text("Your key stays in this device's Keychain and is sent only to make the voice. Only app text and Luna's answers are spoken — never what your child types.")
          }
        }
        Section { GardenLimitSetting() } header: { Text("Moon Garden") } footer: {
          Text("Kids can plant Moon points (earned in the app, never money) in companies they know and harvest them back any time. This caps how much of their points they can plant each day, so their Moon Shop points stay safe. Prices update once a day. No real money, no real trades.")
        }
        Section { PlaySettings() } header: { Text("Games") } footer: {
          Text("Relaxed play hides the speed ring, so there's no clock at all. Hearts never cost anything: out of hearts just means \"try again\". Sounds follow the ring/silent switch. After about 20 minutes, between games, Luna gets sleepy and offers a goodnight; \"one more game\" is always fine. Moon Club is also made for iPhone Duo: lessons become storybooks, bosses play in tabletop mode, and the hinge is a game control.")
        }
        Section { LeagueSettings() } header: { Text("Family league") } footer: {
          Text("Each player picks an emoji instead of a name. A code holds only the company, the date and the guess. Codes work with the website too.")
        }
        SyncSections()
        Section("Conversation starters") {
          bullet("“Which companies do we buy things from every week?”")
          bullet("“If you had $10, would you save it or invest it? Why?”")
          bullet("“Why do you think the price went down even though they beat?”")
          bullet("“How could we check if a video about a stock is true?”")
        }
        Section("More") {
          Link(destination: URL(string: "https://mutaafaziz.com/metaphases/kids")!) { Label("Metaphases Kids on the web", systemImage: "safari") }
          Link(destination: URL(string: "https://mutaafaziz.com/metaphases/kids/grownups")!) { Label("Printable worksheets", systemImage: "printer") }
          ResetProgressButton()
        }
      }
      #if DEBUG
      .onAppear { if ProcessInfo.processInfo.arguments.contains("-askReset") { Task { try? await Task.sleep(for: .milliseconds(400)); proxy.scrollTo("reset", anchor: .bottom) } } }
      .onAppear { if ProcessInfo.processInfo.arguments.contains("-scrollPacks") { Task { try? await Task.sleep(for: .milliseconds(400)); proxy.scrollTo("packs", anchor: .top) } } }
      .onAppear { if ProcessInfo.processInfo.arguments.contains("-scrollSync") { Task { try? await Task.sleep(for: .milliseconds(400)); proxy.scrollTo("sync", anchor: .top) } } }
      .onAppear { if ProcessInfo.processInfo.arguments.contains("-scrollBrain") { Task { try? await Task.sleep(for: .milliseconds(400)); proxy.scrollTo("brain", anchor: .top) } } }
      #endif
      }
      .navigationTitle("For grown-ups")
      .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
    }
  }
  func bullet(_ s: LocalizedStringKey) -> some View { Text(s).font(.callout) }
}

struct PlaySettings: View {
  @AppStorage(PlayPrefs.relaxedKey) private var relaxed = false
  @AppStorage(PlayPrefs.soundsKey) private var sounds = true
  var body: some View {
    Toggle("Relaxed play (no speed ring)", isOn: $relaxed)
    Toggle("Game sounds", isOn: $sounds)
  }
}

struct VoiceSettingsView: View {
  @Environment(AppModel.self) private var app
  @State private var s = VoiceSettings.load()
  @State private var key = ""
  @State private var saved = Keychain.get()
  var body: some View {
    Picker("Voice", selection: $s.mode) {
      Text("Device voice (free)").tag(VoiceSettings.Mode.device)
      Text("OpenAI (your key)").tag(VoiceSettings.Mode.openai)
      Text("Google Gemini (your key)").tag(VoiceSettings.Mode.gemini)
    }
    .onChange(of: s.mode) { _, m in
      if let p = Requests.VoiceProvider(rawValue: m.rawValue), !(Requests.voices[p]?.contains(s.voice) ?? false) { s.voice = Requests.voices[p]![0] }
      s.save()
    }
    if let p = Requests.VoiceProvider(rawValue: s.mode.rawValue) {
      Picker("Friendly voice", selection: $s.voice) { ForEach(Requests.voices[p]!, id: \.self) { Text($0.capitalized).tag($0) } }
        .onChange(of: s.voice) { _, _ in s.save() }
      if let saved, !saved.isEmpty {
        LabeledContent("Key", value: "••••" + String(saved.suffix(4)))
        Button("Forget key", role: .destructive) { Keychain.set(nil); self.saved = nil }
      } else {
        SecureField(p == .openai ? "sk-…" : "AIza…", text: $key).textContentType(.password).autocorrectionDisabled().textInputAutocapitalization(.never)
        Button("Save key") { Keychain.set(key.trimmingCharacters(in: .whitespaces)); saved = Keychain.get(); key = "" }.disabled(key.count < 8)
      }
    }
    Button { Task { await app.voice.speak(.appCopy("Hi! I'm Luna. Let's learn about money together!")) } } label: { Label("Hear a sample", systemImage: "play.circle.fill") }
  }
}

struct LeagueSettings: View {
  @Environment(AppModel.self) private var app
  @State private var paste = ""
  @State private var msg: (ok: Bool, text: String)?
  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("1. This device's player").font(.subheadline.weight(.semibold))
      HStack(spacing: 6) {
        ForEach(app.content.players.indices, id: \.self) { i in
          Button { app.mutate { $0.setMe(i) } } label: {
            Text(app.content.players[i]).font(.title2).frame(width: 40, height: 44)
              .background(app.state.me == i ? Palette.lavender : .clear, in: RoundedRectangle(cornerRadius: 12))
              .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(app.state.me == i ? Palette.accent : .clear, lineWidth: 2))
          }.buttonStyle(.plain).accessibilityLabel(app.content.playerNames[i])
        }
      }
    }
    if let me = app.state.me {
      let code = League.encode(LeaguePlayer(emoji: me, guesses: app.state.guesses.map { LeagueGuess(s: $0.s, d: $0.d, pick: $0.pick, price: $0.price) }), companies: app.content.companies)
      VStack(alignment: .leading, spacing: 6) {
        Text("2. Send this code to the other device").font(.subheadline.weight(.semibold))
        Text(code).font(.system(.body, design: .monospaced).weight(.semibold)).textSelection(.enabled)
        HStack { Button("Copy") { UIPasteboard.general.string = code }; Spacer(); ShareLink(item: code) { Label("Share", systemImage: "square.and.arrow.up") } }
      }
    }
    VStack(alignment: .leading, spacing: 6) {
      Text("3. Paste a code from another device").font(.subheadline.weight(.semibold))
      TextField("MOON-1…", text: $paste).font(.system(.body, design: .monospaced)).autocorrectionDisabled().textInputAutocapitalization(.characters)
      Button("Add player") {
        switch League.decode(paste, companies: app.content.companies) {
        case let .success(p):
          if p.emoji == app.state.me { msg = (false, "That's this device's own player. Each player needs a different emoji."); return }
          app.mutate { $0.addPlayer(p) }; paste = ""
          msg = (true, "\(app.content.players[p.emoji]) \(app.content.playerNames[p.emoji]) joined with \(p.guesses.count) \(p.guesses.count == 1 ? "guess" : "guesses").")
        case let .failure(e): msg = (false, e.message)
        }
      }.disabled(paste.trimmingCharacters(in: .whitespaces).isEmpty)
      if let msg { Text(msg.text).font(.callout).foregroundStyle(msg.ok ? Palette.good : Palette.bad) }
    }
    ForEach(app.state.leaguePlayers) { p in
      HStack { Glyph(app.content.players[p.emoji], size: 28); Text("\(app.content.playerNames[p.emoji]) · \(p.guesses.count) guesses"); Spacer(); Button("Remove", role: .destructive) { app.mutate { $0.removePlayer(p.emoji) } }.font(.caption) }
    }
  }
}

/// "What's new": the same release notes TestFlight shows (release-notes/<version>.md, bundled as a folder resource).
struct WhatsNewSection: View {
  static let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
  static let lines: [String] = {
    guard let url = Bundle.main.url(forResource: version, withExtension: "md", subdirectory: "release-notes"),
          let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
    return text.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty && !$0.hasPrefix("<!--") }
  }()
  @State private var open = false
  var body: some View {
    if let first = Self.lines.first {
      Section {
        DisclosureGroup(isExpanded: $open) {
          ForEach(Array(Self.lines.dropFirst().enumerated()), id: \.offset) { _, line in row(line) }
        } label: {
          VStack(alignment: .leading, spacing: 2) {
            Text("What's new").font(.headline)
            Text(first.replacingOccurrences(of: "# ", with: "")).font(.caption).foregroundStyle(.secondary)
          }
        }
        .accessibilityIdentifier("whats-new")
      }
    }
  }
  @ViewBuilder func row(_ line: String) -> some View {
    if line.hasPrefix("#") {
      Text(line.drop(while: { $0 == "#" || $0 == " " })).font(.subheadline.weight(.semibold)).padding(.top, 4)
    } else {
      let body = line.hasPrefix("- ") ? "• " + line.dropFirst(2) : Substring(line)
      Text((try? AttributedString(markdown: String(body))) ?? AttributedString(String(body))).font(.callout)
    }
  }
}

/// The Moon Garden's daily planting limit (synced: the later grown-up pick wins on every device).
struct GardenLimitSetting: View {
  @Environment(AppModel.self) private var app
  var body: some View {
    Picker("Plant each day, at most", selection: Binding(get: { app.state.gardenLimitPct }, set: { v in app.mutate { $0.setGardenLimit(v, nowMillis: Int(Date().timeIntervalSince1970 * 1000)) } })) {
      ForEach(Garden.limitChoices, id: \.self) { p in Text(p == 0 ? "Planting paused" : "\(p)% of their points").tag(p) }
    }
  }
}
