import Foundation
import ResizerCore

extension PresetGroup {
  var displayTitle: String {
    switch self {
    case .ratios: String(localized: "Ratios")
    case .screens: String(localized: "Screens")
    case .social: String(localized: "Social")
    case .appStore: String(localized: "App Store")
    case .custom: String(localized: "Custom")
    }
  }
}

extension Preset {
  // Built-in names are translated in the "Presets" table. Custom presets keep the name that the user typed.
  var displayName: String {
    guard group != .custom else { return name }
    return Bundle.main.localizedString(forKey: name, value: name, table: "Presets")
  }
}
