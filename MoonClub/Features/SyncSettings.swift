import SwiftUI
import MoonClubCore

// Grown-up corner (behind the gate): keep progress the same on the family's devices.
//   • Sync with iCloud: opt-in, per device, through the family's own iCloud account (no server of ours)
//   • Move my progress: paste a code from the Metaphases Kids website, merged in, safe to repeat
//   • Reset: this device only, or all devices

/// The sections for the grown-up corner's List.
struct SyncSections: View {
  @Environment(AppModel.self) private var app
  @State private var code = ""
  @State private var importNote: String?
  @State private var importOK = false

  var body: some View {
    Section {
      Toggle(isOn: Binding(get: { app.syncOn }, set: { app.setSync($0) })) {
        Label { VStack(alignment: .leading, spacing: 2) {
          Text("Sync with iCloud").font(.body.weight(.semibold))
          Text(status).font(.caption).foregroundStyle(.secondary)
        } } icon: { Image(systemName: "icloud").foregroundStyle(Palette.accentInk) }
      }
      .disabled(!app.sync.isAvailable && !app.syncOn)
      .accessibilityIdentifier("sync-toggle")
      if app.syncOn {
        Button { app.syncNow() } label: { Label("Sync now", systemImage: "arrow.triangle.2.circlepath") }
      }
    } header: { Text("Your devices").id("sync") } footer: {
      Text("Lessons, quests, badges, guesses and the piggy bank stay the same on every iPhone and iPad signed in to the same iCloud account. It goes through your iCloud, not to us. Turn it on only on devices one child uses: two kids sharing an Apple ID would share progress.")
    }

    Section {
      TextField("Paste the code from the website", text: $code, axis: .vertical)
        .font(code.isEmpty ? .body : .system(.footnote, design: .monospaced)).lineLimit(2...4)
        .textInputAutocapitalization(.never).autocorrectionDisabled()
        .accessibilityIdentifier("move-code")
      Button {
        switch app.importProgress(code) {
        case .success(let n):
          importOK = true; code = ""
          importNote = n > 0 ? "Moved! \(n) new \(n == 1 ? "thing" : "things") from the website." : "All set. This device already had everything in that code."
        case .failure(let f):
          importOK = false
          importNote = f == .notACode ? "That doesn't look like a progress code. It starts with MOONP1-." : f == .tooBig ? "That code is too long. Make a new one on the website." : "Part of that code is missing or changed. Copy it again."
        }
      } label: { Label("Move my progress", systemImage: "square.and.arrow.down") }
      .disabled(code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      if let importNote {
        Label(importNote, systemImage: importOK ? "checkmark.circle.fill" : "exclamationmark.circle")
          .font(.callout).foregroundStyle(importOK ? Palette.good : .orange)
      }
    } header: { Text("From the website") } footer: {
      Text("On the Metaphases Kids website, open the grown-up corner, tap Make my progress code, copy it, and paste it here. Nothing is uploaded, and pasting the same code twice is harmless.")
    }
  }

  private var status: String {
    if !app.sync.isAvailable && !app.syncOn { return "Sign in to iCloud in Settings to use this." }
    guard app.syncOn else { return "Off on this device" }
    guard let d = app.lastSynced else { return "On · waiting for iCloud" }
    return "On · last synced \(d.formatted(.relative(presentation: .named)))"
  }
}

/// "Reset all progress": asks which devices, so a reset on one iPad can't silently wipe another.
struct ResetProgressButton: View {
  @Environment(AppModel.self) private var app
  @State private var asking = false
  var body: some View {
    Button(role: .destructive) { asking = true } label: { Label("Reset all progress…", systemImage: "trash").foregroundStyle(.red) }
      .accessibilityIdentifier("reset-progress")
      .id("reset")
      #if DEBUG
      .onAppear { if ProcessInfo.processInfo.arguments.contains("-askReset") { Task { try? await Task.sleep(for: .milliseconds(900)); asking = true } } }
      #endif
      .confirmationDialog("Reset Moon Club progress?", isPresented: $asking, titleVisibility: .visible) {
        if app.syncOn {
          Button("Reset on all devices", role: .destructive) { app.resetProgress(.everywhere) }
          Button("This device only (turns off sync here)", role: .destructive) { app.resetProgress(.thisDevice) }
        } else {
          Button("Reset this device", role: .destructive) { app.resetProgress(.thisDevice) }
        }
        Button("Cancel", role: .cancel) {}
      } message: {
        Text(app.syncOn ? "Lessons, quests, badges, guesses and the piggy bank start over. “All devices” resets every iPhone and iPad using this iCloud account." : "Lessons, quests, badges, guesses and the piggy bank start over on this device.")
      }
  }
}
