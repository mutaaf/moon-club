import SwiftUI
import MoonClubCore

/// Grown-up corner → "Luna's brain": a guided picker, not bare settings. Three cards, each saying in plain words
/// what it means. Behind the parental gate (it lives inside GrownUpsView).
struct BrainPicker: View {
  @Environment(AppModel.self) private var app
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
      Text("Choose how Luna thinks. You can change it any time.").font(.callout).foregroundStyle(.secondary)
      option(.onDevice, title: "On this device", subtitle: "Apple Intelligence",
             means: "Luna thinks right on this iPhone or iPad. Your child's questions never leave the device. Free, private, and she remembers the chat.",
             status: device == .available ? nil : device.explanation)
      option(.free, title: "Free Luna", subtitle: "Metaphases",
             means: "A free, kid-safe helper on our server. Questions are sent without any name or account and aren't stored. Short answers, one question at a time.",
             status: nil)
      if Distribution.allowsOwnKeys {
        option(.byok, title: "Your own key", subtitle: "Full capabilities",
               means: "Use your own Anthropic, OpenAI, Google or xAI account for Super Luna: longer, richer answers, follow-up memory, deeper “Explain more” on story and report cards, and a friendlier voice.",
               status: nil)
      }
      if Distribution.allowsOwnKeys, s.choice == .byok { byokSetup.transition(.opacity.combined(with: .move(edge: .top))) }
      HStack(spacing: 6) {
        Image(systemName: active.symbol)
        Text("Right now: **\(active.badge)**").accessibilityIdentifier("brain-active")
        if s.choice == .byok && active != .byok { Text("· finish the steps above to switch").foregroundStyle(.secondary) }
      }.font(.footnote)
    }
    .animation(.spring(response: 0.4, dampingFraction: 0.85), value: s)
    .onChange(of: s) { _, v in BrainStore.save(v); app.refreshBrain() }
    .onAppear { device = OnDevice.status() }
  }

  /// The choice the card represents is selected (automatic counts as on-device when it's available, else free).
  private func isSelected(_ k: BrainKind) -> Bool {
    if let c = s.choice { return c == k }
    return k == (device == .available ? .onDevice : .free)
  }

  @ViewBuilder private func option(_ k: BrainKind, title: String, subtitle: String, means: String, status: String?) -> some View {
    let on = isSelected(k)
    Button { s.choice = k } label: {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: k.symbol).font(.title2).frame(width: 34, height: 34).foregroundStyle(on ? Palette.accent : Palette.ink2)
        VStack(alignment: .leading, spacing: 4) {
          HStack(alignment: .firstTextBaseline) {
            Text(title).font(.headline)
            Text(subtitle).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Spacer()
            Image(systemName: on ? "checkmark.circle.fill" : "circle").foregroundStyle(on ? Palette.accent : .secondary)
          }
          Text(means).font(.callout).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
          if let status { Label(status, systemImage: "info.circle").font(.footnote).foregroundStyle(Palette.bad).fixedSize(horizontal: false, vertical: true) }
        }
      }
      .padding(14)
      .background(on ? Palette.lavender.opacity(0.55) : Color.clear, in: RoundedRectangle(cornerRadius: 18))
      .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(on ? Palette.accent : Color.secondary.opacity(0.25), lineWidth: on ? 2 : 1))
      .contentShape(RoundedRectangle(cornerRadius: 18))
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier("brain-\(k.rawValue)")
    .accessibilityAddTraits(on ? .isSelected : [])
  }

  private var byokSetup: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("1. Pick your AI company").font(.subheadline.weight(.semibold))
      Picker("Provider", selection: Binding(get: { s.provider }, set: { p in
        guard p != s.provider else { return }
        s.provider = p; s.model = nil; s.consentFor = nil // consent is per company
        BrainStore.save(s); Keychain.set(nil, service: Keychain.lunaService); savedKey = nil; checkMsg = nil
      })) { ForEach(KeyProvider.allCases) { Text($0.vendor).tag($0) } }
        .pickerStyle(.segmented)

      Text("2. Paste your key").font(.subheadline.weight(.semibold))
      if let k = savedKey, !k.isEmpty {
        HStack {
          Label("\(s.provider.label) key ••••\(String(k.suffix(4)))", systemImage: "key.fill").font(.callout)
          Spacer()
          Button("Remove", role: .destructive) {
            Keychain.set(nil, service: Keychain.lunaService); savedKey = nil; s.consentFor = nil; s.model = nil; checkMsg = nil
          }.accessibilityIdentifier("byok-remove")
        }
        if let m = s.model { Text("Model: \(m)").font(.footnote).foregroundStyle(.secondary) }
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
      if let m = checkMsg { Label(m.text, systemImage: m.ok ? "checkmark.seal.fill" : "exclamationmark.triangle.fill").font(.callout).foregroundStyle(m.ok ? Palette.good : Palette.bad) }

      Text("3. Say it's OK").font(.subheadline.weight(.semibold))
      Toggle(isOn: Binding(get: { s.consented }, set: { s.consentFor = $0 ? s.provider : nil })) {
        Text("I understand my child's questions will be sent to **\(s.provider.label)** using my key, and \(s.provider.label)'s own privacy terms apply.").font(.callout)
      }
      .accessibilityIdentifier("byok-consent")
      if savedKey != nil {
        Toggle(isOn: Binding(get: { keyTravels }, set: { on in KeyTravel.setOn(on, settings: s); keyTravels = KeyTravel.isOn })) {
          VStack(alignment: .leading, spacing: 2) {
            Text("Use on my other devices").font(.callout)
            Text("Your key and this OK travel through iCloud Keychain, encrypted by Apple, to your own iPhones and iPads. Off unless you turn it on.").font(.footnote).foregroundStyle(.secondary)
          }
        }
        .accessibilityIdentifier("byok-travel")
      }
      if let v = s.provider.voice, savedKey != nil {
        Button {
          var vs = VoiceSettings.load()
          vs.mode = v == .openai ? .openai : .gemini
          if !(Requests.voices[v]?.contains(vs.voice) ?? false) { vs.voice = Requests.voices[v]![0] }
          vs.save()
          checkMsg = (true, "Luna's voice now uses this key too.")
        } label: { Label("Use this key for Luna's voice too", systemImage: "speaker.wave.2.fill") }.font(.callout)
      }
      Text("Your key stays in this device's Keychain and goes only to \(s.provider.label). Luna still follows every kid rule: simple words, money topics only, never advice. Use a key with a spending limit.").font(.footnote).foregroundStyle(.secondary)
    }
    .padding(14)
    .moonGlass(radius: 18, weight: .thin)
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
