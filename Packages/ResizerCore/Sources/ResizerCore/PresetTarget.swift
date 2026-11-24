import Foundation

/**
 What a preset sets: an exact size or a ratio.
 Sizes are plain numbers. The app reads them in the unit that the user selects (pixels or points).
 */
public enum PresetTarget: Codable, Hashable, Sendable {
  case size(width: Int, height: Int)
  case ratio(AspectRatio)

  public var label: String {
    switch self {
    case .size(let width, let height): "\(width) × \(height)"
    case .ratio(let ratio): ratio.label
    }
  }

  public var ratioLabel: String {
    switch self {
    case .size(let width, let height): AspectRatio.describe(width: width, height: height)
    case .ratio(let ratio): ratio.label
    }
  }

  public var ratioValue: Double {
    switch self {
    case .size(let width, let height): Double(width) / Double(height)
    case .ratio(let ratio): ratio.value
    }
  }

  public var isRatio: Bool {
    if case .ratio = self { return true }
    return false
  }
}

// The unit for sizes that the user sees and types.
public enum SizeUnit: String, Codable, CaseIterable, Sendable {
  case pixels
  case points

  public var symbol: String {
    switch self {
    case .pixels: "px"
    case .points: "pt"
    }
  }

  // Number of units in one point. On a Retina screen (scale 2), one point is two pixels.
  public func unitsPerPoint(scale: Double) -> Double {
    switch self {
    case .pixels: scale
    case .points: 1
    }
  }
}
