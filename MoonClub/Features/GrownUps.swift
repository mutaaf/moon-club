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

/// The grown-up corner. It leads with bright "at a glance" tiles (our promises, then how to play), and keeps the
/// long words in accordions, closed by default. Settings stay native list rows with one-line footers; each
/// section's longer explanation sits in a "How it works" row that opens in place.
struct GrownUpsView: View {
  /// A settings link that brought the grown-up here (after the gate): a Family League code or a lesson pack.
  var link: DeepLink? = nil
  @Environment(AppModel.self) private var app
  @Environment(\.dismiss) private var dismiss
  var body: some View {
    NavigationStack {
      ScrollViewReader { proxy in
      List {
        if let link, link.needsGrownUp { LinkOffer(link: link) }
        Section {
          HStack(spacing: 14) { Luna(size: 54); VStack(alignment: .leading) { Text("Moon Club").font(.kTitle); Text("Metaphases Kids · prototype").font(.caption).foregroundStyle(.secondary) } }
        }
        Section {
          TileGrid {
            GlanceTile(symbol: "banknote.fill", hue: .mint, title: "Pretend money only", detail: "Nothing to buy, sell or pay for.", glow: [.teal, .lemon], seed: 1)
            GlanceTile(symbol: "lock.shield.fill", hue: .sky, title: "Nothing leaves this device", detail: "No accounts, no ads, no tracking.", glow: [.grape, .mint], seed: 2)
            GlanceTile(symbol: "moon.stars.fill", hue: .grape, title: "Luna plays it safe", detail: "Simple words, money topics, every answer checked.", glow: [.berry, .sky], seed: 3)
            GlanceTile(symbol: "hand.raised.fill", hue: .coral, title: "Never advice", detail: "Learning and play only.", glow: [.orange, .lemon], seed: 4)
          }
          .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
          .accessibilityElement(children: .contain).accessibilityLabel("Our promises")
        } header: { Text("At a glance") }
        Section {
          TileGrid {
            GlanceTile(symbol: "book.pages.fill", hue: .lemon, title: "Story", detail: "Help Luna with today's mission.", glow: [.orange, .berry], seed: 5)
            GlanceTile(symbol: "map.fill", hue: .teal, title: "World", detail: "Play lessons and games on the map.", glow: [.sky, .mint], seed: 6)
            GlanceTile(symbol: "target", hue: .orange, title: "Guess", detail: "Will a company beat or miss?", glow: [.lemon, .coral], seed: 7)
            GlanceTile(symbol: "custom.piggy", hue: .berry, title: "Piggy Bank", detail: "Pretend coins and a Moon Garden.", glow: [.lemon, .mint], seed: 8)
            GlanceTile(symbol: "bubble.left.fill", hue: .grape, title: "Ask Luna", detail: "Ask her a money question.", glow: [.sky, .berry], seed: 9)
            GlanceTile(symbol: "heart.fill", hue: .coral, title: "No pressure", detail: "Hearts cost nothing. Just try again!", glow: [.berry, .gold], seed: 10)
          }
          .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
          .accessibilityElement(children: .contain).accessibilityLabel("How to play")
          .id("play")
        } header: { Text("How to play") }
        Section {
          TileGrid(minimum: 300) {
            Accordion(symbol: "graduationcap.fill", hue: .sky, title: "What kids learn", summary: "Companies, prices, saving, earning and more") {
              Point("What a company, a share and a profit are.", hue: .sky)
              Point("Why prices move: more buyers or sellers, report cards, the whole market, or a normal wiggle. \"We're not sure\" is an honest answer.", hue: .sky)
              Point("Earnings report cards: what beat and miss mean, with companies they know.", hue: .sky)
              Point("Saving vs investing, dividends, and why spreading out is safer.", hue: .sky)
              Point("Patience, and hype vs facts.", hue: .sky)
              Point("Earning, saving goals, smart spending, giving, borrowing and interest, prices over time, insurance and spotting scams (Jump$tart national standards).", hue: .sky)
              Point("Worked examples (“Let's work it out”) and growth pictures that grow one year per tap.", hue: .sky)
              Point("Three tracks: Little Moons (6–8), Big Moons (9–11) and Full Moons, an optional challenge with percents and fees.", hue: .sky)
              Point("Missed questions come back at Review stops; a lesson that slipped away comes back as Luna's refresh.", hue: .sky)
            }
            Accordion(symbol: "checkmark.shield.fill", hue: .mint, title: "Our promises, in full", summary: "Money, data, Luna and advice") {
              Point("**Pretend money only.** Nothing can be bought, sold or paid for. No broker, no buy button.", hue: .mint)
              Point("**No data collected.** No accounts, no sign-up, no analytics, no ads. Progress lives only on this device.", hue: .mint)
              Point("**Read-only market data** (prices, report dates, market mood) comes from mutaafaziz.com/metaphases. Nothing about your child is sent.", hue: .mint)
              if Distribution.allowsOwnKeys {
                Point("**Luna** thinks on this device with Apple Intelligence when available, or uses our free kid-safe model. Only if you add your own key and say OK are questions sent to that company.", hue: .mint)
              } else {
                Point("**Luna** thinks on this device with Apple Intelligence when available, or uses our free kid-safe model, which keeps nothing and never sees a name or account. Questions never go to any other company.", hue: .mint)
              }
              Point("Same rules for every brain: simple words, money topics only, never advice, never asks for personal details. Stay nearby: she can make mistakes.", hue: .mint)
              Point("Nothing here is investment advice.", hue: .mint)
            }
            Accordion(symbol: "bubble.left.and.bubble.right.fill", hue: .orange, title: "Talk at home", summary: "Questions to ask at dinner") {
              Point("“Which companies do we buy things from every week?”", hue: .orange)
              Point("“If you had $10, would you save it or invest it? Why?”", hue: .orange)
              Point("“Why do you think the price went down even though they beat?”", hue: .orange)
              Point("“How could we check if a video about a stock is true?”", hue: .orange)
              Point("Every unit has more under “What your child is learning” below.", hue: .orange)
            }
          }
          .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
          .id("learn")
        } header: { Text("Learn more") }
        WhatsNewSection()
        Section { UnitsReport().id("packs") } header: { Text("What your child is learning") } footer: {
          Text("Worked out on this device. Nothing is sent. Open a unit for its dinner table talk.")
        }
        Section {
          PackSettings()
          About {
            Text("Every pack is checked by a teacher and a markets expert, and follows the same rules: pretend money, no links, no ads, no advice. Guest hosts are always shown as guests, and never ask kids to follow or buy anything.")
          }
        } header: { Text("Lesson packs") } footer: { Text("Every pack is checked by a teacher and a markets expert.") }
        Section { BrainPicker().listRowInsets(EdgeInsets()).listRowBackground(Color.clear).id("brain") } header: { Text("Luna's brain") } footer: {
          Text("Same kid-safe rules for every brain. Every answer is checked on this device first.")
        }
        if Distribution.allowsOwnKeys {
          Section { VoiceSettingsView() } header: { Text("Luna's voice") } footer: {
            Text("Your key stays in this device's Keychain and is sent only to make the voice. Only app text and Luna's answers are spoken — never what your child types.")
          }
        }
        Section {
          GardenLimitSetting()
          About {
            Text("Kids plant Moon points (earned in the app, never money) in companies they know and harvest them back any time. This limit caps how much of their points they can plant each day, so their Moon Shop points stay safe. Prices update once a day. No real money, no real trades.")
          }
        } header: { Text("Moon Garden") } footer: { Text("A daily cap on planting. Points only, never money.") }
        Section {
          PlaySettings()
          About {
            Point("**Relaxed play** hides the speed ring, so there's no clock at all.", hue: .teal)
            Point("**Hearts never cost anything.** Out of hearts just means \"try again\".", hue: .coral)
            Point("**Sounds** follow the ring/silent switch.", hue: .sky)
            Point("**Goodnight:** after about 20 minutes, between games, Luna gets sleepy and offers a goodnight. \"One more game\" is always fine.", hue: .grape)
            Point("**iPhone Duo:** lessons become storybooks, bosses play in tabletop mode, and the hinge is a game control.", hue: .lemon)
          }
        } header: { Text("Games") } footer: { Text("Relaxed play: no clock at all.") }
        Section { LeagueSettings() } header: { Text("Family league") } footer: {
          Text("Each player picks an emoji instead of a name. A code holds only the company, the date and the guess. Codes work with the website too.")
        }
        SyncSections()
        Section { ShareLinks().id("share") } header: { Text("Share") } footer: {
          Text("Opens Moon Club, or the website if it isn't installed. A link names a lesson, never your child.")
        }
        if !Partners.shown.isEmpty {
          Section { PartnerPicks() } header: { Text("Grown-up picks") } footer: { Text(Partners.disclosure) }
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
      .onAppear { if ProcessInfo.processInfo.arguments.contains("-scrollShare") { Task { try? await Task.sleep(for: .milliseconds(400)); proxy.scrollTo("share", anchor: .top) } } }
      .onAppear { if ProcessInfo.processInfo.arguments.contains("-scrollPlay") { Task { try? await Task.sleep(for: .milliseconds(400)); proxy.scrollTo("play", anchor: .top) } } }
      .onAppear { if ProcessInfo.processInfo.arguments.contains("-scrollLearn") { Task { try? await Task.sleep(for: .milliseconds(400)); proxy.scrollTo("learn", anchor: .top) } } }
      .onAppear { if ProcessInfo.processInfo.arguments.contains("-scrollBrain") { Task { try? await Task.sleep(for: .milliseconds(400)); proxy.scrollTo("brain", anchor: .top) } } }
      #endif
      }
      .navigationTitle("For grown-ups")
      .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
    }
  }
}

/// A "How it works" row inside a settings section: the section's longer explanation, closed by default.
struct About<Content: View>: View {
  var title = "How it works"
  @ViewBuilder var content: Content
  @State private var open = Accordion<EmptyView>.startOpen
  var body: some View {
    DisclosureGroup(isExpanded: $open) {
      VStack(alignment: .leading, spacing: 8) { content }.font(.callout).padding(.vertical, 4)
    } label: {
      Label(title, systemImage: "info.circle").font(.subheadline.weight(.semibold))
    }
  }
}

/// "What your child is learning": one summary row (how many units at each stage) that opens to every unit.
struct UnitsReport: View {
  @Environment(AppModel.self) private var app
  @State private var open: Bool = {
    #if DEBUG
    let a = ProcessInfo.processInfo.arguments
    return a.contains("-talkOpen") || a.contains("-scrollPacks") || a.contains("-expand")
    #else
    return false
    #endif
  }()
  var body: some View {
    let ms = app.content.units.map { Review.mastery($0.id, app.state, app.content) }
    let parts = Mastery.allCases.reversed().compactMap { m -> String? in
      let n = ms.filter { $0 == m }.count
      return n == 0 ? nil : "\(n) \(m.label.lowercased())"
    }
    DisclosureGroup(isExpanded: $open) {
      LearningReport()
    } label: {
      HStack(spacing: 12) {
        Glyph(symbol: "chart.bar.fill", hue: .sky, size: 34)
        VStack(alignment: .leading, spacing: 2) {
          Text("\(ms.count) units").font(.kHeadline)
          Text(parts.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
        }
      }
      .accessibilityElement(children: .combine)
    }
  }
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
        // The same code as a link: it opens the other device's Moon Club at its own parental gate (or the website).
        ShareLink(item: DeepLink.league(code).webURL(ref: Campaign.league), subject: Text("Join our Moon Club family league"),
                  message: Text("Tap to add my guesses to your Moon Club family league. A grown-up says OK first.")) {
          Label("Share as a link", systemImage: "link")
        }
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

/// What a settings link offers, shown at the top of the grown-up corner only after the gate was passed.
/// Nothing happens until the grown-up taps the button.
struct LinkOffer: View {
  let link: DeepLink
  @Environment(AppModel.self) private var app
  @State private var done: String?
  var body: some View {
    switch link {
    case .league(let code):
      Section {
        switch League.decode(code, companies: app.content.companies, players: app.content.players.count) {
        case let .success(p):
          let name = app.content.playerNames.indices.contains(p.emoji) ? app.content.playerNames[p.emoji] : "A player"
          HStack(spacing: 12) {
            if app.content.players.indices.contains(p.emoji) { Glyph(app.content.players[p.emoji], size: 36) }
            VStack(alignment: .leading) {
              Text("\(name) wants to join").font(.headline)
              Text("\(p.guesses.count) \(p.guesses.count == 1 ? "guess" : "guesses"). The code holds only companies, dates and guesses.").font(.caption).foregroundStyle(.secondary)
            }
          }
          if p.emoji == app.state.me {
            Text("That's this device's own player. Each player needs a different emoji.").font(.callout).foregroundStyle(Palette.bad)
          } else if let done {
            Text(done).font(.callout).foregroundStyle(Palette.good)
          } else {
            Button("Add to our family league") { app.mutate { $0.addPlayer(p) }; done = "\(name) joined. Their guesses show on Guess." }
              .accessibilityIdentifier("link-league-add")
          }
        case let .failure(e):
          Text(e.message).font(.callout).foregroundStyle(Palette.bad)
        }
      } header: { Text("From a link: family league") }
    case .pack(let id):
      Section {
        if let p = app.packs.first(where: { $0.id == id }) {
          VStack(alignment: .leading, spacing: 3) {
            Text(p.title).font(.headline)
            if let badge = p.hostBadge, let c = p.creator { Text("\(badge): \(c.name). \(c.bio)").font(.caption) }
            Text("Adds \(p.lessonCount) lessons and a new island on the map. Every pack is checked by a teacher and a markets expert.").font(.caption).foregroundStyle(.secondary)
          }
          if app.packOn(id) {
            Text(done ?? "This pack is on.").font(.callout).foregroundStyle(Palette.good)
          } else {
            Button("Turn on this pack") { app.setPack(id, on: true); done = "Turned on. Look for its island on the World map." }
              .accessibilityIdentifier("link-pack-on")
          }
        }
      } header: { Text("From a link: lesson pack") }
    default:
      EmptyView()
    }
  }
}

/// Share links into the club (grown-ups only). Each carries an allow-listed `ref` so the App Store button on the
/// web page can credit the channel in App Analytics, in aggregate (docs/LINKS.md). Nothing about the child.
struct ShareLinks: View {
  @Environment(AppModel.self) private var app
  @State private var lessonId = ""
  var body: some View {
    let lessons = app.content.lessons
    let pick = lessons.first { $0.id == lessonId } ?? lessons.first
    if let pick {
      Picker("Lesson", selection: Binding(get: { pick.id }, set: { lessonId = $0 })) {
        ForEach(lessons) { l in Text(l.title).tag(l.id) }
      }
      .accessibilityIdentifier("share-lesson-pick")
      ShareLink(item: DeepLink.lesson(pick.id).webURL(ref: Campaign.share), subject: Text("A one-minute money lesson: \(pick.title)"),
                message: Text("Try this one-minute Moon Club lesson: \(pick.title). Pretend money only, no ads.")) {
        Label("Share this lesson", systemImage: "square.and.arrow.up")
      }
      .accessibilityIdentifier("share-lesson")
    }
    ShareLink(item: DeepLink.home.webURL(ref: Campaign.share), subject: Text("Moon Club: money, explained for kids"),
              message: Text("Moon Club teaches kids how money works with one-minute lessons and pretend money. No ads, no sign-up.")) {
      Label("Share Moon Club", systemImage: "moon.stars")
    }
    ForEach(app.packs) { p in
      ShareLink(item: DeepLink.pack(p.id).webURL(ref: Campaign.pack(p.id)), subject: Text(p.title),
                message: Text("A Moon Club lesson pack: \(p.title). A grown-up turns it on.")) {
        Label("Share “\(p.title)”", systemImage: "books.vertical")
      }
    }
  }
}

/// Grown-up picks (affiliate slot). Ships EMPTY: `Partners.list` in MoonClubCore. Shown only here, behind the
/// gate, under `Partners.disclosure`. Plain https links that open in Safari: no SDK, no pixel, nothing about the child.
struct PartnerPicks: View {
  var body: some View {
    ForEach(Partners.shown) { p in
      if let url = URL(string: p.url) {
        Link(destination: url) {
          VStack(alignment: .leading, spacing: 2) {
            Text(p.title).font(.subheadline.weight(.semibold))
            Text(p.blurb).font(.caption).foregroundStyle(.secondary)
            Text("Partner link").font(.caption2.weight(.bold)).foregroundStyle(Palette.ink2)
          }
        }
      }
    }
  }
}
