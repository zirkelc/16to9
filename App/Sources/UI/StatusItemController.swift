import AppKit
import SwiftUI

/**
 The icon in the menu bar and its popover.
 */
final class StatusItemController: NSObject, NSPopoverDelegate {
  private let model: AppModel
  private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
  private let popover = NSPopover()

  init(model: AppModel) {
    self.model = model
    super.init()

    if let button = item.button {
      #if DEBUG
        button.image = MenuBarIcon.devImage
      #else
        button.image = MenuBarIcon.image
      #endif
      button.setAccessibilityLabel("16to9")
      button.target = self
      button.action = #selector(togglePopover)
    }

    popover.behavior = .transient
    popover.animates = true
    popover.delegate = self

    model.closePopover = { [weak self] in self?.popover.performClose(nil) }
    model.statusItemFrame = { [weak self] in
      guard let button = self?.item.button, let window = button.window else { return nil }
      return window.convertToScreen(button.convert(button.bounds, to: nil))
    }
  }

  func popoverDidClose(_ notification: Notification) {
    model.hidePreview()
  }

  @objc func togglePopover() {
    if popover.isShown {
      popover.performClose(nil)
      return
    }
    guard let button = item.button else { return }
    model.refreshFrontWindow()
    /**
     A new view for each opening starts with an empty search field that has the keyboard focus. A view that
     stays from the last opening keeps its text and its focus, for example on a tile that the user clicked.
     */
    let controller = NSHostingController(rootView: PopoverView(model: model))
    controller.sizingOptions = .preferredContentSize
    popover.contentViewController = controller
    popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    // The popover needs keyboard focus for the search field and the arrow keys.
    NSApp.activate()
    popover.contentViewController?.view.window?.makeKey()
  }
}

// The menu bar symbol: an L ruler and a window, the same picture as the app icon. The asset is a template image, so macOS colors it.
enum MenuBarIcon {
  static let image: NSImage = {
    let image = NSImage(named: "MenuBarIcon") ?? NSImage()
    image.size = NSSize(width: 18, height: 18)
    image.isTemplate = true
    return image
  }()

  /**
   The symbol with a dot at the top right corner. The dev build uses it, so that its icon is different
   from the icon of the release build when both are in the menu bar. A gap around the dot keeps it
   apart from the lines of the symbol.
   */
  static let devImage: NSImage = {
    let size = image.size
    let marked = NSImage(size: size, flipped: false) { rect in
      image.draw(in: rect)
      let diameter = size.height / 4
      let dot = NSRect(x: rect.maxX - diameter, y: rect.maxY - diameter, width: diameter, height: diameter)
      NSGraphicsContext.current?.compositingOperation = .clear
      NSBezierPath(ovalIn: dot.insetBy(dx: -1.2, dy: -1.2)).fill()
      NSGraphicsContext.current?.compositingOperation = .sourceOver
      NSColor.black.setFill()
      NSBezierPath(ovalIn: dot).fill()
      return true
    }
    marked.isTemplate = true
    return marked
  }()
}
