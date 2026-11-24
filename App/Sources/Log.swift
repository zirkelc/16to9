import Foundation
import OSLog

/**
 The loggers of the app, one for each area. They write to the unified system log, so Console.app and
 the `log` command can show them. The subsystem is the bundle ID, so the logs of the dev build and the
 release build stay apart.

 Notice and error messages stay on disk. Info and debug messages are only in memory, or in a live
 `log stream`. App names and bundle IDs are public, because they are necessary to debug a resize.
 Window titles are never logged, because they can contain private text.
 */
enum Log {
  static let subsystem = Bundle.main.bundleIdentifier ?? "dev.zirkelc.16to9"

  static let app = Logger(subsystem: subsystem, category: "app")
  static let resize = Logger(subsystem: subsystem, category: "resize")
  static let guide = Logger(subsystem: subsystem, category: "guide")
  static let permission = Logger(subsystem: subsystem, category: "permission")
  static let shortcuts = Logger(subsystem: subsystem, category: "shortcuts")
}

extension CGRect {
  // A short form for log messages, for example "(100, 80) 1200×675".
  var logDescription: String {
    "(\(Int(minX.rounded())), \(Int(minY.rounded()))) \(Int(width.rounded()))×\(Int(height.rounded()))"
  }
}
