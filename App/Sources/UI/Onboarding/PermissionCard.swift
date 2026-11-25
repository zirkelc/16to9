import AppKit
import Observation
import ResizerCore
import SwiftUI

/**
 A small card next to the System Settings window. The user drags the app from the card into the
 Accessibility list, which adds the app and turns it on. The card follows the window, hides while
 another app is in front, and closes when the permission is on. The idea comes from the permission
 panel of Scrawl (github.com/kitlangton/scrawl, MIT licence).
 */
final class PermissionCardController {
  static let settingsBundleID = "com.apple.systempreferences"
  static let settingsURL = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility")!
  // Space around the card for its shadow.
  private static let margin: CGFloat = 30
  private static let fadeDuration = 0.18

  private let permission: AccessibilityPermission
  private let state = PermissionCardState()
  private var panel: FloatingPanel?
  private var settingsID: CGWindowID?
  private var settingsFrame: CGRect?
  private var missingSince: Date?
  private var startedAt = Date()
  private var timer: Timer?
  private var tick = 0
  private var isFinishing = false
  // Shows the card also when the permission is on, for screenshots in debug builds.
  private var isPreview = false
  // After a drop, macOS can ask for a password. The card hides until that is done.
  private var dropWait: (deadline: Date, peakWindows: Int)?
  // Changes on each close, so that a wait for the System Settings window from an earlier show stops.
  private var waitID = 0

  // Called after the permission is on and the card has closed.
  var onGranted: () -> Void = {}

  init(permission: AccessibilityPermission) {
    self.permission = permission
    state.onClose = { [weak self] in self?.close() }
    state.onDrop = { [weak self] in self?.dropped() }
  }

  func show(preview: Bool = false) {
    close(animated: false)
    isPreview = preview
    retryHintAt = nil
    state.showsRetryHint = false
    permission.refresh()
    guard !permission.isGranted || preview else { return onGranted() }
    NSWorkspace.shared.open(Self.settingsURL)
    permission.startWatching()
    startedAt = Date()
    waitForSettings(id: waitID, deadline: Date().addingTimeInterval(6), firstSeen: nil, last: nil)
  }

  func close(animated: Bool = true) {
    timer?.invalidate()
    timer = nil
    dropWait = nil
    waitID += 1
    guard let panel else { return }
    self.panel = nil
    guard animated else { return panel.orderOut(nil) }
    NSAnimationContext.runAnimationGroup { context in
      context.duration = Self.fadeDuration
      panel.animator().alphaValue = 0
    } completionHandler: {
      MainActor.assumeIsolated { panel.orderOut(nil) }
    }
  }

  // MARK: Settings window

  // Waits until the System Settings window stops moving: two equal frames 100 ms apart, or 1.2 s after it appears.
  private func waitForSettings(id: Int, deadline: Date, firstSeen: Date?, last: CGRect?) {
    guard id == waitID else { return }
    let now = Date()
    if let window = SettingsWindow.main() {
      if window.frame.integral == last?.integral || now.timeIntervalSince(firstSeen ?? now) >= 1.2 {
        return dock(id: window.id, frame: window.frame)
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        self.waitForSettings(id: id, deadline: deadline, firstSeen: firstSeen ?? now, last: window.frame)
      }
      return
    }
    guard now < deadline else { return }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      self.waitForSettings(id: id, deadline: deadline, firstSeen: nil, last: nil)
    }
  }

  private func dock(id: CGWindowID, frame: CGRect) {
    settingsID = id
    settingsFrame = frame
    isFinishing = false
    state.phase = .instruction
    state.rowWidth = PermissionCardLayout.rowWidth(settingsWidth: frame.width)
    let panel = FloatingPanel(clickThrough: false)
    panel.setRootView(PermissionCardView(state: state).padding(Self.margin))
    self.panel = panel
    place(settings: frame)
    panel.alphaValue = 0
    panel.orderFrontRegardless()
    NSAnimationContext.runAnimationGroup { context in
      context.duration = Self.fadeDuration
      panel.animator().alphaValue = 1
    }
    timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated { self?.track() }
    }
    RunLoop.main.add(timer!, forMode: .common)
  }

  private func place(settings quartzFrame: CGRect) {
    guard let panel else { return }
    let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
    let settings = ScreenGeometry.flip(quartzFrame, primaryHeight: primaryHeight)
    let screen = NSScreen.screens.first { $0.frame.contains(CGPoint(x: settings.midX, y: settings.midY)) } ?? NSScreen.main
    let card = PermissionCardView.size(rowWidth: state.rowWidth)
    let result = PermissionCardLayout.dock(
      settings: settings, visible: screen?.visibleFrame ?? settings, card: card, rowLeading: PermissionCardView.padding)
    state.placement = result.placement
    panel.setFrame(result.frame.insetBy(dx: -Self.margin, dy: -Self.margin), display: true)
    #if DEBUG
      if isPreview { FileHandle.standardError.write("card \(result.placement) \(result.frame) settings \(settings)\n".data(using: .utf8)!) }
    #endif
  }

  // MARK: Tracking

  // Follows the System Settings window, hides while another app is in front, and checks the permission.
  private func track() {
    guard let panel else { return }
    tick += 1

    var frame = settingsID.flatMap(SettingsWindow.frame(of:))
    if frame == nil, let window = SettingsWindow.main() {
      settingsID = window.id
      frame = window.frame
    }
    guard let frame else {
      missingSince = missingSince ?? Date()
      if Date().timeIntervalSince(missingSince!) > 0.6 { close() }
      return
    }
    missingSince = nil
    if frame != settingsFrame {
      settingsFrame = frame
      place(settings: frame)
    }

    if tick % 15 == 0 { permission.refresh() }
    if permission.isGranted && !isPreview { return finish() }

    if let wait = dropWait {
      let count = SettingsWindow.count()
      if count > wait.peakWindows { dropWait = (wait.deadline, count) }
      if count < wait.peakWindows || Date() > wait.deadline {
        dropWait = nil
        state.phase = .instruction
        retryHintAt = Date().addingTimeInterval(2)
      }
    }
    // macOS can take a short time to report the permission after the password dialog closes.
    if let hintAt = retryHintAt, Date() > hintAt {
      retryHintAt = nil
      state.showsRetryHint = true
    }

    let front = NSWorkspace.shared.frontmostApplication
    let isOurs = front?.bundleIdentifier == Self.settingsBundleID
      || front?.processIdentifier == ProcessInfo.processInfo.processIdentifier
    let alpha: CGFloat = (isOurs || state.isDragging) && dropWait == nil ? 1 : 0
    if panel.alphaValue != alpha && !isFading {
      isFading = true
      NSAnimationContext.runAnimationGroup { context in
        context.duration = Self.fadeDuration
        panel.animator().alphaValue = alpha
      } completionHandler: {
        MainActor.assumeIsolated { self.isFading = false }
      }
    }

    if Date().timeIntervalSince(startedAt) > 600 { close() }
  }

  private var isFading = false
  /**
   When a drop ends without the permission, the list usually has an old entry for 16to9, for example from an app
   that was moved or signed by another developer. macOS keeps the old entry, so the card then asks the user to
   remove it and add the app again.
   */
  private var retryHintAt: Date?

  private func dropped() {
    retryHintAt = nil
    state.phase = .waiting
    dropWait = (Date().addingTimeInterval(10), SettingsWindow.count())
    permission.refresh()
  }

  private func finish() {
    guard !isFinishing, let panel else { return }
    isFinishing = true
    dropWait = nil
    state.phase = .granted
    panel.alphaValue = 1
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
      self?.close()
      self?.onGranted()
    }
  }
}

// MARK: - System Settings window

// Finds the System Settings window through the window server. This needs no permission.
private enum SettingsWindow {
  static func windows() -> [[String: Any]] {
    let pids = Set(
      NSRunningApplication.runningApplications(withBundleIdentifier: PermissionCardController.settingsBundleID).map(\.processIdentifier))
    guard !pids.isEmpty,
      let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
    else { return [] }
    return list.filter { ($0[kCGWindowOwnerPID as String] as? pid_t).map(pids.contains) ?? false }
  }

  // The largest normal window of System Settings, with its frame in window server coordinates (top left).
  static func main() -> (id: CGWindowID, frame: CGRect)? {
    windows()
      .compactMap { window -> (id: CGWindowID, frame: CGRect)? in
        guard (window[kCGWindowLayer as String] as? Int) == 0,
          let id = window[kCGWindowNumber as String] as? CGWindowID,
          let bounds = window[kCGWindowBounds as String] as? NSDictionary,
          let frame = CGRect(dictionaryRepresentation: bounds),
          frame.width >= 300, frame.height >= 200
        else { return nil }
        return (id, frame)
      }
      .max { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height }
  }

  static func frame(of id: CGWindowID) -> CGRect? {
    let ids = [UnsafeRawPointer(bitPattern: UInt(id))] as CFArray
    guard let info = CGWindowListCreateDescriptionFromArray(ids) as? [[String: Any]],
      let window = info.first,
      (window[kCGWindowIsOnscreen as String] as? Bool) ?? false,
      let bounds = window[kCGWindowBounds as String] as? NSDictionary
    else { return nil }
    return CGRect(dictionaryRepresentation: bounds)
  }

  // Sheets and alerts add windows. A lower count means that one closed.
  static func count() -> Int { windows().count }
}

// MARK: - Card

@Observable
final class PermissionCardState {
  enum Phase { case instruction, waiting, granted }

  var phase = Phase.instruction
  var placement = PermissionCardLayout.Placement.below
  var rowWidth: CGFloat = 400
  var isDragging = false
  var isHovering = false
  // A drop ended without the permission.
  var showsRetryHint = false
  @ObservationIgnored var onClose: () -> Void = {}
  @ObservationIgnored var onDrop: () -> Void = {}
}

struct PermissionCardView: View {
  static let padding: CGFloat = 12
  static let instructionHeight: CGFloat = 22
  static let rowHeight: CGFloat = 44
  static let spacing: CGFloat = 8

  static func size(rowWidth: CGFloat) -> CGSize {
    CGSize(width: rowWidth + padding * 2, height: padding * 2 + instructionHeight + spacing + rowHeight)
  }

  let state: PermissionCardState

  var body: some View {
    VStack(alignment: .leading, spacing: Self.spacing) {
      instruction.frame(height: Self.instructionHeight)
      appRow.frame(height: Self.rowHeight)
    }
    .padding(Self.padding)
    .frame(width: Self.size(rowWidth: state.rowWidth).width, height: Self.size(rowWidth: state.rowWidth).height)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    .hairlineBorder(RoundedRectangle(cornerRadius: 16, style: .continuous), .primary.opacity(0.1))
    .shadow(color: .black.opacity(0.28), radius: 18, y: 8)
    .animation(.spring(duration: 0.3, bounce: 0), value: state.phase)
  }

  private var instruction: some View {
    HStack(spacing: 8) {
      Group {
        if state.phase == .granted {
          Image(systemName: "checkmark.circle.fill").foregroundStyle(.white, .green)
        } else {
          Image(systemName: arrow).foregroundStyle(Color.accentColor.gradient)
        }
      }
      .font(.system(size: 15, weight: .bold))
      .frame(width: 20)
      .transition(.scale.combined(with: .opacity))

      Group {
        switch state.phase {
        case .instruction where state.showsRetryHint: Brand.text("Still off? Remove 16to9 with −, then drag it in again.", size: 13)
        case .instruction: Brand.text("Drag 16to9 into the list to allow window control.", size: 13)
        case .waiting: Text("Waiting for macOS…")
        case .granted: Brand.text("16to9 is allowed.", size: 13)
        }
      }
      .font(.system(size: 13))
      .lineLimit(1)
      .minimumScaleFactor(0.8)

      Spacer(minLength: 4)

      if state.phase != .granted {
        Button(action: state.onClose) {
          Image(systemName: "xmark")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.secondary)
            .frame(width: 20, height: 20)
            .background(Circle().fill(.primary.opacity(0.08)))
        }
        .buttonStyle(.plain)
        .help("Close")
        .accessibilityLabel("Close")
      }
    }
  }

  // Points to the list: up when the card is below or inside the window, else to the side.
  private var arrow: String {
    switch state.placement {
    case .right: "arrow.left"
    case .left: "arrow.right"
    case .below, .inside, .clamped: "arrow.up"
    }
  }

  private var appRow: some View {
    let shape = RoundedRectangle(cornerRadius: 9, style: .continuous)
    return HStack(spacing: 10) {
      Image(nsImage: NSApp.applicationIconImage)
        .resizable()
        .interpolation(.high)
        .frame(width: 26, height: 26)
      Brand.nameText(size: 13)
      Spacer(minLength: 0)
      Image(systemName: "hand.draw")
        .foregroundStyle(.secondary)
        .opacity(state.isHovering ? 1 : 0)
    }
    .padding(.horizontal, 10)
    .opacity(state.isDragging ? 0.3 : 1)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(shape.fill(.primary.opacity(state.isHovering && !state.isDragging ? 0.1 : 0.065)))
    .overlay(shape.strokeBorder(.primary.opacity(0.08), lineWidth: 1))
    .overlay { AppDragArea(state: state) }
    .opacity(state.phase == .granted ? 0.5 : 1)
    .accessibilityElement(children: .combine)
    .accessibilityHint("Drag into the Accessibility list in System Settings")
  }
}

// MARK: - Drag source

// The area of the app row that starts the drag. The pasteboard item is the file URL of the app.
private struct AppDragArea: NSViewRepresentable {
  let state: PermissionCardState

  func makeNSView(context: Context) -> AppDragView { AppDragView(state: state) }
  func updateNSView(_ view: AppDragView, context: Context) {}
}

private final class AppDragView: NSView, NSDraggingSource {
  private let state: PermissionCardState
  private var mouseDown: NSEvent?

  init(state: PermissionCardState) {
    self.state = state
    super.init(frame: .zero)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

  override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
  override func resetCursorRects() { addCursorRect(bounds, cursor: .openHand) }

  override func updateTrackingAreas() {
    super.updateTrackingAreas()
    trackingAreas.forEach(removeTrackingArea)
    addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
  }

  override func mouseEntered(with event: NSEvent) { state.isHovering = true }
  override func mouseExited(with event: NSEvent) { state.isHovering = false }
  override func mouseDown(with event: NSEvent) { mouseDown = event }
  override func mouseUp(with event: NSEvent) { mouseDown = nil }

  override func mouseDragged(with event: NSEvent) {
    guard let mouseDown else { return }
    let distance = hypot(event.locationInWindow.x - mouseDown.locationInWindow.x, event.locationInWindow.y - mouseDown.locationInWindow.y)
    guard distance >= 3 else { return }
    self.mouseDown = nil
    let item = NSDraggingItem(pasteboardWriter: Bundle.main.bundleURL as NSURL)
    item.setDraggingFrame(bounds, contents: dragImage())
    let session = beginDraggingSession(with: [item], event: mouseDown, source: self)
    session.animatesToStartingPositionsOnCancelOrFail = true
    state.isDragging = true
  }

  // The row as an opaque image, so that it is easy to see over any window.
  private func dragImage() -> NSImage {
    let size = bounds.size
    let appearance = effectiveAppearance
    let icon = NSApp.applicationIconImage ?? NSImage()
    return NSImage(size: size, flipped: false) { rect in
      appearance.performAsCurrentDrawingAppearance {
        let path = NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: 9, yRadius: 9)
        NSColor.windowBackgroundColor.withAlphaComponent(0.96).setFill()
        path.fill()
        NSColor.labelColor.withAlphaComponent(0.12).setStroke()
        path.stroke()
        icon.draw(in: NSRect(x: 10, y: (size.height - 26) / 2, width: 26, height: 26))
        let name = Brand.nsName(size: 13, color: .labelColor)
        name.draw(at: NSPoint(x: 46, y: (size.height - name.size().height) / 2))
      }
      return true
    }
  }

  func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
    .copy
  }

  func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
    state.isDragging = false
    state.isHovering = false
    if !operation.isEmpty { state.onDrop() }
  }
}
