import AppKit
import ResizerCore

/**
 A screen with its frames in Accessibility coordinates (origin at the top-left of the primary
 screen, y goes down).
 */
struct ScreenInfo {
  let screen: NSScreen
  let frame: CGRect
  let visibleFrame: CGRect
  let scale: CGFloat

  init(screen: NSScreen) {
    self.screen = screen
    let primaryHeight = ScreenInfo.primaryHeight
    frame = ScreenGeometry.flip(screen.frame, primaryHeight: primaryHeight)
    visibleFrame = ScreenGeometry.flip(screen.visibleFrame, primaryHeight: primaryHeight)
    scale = screen.backingScaleFactor
  }

  func unitsPerPoint(_ unit: SizeUnit) -> Double { unit.unitsPerPoint(scale: scale) }

  static var primaryHeight: CGFloat { NSScreen.screens.first?.frame.height ?? 0 }

  // The screen that shows the largest part of a rectangle in Accessibility coordinates.
  static func containing(_ rect: CGRect) -> ScreenInfo? {
    let screens = NSScreen.screens.map(ScreenInfo.init(screen:))
    guard let index = ScreenGeometry.bestScreen(for: rect, in: screens.map(\.frame)) else { return nil }
    return screens[index]
  }

  static var main: ScreenInfo? { (NSScreen.main ?? NSScreen.screens.first).map(ScreenInfo.init(screen:)) }

  // Converts a rectangle in Accessibility coordinates to AppKit coordinates.
  static func appKitRect(_ rect: CGRect) -> CGRect { ScreenGeometry.flip(rect, primaryHeight: primaryHeight) }
}
