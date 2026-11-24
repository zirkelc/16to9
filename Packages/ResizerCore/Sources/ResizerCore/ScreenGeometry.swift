import CoreGraphics
import Foundation

public enum ScreenGeometry {
  /**
   Converts a rectangle between AppKit coordinates (origin at the bottom-left of the primary screen,
   y goes up) and Accessibility coordinates (origin at the top-left of the primary screen, y goes down).
   The conversion is the same in both directions.
   */
  public static func flip(_ rect: CGRect, primaryHeight: CGFloat) -> CGRect {
    CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
  }

  // The index of the screen that shows the largest part of the rectangle, or the nearest screen.
  public static func bestScreen(for rect: CGRect, in screens: [CGRect]) -> Int? {
    guard !screens.isEmpty else { return nil }
    var bestIndex: Int?
    var bestArea: CGFloat = 0
    for (index, screen) in screens.enumerated() {
      let overlap = screen.intersection(rect)
      guard !overlap.isNull else { continue }
      let area = overlap.width * overlap.height
      if area > bestArea {
        bestArea = area
        bestIndex = index
      }
    }
    if let bestIndex { return bestIndex }

    let center = CGPoint(x: rect.midX, y: rect.midY)
    return screens.indices.min { distance(center, screens[$0]) < distance(center, screens[$1]) }
  }

  static func distance(_ point: CGPoint, _ rect: CGRect) -> CGFloat {
    let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
    let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
    return (dx * dx + dy * dy).squareRoot()
  }
}
