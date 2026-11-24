import AppKit
import ApplicationServices

/**
 A window of another app, controlled through the Accessibility API. Position and size are in
 points, with the origin at the top-left of the primary screen.
 */
struct AXWindow {
  let element: AXUIElement
  let pid: pid_t

  let timeout: Float

  /**
   The calls run on the main thread and wait until the other app answers, or for the default time of 6 seconds.
   A resize or a snap waits up to 1 second, so that a slow app (for example an Electron app or Xcode while it
   indexes) still answers. The guide reads the window ten times a second, so its reads wait for a short time
   only: a read that does not complete skips one update of the guide.
   */
  static let actionTimeout: Float = 1
  static let trackingTimeout: Float = 0.2

  // The focused window of an app, or its main window, or its first window.
  static func focused(pid: pid_t, timeout: Float = actionTimeout) -> AXWindow? {
    let app = AXUIElementCreateApplication(pid)
    AXUIElementSetMessagingTimeout(app, timeout)
    for attribute in [kAXFocusedWindowAttribute, kAXMainWindowAttribute] {
      var value: CFTypeRef?
      let result = AXUIElementCopyAttributeValue(app, attribute as CFString, &value)
      // An app that does not answer would make each next call wait for the full timeout too.
      if result == .cannotComplete { return nil }
      if result == .success, let value, CFGetTypeID(value) == AXUIElementGetTypeID() {
        return AXWindow(element: value as! AXUIElement, pid: pid, timeout: timeout)
      }
    }
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value) == .success,
      let windows = value as? [AXUIElement], let first = windows.first
    else { return nil }
    return AXWindow(element: first, pid: pid, timeout: timeout)
  }

  private init(element: AXUIElement, pid: pid_t, timeout: Float) {
    AXUIElementSetMessagingTimeout(element, timeout)
    self.element = element
    self.pid = pid
    self.timeout = timeout
  }

  var frame: CGRect? {
    guard let origin = pointValue(kAXPositionAttribute), let size = sizeValue(kAXSizeAttribute) else { return nil }
    return CGRect(origin: origin, size: size)
  }

  var title: String? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &value) == .success else { return nil }
    return value as? String
  }

  var isResizable: Bool {
    var settable: DarwinBoolean = false
    guard AXUIElementIsAttributeSettable(element, kAXSizeAttribute as CFString, &settable) == .success else { return false }
    return settable.boolValue
  }

  var isFullScreen: Bool {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, "AXFullScreen" as CFString, &value) == .success else { return false }
    return (value as? Bool) ?? false
  }

  /**
   Sets the frame in three steps: size, position, size. Apps limit a size by the space on the screen,
   so the second size call applies the full size after the move. Some apps (Chrome, Electron) animate
   slowly while the enhanced user interface is on, so it is off during the change.
   */
  func setFrame(_ rect: CGRect) {
    let app = AXUIElementCreateApplication(pid)
    AXUIElementSetMessagingTimeout(app, timeout)
    let enhanced = Self.boolValue(app, "AXEnhancedUserInterface")
    if enhanced == true { Self.setBool(app, "AXEnhancedUserInterface", false) }
    defer { if enhanced == true { Self.setBool(app, "AXEnhancedUserInterface", true) } }

    setSize(rect.size)
    setPosition(rect.origin)
    setSize(rect.size)
  }

  func isSame(as other: AXWindow) -> Bool { CFEqual(element, other.element) }

  private func setSize(_ size: CGSize) {
    var size = size
    guard let value = AXValueCreate(.cgSize, &size) else { return }
    let result = AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, value)
    if result != .success { Log.resize.error("Set size failed: AXError \(result.rawValue, privacy: .public)") }
  }

  private func setPosition(_ point: CGPoint) {
    var point = point
    guard let value = AXValueCreate(.cgPoint, &point) else { return }
    let result = AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, value)
    if result != .success { Log.resize.error("Set position failed: AXError \(result.rawValue, privacy: .public)") }
  }

  private func pointValue(_ attribute: String) -> CGPoint? {
    guard let value = Self.copyValue(element, attribute) else { return nil }
    var point = CGPoint.zero
    return AXValueGetValue(value, .cgPoint, &point) ? point : nil
  }

  private func sizeValue(_ attribute: String) -> CGSize? {
    guard let value = Self.copyValue(element, attribute) else { return nil }
    var size = CGSize.zero
    return AXValueGetValue(value, .cgSize, &size) ? size : nil
  }

  private static func copyValue(_ element: AXUIElement, _ attribute: String) -> AXValue? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success, let value,
      CFGetTypeID(value) == AXValueGetTypeID()
    else { return nil }
    return (value as! AXValue)
  }

  private static func boolValue(_ element: AXUIElement, _ attribute: String) -> Bool? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
    return value as? Bool
  }

  private static func setBool(_ element: AXUIElement, _ attribute: String, _ flag: Bool) {
    AXUIElementSetAttributeValue(element, attribute as CFString, (flag ? kCFBooleanTrue : kCFBooleanFalse) as CFTypeRef)
  }
}
