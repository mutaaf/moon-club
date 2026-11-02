import SwiftUI
import MoonClubCore

/// Luna, the club's moon, drawn in SwiftUI (crisp at any size). Blinks now and then unless Reduce Motion.
struct Luna: View {
  var size: CGFloat = 56
  var wave = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var blink = false
  @State private var bob = false
  var body: some View {
    let s = size / 64
    ZStack {
      Circle().fill(Palette.moon)
      Circle().fill(Palette.moonShade.opacity(0.55)).mask(alignment: .leading) {
        Ellipse().frame(width: 35 * s, height: 58 * s).offset(x: 3 * s)
      }.clipShape(Circle())
      HStack(spacing: 13 * s) { eye; eye }.offset(y: -3 * s)
      Path { p in p.move(to: .init(x: 25.5 * s, y: 38 * s)); p.addQuadCurve(to: .init(x: 38.5 * s, y: 38 * s), control: .init(x: 32 * s, y: 43.5 * s)) }
        .stroke(Palette.midnight, style: .init(lineWidth: 2.4 * s, lineCap: .round))
      HStack(spacing: 19 * s) { Circle().fill(Palette.blush.opacity(0.6)).frame(width: 6 * s); Circle().fill(Palette.blush.opacity(0.6)).frame(width: 6 * s) }.offset(y: 4 * s)
    }
    .frame(width: 58 * s, height: 58 * s)
    .frame(width: size, height: size)
    .shadow(color: Palette.accent.opacity(0.18), radius: size * 0.18, y: size * 0.08)
    .offset(y: wave && bob ? -size * 0.05 : 0)
    .rotationEffect(.degrees(wave && bob ? -4 : 0))
    .accessibilityHidden(true)
    .task {
      guard !reduceMotion else { return }
      if wave { withAnimation(.easeInOut(duration: 2.4).repeatForever()) { bob = true } }
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(Double.random(in: 3...6)))
        withAnimation(.easeInOut(duration: 0.08)) { blink = true }
        try? await Task.sleep(for: .milliseconds(120))
        withAnimation(.easeInOut(duration: 0.1)) { blink = false }
      }
    }
  }
  private var eye: some View { Capsule().fill(Palette.midnight).frame(width: 5 * size / 64, height: (blink ? 0.8 : 5) * size / 64) }
}

/// Moon-phase badge art: 0 = new moon … 4 = full moon.
struct MoonPhase: View {
  let phase: Int
  var size: CGFloat = 40
  var dim = false
  var body: some View {
    ZStack {
      Circle().fill(Palette.card)
      Group {
        switch max(0, min(4, phase)) {
        case 4: Circle().fill(Palette.accent)
        case 2: Rectangle().fill(Palette.accent).frame(width: size / 2).offset(x: size / 4)
        case 1: Circle().fill(Palette.accent).mask(Rectangle().frame(width: size / 2).offset(x: size / 4)).overlay(Ellipse().fill(Palette.card).frame(width: size * 0.6).offset(x: size * 0.02))
        case 3: Circle().fill(Palette.accent).overlay(Ellipse().fill(Palette.card).frame(width: size * 0.6).offset(x: -size * 0.32).mask(Circle()))
        default: EmptyView()
        }
      }.clipShape(Circle())
      Circle().strokeBorder(Palette.accent, lineWidth: max(1.5, size * 0.06))
    }
    .frame(width: size, height: size)
    .opacity(dim ? 0.3 : 1)
    .accessibilityHidden(true)
  }
}

/// A calm card surface.
struct Card<Content: View>: View {
  var padding: CGFloat = 20
  @ViewBuilder var content: Content
  var body: some View {
    VStack(alignment: .leading, spacing: 14) { content }
      .padding(padding)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
      .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(Palette.line.opacity(0.7), lineWidth: 0.5))
      .shadow(color: Palette.midnight.opacity(0.06), radius: 24, y: 10)
  }
}

struct PrimaryButtonStyle: ButtonStyle {
  var tint: Color = Palette.accent
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.kHeadline)
      .foregroundStyle(.white)
      .frame(maxWidth: .infinity, minHeight: 54)
      .padding(.horizontal, 18)
      .background(tint, in: Capsule())
      .scaleEffect(configuration.isPressed ? 0.97 : 1)
      .opacity(configuration.isPressed ? 0.9 : 1)
      .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
  }
}
struct SoftButtonStyle: ButtonStyle {
  var selected = false
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.kHeadline)
      .foregroundStyle(selected ? Color.white : Palette.ink)
      .multilineTextAlignment(.leading)
      .padding(.vertical, 6)
      .frame(minHeight: 48)
      .padding(.horizontal, 16)
      .background(selected ? AnyShapeStyle(Palette.midnight) : AnyShapeStyle(.thinMaterial), in: Capsule())
      .overlay(Capsule().strokeBorder(Palette.line, lineWidth: selected ? 0 : 1))
      .scaleEffect(configuration.isPressed ? 0.96 : 1)
      .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
  }
}

/// 🔊 "Read it to me" — app copy only (kid-typed text never goes to a voice provider).
struct ReadAloud: View {
  let source: SpeakSource
  var label = "Read it to me"
  @Environment(AppModel.self) private var app
  @State private var speaking = false
  var body: some View {
    Button {
      speaking = true
      Task { await app.voice.speak(source); speaking = false }
    } label: {
      Label(speaking ? "Reading…" : label, systemImage: speaking ? "waveform" : "speaker.wave.2.fill")
        .symbolEffect(.variableColor.iterative, isActive: speaking)
        .font(.subheadline.weight(.semibold))
        .padding(.horizontal, 14).frame(minHeight: 44)
        .background(Palette.lavender.opacity(0.85), in: Capsule())
        .foregroundStyle(Palette.midnight)
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(label): read this out loud")
  }
}

/// 🌙 PRETEND MONEY pill — on every money surface.
struct PretendPill: View {
  var body: some View {
    Label("Pretend money", systemImage: "moon.fill")
      .font(.caption.weight(.bold)).textCase(.uppercase).tracking(1)
      .padding(.horizontal, 10).padding(.vertical, 5)
      .background(Palette.moon, in: Capsule())
      .foregroundStyle(Palette.midnight)
      .accessibilityLabel("This is pretend money. It isn't real and can't buy anything.")
  }
}

/// Big hero header used by each tab.
struct Hero: View {
  let eyebrow: String
  let title: String
  var accent: String? = nil
  var emoji: String? = nil
  var piggy = false
  var body: some View {
    HStack(alignment: .center, spacing: 14) {
      // iPhone Duo: while the phone is partly open, the art becomes a moon that waxes with the hinge
      // (the piggy bank has its own hinge trick: its lid lifts).
      HingeHeroArt(enabled: !piggy) {
        if piggy { PiggyArt() }
        else if let emoji { Text(emoji).font(.system(size: 44)).accessibilityHidden(true) } else { Luna(size: 56, wave: true) }
      }
      VStack(alignment: .leading, spacing: 4) {
        Eyebrow(text: eyebrow)
        (Text(title) + Text(accent.map { " " + $0 } ?? "").foregroundColor(Palette.accent))
          .font(.kHero).foregroundStyle(Palette.ink).minimumScaleFactor(0.7).lineLimit(2)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

/// Number ticker: coins, prices and points roll instead of jumping.
struct Ticker: View {
  let value: Double
  var format: (Double) -> String = { "\(Int($0.rounded()))" }
  var font: Font = .kHero
  var body: some View {
    Text(format(value)).font(font).monospacedDigit().contentTransition(.numericText(value: value)).animation(.snappy, value: value)
  }
}

func coins(_ v: Double) -> String { "$" + Int(v.rounded()).formatted(.number) }

extension View {
  /// Reading width: comfortable on iPad, full on iPhone.
  func readable(_ max: CGFloat = 640) -> some View { frame(maxWidth: max).frame(maxWidth: .infinity) }
}
