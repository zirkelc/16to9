import CoreGraphics
import Foundation

public enum FitMode: String, Codable, CaseIterable, Sendable {
  case smallestChange
  case keepWidth
  case keepHeight
}

public enum ResizeAnchor: String, Codable, CaseIterable, Sendable {
  case topLeft
  case center
}

/**
 The input for a fit calculation. All rectangles are in points, with the origin at the top-left
 corner of the primary screen and y going down (the coordinate space of the Accessibility API).
 */
public struct FitContext: Equatable, Sendable {
  public var window: CGRect
  public var visible: CGRect
  public var unitsPerPoint: Double
  public var mode: FitMode
  public var anchor: ResizeAnchor

  public init(window: CGRect, visible: CGRect, unitsPerPoint: Double, mode: FitMode = .smallestChange, anchor: ResizeAnchor = .topLeft) {
    self.window = window
    self.visible = visible
    self.unitsPerPoint = unitsPerPoint
    self.mode = mode
    self.anchor = anchor
  }
}

// Whether a size is wider or taller than the visible area of a screen.
public struct SizeOverflow: Equatable, Sendable {
  public let isTooWide: Bool
  public let isTooTall: Bool

  public init(isTooWide: Bool, isTooTall: Bool) {
    self.isTooWide = isTooWide
    self.isTooTall = isTooTall
  }

  public var fits: Bool { !isTooWide && !isTooTall }
}

public enum FitCalculator {
  // A size can be larger than the visible area by this amount and still fit (rounding errors).
  static let tolerance: CGFloat = 0.01

  /**
   The sizes to try for a target, best first. The caller sets the first size and reads the size back.
   If the app does not accept it (for example a minimum size), the caller tries the next one.
   An empty list means that the target does not fit on the screen.
   */
  public static func candidates(for target: PresetTarget, in context: FitContext) -> [CGSize] {
    switch target {
    case .size(let width, let height):
      let size = sizeInPoints(width: width, height: height, unitsPerPoint: context.unitsPerPoint)
      return fits(size, in: context.visible) ? [size] : []
    case .ratio(let ratio):
      return ratioCandidates(ratio.value, in: context)
    }
  }

  // The size and position for the first candidate, or nil when the target does not fit.
  public static func frame(for target: PresetTarget, in context: FitContext) -> CGRect? {
    guard let size = candidates(for: target, in: context).first else { return nil }
    return place(size, in: context)
  }

  // Puts a size at the anchor of the current window, then moves it into the visible area.
  public static func place(_ size: CGSize, in context: FitContext) -> CGRect {
    var origin: CGPoint
    switch context.anchor {
    case .topLeft:
      origin = context.window.origin
    case .center:
      origin = CGPoint(x: context.window.midX - size.width / 2, y: context.window.midY - size.height / 2)
      origin = CGPoint(x: snap(origin.x, context.unitsPerPoint), y: snap(origin.y, context.unitsPerPoint))
    }
    let visible = context.visible
    origin.x = max(visible.minX, min(origin.x, visible.maxX - size.width))
    origin.y = max(visible.minY, min(origin.y, visible.maxY - size.height))
    return CGRect(origin: origin, size: size)
  }

  public static func sizeInPoints(width: Int, height: Int, unitsPerPoint: Double) -> CGSize {
    CGSize(width: Double(width) / unitsPerPoint, height: Double(height) / unitsPerPoint)
  }

  public static func fits(_ size: CGSize, in visible: CGRect) -> Bool {
    overflow(of: size, in: visible).fits
  }

  // The sides on which a size is larger than the visible area.
  public static func overflow(of size: CGSize, in visible: CGRect) -> SizeOverflow {
    SizeOverflow(isTooWide: size.width > visible.width + tolerance, isTooTall: size.height > visible.height + tolerance)
  }

  // The largest size with the ratio that fits in the visible area, rounded down to whole units.
  public static func largest(ratio: Double, in visible: CGRect, unitsPerPoint: Double) -> CGSize {
    var width = min(visible.width, visible.height * ratio)
    var height = width / ratio
    width = floorSnap(width, unitsPerPoint)
    height = floorSnap(height, unitsPerPoint)
    return CGSize(width: width, height: height)
  }

  static func ratioCandidates(_ ratio: Double, in context: FitContext) -> [CGSize] {
    let upp = context.unitsPerPoint
    let current = context.window.size
    let keepWidth = CGSize(width: current.width, height: snap(current.width / ratio, upp))
    let keepHeight = CGSize(width: snap(current.height * ratio, upp), height: current.height)

    var ordered: [CGSize]
    switch context.mode {
    case .keepWidth:
      ordered = [keepWidth, keepHeight]
    case .keepHeight:
      ordered = [keepHeight, keepWidth]
    case .smallestChange:
      let widthKeptChange = abs(keepWidth.height - current.height)
      let heightKeptChange = abs(keepHeight.width - current.width)
      if widthKeptChange == heightKeptChange {
        // On a tie, the smaller window is the better choice, because it fits more often.
        let widthKeptArea = keepWidth.width * keepWidth.height
        let heightKeptArea = keepHeight.width * keepHeight.height
        ordered = widthKeptArea <= heightKeptArea ? [keepWidth, keepHeight] : [keepHeight, keepWidth]
      } else {
        ordered = widthKeptChange < heightKeptChange ? [keepWidth, keepHeight] : [keepHeight, keepWidth]
      }
    }

    var result: [CGSize] = []
    for size in ordered where fits(size, in: context.visible) && !result.contains(size) {
      result.append(size)
    }
    if result.isEmpty {
      result.append(largest(ratio: ratio, in: context.visible, unitsPerPoint: upp))
    }
    return result
  }

  static func snap(_ value: CGFloat, _ unitsPerPoint: Double) -> CGFloat {
    (value * unitsPerPoint).rounded() / unitsPerPoint
  }

  static func floorSnap(_ value: CGFloat, _ unitsPerPoint: Double) -> CGFloat {
    // A small offset stops values like 449.99999 from going down one full unit.
    ((value * unitsPerPoint) + 0.000_1).rounded(.down) / unitsPerPoint
  }
}
