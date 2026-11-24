import Foundation

// A ratio of width to height, for example 16:9 or 1.91:1.
public struct AspectRatio: Codable, Hashable, Sendable {
  public var width: Double
  public var height: Double

  public init(_ width: Double, _ height: Double) {
    self.width = width
    self.height = height
  }

  public var value: Double { width / height }

  public var label: String { "\(Self.format(width)):\(Self.format(height))" }

  /**
   Describes the ratio of a size in a short form. Small whole ratios show as "16:9".
   Other ratios show as a decimal, for example "1.91:1".
   */
  public static func describe(width: Int, height: Int) -> String {
    guard width > 0, height > 0 else { return "" }
    let divisor = gcd(width, height)
    let w = width / divisor
    let h = height / divisor
    if w <= 32 && h <= 32 { return "\(w):\(h)" }
    let value = Double(width) / Double(height)
    if value >= 1 { return "\(format(rounded(value))):1" }
    return "1:\(format(rounded(1 / value)))"
  }

  static func rounded(_ value: Double) -> Double { (value * 100).rounded() / 100 }

  static func format(_ value: Double) -> String {
    // A whole number can be larger than the largest integer, for example from the input "1e20".
    if value == value.rounded() { return String(format: "%.0f", value) }
    var text = String(format: "%.2f", value)
    while text.hasSuffix("0") { text.removeLast() }
    if text.hasSuffix(".") { text.removeLast() }
    return text
  }

  static func gcd(_ a: Int, _ b: Int) -> Int {
    var a = a
    var b = b
    while b != 0 { (a, b) = (b, a % b) }
    return a
  }
}
