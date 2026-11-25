import SwiftUI

// The resize from the menu: first 16:9 from the list, then a ratio typed in the search field.
struct ResizeDemo: View {
  static let duration = 10.0
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    TimelineView(.animation(paused: reduceMotion)) { timeline in
      let seconds = timeline.date.timeIntervalSinceReferenceDate
      let t = reduceMotion ? 0.4 : seconds.truncatingRemainder(dividingBy: Self.duration) / Self.duration
      ResizeDemoFrame(t: t)
    }
    .accessibilityElement()
    .accessibilityLabel("Animation: 16to9 resizes a window to 16:9 from the menu, then to 4:5 from a typed ratio.")
  }
}

private struct ResizeDemoFrame: View {
  let t: Double

  // A 3:2 window, the same window at 16:9, and at 4:5 with the same height.
  static let start = CGRect(x: 90, y: 50, width: 240, height: 160)
  static let wide = CGRect(x: 90, y: 50, width: 240, height: 135)
  static let tall = CGRect(x: 90, y: 50, width: 108, height: 135)
  static let typed = "4:5"

  var body: some View {
    let ramp = DemoFrame.ramp
    // The first part: 16:9 from the list.
    let firstMenu = ramp(t, 0.04, 0.07) * (1 - ramp(t, 0.24, 0.27))
    let toWide = DemoFrame.ease(ramp(t, 0.25, 0.31))
    let firstReadout = ramp(t, 0.31, 0.34) * (1 - ramp(t, 0.44, 0.47))
    // The second part: "4:5" typed in the search field, then Return.
    let secondMenu = ramp(t, 0.5, 0.53) * (1 - ramp(t, 0.74, 0.77))
    let toTall = DemoFrame.ease(ramp(t, 0.75, 0.81))
    let secondReadout = ramp(t, 0.81, 0.84) * (1 - ramp(t, 0.94, 0.97))
    let window = DemoFrame.mix(DemoFrame.mix(Self.start, Self.wide, toWide), Self.tall, toTall)
    let letters = t < 0.57 ? 0 : t < 0.61 ? 1 : t < 0.65 ? 2 : 3
    let search = t > 0.5 ? String(Self.typed.prefix(letters)) : ""
    let rows: [DemoScene.MenuRow] =
      if t < 0.5 {
        [.init("Full HD", "1920 × 1080"), .init("16:9", "→ 1200 × 675", isHighlighted: t > 0.14), .init("Open Graph", "1200 × 630")]
      } else if letters == 0 {
        [.init("Full HD", "1920 × 1080"), .init("16:9", "→ 1200 × 675"), .init("Open Graph", "1200 × 630")]
      } else if letters < 3 {
        [.init("4:3", "→ 1200 × 900"), .init("4:5", "→ 540 × 675")]
      } else {
        [.init("4:5", "→ 540 × 675", isHighlighted: true)]
      }
    let menu = t < 0.5 ? firstMenu : secondMenu
    // The caret blinks two times a second.
    let showsCaret = t > 0.5 && Int(t * ResizeDemo.duration * 2) % 2 == 0

    GeometryReader { geometry in
      let scale = geometry.size.width / DemoScene.space.width
      ZStack(alignment: .topLeading) {
        DemoScene.background
        DemoScene.menuBar(highlight: menu > 0.5)

        DemoScene.window
          .frame(width: window.width, height: window.height)
          .offset(x: window.minX, y: window.minY)

        DemoScene.menu(search: search, showsCaret: showsCaret, rows: rows)
          .opacity(menu)
          .offset(x: 330, y: 20 + 4 * (1 - menu))

        DemoScene.readout("1200 × 800  →  1200 × 675 px")
          .offset(x: Self.wide.minX, y: Self.wide.maxY + 6)
          .opacity(firstReadout)
        DemoScene.readout("1200 × 675  →  540 × 675 px")
          .offset(x: Self.tall.minX, y: Self.tall.maxY + 6)
          .opacity(secondReadout)
      }
      .frame(width: DemoScene.space.width, height: DemoScene.space.height, alignment: .topLeading)
      .opacity(ramp(t, 0, 0.03) * (1 - ramp(t, 0.97, 1)))
      .background(DemoScene.background)
      .scaleEffect(scale, anchor: .topLeading)
    }
    .aspectRatio(DemoScene.space.width / DemoScene.space.height, contentMode: .fit)
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    .hairlineBorder(RoundedRectangle(cornerRadius: 12, style: .continuous), .white.opacity(0.12))
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
      DemoFrame(t: Self.range.lowerBound + local * (Self.range.upperBound - Self.range.lowerBound))
    }
    .accessibilityElement()
    .accessibilityLabel("Animation: a guide with rulers shows a frame, and a window moves into the frame.")
  }
}

/**
 The guide for an area of a window: the guide shows, the window moves until its canvas is at the corner of the frame,
 then the pointer drags the corner of the window until the canvas fills the frame. The guide compares only the whole
 window, so its edges stay in the guide color, and only the canvas shows that it fits.
 */
struct AreaDemo: View {
  static let duration = 7.0
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    TimelineView(.animation(paused: reduceMotion)) { timeline in
      let seconds = timeline.date.timeIntervalSinceReferenceDate
      let t = reduceMotion ? 0.85 : seconds.truncatingRemainder(dividingBy: Self.duration) / Self.duration
      AreaDemoFrame(t: t)
    }
    .accessibilityElement()
    .accessibilityLabel("Animation: a guide with rulers shows a frame, and a window is resized by hand until a canvas in it fills the frame.")
  }
}

private struct AreaDemoFrame: View {
  let t: Double

  static let guide = CGRect(x: 150, y: 46, width: 288, height: 162)
  // The window has a title bar, a sidebar and a canvas with a margin around it.
  static let titleBar: CGFloat = 15
  static let sidebar: CGFloat = 60
  static let margin: CGFloat = 8
  static let start = CGRect(x: 60, y: 70, width: 280, height: 150)
  // The canvas is at the top-left corner of the frame.
  static let aligned = CGRect(x: guide.minX - sidebar - margin, y: guide.minY - titleBar - margin, width: start.width, height: start.height)
  // The canvas fills the frame.
  static let fitted = CGRect(
    x: aligned.minX, y: aligned.minY, width: guide.width + sidebar + 2 * margin, height: guide.height + titleBar + 2 * margin)

  static func canvas(in window: CGRect) -> CGRect {
    CGRect(
      x: window.minX + sidebar + margin, y: window.minY + titleBar + margin,
      width: window.width - sidebar - 2 * margin, height: window.height - titleBar - 2 * margin)
  }

  var body: some View {
    let ramp = DemoFrame.ramp
    let move = DemoFrame.ease(ramp(t, 0.14, 0.36))
    let resize = DemoFrame.ease(ramp(t, 0.46, 0.76))
    let window = DemoFrame.mix(DemoFrame.mix(Self.start, Self.aligned, move), Self.fitted, resize)
    let canvas = Self.canvas(in: window)
    let fits = ramp(t, 0.77, 0.81)
    // The pointer holds the title bar, then goes to the bottom-right corner of the window.
    let grip = CGPoint(x: window.minX + 150, y: window.minY + 7)
    let corner = CGPoint(x: window.maxX - 3, y: window.maxY - 3)
    let toCorner = DemoFrame.ease(ramp(t, 0.38, 0.45))
    let pointer = CGPoint(x: grip.x + (corner.x - grip.x) * toCorner, y: grip.y + (corner.y - grip.y) * toCorner)
    let isPressed = (t > 0.13 && t < 0.37) || (t > 0.45 && t < 0.77)
    let pointerOpacity = ramp(t, 0.08, 0.12) * (1 - ramp(t, 0.8, 0.84))

    GeometryReader { geometry in
      let scale = geometry.size.width / DemoScene.space.width
      ZStack(alignment: .topLeading) {
        DemoScene.background
        DemoScene.menuBar(highlight: false)

        windowView(canvasFits: fits)
          .frame(width: window.width, height: window.height)
          .offset(x: window.minX, y: window.minY)

        DemoScene.guide(frame: Self.guide, matches: false)
          .opacity(ramp(t, 0.03, 0.08))

        // The canvas shows above the dimmed area, because it is the part that the user fits.
        Text(verbatim: "1920 × 1080 px")
          .font(.system(size: 10, weight: .semibold, design: .monospaced))
          .foregroundStyle(.white)
          .padding(.horizontal, 7)
          .padding(.vertical, 3)
          .background(Capsule().fill(Color.green.opacity(0.85)))
          .frame(width: canvas.width, height: canvas.height)
          .offset(x: canvas.minX, y: canvas.minY)
          .opacity(fits)

        Image(systemName: "cursorarrow")
          .font(.system(size: 15))
          .foregroundStyle(.white)
          .shadow(color: .black.opacity(0.7), radius: 1.5)
          .scaleEffect(isPressed ? 0.88 : 1)
          .offset(x: pointer.x - 3, y: pointer.y - 2)
          .opacity(pointerOpacity)
      }
      .frame(width: DemoScene.space.width, height: DemoScene.space.height, alignment: .topLeading)
      .opacity(ramp(t, 0, 0.03) * (1 - ramp(t, 0.95, 1)))
      .background(DemoScene.background)
      .scaleEffect(scale, anchor: .topLeading)
    }
    .aspectRatio(DemoScene.space.width / DemoScene.space.height, contentMode: .fit)
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    .hairlineBorder(RoundedRectangle(cornerRadius: 12, style: .continuous), .white.opacity(0.12))
  }

  // A window with a title bar, a sidebar and a canvas, for example of a drawing app or a video player.
  private func windowView(canvasFits: Double) -> some View {
    VStack(spacing: 0) {
      HStack(spacing: 4) {
        ForEach([Color.red, .yellow, .green], id: \.self) { Circle().fill($0.opacity(0.85)).frame(width: 6, height: 6) }
      }
      .padding(.horizontal, 7)
      .frame(maxWidth: .infinity, minHeight: Self.titleBar, maxHeight: Self.titleBar, alignment: .leading)
      .background(Color(white: 0.9))
      HStack(spacing: 0) {
        VStack(alignment: .leading, spacing: 6) {
          ForEach(0..<4, id: \.self) { _ in
            RoundedRectangle(cornerRadius: 2).fill(Color(white: 0.78)).frame(height: 6)
          }
          Spacer(minLength: 0)
        }
        .padding(8)
        .frame(width: Self.sidebar)
        .frame(maxHeight: .infinity)
        .background(Color(white: 0.9))
        ZStack {
          LinearGradient(
            colors: [Color(red: 0.98, green: 0.71, blue: 0.36), Color(red: 0.9, green: 0.38, blue: 0.62), Color(red: 0.4, green: 0.45, blue: 0.95)],
            startPoint: .topLeading, endPoint: .bottomTrailing)
          Image(systemName: "photo")
            .font(.system(size: 18))
            .foregroundStyle(.white.opacity(0.7))
        }
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Color.green, lineWidth: 2).opacity(canvasFits))
        .padding(Self.margin)
      }
    }
    .background(Color(white: 0.96))
    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    .shadow(color: .black.opacity(0.4), radius: 10, y: 5)
  }
}

// The demo loop with the resize from the menu (first half) and the guide for a whole window (second half).
private struct DemoFrame: View {
  let t: Double

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
      let scale = geometry.size.width / DemoScene.space.width
      ZStack(alignment: .topLeading) {
        DemoScene.background

        DemoScene.menuBar(highlight: popover > 0.5)

        DemoScene.window
          .frame(width: window.width, height: window.height)
          .offset(x: window.minX, y: window.minY)

        DemoScene.guide(frame: Self.guide, matches: matches)
          .opacity(guideOpacity)

        DemoScene.menu(
          search: "", showsCaret: false,
          rows: [.init("Full HD", "1920 × 1080"), .init("16:9", "→ 1200 × 675", isHighlighted: t > 0.18), .init("Open Graph", "1200 × 630")]
        )
        .opacity(popover)
        .offset(x: 330, y: 20 + 4 * (1 - popover))

        DemoScene.readout("1200 × 800  →  1200 × 675 px")
          .offset(x: Self.ratio.minX, y: Self.ratio.maxY + 6)
          .opacity(readout)
      }
      .frame(width: DemoScene.space.width, height: DemoScene.space.height, alignment: .topLeading)
      .scaleEffect(scale, anchor: .topLeading)
    }
    .aspectRatio(DemoScene.space.width / DemoScene.space.height, contentMode: .fit)
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    .hairlineBorder(RoundedRectangle(cornerRadius: 12, style: .continuous), .white.opacity(0.12))
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

// The parts that all demos share: the desktop, the menu bar and the guide with rulers.
enum DemoScene {
  // The layout uses a design space of 540 × 244 points.
  static let space = CGSize(width: 540, height: 244)

  static var background: some View {
    LinearGradient(
      colors: [Color(red: 0.17, green: 0.24, blue: 0.42), Color(red: 0.25, green: 0.17, blue: 0.33)],
      startPoint: .topLeading, endPoint: .bottomTrailing)
  }

  static func guide(frame: CGRect, matches: Bool) -> some View {
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
        drawRulers(context, size: size, color: color, frame: frame)
      }
      Text(verbatim: "Full HD · 1920 × 1080 px")
        .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
        .foregroundStyle(Brand.ink)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(RoundedRectangle(cornerRadius: 3).fill(color))
        .offset(x: frame.minX, y: frame.minY - 18)
    }
    .frame(width: space.width, height: space.height)
  }

  /**
   Rulers at the top and the left of the screen, below the menu bar, like the real guide.
   A tick is each 10 points, with a number each 50 points. The numbers are sample pixel values.
   */
  private static func drawRulers(_ context: GraphicsContext, size: CGSize, color: Color, frame: CGRect) {
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
    for x in [frame.minX, frame.maxX] {
      marks.move(to: CGPoint(x: x, y: top))
      marks.addLine(to: CGPoint(x: x, y: top + thickness))
    }
    for y in [frame.minY, frame.maxY] {
      marks.move(to: CGPoint(x: 0, y: y))
      marks.addLine(to: CGPoint(x: thickness, y: y))
    }
    context.stroke(marks, with: .color(color), lineWidth: 1.5)
  }

  // A plain app window with a title bar and lines of text.
  static var window: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 4) {
        ForEach([Color.red, .yellow, .green], id: \.self) { Circle().fill($0.opacity(0.85)).frame(width: 6, height: 6) }
      }
      .padding(.horizontal, 7)
      .frame(maxWidth: .infinity, minHeight: 15, alignment: .leading)
      .background(Color(white: 0.9))
      VStack(alignment: .leading, spacing: 7) {
        RoundedRectangle(cornerRadius: 2).fill(Color(white: 0.17)).frame(maxWidth: 110).frame(height: 10)
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

  struct MenuRow: Identifiable {
    let name: String
    let size: String
    var isHighlighted = false
    var id: String { name }

    init(_ name: String, _ size: String, isHighlighted: Bool = false) {
      self.name = name
      self.size = size
      self.isHighlighted = isHighlighted
    }
  }

  // The menu of the app with its search field and a few rows.
  static func menu(search: String, showsCaret: Bool, rows: [MenuRow]) -> some View {
    VStack(spacing: 1) {
      HStack(spacing: 4) {
        Image(systemName: "magnifyingglass").font(.system(size: 9)).opacity(0.6)
        if search.isEmpty && !showsCaret {
          Text("Size or ratio").opacity(0.45)
        } else {
          Text(verbatim: search)
          Rectangle().fill(Color.accentColor).frame(width: 1.5, height: 11).opacity(showsCaret ? 1 : 0)
        }
        Spacer(minLength: 0)
      }
      .font(.system(size: 11))
      .foregroundStyle(.white)
      .padding(.horizontal, 7)
      .frame(height: 22)
      .background(RoundedRectangle(cornerRadius: 5).fill(.white.opacity(0.08)))
      .padding(.bottom, 3)
      ForEach(rows) { row in
        HStack {
          Text(verbatim: row.name)
          Spacer()
          Text(verbatim: row.size).font(.system(size: 9.5, design: .monospaced)).opacity(0.7)
        }
        .font(.system(size: 11))
        .foregroundStyle(.white)
        .padding(.horizontal, 7)
        .frame(height: 21)
        .background(RoundedRectangle(cornerRadius: 5).fill(row.isHighlighted ? Color.accentColor : .clear))
      }
    }
    .padding(4)
    .frame(width: 180)
    .background(RoundedRectangle(cornerRadius: 8).fill(Color(white: 0.16).opacity(0.97)))
    .hairlineBorder(RoundedRectangle(cornerRadius: 8), .white.opacity(0.15))
    .shadow(color: .black.opacity(0.45), radius: 10, y: 5)
  }

  // The old and the new size below the window.
  static func readout(_ text: String) -> some View {
    Text(verbatim: text)
      .font(.system(size: 11, weight: .semibold, design: .monospaced))
      .foregroundStyle(.white)
      .padding(.horizontal, 7)
      .padding(.vertical, 3)
      .background(Capsule().fill(.black.opacity(0.45)))
  }

  static func menuBar(highlight: Bool) -> some View {
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
    .frame(width: space.width, height: 16)
    .background(.black.opacity(0.35))
  }
}
