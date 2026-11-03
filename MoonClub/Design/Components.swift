import SwiftUI
import MoonClubCore

/// Luna, the club's moon, drawn in vector (crisp at any size) with five moods. She blinks now and then and
/// floats gently; both stop under Reduce Motion. The float is a render-server repeat (no per-frame work).
struct Luna: View {
  enum Mood { case idle, happy, thinking, cheering, sleepy, oops }
  var size: CGFloat = 56
  var wave = false
  var mood: Mood = .idle
  /// Wear the kid's Moon Shop hat (off for shop previews of other hats).
  var dressed = true
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.lunaLook) private var look
  @State private var blink = false
  @State private var bob = false
  var body: some View {
    let s = size / 64
    ZStack {
      Circle().fill(RadialGradient(colors: [Color(hex: 0xFFF8DA), Palette.moon, Palette.moonShade.opacity(0.9)], center: UnitPoint(x: 0.38, y: 0.32), startRadius: 2 * s, endRadius: 40 * s))
      // craters: two soft dimples give her a real moon surface
      Circle().fill(Palette.moonShade.opacity(0.5)).frame(width: 9 * s, height: 9 * s).offset(x: 15 * s, y: -17 * s)
      Circle().fill(Palette.moonShade.opacity(0.4)).frame(width: 6 * s, height: 6 * s).offset(x: -18 * s, y: 16 * s)
      eyes.offset(y: -3 * s)
      mouth
      HStack(spacing: 21 * s) { Circle().fill(Palette.blush.opacity(mood == .sleepy ? 0.35 : 0.6)).frame(width: 7 * s); Circle().fill(Palette.blush.opacity(mood == .sleepy ? 0.35 : 0.6)).frame(width: 7 * s) }.offset(y: 5 * s)
      extras(s)
      if dressed, let hat = look.hat { LunaHat(item: hat, size: 58 * s) }
    }
    .frame(width: 58 * s, height: 58 * s)
    .frame(width: size, height: size)
    .shadow(color: Color(hex: 0xF2BE2E).opacity(0.28), radius: size * 0.2)
    .offset(y: wave && bob ? -size * 0.04 : 0)
    .accessibilityHidden(true)
    .task {
      guard !reduceMotion else { return }
      if wave, !bob { withAnimation(.easeInOut(duration: 2.6).repeatForever()) { bob = true } }
      guard mood != .sleepy else { return }
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(Double.random(in: 3...6)))
        withAnimation(.easeInOut(duration: 0.08)) { blink = true }
        try? await Task.sleep(for: .milliseconds(120))
        withAnimation(.easeInOut(duration: 0.1)) { blink = false }
      }
    }
  }

  @ViewBuilder private var eyes: some View {
    let s = size / 64
    switch mood {
    case .happy, .cheering:
      HStack(spacing: 13 * s) { arcEye(up: true); arcEye(up: true) }
    case .sleepy:
      HStack(spacing: 13 * s) { arcEye(up: false); arcEye(up: false) }
    case .thinking:
      HStack(spacing: 13 * s) { dot; dot }.offset(x: 2 * s, y: -2 * s)
    case .idle:
      HStack(spacing: 13 * s) { dot; dot }
    case .oops: // a wince: squeezed eyes
      HStack(spacing: 13 * s) { squint(left: true); squint(left: false) }
    }
  }
  private func squint(left: Bool) -> some View {
    let s = size / 64
    return Path { p in
      p.move(to: .init(x: left ? 0 : 7 * s, y: 0)); p.addLine(to: .init(x: left ? 7 * s : 0, y: 2.2 * s)); p.addLine(to: .init(x: left ? 0 : 7 * s, y: 4.4 * s))
    }
    .stroke(Palette.midnight, style: .init(lineWidth: 2 * s, lineCap: .round, lineJoin: .round)).frame(width: 7 * s, height: 4.4 * s)
  }
  private var dot: some View { let s = size / 64; return Capsule().fill(Palette.midnight).frame(width: 5.4 * s, height: (blink ? 0.8 : 6) * s) }
  private func arcEye(up: Bool) -> some View {
    let s = size / 64
    return Path { p in
      p.move(to: .init(x: 0, y: up ? 3 * s : 0)); p.addQuadCurve(to: .init(x: 7 * s, y: up ? 3 * s : 0), control: .init(x: 3.5 * s, y: up ? -2.5 * s : 4 * s))
    }
    .stroke(Palette.midnight, style: .init(lineWidth: 2.2 * s, lineCap: .round)).frame(width: 7 * s, height: 4 * s)
  }
  @ViewBuilder private var mouth: some View {
    let s = size / 64
    switch mood {
    case .cheering:
      Path { p in p.move(to: .init(x: 25 * s, y: 37 * s)); p.addQuadCurve(to: .init(x: 39 * s, y: 37 * s), control: .init(x: 32 * s, y: 49 * s)); p.closeSubpath() }
        .fill(Palette.midnight).overlay(Path { p in p.addEllipse(in: CGRect(x: 29 * s, y: 40.5 * s, width: 6 * s, height: 3.4 * s)) }.fill(Palette.blush))
    case .thinking:
      Path { p in p.move(to: .init(x: 28 * s, y: 40 * s)); p.addLine(to: .init(x: 36 * s, y: 38.5 * s)) }.stroke(Palette.midnight, style: .init(lineWidth: 2.2 * s, lineCap: .round))
    case .sleepy:
      Ellipse().stroke(Palette.midnight, lineWidth: 1.8 * s).frame(width: 4 * s, height: 4.6 * s).offset(y: 8 * s)
    case .happy:
      Path { p in p.move(to: .init(x: 24.5 * s, y: 37 * s)); p.addQuadCurve(to: .init(x: 39.5 * s, y: 37 * s), control: .init(x: 32 * s, y: 46 * s)) }.stroke(Palette.midnight, style: .init(lineWidth: 2.4 * s, lineCap: .round))
    case .oops:
      Ellipse().fill(Palette.midnight).frame(width: 6 * s, height: 4.6 * s).offset(y: 8 * s)
    case .idle:
      Path { p in p.move(to: .init(x: 25.5 * s, y: 38 * s)); p.addQuadCurve(to: .init(x: 38.5 * s, y: 38 * s), control: .init(x: 32 * s, y: 43.5 * s)) }.stroke(Palette.midnight, style: .init(lineWidth: 2.4 * s, lineCap: .round))
    }
  }
  @ViewBuilder private func extras(_ s: CGFloat) -> some View {
    switch mood {
    case .cheering:
      Image(systemName: "sparkle").font(.system(size: 12 * s, weight: .bold)).foregroundStyle(Hue.gold.color).offset(x: 30 * s, y: -26 * s)
      Image(systemName: "sparkle").font(.system(size: 8 * s, weight: .bold)).foregroundStyle(Hue.berry.color).offset(x: -31 * s, y: -20 * s)
    case .thinking:
      HStack(spacing: 2 * s) { ForEach(0..<3) { _ in Circle().fill(Palette.ink2.opacity(0.6)).frame(width: 3.4 * s) } }.offset(x: 30 * s, y: -28 * s)
    case .sleepy:
      Text("z").font(.system(size: 13 * s, weight: .heavy, design: .rounded)).foregroundStyle(Palette.accent.opacity(0.7)).offset(x: 28 * s, y: -26 * s)
    default: EmptyView()
    }
  }
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
  /// Stretch to the height offered (e.g. so every card in a pager row matches the tallest).
  var fill = false
  @ViewBuilder var content: Content
  var body: some View {
    VStack(alignment: .leading, spacing: 14) { content }
      .padding(padding)
      .frame(maxWidth: .infinity, maxHeight: fill ? .infinity : nil, alignment: .topLeading)
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
        else if let emoji { Glyph(emoji, size: 52) } else { Luna(size: 56, wave: true) }
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
