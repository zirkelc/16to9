import ResizerCore
import SwiftUI

/**
 Draws the guide over a full screen: a dim area outside the frame, guide lines along the frame
 edges, the frame with a color for each edge, and rulers at the top and left of the screen.
 */
struct GuideOverlayView: View {
  let guide: GuideController

  static let matchColor = Color(red: 0.19, green: 0.82, blue: 0.35)

  private var offColor: Color { guide.settings.guideColor.offColor }

  var body: some View {
    let settings = guide.settings
    let screen = guide.screen
    let frame = guide.frame
    let match = guide.match
    let color = settings.guideColor.color
    let dim = settings.dimOutsideGuide
    let centerLines = settings.showCenterLines
    let upp = guide.unitsPerPoint
    let unit = settings.units

    Canvas { context, size in
      guard let screen else { return }
      let local = frame.offsetBy(dx: -screen.frame.minX, dy: -screen.frame.minY)
      let bounds = CGRect(origin: .zero, size: size)

      if dim {
        var path = Path(bounds)
        path.addRect(local)
        context.fill(path, with: .color(.black.opacity(0.32)), style: FillStyle(eoFill: true))
      }

      drawGuideLines(context, local: local, size: size, color: color)
      if centerLines { drawCenterLines(context, local: local, color: color) }
      drawEdges(context, local: local, match: match, color: color)
      if let match { drawDeltas(context, local: local, match: match, unit: unit) }

      GuideRulers.draw(
        context, size: size, visible: screen.visibleFrame.offsetBy(dx: -screen.frame.minX, dy: -screen.frame.minY),
        frame: local, unitsPerPoint: upp, color: color)
    }
    .ignoresSafeArea()
  }

  private func drawGuideLines(_ context: GraphicsContext, local: CGRect, size: CGSize, color: Color) {
    var path = Path()
    for x in [local.minX, local.maxX] {
      path.move(to: CGPoint(x: x, y: 0))
      path.addLine(to: CGPoint(x: x, y: size.height))
    }
    for y in [local.minY, local.maxY] {
      path.move(to: CGPoint(x: 0, y: y))
      path.addLine(to: CGPoint(x: size.width, y: y))
    }
    context.stroke(path, with: .color(color.opacity(0.35)), lineWidth: 1)
  }

  private func drawCenterLines(_ context: GraphicsContext, local: CGRect, color: Color) {
    var path = Path()
    path.move(to: CGPoint(x: local.midX, y: local.minY))
    path.addLine(to: CGPoint(x: local.midX, y: local.maxY))
    path.move(to: CGPoint(x: local.minX, y: local.midY))
    path.addLine(to: CGPoint(x: local.maxX, y: local.midY))
    context.stroke(path, with: .color(color.opacity(0.6)), style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
  }

  // Each edge is drawn just outside the frame, so that it does not cover the window.
  private func drawEdges(_ context: GraphicsContext, local: CGRect, match: GuideMatch?, color: Color) {
    let width: CGFloat = 2
    func edgeColor(_ delta: Int?) -> Color {
      guard let delta else { return color }
      return delta == 0 ? Self.matchColor : offColor
    }
    let outer = local.insetBy(dx: -width, dy: -width)
    context.fill(Path(CGRect(x: outer.minX, y: outer.minY, width: outer.width, height: width)), with: .color(edgeColor(match?.top)))
    context.fill(Path(CGRect(x: outer.minX, y: local.maxY, width: outer.width, height: width)), with: .color(edgeColor(match?.bottom)))
    context.fill(Path(CGRect(x: outer.minX, y: outer.minY, width: width, height: outer.height)), with: .color(edgeColor(match?.left)))
    context.fill(Path(CGRect(x: local.maxX, y: outer.minY, width: width, height: outer.height)), with: .color(edgeColor(match?.right)))
  }

  // Shows how far each edge of the window must move, with an arrow for the direction.
  private func drawDeltas(_ context: GraphicsContext, local: CGRect, match: GuideMatch, unit: SizeUnit) {
    func label(_ text: String, at point: CGPoint, anchor: UnitPoint) {
      let text = Text(text).font(.system(size: 11, weight: .semibold, design: .monospaced)).foregroundStyle(offColor)
      context.draw(text, at: point, anchor: anchor)
    }
    let symbol = unit.symbol
    if match.left != 0 {
      label("\(match.left > 0 ? "←" : "→") \(abs(match.left)) \(symbol)", at: CGPoint(x: local.minX - 8, y: local.midY), anchor: .trailing)
    }
    if match.right != 0 {
      label("\(match.right > 0 ? "←" : "→") \(abs(match.right)) \(symbol)", at: CGPoint(x: local.maxX + 8, y: local.midY), anchor: .leading)
    }
    if match.top != 0 {
      label("\(match.top > 0 ? "↑" : "↓") \(abs(match.top)) \(symbol)", at: CGPoint(x: local.midX, y: local.minY - 8), anchor: .bottom)
    }
    if match.bottom != 0 {
      label("\(match.bottom > 0 ? "↑" : "↓") \(abs(match.bottom)) \(symbol)", at: CGPoint(x: local.midX, y: local.maxY + 8), anchor: .top)
    }
  }
}

enum GuideRulers {
  static let size: CGFloat = 18

  /**
   Draws the rulers along the top and left edges of the visible screen area. Zero is at the top left corner of
   the visible area, so the rulers stay in place while the frame moves. A marker shows the position of each edge
   of the frame. All rectangles are in the coordinates of the canvas.
   */
  static func draw(
    _ context: GraphicsContext, size: CGSize, visible: CGRect, frame local: CGRect, unitsPerPoint upp: Double, color: Color
  ) {
    let top = visible.minY
    let left = visible.minX
    let thickness = Self.size
    let background = Color(red: 0.1, green: 0.1, blue: 0.12).opacity(0.92)
    let tickColor = Color.white.opacity(0.45)
    let labelColor = Color.white.opacity(0.65)
    let marks = GuideGeometry.rulerMarks(frame: local, visible: visible, unitsPerPoint: upp)
    // A tick label next to a marker would overlap the label of the marker.
    func clear(of markers: CGFloat...) -> (CGFloat) -> Bool {
      { offset in markers.allSatisfy { abs(offset - $0) > 40 } }
    }
    let clearTop = clear(of: local.minX, local.maxX)
    let clearLeft = clear(of: local.minY, local.maxY)

    // Top ruler.
    let topRect = CGRect(x: left, y: top, width: size.width - left, height: thickness)
    context.fill(Path(topRect), with: .color(background))
    context.fill(Path(CGRect(x: local.minX, y: top, width: local.width, height: thickness)), with: .color(color.opacity(0.18)))
    let topTicks = GuideGeometry.ticks(length: size.width, origin: left, unitsPerPoint: upp)
    var path = Path()
    for tick in topTicks where tick.offset >= left + thickness {
      let length = tickLength(tick.kind)
      path.move(to: CGPoint(x: tick.offset + 0.5, y: top + thickness - length))
      path.addLine(to: CGPoint(x: tick.offset + 0.5, y: top + thickness))
      if tick.kind == .major, clearTop(tick.offset) {
        context.draw(rulerText("\(tick.value)", labelColor), at: CGPoint(x: tick.offset + 3, y: top + 1), anchor: .topLeading)
      }
    }
    context.stroke(path, with: .color(tickColor), lineWidth: 1)
    drawMarker(context, at: local.minX, value: marks.left, vertical: false, start: top, color: color)
    drawMarker(context, at: local.maxX, value: marks.right, vertical: false, start: top, color: color)

    // Left ruler.
    let leftTop = top + thickness
    let leftRect = CGRect(x: left, y: leftTop, width: thickness, height: size.height - leftTop)
    context.fill(Path(leftRect), with: .color(background))
    context.fill(Path(CGRect(x: left, y: local.minY, width: thickness, height: local.height)), with: .color(color.opacity(0.18)))
    let leftTicks = GuideGeometry.ticks(length: size.height, origin: top, unitsPerPoint: upp)
    path = Path()
    for tick in leftTicks where tick.offset >= leftTop {
      let length = tickLength(tick.kind)
      path.move(to: CGPoint(x: left + thickness - length, y: tick.offset + 0.5))
      path.addLine(to: CGPoint(x: left + thickness, y: tick.offset + 0.5))
      if tick.kind == .major, clearLeft(tick.offset) {
        drawVertical(context, rulerText("\(tick.value)", labelColor), x: left + 1, y: tick.offset + 3)
      }
    }
    context.stroke(path, with: .color(tickColor), lineWidth: 1)
    drawMarker(context, at: local.minY, value: marks.top, vertical: true, start: left, color: color)
    drawMarker(context, at: local.maxY, value: marks.bottom, vertical: true, start: left, color: color)

    // Corner square.
    context.fill(Path(CGRect(x: left, y: top, width: thickness, height: thickness)), with: .color(background))
  }

  private static func drawMarker(_ context: GraphicsContext, at position: CGFloat, value: Int, vertical: Bool, start: CGFloat, color: Color) {
    let thickness = Self.size
    var path = Path()
    let text = Text(verbatim: "\(value)").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(color)
    if vertical {
      path.move(to: CGPoint(x: start, y: position))
      path.addLine(to: CGPoint(x: start + thickness, y: position))
      drawVertical(context, text, x: start + 1, y: position + 3)
    } else {
      path.move(to: CGPoint(x: position, y: start))
      path.addLine(to: CGPoint(x: position, y: start + thickness))
      context.draw(text, at: CGPoint(x: position + 3, y: start + 1), anchor: .topLeading)
    }
    context.stroke(path, with: .color(color), lineWidth: 1.5)
  }

  // Draws text turned by 90 degrees, so that it reads from top to bottom along the left ruler.
  private static func drawVertical(_ context: GraphicsContext, _ text: Text, x: CGFloat, y: CGFloat) {
    var layer = context
    layer.translateBy(x: x, y: y)
    layer.rotate(by: .degrees(90))
    layer.draw(text, at: CGPoint(x: 0, y: -Self.size + 2), anchor: .topLeading)
  }

  private static func rulerText(_ value: String, _ color: Color) -> Text {
    Text(value).font(.system(size: 9, design: .monospaced)).foregroundStyle(color)
  }

  private static func tickLength(_ kind: RulerTick.Kind) -> CGFloat {
    switch kind {
    case .major: Self.size
    case .medium: 8
    case .minor: 4
    }
  }
}
