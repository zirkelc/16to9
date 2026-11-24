import Foundation

// The changes of the user to the presets. The app stores this value as JSON.
public struct PresetPreferences: Codable, Equatable, Sendable {
  public var favorites: [String]
  public var custom: [Preset]

  public init(favorites: [String] = PresetCatalog.defaultFavorites, custom: [Preset] = []) {
    self.favorites = favorites
    self.custom = custom
  }
}

// Built-in presets combined with the changes of the user.
public struct PresetLibrary: Equatable, Sendable {
  public var builtIn: [Preset]
  public var preferences: PresetPreferences

  public init(builtIn: [Preset] = PresetCatalog.builtIn, preferences: PresetPreferences = PresetPreferences()) {
    self.builtIn = builtIn
    self.preferences = preferences
  }

  public var all: [Preset] { builtIn + preferences.custom }

  public func preset(id: String) -> Preset? { all.first { $0.id == id } }

  public func presets(in group: PresetGroup) -> [Preset] { all.filter { $0.group == group } }

  // Favorites in the order of the user.
  public var favorites: [Preset] { preferences.favorites.compactMap { preset(id: $0) } }

  public func isFavorite(_ id: String) -> Bool { preferences.favorites.contains(id) }

  /**
   Presets whose name, size, ratio or group contains all words of the query. An empty query gives no
   result. The extra text adds, for example, translated names.
   */
  public func search(_ query: String, extraText: (Preset) -> String = { _ in "" }) -> [Preset] {
    let words = query.lowercased().split(separator: " ").map(String.init)
    guard !words.isEmpty else { return [] }
    return all.filter { preset in
      let base = "\(preset.name) \(preset.target.label) \(preset.target.ratioLabel) \(preset.group.title)"
      let text = "\(base) \(extraText(preset))".lowercased()
      return words.allSatisfy { text.contains($0) }
    }
  }

  public mutating func setFavorite(_ id: String, _ isFavorite: Bool) {
    preferences.favorites.removeAll { $0 == id }
    if isFavorite { preferences.favorites.append(id) }
  }

  // Moves a favorite to the place of another favorite. The other favorites keep their order.
  public mutating func moveFavorite(_ id: String, to target: String) {
    var favorites = preferences.favorites
    guard let from = favorites.firstIndex(of: id), let to = favorites.firstIndex(of: target), from != to else { return }
    favorites.remove(at: from)
    favorites.insert(id, at: to)
    preferences.favorites = favorites
  }

  @discardableResult
  public mutating func addCustom(name: String, target: PresetTarget) -> Preset {
    let preset = Preset(id: "custom.\(UUID().uuidString)", name: name, group: .custom, target: target)
    preferences.custom.append(preset)
    return preset
  }

  public mutating func updateCustom(_ preset: Preset) {
    guard let index = preferences.custom.firstIndex(where: { $0.id == preset.id }) else { return }
    preferences.custom[index] = preset
  }

  // Deletes a custom preset. Built-in presets cannot be deleted.
  public mutating func removeCustom(_ id: String) {
    guard preferences.custom.contains(where: { $0.id == id }) else { return }
    preferences.custom.removeAll { $0.id == id }
    preferences.favorites.removeAll { $0 == id }
  }

  // Resets the favorites. Custom presets stay.
  public mutating func restoreDefaults() {
    preferences.favorites = PresetCatalog.defaultFavorites
  }
}
