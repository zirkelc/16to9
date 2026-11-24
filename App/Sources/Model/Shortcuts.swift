import KeyboardShortcuts
import ResizerCore
import SwiftUI

extension KeyboardShortcuts.Name {
  // The guide has a default shortcut, so that the guide can show and hide from any app.
  static let toggleGuide = Self("toggleGuide", default: .init(.g, modifiers: [.control, .option]))
  static let undoResize = Self("undoResize")

  static func preset(_ id: String) -> Self { Self("preset.\(id)") }
}

/**
 Connects the global shortcuts to the actions. A preset shortcut always resizes the front window.
 */
final class ShortcutCenter {
  private let model: AppModel
  private var registeredPresets: Set<String> = []

  init(model: AppModel) {
    self.model = model
  }

  func start() {
    KeyboardShortcuts.onKeyUp(for: .toggleGuide) { [weak self] in
      Log.shortcuts.info("Shortcut: show or hide the guide")
      self?.model.toggleGuide()
    }
    KeyboardShortcuts.onKeyUp(for: .undoResize) { [weak self] in
      Log.shortcuts.info("Shortcut: undo")
      self?.model.undo()
    }
    ShortcutField.findOwner = { [weak self] shortcut, name in self?.owner(of: shortcut, except: name) }
    syncPresets()
  }

  // The name of the action that uses the shortcut, other than the given one, or nil.
  func owner(of shortcut: KeyboardShortcuts.Shortcut, except name: KeyboardShortcuts.Name) -> String? {
    let actions: [(KeyboardShortcuts.Name, String)] = [
      (.toggleGuide, String(localized: "Show or hide the guide")),
      (.undoResize, String(localized: "Undo the last resize")),
    ]
    for (other, title) in actions where other != name && KeyboardShortcuts.getShortcut(for: other) == shortcut {
      return title
    }
    for preset in model.settings.presets.all where KeyboardShortcuts.Name.preset(preset.id) != name {
      if KeyboardShortcuts.getShortcut(for: .preset(preset.id)) == shortcut { return preset.displayName }
    }
    return nil
  }

  // Adds handlers for new presets and removes the handlers of deleted presets.
  func syncPresets() {
    let ids = Set(model.settings.presets.all.map(\.id))
    for id in ids.subtracting(registeredPresets) {
      KeyboardShortcuts.onKeyUp(for: .preset(id)) { [weak self] in
        guard let self, let preset = self.model.settings.presets.preset(id: id) else { return }
        Log.shortcuts.info("Shortcut: preset \(preset.id, privacy: .public)")
        self.model.resize(to: preset.target)
      }
    }
    for id in registeredPresets.subtracting(ids) {
      KeyboardShortcuts.removeHandler(for: .preset(id))
      KeyboardShortcuts.reset(.preset(id))
    }
    registeredPresets = ids
  }
}
