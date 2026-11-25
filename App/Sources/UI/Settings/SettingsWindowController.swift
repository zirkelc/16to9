import AppKit
import Observation
import SwiftUI

enum SettingsTab: Int, CaseIterable, Identifiable {
  case general
  case presets
  case guide
  case shortcuts
  case about

  var id: Int { rawValue }

  var title: String {
    switch self {
    case .general: String(localized: "General")
    case .presets: String(localized: "Presets")
    case .guide: String(localized: "Guide")
    case .shortcuts: String(localized: "Shortcuts")
    case .about: String(localized: "About")
    }
  }

  var symbol: String {
    switch self {
    case .general: "gearshape.fill"
    case .presets: "rectangle.stack.fill"
    case .guide: "ruler.fill"
    case .shortcuts: "command"
    case .about: "info"
    }
  }

  var tint: IconTile.Tint {
    switch self {
    case .general, .about: .gray
    case .presets: .blue
    case .guide: .cyan
    case .shortcuts: .purple
    }
  }
}

// The selected pane, shared by the window controller and the view.
@Observable
final class SettingsNavigation {
  var tab = SettingsTab.general
}

/**
 The settings window with the native sidebar of macOS, as in System Settings. The window has one
 fixed size, so it does not change its size, and a pane shows at once without a transition.
 */
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
  // Just large enough that the General pane with two screens, the largest preset group and the About pane need no scroll bar.
  static let size = NSSize(width: 780, height: 740)

  private let navigation = SettingsNavigation()

  init(model: AppModel, shortcuts: ShortcutCenter) {
    let window = NSWindow(
      contentRect: NSRect(origin: .zero, size: Self.size),
      styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
      backing: .buffered, defer: false
    )
    window.title = String(localized: "16to9 Settings")
    window.toolbarStyle = .unified
    window.isReleasedWhenClosed = false
    super.init(window: window)
    window.delegate = self

    let root = SettingsView(model: model, shortcuts: shortcuts, navigation: navigation)
    let controller = NSHostingController(rootView: root)
    controller.sizingOptions = []
    // The pane title goes into the title bar of the window.
    controller.sceneBridgingOptions = [.title]
    window.contentViewController = controller
    // An empty toolbar gives the title bar its full height, as in System Settings, so that the
    // window buttons have a margin in the sidebar.
    let toolbar = NSToolbar(identifier: "settings")
    toolbar.showsBaselineSeparator = false
    window.toolbar = toolbar
    window.toolbarStyle = .unified
    window.titlebarSeparatorStyle = .none
    // A transparent title bar draws no background, so macOS draws no line below it.
    window.titlebarAppearsTransparent = true
    window.setContentSize(Self.size)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

  func show(_ tab: SettingsTab) {
    navigation.tab = tab
    NSApp.setActivationPolicy(.regular)
    /**
     The settings open from the menu of the menu bar item, which belongs to another process on macOS. A
     plain activation is only a request that macOS refuses then, and an inactive window draws its
     switches grey. This activation does not ask the front app.
     */
    NSApp.activate(ignoringOtherApps: true)
    let mouse = NSEvent.mouseLocation
    if let window, !window.isVisible, let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.screens.first {
      // Centers on the screen with the mouse pointer, where the user works.
      let visible = screen.visibleFrame
      window.setFrameOrigin(NSPoint(x: visible.midX - window.frame.width / 2, y: visible.midY - window.frame.height / 2))
    }
    showWindow(nil)
    window?.makeKeyAndOrderFront(nil)
  }

  // The app has no Dock icon, except while the settings window is open.
  func windowWillClose(_ notification: Notification) {
    NSApp.hideDockIconUnlessWindowOpen(closing: window)
  }
}

extension NSApplication {
  /**
   Removes the Dock icon when the last titled window of the app closes. The settings window and the
   tour can be open at the same time, so one of them can close while the other still needs the icon.
   */
  func hideDockIconUnlessWindowOpen(closing: NSWindow?) {
    let isOtherOpen = windows.contains { $0 !== closing && $0.styleMask.contains(.titled) && ($0.isVisible || $0.isMiniaturized) }
    if !isOtherOpen { setActivationPolicy(.accessory) }
  }
}

struct SettingsView: View {
  let model: AppModel
  let shortcuts: ShortcutCenter
  let navigation: SettingsNavigation

  static let sidebarWidth: CGFloat = 215
  // The space between the edge of the pane and its groups and callouts.
  static let contentInset: CGFloat = 20

  private var selection: Binding<SettingsTab?> {
    Binding(get: { navigation.tab }, set: { if let tab = $0 { navigation.tab = tab } })
  }

  var body: some View {
    NavigationSplitView(columnVisibility: .constant(.all)) {
      List(selection: selection) {
        ForEach(SettingsTab.allCases) { row($0) }
      }
      .listStyle(.sidebar)
      .navigationSplitViewColumnWidth(min: Self.sidebarWidth, ideal: Self.sidebarWidth, max: Self.sidebarWidth)
      .frame(width: Self.sidebarWidth)
      .toolbar(removing: .sidebarToggle)
    } detail: {
      pane(navigation.tab)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // A pane replaces the last one without a transition: a fade reads as a delay.
        .id(navigation.tab)
        .navigationTitle(navigation.tab.title)
        // No line below the title, as in System Settings.
        .toolbarBackground(.hidden, for: .windowToolbar)
    }
  }

  private func row(_ tab: SettingsTab) -> some View {
    Label {
      Text(tab.title)
    } icon: {
      IconTile(symbol: tab.symbol, tint: tab.tint, size: 20)
    }
    .tag(tab)
  }

  @ViewBuilder
  private func pane(_ tab: SettingsTab) -> some View {
    switch tab {
    case .general: GeneralPane(model: model)
    case .presets: PresetsPane(model: model, shortcuts: shortcuts)
    case .guide: GuidePane(settings: model.settings)
    case .shortcuts: ShortcutsPane(settings: model.settings)
    case .about: AboutPane(model: model)
    }
  }
}
