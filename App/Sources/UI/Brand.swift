import AppKit
import SwiftUI

// The brand colors. They match the app icon: a navy tile with white rulers and an amber guide frame.
enum Brand {
  // The amber of the guide frame in the icon.
  static let amber = Color(red: 1.0, green: 0.71, blue: 0.28)
  // The lower stop of the amber button gradient.
  static let amberDeep = Color(red: 0.95, green: 0.60, blue: 0.16)
  // The navy of the icon tile.
  static let navy = Color(red: 0.14, green: 0.31, blue: 0.63)
  // The darkest navy. Text and glyphs on amber use it.
  static let ink = Color(red: 0.04, green: 0.11, blue: 0.27)
  // The background of dark brand surfaces, for example the onboarding window.
  static let night = Color(red: 0.03, green: 0.06, blue: 0.14)

  // The amber of the "to" in the app name. It is darker on a light background, because the icon amber is too light to read on white.
  static let nameAccent = NSColor(name: nil) { appearance in
    appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
      ? NSColor(srgbRed: 1.0, green: 0.71, blue: 0.28, alpha: 1)
      : NSColor(srgbRed: 0.85, green: 0.55, blue: 0.0, alpha: 1)
  }
}

// The app name in its brand style: JetBrains Mono ExtraBold, with "to" in amber. The font file is in the app bundle.
extension Brand {
  static let name = "16to9"
  static let nameFontName = "JetBrainsMono-ExtraBold"

  // The app name alone, in the brand style.
  static func nameText(size: CGFloat) -> Text {
    Text(styled(AttributedString(name), size: size))
  }

  // A localized text. Each "16to9" in it has the brand style. The other characters keep the font and color of the view.
  static func text(_ resource: LocalizedStringResource, size: CGFloat) -> Text {
    Text(styled(AttributedString(localized: resource), size: size))
  }

  // Each "16to9" in the string gets the brand font, and its "to" gets the amber color.
  static func styled(_ string: AttributedString, size: CGFloat) -> AttributedString {
    var result = string
    var start = result.startIndex
    while let range = result[start...].range(of: name) {
      result[range].font = .custom(nameFontName, size: size)
      let accentStart = result.index(range.lowerBound, offsetByCharacters: 2)
      let accentEnd = result.index(accentStart, offsetByCharacters: 2)
      result[accentStart..<accentEnd].foregroundColor = Color(nsColor: nameAccent)
      start = range.upperBound
    }
    return result
  }

  // The app name in the brand style, for AppKit drawing.
  static func nsName(size: CGFloat, color: NSColor) -> NSAttributedString {
    let font = NSFont(name: nameFontName, size: size) ?? .systemFont(ofSize: size, weight: .heavy)
    let result = NSMutableAttributedString(string: name, attributes: [.font: font, .foregroundColor: color])
    result.addAttribute(.foregroundColor, value: nameAccent, range: NSRange(location: 2, length: 2))
    return result
  }
}
