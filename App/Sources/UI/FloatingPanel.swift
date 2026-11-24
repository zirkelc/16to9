import AppKit
import SwiftUI

/**
 A borderless panel that floats over other windows and on all Spaces. It never becomes the key
 window, so the window of the user stays active while the panel shows.
 */
final class FloatingPanel: NSPanel {
  init(clickThrough: Bool) {
    super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
    isFloatingPanel = true
    level = .floating
    backgroundColor = .clear
    isOpaque = false
    hasShadow = false
    ignoresMouseEvents = clickThrough
    hidesOnDeactivate = false
    isReleasedWhenClosed = false
    animationBehavior = .none
    collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
  }

  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }

  func setRootView<Content: View>(_ view: Content) {
    contentView = FirstMouseHostingView(rootView: view)
  }

  // Excludes the panel from screenshots and screen recordings when `hidden` is true.
  func setHiddenFromCapture(_ hidden: Bool) {
    sharingType = hidden ? .none : .readOnly
  }
}

// Takes the first click, so that a button in a panel works while another app is active.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
  override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
