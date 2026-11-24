import Foundation
import Testing

@testable import ResizerCore

@Suite("PresetLibrary")
struct PresetLibraryTests {
  @Test("built-in presets have unique IDs")
  func uniqueIDs() {
    // Arrange
    let ids = PresetCatalog.builtIn.map(\.id)

    // Act
    let unique = Set(ids)

    // Assert
    #expect(unique.count == ids.count)
  }

  @Test("default favorites exist in the catalog")
  func defaultFavoritesExist() {
    // Arrange
    let library = PresetLibrary()

    // Act
    let favorites = library.favorites

    // Assert
    #expect(favorites.map(\.id) == PresetCatalog.defaultFavorites)
  }

  @Test("a favorite moves to the place of another favorite", arguments: [
    ("a", "c", ["b", "c", "a", "d"]),
    ("d", "b", ["a", "d", "b", "c"]),
    ("b", "b", ["a", "b", "c", "d"]),
    ("x", "b", ["a", "b", "c", "d"]),
  ])
  func movesFavorite(id: String, target: String, expected: [String]) {
    // Arrange
    var library = PresetLibrary(preferences: PresetPreferences(favorites: ["a", "b", "c", "d"]))

    // Act
    library.moveFavorite(id, to: target)

    // Assert
    #expect(library.preferences.favorites == expected)
  }

  @Test("favorites keep the order in which they were added")
  func favoriteOrder() {
    // Arrange
    var library = PresetLibrary(preferences: PresetPreferences(favorites: []))

    // Act
    library.setFavorite("ratio.4x3", true)
    library.setFavorite("social.og", true)
    library.setFavorite("ratio.4x3", false)
    library.setFavorite("ratio.1x1", true)

    // Assert
    #expect(library.favorites.map(\.id) == ["social.og", "ratio.1x1"])
  }

  @Test("removing a custom preset also removes it from favorites")
  func removesCustom() {
    // Arrange
    var library = PresetLibrary()
    let preset = library.addCustom(name: "Blog header", target: .size(width: 1400, height: 600))
    library.setFavorite(preset.id, true)

    // Act
    library.removeCustom(preset.id)

    // Assert
    #expect(library.preset(id: preset.id) == nil)
    #expect(library.isFavorite(preset.id) == false)
  }

  @Test("built-in presets cannot be removed")
  func keepsBuiltIn() {
    // Arrange
    var library = PresetLibrary()

    // Act
    library.removeCustom("ratio.16x9")

    // Assert
    #expect(library.preset(id: "ratio.16x9") != nil)
  }

  @Test("restore defaults resets the favorites and keeps custom presets")
  func restoresDefaults() {
    // Arrange
    var library = PresetLibrary(preferences: PresetPreferences(favorites: []))
    let custom = library.addCustom(name: "Mine", target: .ratio(AspectRatio(5, 4)))

    // Act
    library.restoreDefaults()

    // Assert
    #expect(library.favorites.map(\.id) == PresetCatalog.defaultFavorites)
    #expect(library.preset(id: custom.id) == custom)
  }

  @Test("search finds presets by name and size")
  func searches() {
    // Arrange
    let library = PresetLibrary()

    // Act
    let byName = library.search("linkedin cover")
    let bySize = library.search("1200 × 630")

    // Assert
    #expect(byName.map(\.id) == ["social.linkedin.cover"])
    #expect(bySize.map(\.id) == ["social.og"])
  }

  @Test("search also matches the extra text, for example a translated name")
  func searchesExtraText() {
    // Arrange
    let library = PresetLibrary()
    let translated = ["social.og": "Open-Graph-Bild"]

    // Act
    let result = library.search("graph-bild") { translated[$0.id] ?? "" }

    // Assert
    #expect(result.map(\.id) == ["social.og"])
  }

  @Test("preferences survive a JSON round trip")
  func codable() throws {
    // Arrange
    var library = PresetLibrary()
    library.addCustom(name: "Wide", target: .ratio(AspectRatio(1.91, 1)))
    library.setFavorite("ratio.2x1", true)

    // Act
    let data = try JSONEncoder().encode(library.preferences)
    let decoded = try JSONDecoder().decode(PresetPreferences.self, from: data)

    // Assert
    #expect(decoded == library.preferences)
  }
}
