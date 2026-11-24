import AppKit
import Observation
import ResizerCore
import SwiftUI

/**
 Shows the guide: a frame with rulers over one screen, a tag to move the frame, and a small bar with
 actions. While the guide shows, it reads the size of the front window ten times a second and
 compares it with the frame.

 While the guide shows, Escape hides it and the arrow keys move the frame, when the settings turn these keys on.
 */
@Observable
final class GuideController {
  private(set) var isVisible = false
  private(set) var frame: CGRect = .zero
  private(set) var screen: ScreenInfo?
  private(set) var target: PresetTarget?
  private(set) var title = ""
  private(set) var match: GuideMatch?
  private(set) var windowSize: CGSize?
  private(set) var windowAppName: String?

  @ObservationIgnored let settings: AppSettings
  @ObservationIgnored let tracker: FrontAppTracker
  @ObservationIgnored let permission: AccessibilityPermission
  @ObservationIgnored var onSnap: () -> Void = {}
  @ObservationIgnored var onRequestPermission: () -> Void = {}

  @ObservationIgnored private let overlayPanel = FloatingPanel(clickThrough: true)
  @ObservationIgnored private let tagPanel = FloatingPanel(clickThrough: false)
  @ObservationIgnored private let hudPanel = FloatingPanel(clickThrough: false)
  @ObservationIgnored private var trackTask: Task<Void, Never>?
  @ObservationIgnored private var dragStart: (mouse: CGPoint, frame: CGRect)?
  @ObservationIgnored private var screenObserver: NSObjectProtocol?
  @ObservationIgnored private let keyTap = GuideKeyTap()

  // The bar panel has room above the bar for the tooltips of its buttons.
  static let hudTipSpace: CGFloat = 14
  static let hudSize = CGSize(width: 620, height: 64 + hudTipSpace)

  init(settings: AppSettings, tracker: FrontAppTracker, permission: AccessibilityPermission) {
    self.settings = settings
    self.tracker = tracker
    self.permission = permission
    overlayPanel.setRootView(GuideOverlayView(guide: self))
    tagPanel.setRootView(GuideTagView(guide: self))
    hudPanel.setRootView(GuideHUDView(guide: self))
    keyTap.keys = { [weak self] in self?.settings.guideKeys ?? [] }
    keyTap.onCommand = { [weak self] command in
      switch command {
      case .hide: self?.hide()
      case .move(let dx, let dy): self?.nudge(dx: dx, dy: dy)
      }
    }
    tagPanel.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1)
    hudPanel.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1)
    screenObserver = NotificationCenter.default.addObserver(
      forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated { self?.hide() }
    }
  }

  var unitsPerPoint: Double { screen?.unitsPerPoint(settings.units) ?? 1 }

  // The size of the frame in the selected units.
  var sizeInUnits: (width: Int, height: Int) {
    (Int((frame.width * unitsPerPoint).rounded()), Int((frame.height * unitsPerPoint).rounded()))
  }

  func show(target: PresetTarget, title: String, window: WindowSnapshot?) {
    guard let screen = window?.screen ?? ScreenInfo.main else {
      Log.guide.error("Show: no screen found")
      return
    }
    Log.guide.notice("Show \(title, privacy: .public) for \(window?.app.bundleIdentifier ?? "no window", privacy: .public)")
    self.screen = screen
    self.target = target
    self.title = title
    frame = GuideGeometry.frame(
      for: target, window: window?.frame, visible: screen.visibleFrame, unitsPerPoint: screen.unitsPerPoint(settings.units),
      mode: settings.fitMode)
    match = nil
    windowSize = nil
    isVisible = true

    for panel in [overlayPanel, tagPanel, hudPanel] {
      panel.setHiddenFromCapture(settings.hideGuideInScreenshots)
    }
    overlayPanel.setFrame(screen.screen.frame, display: true)
    layoutTag()
    layoutHUD()
    overlayPanel.orderFrontRegardless()
    tagPanel.orderFrontRegardless()
    hudPanel.orderFrontRegardless()
    startTracking()
    keyTap.start()
  }

  func hide() {
    guard isVisible else { return }
    Log.guide.notice("Hide")
    isVisible = false
    trackTask?.cancel()
    trackTask = nil
    keyTap.stop()
    overlayPanel.orderOut(nil)
    tagPanel.orderOut(nil)
    hudPanel.orderOut(nil)
  }

  func center() {
    guard let screen else { return }
    frame.origin = GuideGeometry.centeredOrigin(size: frame.size, in: screen.visibleFrame)
    layoutTag()
    layoutHUD()
  }

  /**
   Moves the frame with the arrow buttons or the arrow keys, by at least one point. The bar stays where it is, so
   that the arrow buttons stay under the mouse.
   */
  func nudge(dx: Int, dy: Int) {
    let upp = unitsPerPoint
    frame = frame.offsetBy(
      dx: GuideGeometry.nudgePoints(units: dx, unitsPerPoint: upp), dy: GuideGeometry.nudgePoints(units: dy, unitsPerPoint: upp))
    layoutTag()
  }

  /**
   Drag of the tag. The mouse position on the screen is stable while the tag panel moves. The frame moves by whole
   points, because windows move only by whole points.
   */
  func dragChanged() {
    let mouse = NSEvent.mouseLocation
    if dragStart == nil { dragStart = (mouse, frame) }
    guard let start = dragStart else { return }
    let dx = (mouse.x - start.mouse.x).rounded()
    let dy = (start.mouse.y - mouse.y).rounded()
    frame.origin = CGPoint(x: start.frame.minX + dx, y: start.frame.minY + dy)
    layoutTag()
    layoutHUD()
  }

  func dragEnded() { dragStart = nil }

  func snap() { onSnap() }

  private func layoutTag() {
    guard let screen else { return }
    let visible = screen.visibleFrame
    let tagSize = tagPanel.contentView?.fittingSize ?? CGSize(width: 200, height: 26)
    var tagOrigin = CGPoint(x: frame.minX - 2, y: frame.minY - tagSize.height - 4)
    if tagOrigin.y < visible.minY + 20 { tagOrigin.y = frame.minY + 6 }
    tagOrigin.x = max(visible.minX + 20, min(tagOrigin.x, visible.maxX - tagSize.width))
    tagPanel.setFrame(ScreenInfo.appKitRect(CGRect(origin: tagOrigin, size: tagSize)), display: true)
  }

  // Places the bar under the frame, or inside the frame at the bottom when the screen has no room below it.
  private func layoutHUD() {
    guard let screen else { return }
    let visible = screen.visibleFrame
    let tip = Self.hudTipSpace
    let bar = CGSize(width: Self.hudSize.width, height: Self.hudSize.height - tip)
    var barOrigin = CGPoint(x: frame.midX - bar.width / 2, y: frame.maxY + 22)
    if barOrigin.y + bar.height > visible.maxY { barOrigin.y = frame.maxY - bar.height - 26 }
    barOrigin.x = max(visible.minX + 8, min(barOrigin.x, visible.maxX - bar.width - 8))
    barOrigin.y = max(visible.minY + 8, min(barOrigin.y, visible.maxY - bar.height - 8))
    let panelRect = CGRect(x: barOrigin.x, y: barOrigin.y - tip, width: Self.hudSize.width, height: Self.hudSize.height)
    hudPanel.setFrame(ScreenInfo.appKitRect(panelRect), display: true)
  }

  private func startTracking() {
    trackTask?.cancel()
    trackTask = Task { [weak self] in
      while !Task.isCancelled {
        self?.readWindow()
        try? await Task.sleep(for: .milliseconds(100))
      }
    }
  }

  private func readWindow() {
    guard permission.isGranted, let app = tracker.targetApp,
      let window = AXWindow.focused(pid: app.processIdentifier, timeout: AXWindow.trackingTimeout),
      let windowFrame = window.frame
    else {
      if match != nil { match = nil }
      return
    }
    let newMatch = GuideGeometry.compare(window: windowFrame, guide: frame, unitsPerPoint: unitsPerPoint)
    if newMatch != match { match = newMatch }
    if windowSize != windowFrame.size { windowSize = windowFrame.size }
    let name = app.localizedName
    if windowAppName != name { windowAppName = name }
  }
}
