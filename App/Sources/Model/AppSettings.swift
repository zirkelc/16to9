import AppKit
import Observation
import ResizerCore
import SwiftUI

enum PopoverLayout: String, CaseIterable, Identifiable {
  case list
  case grid

  var id: String { rawValue }

  var title: String {
    switch self {
    case .list: String(localized: "List")
    case .grid: String(localized: "Grid")
    }
  }

  var symbol: String {
    switch self {
    case .list: "list.bullet"
    case .grid: "square.grid.3x3"
    }
  }
}

enum PresetAction: String, CaseIterable, Identifiable {
  case resize
  case guide

  var id: String { rawValue }

  var title: String {
    switch self {
    case .resize: String(localized: "Resize window")
    case .guide: String(localized: "Show guide")
    }
  }
}

enum GuideColor: String, CaseIterable, Identifiable {
  case amber
  case cyan
  case pink
  case white

  var id: String { rawValue }

  var color: Color {
    switch self {
    case .amber: Brand.amber
    case .cyan: Color(red: 0.18, green: 0.90, blue: 0.84)
    case .pink: Color(red: 1.0, green: 0.22, blue: 0.37)
    case .white: .white
    }
  }

  // The color of an edge that is not at its target. It must be clearly different from the guide color.
  var offColor: Color {
    switch self {
    case .pink: Color(red: 1.0, green: 0.62, blue: 0.04)
    case .amber, .cyan, .white: Color(red: 1.0, green: 0.27, blue: 0.23)
    }
  }

  var title: String {
    switch self {
    case .amber: String(localized: "Amber")
    case .cyan: String(localized: "Cyan")
    case .pink: String(localized: "Pink")
    case .white: String(localized: "White")
    }
  }
}

/**
 All user settings. Each property writes its value to the user defaults when it changes.
 */
@Observable
final class AppSettings {
  @ObservationIgnored private let defaults: UserDefaults

  var units: SizeUnit { didSet { defaults.set(units.rawValue, forKey: Key.units) } }
  var fitMode: FitMode { didSet { defaults.set(fitMode.rawValue, forKey: Key.fitMode) } }
  var anchor: ResizeAnchor { didSet { defaults.set(anchor.rawValue, forKey: Key.anchor) } }
  var popoverLayout: PopoverLayout { didSet { defaults.set(popoverLayout.rawValue, forKey: Key.popoverLayout) } }
  var action: PresetAction { didSet { defaults.set(action.rawValue, forKey: Key.action) } }
  var guideColor: GuideColor { didSet { defaults.set(guideColor.rawValue, forKey: Key.guideColor) } }
  var showCenterLines: Bool { didSet { defaults.set(showCenterLines, forKey: Key.showCenterLines) } }
  var dimOutsideGuide: Bool { didSet { defaults.set(dimOutsideGuide, forKey: Key.dimOutsideGuide) } }
  var hideGuideInScreenshots: Bool { didSet { defaults.set(hideGuideInScreenshots, forKey: Key.hideGuideInScreenshots) } }
  var escapeHidesGuide: Bool { didSet { defaults.set(escapeHidesGuide, forKey: Key.escapeHidesGuide) } }
  var arrowKeysMoveGuide: Bool { didSet { defaults.set(arrowKeysMoveGuide, forKey: Key.arrowKeysMoveGuide) } }
  // The keys that control the guide while it shows.
  var guideKeys: GuideKeys {
    var keys: GuideKeys = []
    if escapeHidesGuide { keys.insert(.escape) }
    if arrowKeysMoveGuide { keys.insert(.arrows) }
    return keys
  }

  var showToasts: Bool { didSet { defaults.set(showToasts, forKey: Key.showToasts) } }
  var showsSizePreview: Bool { didSet { defaults.set(showsSizePreview, forKey: Key.showsSizePreview) } }
  var collapsedGroups: Set<String> { didSet { defaults.set(Array(collapsedGroups), forKey: Key.collapsedGroups) } }
  var gridTab: String { didSet { defaults.set(gridTab, forKey: Key.gridTab) } }
  var hasSeenOnboarding: Bool { didSet { defaults.set(hasSeenOnboarding, forKey: Key.hasSeenOnboarding) } }
  var lastGuidePresetID: String? { didSet { defaults.set(lastGuidePresetID, forKey: Key.lastGuidePresetID) } }

  var presets: PresetLibrary {
    didSet {
      guard presets.preferences != oldValue.preferences else { return }
      if let data = try? JSONEncoder().encode(presets.preferences) {
        defaults.set(data, forKey: Key.presetPreferences)
      }
    }
  }

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    units = Self.load(defaults, Key.units, .pixels)
    fitMode = Self.load(defaults, Key.fitMode, .smallestChange)
    anchor = Self.load(defaults, Key.anchor, .topLeft)
    popoverLayout = Self.load(defaults, Key.popoverLayout, .list)
    action = Self.load(defaults, Key.action, .resize)
    guideColor = Self.load(defaults, Key.guideColor, .amber)
    showCenterLines = Self.bool(defaults, Key.showCenterLines, false)
    dimOutsideGuide = Self.bool(defaults, Key.dimOutsideGuide, true)
    hideGuideInScreenshots = Self.bool(defaults, Key.hideGuideInScreenshots, true)
    escapeHidesGuide = Self.bool(defaults, Key.escapeHidesGuide, true)
    arrowKeysMoveGuide = Self.bool(defaults, Key.arrowKeysMoveGuide, true)
    showToasts = Self.bool(defaults, Key.showToasts, true)
    showsSizePreview = Self.bool(defaults, Key.showsSizePreview, true)
    let collapsed = defaults.stringArray(forKey: Key.collapsedGroups)
    collapsedGroups = Set(collapsed ?? [PresetGroup.ratios, .screens, .appStore].map(\.rawValue))
    gridTab = defaults.string(forKey: Key.gridTab) ?? "favorites"
    hasSeenOnboarding = defaults.bool(forKey: Key.hasSeenOnboarding)
    lastGuidePresetID = defaults.string(forKey: Key.lastGuidePresetID)

    var preferences = PresetPreferences()
    if let data = defaults.data(forKey: Key.presetPreferences),
      let stored = try? JSONDecoder().decode(PresetPreferences.self, from: data)
    {
      preferences = stored
    }
    presets = PresetLibrary(preferences: preferences)
  }

  // Reads a Boolean value, also from a launch argument such as "-dimOutsideGuide NO".
  private static func bool(_ defaults: UserDefaults, _ key: String, _ fallback: Bool) -> Bool {
    defaults.object(forKey: key) == nil ? fallback : defaults.bool(forKey: key)
  }

  private static func load<VALUE: RawRepresentable<String>>(_ defaults: UserDefaults, _ key: String, _ fallback: VALUE) -> VALUE {
    defaults.string(forKey: key).flatMap { VALUE(rawValue: $0) } ?? fallback
  }

  private enum Key {
    static let units = "units"
    static let fitMode = "fitMode"
    static let anchor = "anchor"
    static let popoverLayout = "popoverLayout"
    static let action = "action"
    static let guideColor = "guideColor"
    static let showCenterLines = "showCenterLines"
    static let dimOutsideGuide = "dimOutsideGuide"
    static let hideGuideInScreenshots = "hideGuideInScreenshots"
    static let escapeHidesGuide = "escapeHidesGuide"
    static let arrowKeysMoveGuide = "arrowKeysMoveGuide"
    static let showToasts = "showToasts"
    static let showsSizePreview = "showsSizePreview"
    static let collapsedGroups = "collapsedGroups"
    static let gridTab = "gridTab"
    static let hasSeenOnboarding = "hasSeenOnboarding"
    static let lastGuidePresetID = "lastGuidePresetID"
    static let presetPreferences = "presetPreferences"
  }
}
