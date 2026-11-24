import AppKit
import Observation
import ResizerCore

// The front window of an app at one point in time.
struct WindowSnapshot {
  let app: NSRunningApplication
  let window: AXWindow
  let frame: CGRect
  let screen: ScreenInfo
  let isResizable: Bool
  let isFullScreen: Bool

  var appName: String { app.localizedName ?? String(localized: "App") }

  @MainActor
  static func capture(app: NSRunningApplication) -> WindowSnapshot? {
    guard let window = AXWindow.focused(pid: app.processIdentifier), let frame = window.frame,
      let screen = ScreenInfo.containing(frame)
    else { return nil }
    return WindowSnapshot(
      app: app, window: window, frame: frame, screen: screen,
      isResizable: window.isResizable, isFullScreen: window.isFullScreen
    )
  }
}

enum ResizeOutcome {
  case resized(requested: CGRect, actual: CGRect)
  case tooLarge
  case notResizable
  case fullScreen
}

/**
 Applies sizes to windows of other apps and keeps the previous frames for undo.
 */
@Observable
final class ResizeService {
  private struct UndoEntry {
    let window: AXWindow
    let frame: CGRect
  }

  private var undoStack: [UndoEntry] = []
  @ObservationIgnored private let undoLimit = 20

  var canUndo: Bool { !undoStack.isEmpty }

  /**
   Tries the candidate sizes for the target one after the other. It stops at the first size that the
   app accepts. When no size is accepted exactly, the result has the real frame of the last try.
   */
  func resize(_ snapshot: WindowSnapshot, to target: PresetTarget, settings: AppSettings) async -> ResizeOutcome {
    if snapshot.isFullScreen { return .fullScreen }
    if !snapshot.isResizable { return .notResizable }

    let unitsPerPoint = snapshot.screen.unitsPerPoint(settings.units)
    let context = FitContext(
      window: snapshot.frame, visible: snapshot.screen.visibleFrame,
      unitsPerPoint: unitsPerPoint, mode: settings.fitMode, anchor: settings.anchor
    )
    let candidates = FitCalculator.candidates(for: target, in: context)
    guard !candidates.isEmpty else { return .tooLarge }

    pushUndo(snapshot.window, snapshot.frame)
    var requested = CGRect.zero
    var actual = snapshot.frame
    for size in candidates {
      requested = FitCalculator.place(size, in: context)
      actual = await apply(requested, to: snapshot.window) ?? actual
      if Self.matches(actual.size, requested.size, unitsPerPoint: unitsPerPoint) { break }
    }
    return .resized(requested: requested, actual: actual)
  }

  // Sets an exact frame, for example the frame of the guide.
  func setFrame(_ frame: CGRect, of snapshot: WindowSnapshot) async -> ResizeOutcome {
    if snapshot.isFullScreen { return .fullScreen }
    if !snapshot.isResizable { return .notResizable }
    pushUndo(snapshot.window, snapshot.frame)
    let actual = await apply(frame, to: snapshot.window) ?? snapshot.frame
    return .resized(requested: frame, actual: actual)
  }

  // Restores the frame before the last change. Returns false when there is nothing to undo.
  @discardableResult
  func undo() async -> Bool {
    guard let entry = undoStack.popLast() else { return false }
    _ = await apply(entry.frame, to: entry.window)
    return true
  }

  private func apply(_ frame: CGRect, to window: AXWindow) async -> CGRect? {
    window.setFrame(frame)
    // Some apps apply the size a short time after the call returns.
    try? await Task.sleep(for: .milliseconds(80))
    return window.frame
  }

  private func pushUndo(_ window: AXWindow, _ frame: CGRect) {
    undoStack.append(UndoEntry(window: window, frame: frame))
    if undoStack.count > undoLimit { undoStack.removeFirst() }
  }

  static func matches(_ a: CGSize, _ b: CGSize, unitsPerPoint: Double) -> Bool {
    let tolerance = 0.5 / unitsPerPoint
    return abs(a.width - b.width) < tolerance && abs(a.height - b.height) < tolerance
  }
}
