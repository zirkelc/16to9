import AppKit
import ResizerCore

final class AppDelegate: NSObject, NSApplicationDelegate {
  private var model: AppModel!
  private var statusItem: StatusItemController!
  private var shortcuts: ShortcutCenter!
  private lazy var settingsWindow = SettingsWindowController(model: model, shortcuts: shortcuts)
  private lazy var onboardingWindow = OnboardingWindowController(model: model)

  func applicationDidFinishLaunching(_ notification: Notification) {
    let info = Bundle.main.infoDictionary
    Log.app.notice(
      "Launch \(Log.subsystem, privacy: .public) \(info?["CFBundleShortVersionString"] as? String ?? "?", privacy: .public) (\(info?["CFBundleVersion"] as? String ?? "?", privacy: .public)), macOS \(ProcessInfo.processInfo.operatingSystemVersionString, privacy: .public)")
    model = AppModel()
    shortcuts = ShortcutCenter(model: model)
    statusItem = StatusItemController(model: model)

    model.openSettings = { [weak self] tab in self?.settingsWindow.show(tab) }
    model.openOnboarding = { [weak self] in self?.onboardingWindow.show(.permission) }
    model.openTour = { [weak self] in self?.onboardingWindow.show(.welcome) }
    model.permissionCard.onGranted = { [weak self] in self?.onboardingWindow.showAgainIfOpen() }
    shortcuts.start()

    #if DEBUG
      if let screen = ProcessInfo.processInfo.environment["APP_DEBUG_SHOW"] {
        showDebugScreen(screen)
        return
      }
    #endif

    if !model.settings.hasSeenOnboarding {
      onboardingWindow.show(.welcome)
    }
  }

  #if DEBUG
    // Opens one part of the app at launch, for screenshots and manual checks.
    private func showDebugScreen(_ screen: String) {
      switch screen {
      case "popover":
        // The status item gets its window a short time after launch.
        Task {
          try? await Task.sleep(for: .seconds(1))
          statusItem.togglePopover()
        }
      case "guide": model.showGuide(.size(width: 1920, height: 1080), title: "Full HD", presetID: nil)
      case "guide-snap":
        model.showGuide(.size(width: 1920, height: 1080), title: "Full HD", presetID: nil)
        Task {
          try? await Task.sleep(for: .seconds(1.5))
          model.snapToGuide()
          try? await Task.sleep(for: .seconds(1))
          let frame = model.tracker.targetApp.flatMap { AXWindow.focused(pid: $0.processIdentifier)?.frame }
          FileHandle.standardError.write("guide \(model.guide.frame) window \(String(describing: frame)) match \(String(describing: model.guide.match))\n".data(using: .utf8)!)
        }
      case "onboarding": onboardingWindow.show(.welcome)
      case "onboarding-resized":
        // The tour after a resize of a Finder window in the "Try it" step.
        onboardingWindow.show(.tryIt)
        if let finder = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first {
          model.onResize(ResizeSummary(app: finder, appName: finder.localizedName ?? "Finder", size: "1920 × 1080 px"))
        }
      case let command where command.hasPrefix("onboarding-"):
        // One step of the tour, for example "onboarding-tryIt".
        let name = String(command.dropFirst(11))
        if let step = OnboardingFlow.Step.allCases.first(where: { "\($0)" == name }) { onboardingWindow.show(step) }
      case "permission-card": model.permissionCard.show(preview: true)
      case "settings-cycle":
        // Switches through all settings tabs and logs the window frame and the time of each switch.
        settingsWindow.show(.general)
        Task {
          for tab in SettingsTab.allCases + SettingsTab.allCases {
            try? await Task.sleep(for: .milliseconds(400))
            let start = Date()
            settingsWindow.show(tab)
            settingsWindow.window?.displayIfNeeded()
            let ms = Int(Date().timeIntervalSince(start) * 1000)
            FileHandle.standardError.write("\(tab) \(settingsWindow.window?.frame ?? .zero) \(ms) ms\n".data(using: .utf8)!)
          }
        }
      case let command where command.hasPrefix("preview:"):
        guard let target = SizeInput.parse(String(command.dropFirst(8))) else { return }
        Task {
          try? await Task.sleep(for: .seconds(1))
          model.refreshFrontWindow()
          model.showPreview(for: MenuEntry(id: "debug", name: target.label, target: target, preset: nil))
        }
      case let command where command.hasPrefix("resize:"):
        guard let target = SizeInput.parse(String(command.dropFirst(7))) else { return }
        Task {
          try? await Task.sleep(for: .seconds(1))
          model.resize(to: target)
          try? await Task.sleep(for: .seconds(1))
          let frame = model.tracker.targetApp.flatMap { AXWindow.focused(pid: $0.processIdentifier)?.frame }
          FileHandle.standardError.write("frame after resize: \(String(describing: frame))\n".data(using: .utf8)!)
        }
      default:
        // A settings pane, by its name. The prefix "settings-" is for names that other screens use, such as "guide".
        let name = screen.hasPrefix("settings-") ? String(screen.dropFirst(9)) : screen
        if let tab = SettingsTab.allCases.first(where: { "\($0)" == name }) { settingsWindow.show(tab) }
      }
    }
  #endif

  // Opening the app again (for example from Finder) shows the settings.
  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    settingsWindow.show(.general)
    return true
  }
}
