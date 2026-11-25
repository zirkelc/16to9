import SwiftUI

// A rounded square with a color and a white symbol, like the icons in System Settings.
struct IconTile: View {
  enum Tint {
    case gray, blue, cyan, purple, green

    var colors: [Color] {
      switch self {
      case .gray: [Color(red: 0.56, green: 0.56, blue: 0.58), Color(red: 0.39, green: 0.39, blue: 0.40)]
      case .blue: [Color(red: 0.23, green: 0.61, blue: 1.0), Color(red: 0.04, green: 0.39, blue: 0.85)]
      case .cyan: [Color(red: 0.25, green: 0.88, blue: 0.82), Color(red: 0.06, green: 0.66, blue: 0.61)]
      case .purple: [Color(red: 0.69, green: 0.45, blue: 1.0), Color(red: 0.49, green: 0.25, blue: 0.88)]
      case .green: [Color(red: 0.30, green: 0.85, blue: 0.39), Color(red: 0.16, green: 0.65, blue: 0.27)]
      }
    }
  }

  let symbol: String
  let tint: Tint
  var size: CGFloat = 22

  var body: some View {
    RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
      .fill(LinearGradient(colors: tint.colors, startPoint: .top, endPoint: .bottom))
      .hairlineBorder(RoundedRectangle(cornerRadius: size * 0.27, style: .continuous), .white.opacity(0.18))
      .overlay(
        Image(systemName: symbol)
          .font(.system(size: size * 0.55, weight: .semibold))
          .foregroundStyle(.white)
      )
      .frame(width: size, height: size)
      .accessibilityHidden(true)
  }
}
