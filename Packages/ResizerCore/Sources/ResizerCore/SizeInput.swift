import Foundation

// Reads a size or a ratio that the user types, for example "1280x720", "1280 × 720", "16:9" or "1.91:1".
public enum SizeInput {
  public static let sizeRange = 50...20_000
  public static let ratioRange = 0.1...10.0

  public static func parse(_ text: String) -> PresetTarget? {
    let input = text
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
      .replacingOccurrences(of: "×", with: "x")

    if let match = input.wholeMatch(of: /(\d{1,5})\s*(?:x|\*|,|\s)\s*(\d{1,5})/) {
      guard let width = Int(match.1), let height = Int(match.2) else { return nil }
      guard sizeRange.contains(width), sizeRange.contains(height) else { return nil }
      return .size(width: width, height: height)
    }

    if let match = input.wholeMatch(of: /(\d+(?:\.\d+)?)\s*[:\/]\s*(\d+(?:\.\d+)?)/) {
      guard let width = Double(match.1), let height = Double(match.2), width > 0, height > 0 else { return nil }
      guard ratioRange.contains(width / height) else { return nil }
      return .ratio(AspectRatio(width, height))
    }

    return nil
  }

  // Reads a size from two fields, one for the width and one for the height.
  public static func size(width: String, height: String) -> PresetTarget? {
    guard let width = Int(width.trimmingCharacters(in: .whitespaces)),
      let height = Int(height.trimmingCharacters(in: .whitespaces)),
      sizeRange.contains(width), sizeRange.contains(height)
    else { return nil }
    return .size(width: width, height: height)
  }

  // Reads a ratio from two fields. A decimal comma counts as a decimal point.
  public static func ratio(width: String, height: String) -> PresetTarget? {
    func number(_ text: String) -> Double? {
      Double(text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))
    }
    guard let width = number(width), let height = number(height), width > 0, height > 0,
      ratioRange.contains(width / height)
    else { return nil }
    return .ratio(AspectRatio(width, height))
  }
}
