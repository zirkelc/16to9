import AppKit
import Observation
import ResizerCore

// One entry in the popover: a preset, or a size that the user typed.
struct MenuEntry: Identifiable, Equatable {
  let id: String
  let name: String
  let target: PresetTarget
  let preset: Preset?
}

// What the popover shows on the right side of an entry.
struct EntryPreview {
  let text: String
  let isEnabled: Bool
}

// The result of one resize: the app of the window and its new size as text, for example "1200 × 675 px".
struct ResizeSummary {
  let app: NSRunningApplication
  let appName: String
  let size: String
}

/**
 Connects the parts of the app: settings, window control, guide, toasts and windows.
 The views call the actions in this class.
 */
@Observable
final class AppModel {
  let settings: AppSettings
  let permission = AccessibilityPermission()
  let updater = Updater()
  @ObservationIgnored let permissionCard: PermissionCardController
  @ObservationIgnored let tracker = FrontAppTracker()
  let resizer = ResizeService()
  @ObservationIgnored let toast = ToastController()
  @ObservationIgnored let guide: GuideController
  @ObservationIgnored let sizePreview = SizePreviewController()

  private(set) var frontWindow: WindowSnapshot?
  private(set) var frontApp: NSRunningApplication?

  @ObservationIgnored var openSettings: (SettingsTab) -> Void = { _ in }
  @ObservationIgnored var openOnboarding: () -> Void = {}
  // Opens the full welcome tour.
  @ObservationIgnored var openTour: () -> Void = {}
  @ObservationIgnored var closePopover: () -> Void = {}
  // Called after each resize, with the app and the new size.
  @ObservationIgnored var onResize: (ResizeSummary) -> Void = { _ in }
  // The frame of the menu bar icon on the screen, in AppKit coordinates.
  @ObservationIgnored var statusItemFrame: () -> NSRect? = { nil }

  init(settings: AppSettings = AppSettings()) {
    self.settings = settings
    permissionCard = PermissionCardController(permission: permission)
    guide = GuideController(settings: settings, tracker: tracker, permission: permission)
    guide.onSnap = { [weak self] in self?.snapToGuide() }
    guide.onRequestPermission = { [weak self] in self?.openOnboarding() }
    toast.onUndo = { [weak self] in self?.undo() }
  }

  // Opens the Accessibility list in System Settings with a card, from which the user drags the app into the list.
  func requestPermission() {
    permissionCard.show()
  }

  // Reads the front window again. The popover calls this each time it opens.
  func refreshFrontWindow() {
    permission.refresh()
    frontApp = tracker.targetApp
    guard permission.isGranted, let frontApp else {
      frontWindow = nil
      return
    }
    frontWindow = WindowSnapshot.capture(app: frontApp)
  }

  func unitsPerPoint(for window: WindowSnapshot?) -> Double {
    (window?.screen ?? ScreenInfo.main)?.unitsPerPoint(settings.units) ?? 1
  }

  // The size of the front window in the selected units, for example "3024 × 1890 px".
  func describe(_ size: CGSize, on window: WindowSnapshot?) -> String {
    let upp = unitsPerPoint(for: window)
    return "\(Int((size.width * upp).rounded())) × \(Int((size.height * upp).rounded())) \(settings.units.symbol)"
  }

  // The text on the right of an entry: the result for a ratio, or the size and whether it fits.
  func preview(for target: PresetTarget) -> EntryPreview {
    guard let window = frontWindow else {
      return EntryPreview(text: target.label, isEnabled: true)
    }
    let upp = unitsPerPoint(for: window)
    let context = FitContext(
      window: window.frame, visible: window.screen.visibleFrame, unitsPerPoint: upp,
      mode: settings.fitMode, anchor: settings.anchor
    )
    switch target {
    case .ratio:
      guard let size = FitCalculator.candidates(for: target, in: context).first else {
        return EntryPreview(text: target.label, isEnabled: true)
      }
      return EntryPreview(text: "→ \(Int((size.width * upp).rounded())) × \(Int((size.height * upp).rounded()))", isEnabled: true)
    case .size:
      let fits = !FitCalculator.candidates(for: target, in: context).isEmpty
      // A guide can be larger than the visible area, only a resize cannot.
      if !fits && settings.action == .resize { return EntryPreview(text: String(localized: "too large"), isEnabled: false) }
      return EntryPreview(text: target.label, isEnabled: true)
    }
  }

  /**
   The entries for presets. A favorite also shows in its group, so the favorite entries get a prefix
   that keeps each entry ID unique in the popover.
   */
  func entries(for presets: [Preset], idPrefix: String = "") -> [MenuEntry] {
    presets.map { MenuEntry(id: idPrefix + $0.id, name: $0.displayName, target: $0.target, preset: $0) }
  }

  var favoriteEntries: [MenuEntry] { entries(for: settings.presets.favorites, idPrefix: "favorite.") }

  // An entry for a size or ratio that the user typed, or nil when the text is not valid.
  func typedEntry(_ text: String) -> MenuEntry? {
    guard let target = SizeInput.parse(text) else { return nil }
    return MenuEntry(id: "typed", name: String(localized: "Use \(target.label)"), target: target, preset: nil)
  }

  /**
   Shows on the screen the frame that the selected action gives the front window for an entry: the new frame
   of a resize, or the frame of the guide. It hides the preview when the action cannot change the window.
   */
  func showPreview(for entry: MenuEntry) {
    guard settings.showsSizePreview, let window = frontWindow, !window.isFullScreen else {
      hidePreview()
      return
    }
    let upp = unitsPerPoint(for: window)
    let visible = window.screen.visibleFrame
    let frame: CGRect?
    switch settings.action {
    case .resize:
      let context = FitContext(
        window: window.frame, visible: visible, unitsPerPoint: upp, mode: settings.fitMode, anchor: settings.anchor)
      frame = window.isResizable ? FitCalculator.frame(for: entry.target, in: context) : nil
    case .guide:
      frame = GuideGeometry.frame(
        for: entry.target, window: window.frame, visible: visible, unitsPerPoint: upp, mode: settings.fitMode)
    }
    guard let frame else {
      hidePreview()
      return
    }
    sizePreview.show(
      frame: frame, window: window.frame, screen: window.screen, unitsPerPoint: upp, label: describe(frame.size, on: window),
      color: settings.guideColor.color, showsRulers: settings.action == .guide,
      hiddenFromCapture: settings.hideGuideInScreenshots)
  }

  func hidePreview() { sizePreview.hide() }

  // Runs the selected action of the popover for an entry.
  func perform(_ entry: MenuEntry) {
    hidePreview()
    closePopover()
    switch settings.action {
    case .resize: resize(to: entry.target)
    case .guide: showGuide(entry.target, title: entry.preset?.displayName ?? entry.target.label, presetID: entry.preset?.id)
    }
  }

  func resize(to target: PresetTarget) {
    permission.refresh()
    guard permission.isGranted else {
      Log.resize.notice("Resize to \(target.label, privacy: .public) needs the Accessibility permission")
      openOnboarding()
      return
    }
    guard let app = tracker.targetApp, let window = WindowSnapshot.capture(app: app) else {
      Log.resize.notice("Resize to \(target.label, privacy: .public): no front window (app \(self.tracker.targetApp?.bundleIdentifier ?? "none", privacy: .public))")
      showToast(Toast(kind: .failure, title: String(localized: "No window to resize"), detail: String(localized: "Click a window first")), screen: nil)
      return
    }
    Log.resize.notice(
      "Resize \(app.bundleIdentifier ?? "?", privacy: .public) to \(target.label, privacy: .public), mode \(self.settings.fitMode.rawValue, privacy: .public), from \(window.frame.logDescription, privacy: .public)")
    Task {
      let outcome = await resizer.resize(window, to: target, settings: settings)
      app.activate()
      report(outcome, window: window, label: target.label)
    }
  }

  func showGuide(_ target: PresetTarget, title: String, presetID: String?) {
    if let presetID { settings.lastGuidePresetID = presetID }
    permission.refresh()
    let window = tracker.targetApp.flatMap { permission.isGranted ? WindowSnapshot.capture(app: $0) : nil }
    guide.show(target: target, title: title, window: window)
    tracker.targetApp?.activate()
  }

  // Shows or hides the guide with the last guide preset, or the first favorite.
  func toggleGuide() {
    if guide.isVisible {
      guide.hide()
      return
    }
    let library = settings.presets
    let preset = settings.lastGuidePresetID.flatMap(library.preset(id:)) ?? library.favorites.first ?? library.all.first
    guard let preset else { return }
    showGuide(preset.target, title: preset.displayName, presetID: preset.id)
  }

  func snapToGuide() {
    permission.refresh()
    guard permission.isGranted else {
      openOnboarding()
      return
    }
    guard let app = tracker.targetApp, let window = WindowSnapshot.capture(app: app) else {
      Log.guide.notice("Snap: no front window (app \(self.tracker.targetApp?.bundleIdentifier ?? "none", privacy: .public))")
      showToast(Toast(kind: .failure, title: String(localized: "No window to snap"), detail: nil), screen: guide.screen)
      return
    }
    let frame = guide.frame
    Log.guide.notice("Snap \(app.bundleIdentifier ?? "?", privacy: .public) from \(window.frame.logDescription, privacy: .public) to \(frame.logDescription, privacy: .public)")
    Task {
      let outcome = await resizer.setFrame(frame, of: window)
      report(outcome, window: window, label: guide.title)
    }
  }

  func undo() {
    Task {
      let done = await resizer.undo()
      Log.resize.notice("Undo: \(done ? "restored the last frame" : "nothing to undo", privacy: .public)")
      if !done { showToast(Toast(kind: .failure, title: String(localized: "Nothing to undo"), detail: nil), screen: nil) }
    }
  }

  private func report(_ outcome: ResizeOutcome, window: WindowSnapshot, label: String) {
    let screen = window.screen
    switch outcome {
    case .resized(let requested, let actual):
      let upp = screen.unitsPerPoint(settings.units)
      let isExact = ResizeService.matches(actual.size, requested.size, unitsPerPoint: upp)
      Log.resize.notice(
        "\(isExact ? "Resized" : "Not exact", privacy: .public): requested \(requested.logDescription, privacy: .public), got \(actual.logDescription, privacy: .public)")
      let size = describe(actual.size, on: window)
      onResize(ResizeSummary(app: window.app, appName: window.appName, size: size))
      if isExact {
        showToast(Toast(kind: .success, title: "\(window.appName): \(label)", detail: size, canUndo: true), screen: screen)
      } else {
        showToast(
          Toast(kind: .warning, title: String(localized: "\(window.appName) did not accept the exact size"), detail: size, canUndo: true),
          screen: screen)
      }
    case .tooLarge:
      Log.resize.notice("Too large for the screen: \(label, privacy: .public)")
      showToast(Toast(kind: .failure, title: String(localized: "Too large for this screen"), detail: label), screen: screen)
    case .notResizable:
      Log.resize.notice("Window of \(window.app.bundleIdentifier ?? "?", privacy: .public) is not resizable")
      showToast(Toast(kind: .failure, title: String(localized: "This window cannot be resized"), detail: window.appName), screen: screen)
    case .fullScreen:
      Log.resize.notice("Window of \(window.app.bundleIdentifier ?? "?", privacy: .public) is in full screen")
      showToast(Toast(kind: .failure, title: String(localized: "This window is in full screen"), detail: window.appName), screen: screen)
    }
  }

  private func showToast(_ toast: Toast, screen: ScreenInfo?) {
    guard settings.showToasts || toast.kind != .success else { return }
    self.toast.show(toast, on: screen)
  }
}
