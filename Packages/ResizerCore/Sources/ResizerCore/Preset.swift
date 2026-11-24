import Foundation

public enum PresetGroup: String, Codable, CaseIterable, Sendable {
  case ratios
  case screens
  case social
  case appStore
  case custom

  public var title: String {
    switch self {
    case .ratios: "Ratios"
    case .screens: "Screens"
    case .social: "Social"
    case .appStore: "App Store"
    case .custom: "Custom"
    }
  }
}

public struct Preset: Codable, Hashable, Identifiable, Sendable {
  public var id: String
  public var name: String
  public var group: PresetGroup
  public var target: PresetTarget

  public init(id: String, name: String, group: PresetGroup, target: PresetTarget) {
    self.id = id
    self.name = name
    self.group = group
    self.target = target
  }

  public var isCustom: Bool { group == .custom }
}

/**
 The built-in presets. Social sizes change often: check them against the platform documentation
 before each release.
 */
public enum PresetCatalog {
  public static let builtIn: [Preset] = ratios + screens + social + appStore

  public static let defaultFavorites = ["ratio.16x9", "screen.fullhd", "social.og", "screen.4k"]

  static let ratios: [Preset] = [
    ratio("16x9", "16:9", 16, 9),
    ratio("16x10", "16:10", 16, 10),
    ratio("4x3", "4:3", 4, 3),
    ratio("3x2", "3:2", 3, 2),
    ratio("1x1", "1:1", 1, 1),
    ratio("4x5", "4:5", 4, 5),
    ratio("9x16", "9:16", 9, 16),
    ratio("21x9", "21:9", 21, 9),
    ratio("2x1", "2:1", 2, 1),
    ratio("1.91x1", "1.91:1", 1.91, 1),
  ]

  static let screens: [Preset] = [
    size("screen.hd", "HD", .screens, 1280, 720),
    size("screen.fullhd", "Full HD", .screens, 1920, 1080),
    size("screen.qhd", "QHD", .screens, 2560, 1440),
    size("screen.4k", "4K UHD", .screens, 3840, 2160),
    size("screen.mba13", "MacBook Air 13\"", .screens, 2560, 1664),
    size("screen.mbp14", "MacBook Pro 14\"", .screens, 3024, 1964),
  ]

  static let social: [Preset] = [
    size("social.x.post", "X post", .social, 1600, 900),
    size("social.x.header", "X header", .social, 1500, 500),
    size("social.linkedin.post", "LinkedIn post", .social, 1200, 627),
    size("social.linkedin.square", "LinkedIn square", .social, 1200, 1200),
    size("social.linkedin.cover", "LinkedIn cover", .social, 1584, 396),
    size("social.instagram.square", "Instagram square", .social, 1080, 1080),
    size("social.instagram.portrait", "Instagram portrait", .social, 1080, 1350),
    size("social.instagram.story", "Instagram story", .social, 1080, 1920),
    size("social.youtube.thumbnail", "YouTube thumbnail", .social, 1280, 720),
    size("social.og", "Open Graph image", .social, 1200, 630),
    size("social.producthunt", "Product Hunt gallery", .social, 1270, 760),
  ]

  static let appStore: [Preset] = [
    size("appstore.1280", "Mac 1280 × 800", .appStore, 1280, 800),
    size("appstore.1440", "Mac 1440 × 900", .appStore, 1440, 900),
    size("appstore.2560", "Mac 2560 × 1600", .appStore, 2560, 1600),
    size("appstore.2880", "Mac 2880 × 1800", .appStore, 2880, 1800),
  ]

  static func ratio(_ key: String, _ name: String, _ width: Double, _ height: Double) -> Preset {
    Preset(id: "ratio.\(key)", name: name, group: .ratios, target: .ratio(AspectRatio(width, height)))
  }

  static func size(_ id: String, _ name: String, _ group: PresetGroup, _ width: Int, _ height: Int) -> Preset {
    Preset(id: id, name: name, group: group, target: .size(width: width, height: height))
  }
}
