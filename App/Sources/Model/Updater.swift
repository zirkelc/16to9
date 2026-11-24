import Foundation
import Observation
import Sparkle

/**
 Checks for new versions with Sparkle. The updater starts only when the build has a feed URL and
 a public key, so that development builds do not show update errors.
 */
@Observable
final class Updater {
  @ObservationIgnored private let controller: SPUStandardUpdaterController?
  private(set) var canCheck = false

  var checksAutomatically: Bool {
    get {
      access(keyPath: \.checksAutomatically)
      return controller?.updater.automaticallyChecksForUpdates ?? false
    }
    set {
      withMutation(keyPath: \.checksAutomatically) {
        controller?.updater.automaticallyChecksForUpdates = newValue
      }
    }
  }

  var isConfigured: Bool { controller != nil }

  init(bundle: Bundle = .main) {
    let key = bundle.object(forInfoDictionaryKey: "SUPublicEDKey") as? String ?? ""
    let feed = bundle.object(forInfoDictionaryKey: "SUFeedURL") as? String ?? ""
    guard !key.isEmpty, !feed.isEmpty else {
      Log.app.notice("Updates are off: the build has no feed URL or no public key")
      controller = nil
      return
    }
    controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    canCheck = controller?.updater.canCheckForUpdates ?? false
    observation = controller?.updater.observe(\.canCheckForUpdates, options: [.new]) { [weak self] updater, _ in
      MainActor.assumeIsolated { self?.canCheck = updater.canCheckForUpdates }
    }
  }

  @ObservationIgnored private var observation: NSKeyValueObservation?

  func checkForUpdates() {
    controller?.checkForUpdates(nil)
  }
}
