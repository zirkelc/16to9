import CoreGraphics
import Testing

@testable import ResizerCore

@Suite("FitCalculator")
struct FitCalculatorTests {
  let largeVisible = CGRect(x: 0, y: 25, width: 2560, height: 1390)

  @Test("keeps the width when that is the smaller change")
  func keepsWidthForSmallerChange() {
    // Arrange
    let context = FitContext(window: CGRect(x: 0, y: 25, width: 1512, height: 945), visible: largeVisible, unitsPerPoint: 1)

    // Act
    let frame = FitCalculator.frame(for: .ratio(AspectRatio(16, 9)), in: context)

    // Assert
    #expect(frame == CGRect(x: 0, y: 25, width: 1512, height: 851))
  }

  @Test("keeps the height when that is the smaller change")
  func keepsHeightForSmallerChange() {
    // Arrange
    let context = FitContext(window: CGRect(x: 100, y: 100, width: 800, height: 900), visible: largeVisible, unitsPerPoint: 1)

    // Act
    let frame = FitCalculator.frame(for: .ratio(AspectRatio(4, 5)), in: context)

    // Assert
    #expect(frame == CGRect(x: 100, y: 100, width: 720, height: 900))
  }

  @Test("rounds to whole pixels on a Retina screen")
  func roundsToPixels() {
    // Arrange
    let context = FitContext(window: CGRect(x: 0, y: 25, width: 1512, height: 945), visible: largeVisible, unitsPerPoint: 2)

    // Act
    let frame = FitCalculator.frame(for: .ratio(AspectRatio(16, 9)), in: context)

    // Assert
    #expect(frame?.size == CGSize(width: 1512, height: 850.5))
  }

  @Test("picks the smaller window on a tie")
  func tiePicksSmallerWindow() {
    // Arrange
    let context = FitContext(window: CGRect(x: 0, y: 25, width: 1512, height: 945), visible: largeVisible, unitsPerPoint: 1)

    // Act
    let sizes = FitCalculator.candidates(for: .ratio(AspectRatio(1, 1)), in: context)

    // Assert
    #expect(sizes == [CGSize(width: 945, height: 945)])
  }

  @Test("keep width mode puts the width candidate first")
  func keepWidthMode() {
    // Arrange
    let context = FitContext(window: CGRect(x: 0, y: 25, width: 800, height: 900), visible: largeVisible, unitsPerPoint: 1, mode: .keepWidth)

    // Act
    let sizes = FitCalculator.candidates(for: .ratio(AspectRatio(1, 1)), in: context)

    // Assert
    #expect(sizes == [CGSize(width: 800, height: 800), CGSize(width: 900, height: 900)])
  }

  @Test("keep height mode puts the height candidate first")
  func keepHeightMode() {
    // Arrange
    let context = FitContext(window: CGRect(x: 0, y: 25, width: 1200, height: 800), visible: largeVisible, unitsPerPoint: 1, mode: .keepHeight)

    // Act
    let sizes = FitCalculator.candidates(for: .ratio(AspectRatio(16, 9)), in: context)

    // Assert
    #expect(sizes == [CGSize(width: 1422, height: 800), CGSize(width: 1200, height: 675)])
  }

  @Test("uses the other candidate when the best one does not fit")
  func fallsBackWhenTooLarge() {
    // Arrange
    let visible = CGRect(x: 0, y: 25, width: 1512, height: 920)
    let context = FitContext(window: CGRect(x: 0, y: 25, width: 1500, height: 900), visible: visible, unitsPerPoint: 1)

    // Act
    let sizes = FitCalculator.candidates(for: .ratio(AspectRatio(16, 10)), in: context)

    // Assert
    #expect(sizes == [CGSize(width: 1440, height: 900)])
  }

  @Test("uses the largest size that fits when no candidate fits")
  func largestWhenNothingFits() {
    // Arrange
    let visible = CGRect(x: 0, y: 25, width: 1512, height: 920)
    let context = FitContext(window: CGRect(x: 0, y: 0, width: 1600, height: 1000), visible: visible, unitsPerPoint: 1)

    // Act
    let sizes = FitCalculator.candidates(for: .ratio(AspectRatio(1, 1)), in: context)

    // Assert
    #expect(sizes == [CGSize(width: 920, height: 920)])
  }

  @Test("converts an exact pixel size to points")
  func exactSizeInPoints() {
    // Arrange
    let context = FitContext(window: CGRect(x: 40, y: 60, width: 500, height: 400), visible: largeVisible, unitsPerPoint: 2)

    // Act
    let frame = FitCalculator.frame(for: .size(width: 1920, height: 1080), in: context)

    // Assert
    #expect(frame == CGRect(x: 40, y: 60, width: 960, height: 540))
  }

  @Test("gives no frame for an exact size that is too large")
  func exactSizeTooLarge() {
    // Arrange
    let visible = CGRect(x: 0, y: 25, width: 1512, height: 920)
    let context = FitContext(window: CGRect(x: 0, y: 25, width: 500, height: 400), visible: visible, unitsPerPoint: 1)

    // Act
    let frame = FitCalculator.frame(for: .size(width: 1920, height: 1080), in: context)

    // Assert
    #expect(frame == nil)
  }

  @Test("moves the frame back into the visible area")
  func clampsIntoVisibleArea() {
    // Arrange
    let visible = CGRect(x: 0, y: 25, width: 1512, height: 920)
    let context = FitContext(window: CGRect(x: 1000, y: 600, width: 400, height: 300), visible: visible, unitsPerPoint: 1)

    // Act
    let frame = FitCalculator.frame(for: .size(width: 800, height: 600), in: context)

    // Assert
    #expect(frame == CGRect(x: 712, y: 345, width: 800, height: 600))
  }

  @Test("keeps the center with the center anchor")
  func centerAnchor() {
    // Arrange
    let context = FitContext(window: CGRect(x: 200, y: 200, width: 400, height: 400), visible: largeVisible, unitsPerPoint: 1, anchor: .center)

    // Act
    let frame = FitCalculator.frame(for: .size(width: 600, height: 200), in: context)

    // Assert
    #expect(frame == CGRect(x: 100, y: 300, width: 600, height: 200))
  }
}
