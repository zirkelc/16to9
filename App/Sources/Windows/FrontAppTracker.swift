import AppKit

/**
 Remembers the last active app that is not this app. When the popover opens, this app becomes
 active, but the resize must go to the app that the user worked in before.
 */
final class FrontAppTracker {
  private(set) var lastApp: NSRunningApplication?
  private var observer: NSObjectProtocol?

  init() {
    if let front = NSWorkspace.shared.frontmostApplication, !Self.isSelf(front) {
      lastApp = front
    }
    observer = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
    ) { [weak self] note in
      let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
      let pid = app?.processIdentifier
      MainActor.assumeIsolated {
        guard let pid, let app = NSRunningApplication(processIdentifier: pid), !Self.isSelf(app) else { return }
        self?.lastApp = app
      }
    }
  }

  // The app that gets the resize: the front app, or the last front app when this app is in front.
  var targetApp: NSRunningApplication? {
    if let front = NSWorkspace.shared.frontmostApplication, !Self.isSelf(front) { return front }
    if let lastApp, !lastApp.isTerminated { return lastApp }
    return nil
  }

  private static func isSelf(_ app: NSRunningApplication) -> Bool {
    app.processIdentifier == ProcessInfo.processInfo.processIdentifier
  }
}
