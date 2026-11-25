import SwiftUI

/**
 A border of one physical pixel. A fixed 0.5 pt border is half a pixel on a screen with a scale of 1, and an edge
 that falls between two pixel rows then fades out.
 */
struct HairlineBorder<S: InsettableShape>: ViewModifier {
  let shape: S
  let color: Color
  @Environment(\.displayScale) private var displayScale

  func body(content: Content) -> some View {
    content.overlay(shape.strokeBorder(color, lineWidth: 1 / displayScale))
  }
}

extension View {
  func hairlineBorder<S: InsettableShape>(_ shape: S, _ color: Color) -> some View {
    modifier(HairlineBorder(shape: shape, color: color))
  }
}
