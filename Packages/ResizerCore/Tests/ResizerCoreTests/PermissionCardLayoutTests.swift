import CoreGraphics
import Testing

@testable import ResizerCore

@Suite("PermissionCardLayout")
struct PermissionCardLayoutTests {
  let screen = CGRect(x: 0, y: 0, width: 1728, height: 1080)
  let card = CGSize(width: 500, height: 100)

  @Test("the card moves left when its row under the list would pass the right edge of the window")
  func belowNarrowWindow() {
    // Arrange
    let settings = CGRect(x: 400, y: 300, width: 715, height: 640)

    // Act
    let result = PermissionCardLayout.dock(settings: settings, visible: screen, card: card, rowLeading: 40)

    // Assert
    #expect(result.placement == .below)
    #expect(result.frame == CGRect(x: 607, y: 190, width: 500, height: 100))
  }

  @Test("the card goes below the window, with its row under the list")
  func below() {
    // Arrange
    let settings = CGRect(x: 400, y: 300, width: 1000, height: 640)

    // Act
    let result = PermissionCardLayout.dock(settings: settings, visible: screen, card: card, rowLeading: 40)

    // Assert
    #expect(result.placement == .below)
    #expect(result.frame == CGRect(x: 612, y: 190, width: 500, height: 100))
  }

  @Test("the card goes into the empty lower part when the window touches the bottom of the screen")
  func inside() {
    // Arrange
    let settings = CGRect(x: 400, y: 20, width: 1000, height: 900)

    // Act
    let result = PermissionCardLayout.dock(settings: settings, visible: screen, card: card, rowLeading: 40)

    // Assert
    #expect(result.placement == .inside)
    #expect(result.frame == CGRect(x: 612, y: 40, width: 500, height: 100))
  }

  @Test("the card goes on the right when the lower part of the window is too small")
  func right() {
    // Arrange
    let settings = CGRect(x: 100, y: 20, width: 715, height: 300)

    // Act
    let result = PermissionCardLayout.dock(settings: settings, visible: screen, card: card, rowLeading: 40)

    // Assert
    #expect(result.placement == .right)
    #expect(result.frame == CGRect(x: 825, y: 20, width: 500, height: 100))
  }

  @Test("the card goes on the left when the right side has no space")
  func left() {
    // Arrange
    let settings = CGRect(x: 1000, y: 20, width: 715, height: 300)

    // Act
    let result = PermissionCardLayout.dock(settings: settings, visible: screen, card: card, rowLeading: 40)

    // Assert
    #expect(result.placement == .left)
    #expect(result.frame == CGRect(x: 490, y: 20, width: 500, height: 100))
  }

  @Test("the card stays on the screen when no position fits")
  func clamped() {
    // Arrange
    let small = CGRect(x: 0, y: 0, width: 600, height: 400)
    let tall = CGSize(width: 500, height: 150)

    // Act
    let result = PermissionCardLayout.dock(settings: small, visible: small, card: tall, rowLeading: 40)

    // Assert
    #expect(result.placement == .clamped)
    #expect(result.frame == CGRect(x: 92, y: 8, width: 500, height: 150))
  }

  @Test("the row has the width of the list, within limits", arguments: [(CGFloat(715), CGFloat(443)), (500, 300), (1400, 560)])
  func rowWidth(settingsWidth: CGFloat, expected: CGFloat) {
    // Act
    let width = PermissionCardLayout.rowWidth(settingsWidth: settingsWidth)

    // Assert
    #expect(width == expected)
  }
}
