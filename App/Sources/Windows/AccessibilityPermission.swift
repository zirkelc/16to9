import AppKit
import ApplicationServices
import Observation

/**
 The state of the Accessibility permission. The user can give or remove it at any time in System
 Settings, so the app checks it again when macOS reports a change of the privacy settings and when
 the app becomes active. While the app waits for the user, it also checks two times a second.
 */
@Observable
final class AccessibilityPermission {
  private(set) var isGranted = false
  @ObservationIgnored private var watchTask: Task<Void, Never>?
  // The app keeps one instance for its whole run, so the observers are never removed.
  @ObservationIgnored private var observers: [NSObjectProtocol] = []

  init() {
    refresh()
    let refresh: @Sendable (Notification) -> Void = { [weak self] _ in
      MainActor.assumeIsolated { self?.refresh() }
    }
    let distributed = DistributedNotificationCenter.default()
    let local = NotificationCenter.default
    observers = [
      distributed.addObserver(forName: Notification.Name("com.apple.TCC.updated"), object: nil, queue: .main, using: refresh),
      local.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main, using: refresh),
    ]
  }

  func refresh() {
    var granted = AXIsProcessTrusted()
    #if DEBUG
      // Shows the screens for a missing permission, also when the permission is on.
      if ProcessInfo.processInfo.environment["APP_DEBUG_DENIED"] != nil { granted = false }
    #endif
    if granted != isGranted {
      Log.permission.notice("Accessibility permission: \(granted ? "granted" : "not granted", privacy: .public)")
      isGranted = granted
    }
  }

  // Checks the permission for ten minutes, or until the user gives it.
  func startWatching() {
    guard !isGranted, watchTask == nil else { return }
    watchTask = Task { [weak self] in
      for _ in 0..<1_200 {
        try? await Task.sleep(for: .milliseconds(500))
        guard let self, !Task.isCancelled else { return }
        self.refresh()
        if self.isGranted { break }
      }
      self?.watchTask = nil
    }
  }
}
