import SwiftUI

/**
 A short loop that shows the two ways to use the app: pick 16:9 in the menu, and the window gets
 16:9; then show the guide, and the window moves into the frame until its edges turn green.
 One clock drives all parts, so each moment of the loop looks the same every time.
 */
struct OnboardingDemo: View {
  static let duration = 9.0
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    TimelineView(.animation(paused: reduceMotion)) { timeline in
      let seconds = timeline.date.timeIntervalSinceReferenceDate
      let t = reduceMotion ? 0.9 : seconds.truncatingRemainder(dividingBy: Self.duration) / Self.duration
      DemoFrame(t: t, showsCaption: true)
    }
    .accessibilityElement()
    .accessibilityLabel("Animation: 16to9 resizes a window to 16:9, then a guide with rulers shows a frame for the window.")
  }
}

// Only the guide part of the loop: the guide with rulers shows, and the window moves into its frame until the edges turn green.
struct GuideDemo: View {
  static let duration = 4.5
  // The part of the full loop that shows the guide.
  static let range = 0.5...1.0
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    TimelineView(.animation(paused: reduceMotion)) { timeline in
      let seconds = timeline.date.timeIntervalSinceReferenceDate
      let local = reduceMotion ? 0.8 : seconds.truncatingRemainder(dividingBy: Self.duration) / Self.duration
      DemoFrame(t: Self.range.lowerBound + local * (Self.range.upperBound - Self.range.lowerBound), showsCaption: false)
    }
    .accessibilityElement()
    .accessibilityLabel("Animation: a guide with rulers shows a frame, and a window moves into the frame.")
  }
}

private struct DemoFrame: View {
  let t: Double
  let showsCaption: Bool

  // The layout uses a design space of 540 × 244 points.
  static let space = CGSize(width: 540, height: 244)
  // A 3:2 window, the same window at 16:9, and a 16:9 guide frame.
  static let start = CGRect(x: 90, y: 50, width: 240, height: 160)
  static let ratio = CGRect(x: 90, y: 50, width: 240, height: 135)
  static let guide = CGRect(x: 78, y: 48, width: 288, height: 162)

  var body: some View {
    let popover = Self.ramp(t, 0.05, 0.09) * (1 - Self.ramp(t, 0.32, 0.36))
    let toRatio = Self.ease(Self.ramp(t, 0.33, 0.39))
    let toGuide = Self.ease(Self.ramp(t, 0.62, 0.86))
    let window = Self.mix(Self.mix(Self.start, Self.ratio, toRatio), Self.guide, toGuide)
    let guideOpacity = Self.ramp(t, 0.55, 0.6) * (1 - Self.ramp(t, 0.96, 1))
    let matches = t > 0.86
    let readout = Self.ramp(t, 0.38, 0.42) * (1 - Self.ramp(t, 0.52, 0.56))

    GeometryReader { geometry in
      let scale = geometry.size.width / Self.space.width
      ZStack(alignment: .topLeading) {
        LinearGradient(
          colors: [Color(red: 0.17, green: 0.24, blue: 0.42), Color(red: 0.25, green: 0.17, blue: 0.33)],
          startPoint: .topLeading, endPoint: .bottomTrailing)

        menuBar(highlight: popover > 0.5)

        windowView
          .frame(width: window.width, height: window.height)
          .offset(x: window.minX, y: window.minY)

        guideView(matches: matches)
          .opacity(guideOpacity)

        menu(highlight16x9: t > 0.18)
          .opacity(popover)
          .offset(x: 330, y: 20 + 4 * (1 - popover))

        Text(verbatim: "1200 × 800  →  1200 × 675 px")
          .font(.system(size: 11, weight: .semibold, design: .monospaced))
          .foregroundStyle(.white)
          .padding(.horizontal, 7)
          .padding(.vertical, 3)
          .background(Capsule().fill(.black.opacity(0.45)))
          .offset(x: Self.ratio.minX, y: Self.ratio.maxY + 6)
          .opacity(readout)

        if showsCaption { caption }
      }
      .frame(width: Self.space.width, height: Self.space.height, alignment: .topLeading)
      .scaleEffect(scale, anchor: .topLeading)
    }
    .aspectRatio(Self.space.width / Self.space.height, contentMode: .fit)
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.white.opacity(0.12), lineWidth: 0.5))
  }

  private var windowView: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 4) {
        ForEach([Color.red, .yellow, .green], id: \.self) { Circle().fill($0.opacity(0.85)).frame(width: 6, height: 6) }
      }
      .padding(.horizontal, 7)
      .frame(maxWidth: .infinity, minHeight: 15, alignment: .leading)
      .background(Color(white: 0.9))
      VStack(alignment: .leading, spacing: 7) {
        RoundedRectangle(cornerRadius: 2).fill(Color(white: 0.17)).frame(width: 110, height: 10)
        ForEach([0.8, 0.62, 0.72], id: \.self) { width in
          RoundedRectangle(cornerRadius: 2).fill(Color(white: 0.8)).frame(maxWidth: .infinity).frame(height: 6)
            .padding(.trailing, 160 * (1 - width))
        }
      }
      .padding(12)
      Spacer(minLength: 0)
    }
    .background(Color(white: 0.96))
    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    .shadow(color: .black.opacity(0.4), radius: 10, y: 5)
  }

  private func guideView(matches: Bool) -> some View {
    let frame = Self.guide
    let color = OnboardingView.accent
    return ZStack(alignment: .topLeading) {
      Canvas { context, size in
        var dim = Path(CGRect(origin: .zero, size: size))
        dim.addRect(frame)
        context.fill(dim, with: .color(.black.opacity(0.35)), style: FillStyle(eoFill: true))
        var lines = Path()
        for x in [frame.minX, frame.maxX] {
          lines.move(to: CGPoint(x: x, y: 16))
          lines.addLine(to: CGPoint(x: x, y: size.height))
        }
        for y in [frame.minY, frame.maxY] {
          lines.move(to: CGPoint(x: 0, y: y))
          lines.addLine(to: CGPoint(x: size.width, y: y))
        }
        context.stroke(lines, with: .color(color.opacity(0.3)), lineWidth: 0.5)
        context.stroke(Path(frame), with: .color(matches ? .green : color), lineWidth: 2)
        drawRulers(context, size: size, color: color)
      }
      Text(verbatim: "Full HD · 1920 × 1080 px")
        .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
        .foregroundStyle(Brand.ink)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(RoundedRectangle(cornerRadius: 3).fill(color))
        .offset(x: frame.minX, y: frame.minY - 18)
    }
    .frame(width: Self.space.width, height: Self.space.height)
  }

  /**
   Rulers at the top and the left of the screen, below the menu bar, like the real guide.
   A tick is each 10 points, with a number each 50 points. The numbers are sample pixel values.
   */
  private func drawRulers(_ context: GraphicsContext, size: CGSize, color: Color) {
    let top = 16.0
    let thickness = 12.0
    let band = Color(red: 0.08, green: 0.1, blue: 0.16).opacity(0.92)
    context.fill(Path(CGRect(x: 0, y: top, width: size.width, height: thickness)), with: .color(band))
    context.fill(Path(CGRect(x: 0, y: top + thickness, width: thickness, height: size.height - top - thickness)), with: .color(band))
    var ticks = Path()
    for x in stride(from: thickness + 10, to: size.width, by: 10) {
      let major = Int(x - thickness) % 50 == 0
      ticks.move(to: CGPoint(x: x, y: top + thickness - (major ? thickness : 4)))
      ticks.addLine(to: CGPoint(x: x, y: top + thickness))
      if major {
        let label = Text(verbatim: "\(Int(x - thickness) * 8)").font(.system(size: 6, design: .monospaced)).foregroundStyle(.white.opacity(0.6))
        context.draw(label, at: CGPoint(x: x + 2, y: top + 1), anchor: .topLeading)
      }
    }
    for y in stride(from: top + thickness + 10, to: size.height, by: 10) {
      let major = Int(y - top - thickness) % 50 == 0
      ticks.move(to: CGPoint(x: thickness - (major ? thickness : 4), y: y))
      ticks.addLine(to: CGPoint(x: thickness, y: y))
    }
    context.stroke(ticks, with: .color(.white.opacity(0.45)), lineWidth: 0.5)
    // The position of the frame on each ruler.
    var marks = Path()
    for x in [Self.guide.minX, Self.guide.maxX] {
      marks.move(to: CGPoint(x: x, y: top))
      marks.addLine(to: CGPoint(x: x, y: top + thickness))
    }
    for y in [Self.guide.minY, Self.guide.maxY] {
      marks.move(to: CGPoint(x: 0, y: y))
      marks.addLine(to: CGPoint(x: thickness, y: y))
    }
    context.stroke(marks, with: .color(color), lineWidth: 1.5)
  }

  private func menuBar(highlight: Bool) -> some View {
    HStack(spacing: 12) {
      Spacer()
      Image(systemName: "wifi")
      Image(nsImage: MenuBarIcon.image)
        .renderingMode(.template)
        .resizable()
        .frame(width: 13, height: 10)
        .padding(.horizontal, 3)
        .padding(.vertical, 1)
        .background(RoundedRectangle(cornerRadius: 3).fill(.white.opacity(highlight ? 0.3 : 0)))
      Text(verbatim: "Mon 9:41")
    }
    .font(.system(size: 9))
    .foregroundStyle(.white.opacity(0.85))
    .padding(.horizontal, 10)
    .frame(width: Self.space.width, height: 16)
    .background(.black.opacity(0.35))
  }

  private func menu(highlight16x9: Bool) -> some View {
    VStack(spacing: 1) {
      row("Full HD", "1920 × 1080", false)
      row("16:9", "→ 1200 × 675", highlight16x9)
      row("Open Graph", "1200 × 630", false)
    }
    .padding(4)
    .frame(width: 180)
    .background(RoundedRectangle(cornerRadius: 8).fill(Color(white: 0.16).opacity(0.97)))
    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.white.opacity(0.15), lineWidth: 0.5))
    .shadow(color: .black.opacity(0.45), radius: 10, y: 5)
  }

  private func row(_ name: String, _ size: String, _ highlighted: Bool) -> some View {
    HStack {
      Text(verbatim: name)
      Spacer()
      Text(verbatim: size).font(.system(size: 9.5, design: .monospaced)).opacity(0.7)
    }
    .font(.system(size: 11))
    .foregroundStyle(.white)
    .padding(.horizontal, 7)
    .frame(height: 21)
    .background(RoundedRectangle(cornerRadius: 5).fill(highlighted ? Color.accentColor : .clear))
  }

  private var caption: some View {
    let first = 1 - Self.ramp(t, 0.52, 0.56)
    return ZStack {
      Brand.text("Pick a size or ratio in the menu bar. 16to9 resizes the front window.", size: 12).opacity(first)
      Text("Or show a guide with rulers, and fit the window by hand.").opacity(1 - first)
    }
    .font(.system(size: 12, weight: .medium))
    .foregroundStyle(.white)
    .shadow(color: .black.opacity(0.6), radius: 3)
    .frame(width: Self.space.width)
    .offset(y: Self.space.height - 22)
  }

  // MARK: Math

  // 0 before `start`, 1 after `end`, and a straight line between them.
  static func ramp(_ t: Double, _ start: Double, _ end: Double) -> Double {
    min(max((t - start) / (end - start), 0), 1)
  }

  static func ease(_ x: Double) -> Double { x * x * (3 - 2 * x) }

  static func mix(_ a: CGRect, _ b: CGRect, _ f: Double) -> CGRect {
    let f = CGFloat(f)
    return CGRect(
      x: a.minX + (b.minX - a.minX) * f, y: a.minY + (b.minY - a.minY) * f,
      width: a.width + (b.width - a.width) * f, height: a.height + (b.height - a.height) * f)
  }
}
