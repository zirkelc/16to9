import AppKit
import Observation
import SwiftUI

/**
 Shows the new frame of the front window while the user points at a size in the popover: the frame in the
 guide color with its size, and the outline of the window as it is now. For the guide action it also shows the
 rulers of the guide. The panel lets all clicks through.
 */
@Observable
final class SizePreviewController {
  private(set) var frame: CGRect?
  private(set) var windowFrame: CGRect = .zero
  private(set) var screenFrame: CGRect = .zero
  private(set) var visibleFrame: CGRect = .zero
  private(set) var unitsPerPoint: Double = 1
  private(set) var showsRulers = false
  private(set) var label = ""
  private(set) var color = Color.orange

  @ObservationIgnored private let panel = FloatingPanel(clickThrough: true)
  @ObservationIgnored private var panelScreen: CGRect?

  init() {
    panel.setRootView(SizePreviewView(preview: self))
  }

  // All frames are in Accessibility coordinates. The screen is the screen of the window.
  func show(
    frame: CGRect, window: CGRect, screen: ScreenInfo, unitsPerPoint: Double, label: String, color: Color,
    showsRulers: Bool, hiddenFromCapture: Bool
  ) {
    windowFrame = window
    screenFrame = screen.frame
    visibleFrame = screen.visibleFrame
    self.unitsPerPoint = unitsPerPoint
    self.showsRulers = showsRulers
    self.label = label
    self.color = color
    panel.setHiddenFromCapture(hiddenFromCapture)
    if panelScreen != screen.frame {
      panelScreen = screen.frame
      panel.setFrame(screen.screen.frame, display: true)
    }
    // The first frame shows at once. A change to another frame moves the drawing.
    if self.frame == nil {
      self.frame = frame
    } else {
      withAnimation(.easeOut(duration: 0.12)) { self.frame = frame }
    }
    panel.orderFrontRegardless()
  }

  func hide() {
    guard frame != nil else { return }
    frame = nil
    panel.orderOut(nil)
  }
}

private struct SizePreviewView: View {
  let preview: SizePreviewController

  var body: some View {
    let origin = preview.screenFrame.origin
    let window = preview.windowFrame.offsetBy(dx: -origin.x, dy: -origin.y)
    ZStack(alignment: .topLeading) {
      if preview.showsRulers, let frame = preview.frame?.offsetBy(dx: -origin.x, dy: -origin.y) {
        RulerLayer(
          frame: frame, visible: preview.visibleFrame.offsetBy(dx: -origin.x, dy: -origin.y),
          unitsPerPoint: preview.unitsPerPoint, color: preview.color)
      }

      // The window as it is now: a dashed outline with a dark edge, so that it shows on light and dark windows.
      outline(window).stroke(.black.opacity(0.35), lineWidth: 3)
      outline(window).stroke(.white.opacity(0.85), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))

      if let frame = preview.frame?.offsetBy(dx: -origin.x, dy: -origin.y) {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
          .fill(preview.color.opacity(0.16))
          .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(preview.color, lineWidth: 2.5))
          .overlay {
            Text(verbatim: preview.label)
              .font(.system(size: 13, weight: .semibold, design: .monospaced))
              .foregroundStyle(Brand.ink)
              .padding(.horizontal, 9)
              .padding(.vertical, 4)
              .background(preview.color, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
              .fixedSize()
          }
          .frame(width: frame.width, height: frame.height)
          .offset(x: frame.minX, y: frame.minY)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .ignoresSafeArea()
    .accessibilityHidden(true)
  }

  private func outline(_ rect: CGRect) -> Path {
    Path(roundedRect: rect, cornerRadius: 4)
  }
}

// The rulers of the guide. The frame is animatable, so that the rulers move together with the frame.
private struct RulerLayer: View, Animatable {
  var frame: CGRect
  let visible: CGRect
  let unitsPerPoint: Double
  let color: Color

  var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>> {
    get { AnimatablePair(AnimatablePair(frame.minX, frame.minY), AnimatablePair(frame.width, frame.height)) }
    set {
      frame = CGRect(x: newValue.first.first, y: newValue.first.second, width: newValue.second.first, height: newValue.second.second)
    }
  }

  var body: some View {
    Canvas { context, size in
      GuideRulers.draw(context, size: size, visible: visible, frame: frame, unitsPerPoint: unitsPerPoint, color: color)
    }
  }
}
