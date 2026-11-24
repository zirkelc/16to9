import CoreGraphics

/**
 Where the permission card goes next to the System Settings window. All rectangles use AppKit
 coordinates (origin at the bottom left). The idea comes from the permission panel of Scrawl
 (github.com/kitlangton/scrawl, MIT licence).
 */
public enum PermissionCardLayout {
  public enum Placement: Equatable, Sendable {
    case below, inside, right, left, clamped
  }

  // The list in the Privacy pane starts this far from the left edge of the window (after the sidebar).
  public static let listLeading: CGFloat = 252
  public static let listTrailing: CGFloat = 20
  // Space between the card and the window.
  public static let gap: CGFloat = 10
  // Smallest space between the card and the edge of the screen or window.
  public static let inset: CGFloat = 8
  // Inside the window, the card stays this far above its bottom edge.
  public static let insideBottom: CGFloat = 20
  // The lower part of the Privacy panes has no rows, so the card can cover it.
  public static let emptyLowerShare: CGFloat = 0.3

  // The width of the app row, so that it has the width of the list in System Settings.
  public static func rowWidth(settingsWidth: CGFloat) -> CGFloat {
    max(300, min(settingsWidth - listLeading - listTrailing, 560))
  }

  /**
   The frame of the card, in this order:
   1. Below the window, with the app row under the list, if all of the card is on the screen.
   2. In the empty lower part of the window.
   3. On the right of the window, then on the left.
   4. Else below the window, moved onto the screen.
   `rowLeading` is the space between the left edge of the card and its app row.
   */
  public static func dock(settings: CGRect, visible: CGRect, card: CGSize, rowLeading: CGFloat) -> (frame: CGRect, placement: Placement) {
    func fits(_ rect: CGRect) -> Bool {
      rect.minX >= visible.minX && rect.maxX <= visible.maxX && rect.minY >= visible.minY && rect.maxY <= visible.maxY
    }
    func clampX(_ x: CGFloat) -> CGFloat { min(max(x, visible.minX + inset), visible.maxX - card.width - inset) }
    func clampY(_ y: CGFloat) -> CGFloat { min(max(y, visible.minY + inset), visible.maxY - card.height - inset) }

    let column = min(settings.minX + listLeading - rowLeading, settings.maxX - inset - card.width)

    let below = CGRect(x: clampX(column), y: settings.minY - gap - card.height, width: card.width, height: card.height)
    if fits(below) { return (below, .below) }

    let inside = CGRect(x: column, y: max(settings.minY + insideBottom, visible.minY + inset), width: card.width, height: card.height)
    if fits(inside), inside.minX >= settings.minX, inside.maxY <= settings.minY + settings.height * emptyLowerShare {
      return (inside, .inside)
    }

    let right = CGRect(x: settings.maxX + gap, y: clampY(settings.minY), width: card.width, height: card.height)
    if fits(right) { return (right, .right) }

    let left = CGRect(x: settings.minX - gap - card.width, y: clampY(settings.minY), width: card.width, height: card.height)
    if fits(left) { return (left, .left) }

    return (CGRect(x: clampX(below.minX), y: clampY(below.minY), width: card.width, height: card.height), .clamped)
  }
}
