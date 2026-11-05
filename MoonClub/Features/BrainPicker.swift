import SwiftUI
import MoonClubCore

/// Grown-up corner → "Luna's brain": a guided picker, not bare settings. Each brain is a bright aurora tile
/// (symbol, name, one short line); the selected one glows and carries a check. The long words (what each brain
/// sends where, key notes) live in accordions, closed by default. Behind the parental gate (inside GrownUpsView).
struct BrainPicker: View {
  @Environment(AppModel.self) private var app
  @Environment(\.accessibilityReduceMotion) private var rm
  @State private var s = BrainStore.load()
  @State private var keyTravels = KeyTravel.isOn
  @State private var device = OnDevice.status()
  @State private var savedKey = BrainStore.lunaKey
  @State private var paste = ""
  @State private var checking = false
  @State private var checkMsg: (ok: Bool, text: String)?

  private var active: BrainKind { BrainRouter.resolve(s, onDevice: device, hasKey: !(savedKey ?? "").isEmpty) }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Choose how Luna thinks. Change it any time.").font(.callout).foregroundStyle(Palette.ink2)
        .padding(.horizontal, 4)
      TileGrid(minimum: 250) {
        tile(.onDevice, title: "On this device", line: device == .available ? "Private and free. Questions stay here." : "Not ready here yet.",
             hue: .grape, glow: [.sky, .berry], seed: 21, warn: device != .available)
        tile(.free, title: "Free Luna", line: "Free, no key. No name, nothing stored.", hue: .sky, glow: [.mint, .grape], seed: 22)
        if Distribution.allowsOwnKeys {
          tile(.byok, title: "Your own key", line: "Super Luna: richer answers and voice.", hue: .gold, glow: [.orange, .berry], seed: 23)
        }
      }
      .accessibilityElement(children: .contain).accessibilityLabel("Luna's brain choices")

      if s.choice == .onDevice, device != .available {
        Label(device.explanation, systemImage: "info.circle.fill")
          .font(.footnote).foregroundStyle(Palette.badInk).fixedSize(horizontal: false, vertical: true)
          .padding(.horizontal, 4)
      }

      nowPill

      if Distribution.allowsOwnKeys, s.choice == .byok {
        byokSetup.transition(rm ? .opacity : .opacity.combined(with: .move(edge: .top)))
      }

      Accordion(symbol: "arrow.left.arrow.right.circle.fill", hue: .teal, title: "What's sent where", summary: "How each brain works, in full") {
        Point("**On this device** (Apple Intelligence): Luna thinks right on this iPhone or iPad. Your child's questions never leave the device. Free, private, and she remembers the chat.", hue: .grape)
        if device != .available { Point("\(device.explanation)", hue: .grape) }
        Point("**Free Luna** (Metaphases): a free, kid-safe helper on our server. Questions are sent without any name or account and aren't stored. Short answers, one question at a time.", hue: .sky)
        if Distribution.allowsOwnKeys {
          Point("**Your own key** (full capabilities): use your own Anthropic, OpenAI, Google or xAI account for Super Luna: longer, richer answers, follow-up memory, deeper “Explain more” on story and report cards, and a friendlier voice.", hue: .gold)
        }
        Point("If you don't pick, Luna uses this device when it can, and Free Luna when it can't.", hue: .teal)
      }
    }
    .animation(Motion.safe(.spring(response: 0.4, dampingFraction: 0.85), rm), value: s)
    .onChange(of: s) { _, v in BrainStore.save(v); app.refreshBrain() }
    .onAppear { device = OnDevice.status() }
  }

  /// The choice the tile represents is selected (automatic counts as on-device when it's available, else free).
  private func isSelected(_ k: BrainKind) -> Bool {
    if let c = s.choice { return c == k }
    return k == (device == .available ? .onDevice : .free)
  }

  /// One brain as a compact tile. Selected: the aurora field glows, an accent ring and a filled check.
  /// Not selected: a quiet card with an empty circle (the state never rests on color alone).
  @ViewBuilder private func tile(_ k: BrainKind, title: String, line: String, hue: Hue, glow: [Hue], seed: Float, warn: Bool = false) -> some View {
    let on = isSelected(k)
    let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
    Button { s.choice = k } label: {
      HStack(alignment: .center, spacing: 12) {
        Glyph(symbol: k.symbol, hue: hue, size: 40)
        VStack(alignment: .leading, spacing: 3) {
          Text(title).font(.kHeadline).foregroundStyle(Palette.ink)
          HStack(alignment: .firstTextBaseline, spacing: 4) {
            if warn { Image(systemName: "info.circle.fill").foregroundStyle(Palette.badInk) }
            Text(line).foregroundStyle(warn ? Palette.badInk : Palette.ink2)
          }
          .font(.subheadline)
        }
        .fixedSize(horizontal: false, vertical: true)
        Spacer(minLength: 0)
        Image(systemName: on ? "checkmark.circle.fill" : "circle")
          .font(.title2.weight(.semibold))
          .foregroundStyle(on ? Palette.accent : Palette.ink2.opacity(0.6))
          .background(Circle().fill(on ? Color.white : .clear).padding(3))
      }
      .padding(.horizontal, 16).padding(.vertical, 12)
      .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
      .background {
        if on {
          AuroraSwatch(colors: [hue.light, glow[0].color.blend(with: .white, by: 0.25), glow[1].color.blend(with: .white, by: 0.25)], seed: seed)
        } else {
          Palette.card
        }
      }
      .clipShape(shape)
      .overlay(shape.strokeBorder(on ? Palette.accent : Palette.line, lineWidth: on ? 2.5 : 1))
      .shadow(color: on ? hue.color.opacity(0.22) : .clear, radius: 10, y: 4)
      .contentShape(shape)
    }
    .buttonStyle(PressStyle())
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("\(title). \(line)")
    .accessibilityHint(on ? "" : "Makes Luna use this brain")
    .accessibilityIdentifier("brain-\(k.rawValue)")
    .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
  }

  /// Which brain answers right now (a choice that isn't ready yet falls back, and says so).
  private var nowPill: some View {
    HStack(spacing: 8) {
      Image(systemName: active.symbol).foregroundStyle(Palette.accent)
      // One Text so the hint wraps as a sentence instead of a squeezed second column.
      (Text("Right now: **\(active.badge)**").foregroundColor(Palette.ink)
        + Text(s.choice == .byok && active != .byok ? " · finish the steps below to switch" : "").foregroundColor(Palette.ink2))
        .accessibilityIdentifier("brain-active")
    }
    .font(.footnote)
    .fixedSize(horizontal: false, vertical: true)
    .padding(.horizontal, 12).padding(.vertical, 8)
    .background(Palette.card, in: Capsule())
    .overlay(Capsule().strokeBorder(Palette.line, lineWidth: 1))
    .accessibilityElement(children: .combine)
  }

  private func step(_ n: Int, _ title: String) -> some View {
    HStack(spacing: 8) {
      Text("\(n)").font(.footnote.weight(.heavy)).foregroundStyle(.white)
        .frame(minWidth: 24, minHeight: 24).background(Circle().fill(Palette.accent))
      Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
    }
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(.isHeader)
  }

  private var byokSetup: some View {
    VStack(alignment: .leading, spacing: 12) {
      step(1, "Pick your AI company")
      Picker("Provider", selection: Binding(get: { s.provider }, set: { p in
        guard p != s.provider else { return }
        s.provider = p; s.model = nil; s.consentFor = nil // consent is per company
        BrainStore.save(s); Keychain.set(nil, service: Keychain.lunaService); savedKey = nil; checkMsg = nil
      })) { ForEach(KeyProvider.allCases) { Text($0.vendor).tag($0) } }
        .pickerStyle(.segmented)

      step(2, "Paste your key")
      if let k = savedKey, !k.isEmpty {
        HStack {
          Label("\(s.provider.label) key ••••\(String(k.suffix(4)))", systemImage: "key.fill").font(.callout)
          Spacer()
          Button("Remove", role: .destructive) {
            Keychain.set(nil, service: Keychain.lunaService); savedKey = nil; s.consentFor = nil; s.model = nil; checkMsg = nil
          }.accessibilityIdentifier("byok-remove")
        }
        if let m = s.model { Text("Model: \(m)").font(.footnote).foregroundStyle(Palette.ink2) }
      } else {
        SecureField(s.provider.keyHint, text: $paste).textContentType(.password).autocorrectionDisabled().textInputAutocapitalization(.never)
          .padding(10).moonGlass(radius: 12, weight: .thin)
          .accessibilityIdentifier("byok-key")
      }
      Button {
        Task { await check() }
      } label: {
        HStack { if checking { ProgressView() }; Text(savedKey == nil ? "Save and check key" : "Check key again") }
      }
      .buttonStyle(SoftButtonStyle())
      .disabled(checking || (savedKey == nil && paste.trimmingCharacters(in: .whitespaces).count < 8))
      .accessibilityIdentifier("byok-check")
      if let m = checkMsg { Label(m.text, systemImage: m.ok ? "checkmark.seal.fill" : "exclamationmark.triangle.fill").font(.callout).foregroundStyle(m.ok ? Palette.goodInk : Palette.badInk) }

      step(3, "Say it's OK")
      Toggle(isOn: Binding(get: { s.consented }, set: { s.consentFor = $0 ? s.provider : nil })) {
        Text("I understand my child's questions will be sent to **\(s.provider.label)** using my key, and \(s.provider.label)'s own privacy terms apply.").font(.callout)
          .fixedSize(horizontal: false, vertical: true) // consent must never truncate
      }
      .accessibilityIdentifier("byok-consent")
      if savedKey != nil {
        Toggle(isOn: Binding(get: { keyTravels }, set: { on in KeyTravel.setOn(on, settings: s); keyTravels = KeyTravel.isOn })) {
          VStack(alignment: .leading, spacing: 2) {
            Text("Use on my other devices").font(.callout)
            Text("Through iCloud Keychain. Off unless you turn it on.").font(.footnote).foregroundStyle(Palette.ink2)
          }
        }
        .accessibilityIdentifier("byok-travel")
      }
      if let v = s.provider.voice, savedKey != nil {
        Button {
          var vs = VoiceSettings.load()
          vs.mode = v == .openai ? .openai : .gemini
          if !(Requests.voices[v]?.contains(vs.voice) ?? false), let first = Requests.voices[v]?.first { vs.voice = first }
          vs.save()
          checkMsg = (true, "Luna's voice now uses this key too.")
        } label: { Label("Use this key for Luna's voice too", systemImage: "speaker.wave.2.fill") }.font(.callout)
      }
      Accordion(symbol: "key.fill", hue: .gold, title: "About your key", summary: "Where it's kept, where it goes, limits") {
        Point("Your key stays in this device's Keychain and goes only to **\(s.provider.label)**.", hue: .gold)
        Point("Use on my other devices: your key and this OK travel through iCloud Keychain, encrypted by Apple, to your own iPhones and iPads. Off unless you turn it on.", hue: .gold)
        Point("Luna still follows every kid rule: simple words, money topics only, never advice.", hue: .gold)
        Point("Use a key with a spending limit.", hue: .gold)
      }
    }
    .padding(14)
    .moonGlass(radius: 22, weight: .thin)
  }

  private func check() async {
    if savedKey == nil {
      let k = paste.trimmingCharacters(in: .whitespacesAndNewlines)
      Keychain.set(k, service: Keychain.lunaService); savedKey = BrainStore.lunaKey; paste = ""; keyTravels = KeyTravel.isOn
    }
    guard let key = savedKey else { return }
    checking = true; defer { checking = false }
    switch await ByokBrain.check(s.provider, key: key) {
    case let .success(model): s.model = model; checkMsg = (true, "\(s.provider.label) said yes! Luna will use \(model).")
    case let .failure(e): checkMsg = (false, e.message)
    }
  }
}
