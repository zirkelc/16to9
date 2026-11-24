import CoreGraphics
import Foundation
import ResizerCore

/**
 Takes the keys of the guide from all apps while the guide shows, so that the front app does not also get them.
 Keys with Command, Option or Control go to the apps. The event tap needs the Accessibility permission.
 */
final class GuideKeyTap {
  // The keys to take. The tap reads them for each key press, so a change in the settings applies at once.
  var keys: () -> GuideKeys = { [] }
  var onCommand: (GuideKeyCommand) -> Void = { _ in }

  private var port: CFMachPort?
  private var source: CFRunLoopSource?

  func start() {
    guard port == nil else { return }
    let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
    guard
      let port = CGEvent.tapCreate(
        tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: mask,
        callback: Self.callback, userInfo: Unmanaged.passUnretained(self).toOpaque())
    else {
      Log.guide.error("Key tap: no event tap, the app needs the Accessibility permission")
      return
    }
    let source = CFMachPortCreateRunLoopSource(nil, port, 0)
    CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    self.port = port
    self.source = source
  }

  func stop() {
    guard let port else { return }
    CGEvent.tapEnable(tap: port, enable: false)
    if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
    CFMachPortInvalidate(port)
    self.port = nil
    source = nil
  }

  // Returns true when the key press is a command for the guide. The app then keeps the event.
  private func handle(type: CGEventType, event: CGEvent) -> Bool {
    // macOS turns a tap off when it is too slow. It must then be turned on again.
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
      if let port { CGEvent.tapEnable(tap: port, enable: true) }
      return false
    }
    guard type == .keyDown, event.flags.isDisjoint(with: [.maskCommand, .maskAlternate, .maskControl]) else { return false }
    let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
    guard let command = GuideKeyCommand(keyCode: keyCode, shift: event.flags.contains(.maskShift), keys: keys()) else {
      return false
    }
    onCommand(command)
    return true
  }

  // The run loop source is on the main run loop, so the tap calls this on the main thread.
  private static let callback: CGEventTapCallBack = { _, type, event, info in
    guard let info else { return Unmanaged.passUnretained(event) }
    // The values stay on the main thread, so they do not cross threads.
    nonisolated(unsafe) let pointer = info
    nonisolated(unsafe) let keyEvent = event
    let taken = MainActor.assumeIsolated {
      Unmanaged<GuideKeyTap>.fromOpaque(pointer).takeUnretainedValue().handle(type: type, event: keyEvent)
    }
    return taken ? nil : Unmanaged.passUnretained(event)
  }
}
