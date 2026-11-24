import CoreGraphics
import Testing

@testable import ResizerCore

@Suite("ScreenGeometry")
struct ScreenGeometryTests {
  @Test("flips a rectangle between AppKit and Accessibility coordinates")
  func flipsRect() {
    // Arrange
    let appKit = CGRect(x: 100, y: 200, width: 300, height: 400)

    // Act
    let accessibility = ScreenGeometry.flip(appKit, primaryHeight: 1000)
    let back = ScreenGeometry.flip(accessibility, primaryHeight: 1000)

    // Assert
    #expect(accessibility == CGRect(x: 100, y: 400, width: 300, height: 400))
    #expect(back == appKit)
  }

  @Test("flips a screen above the primary screen to negative y")
  func flipsScreenAbove() {
    // Arrange
    let screenAbove = CGRect(x: 0, y: 982, width: 2560, height: 1440)

    // Act
    let accessibility = ScreenGeometry.flip(screenAbove, primaryHeight: 982)

    // Assert
    #expect(accessibility == CGRect(x: 0, y: -1440, width: 2560, height: 1440))
  }

  @Test("finds the screen with the largest part of a window")
  func findsBestScreen() {
    // Arrange
    let screens = [CGRect(x: 0, y: 0, width: 1512, height: 982), CGRect(x: 1512, y: 0, width: 2560, height: 1440)]
    let window = CGRect(x: 1400, y: 100, width: 600, height: 400)

    // Act
    let index = ScreenGeometry.bestScreen(for: window, in: screens)

    // Assert
    #expect(index == 1)
  }

  @Test("finds the nearest screen for a window outside all screens")
  func findsNearestScreen() {
    // Arrange
    let screens = [CGRect(x: 0, y: 0, width: 1512, height: 982), CGRect(x: 1512, y: 0, width: 2560, height: 1440)]
    let window = CGRect(x: -900, y: 100, width: 600, height: 400)

    // Act
    let index = ScreenGeometry.bestScreen(for: window, in: screens)

    // Assert
    #expect(index == 0)
  }
}

@Suite("GuideGeometry")
struct GuideGeometryTests {
  @Test("reports the difference of each edge in pixels")
  func comparesEdges() {
    // Arrange
    let guide = CGRect(x: 100, y: 100, width: 960, height: 540)
    let window = CGRect(x: 100, y: 100, width: 994, height: 540)

    // Act
    let match = GuideGeometry.compare(window: window, guide: guide, unitsPerPoint: 2)

    // Assert
    #expect(match == GuideMatch(left: 0, top: 0, right: 68, bottom: 0, width: 68, height: 0))
    #expect(match.isExact == false)
  }

  @Test("reports an exact match")
  func exactMatch() {
    // Arrange
    let guide = CGRect(x: 100, y: 100, width: 960, height: 540)

    // Act
    let match = GuideGeometry.compare(window: guide, guide: guide, unitsPerPoint: 2)

    // Assert
    #expect(match.isExact == true)
  }

  @Test("selects tick steps that do not crowd the ruler")
  func tickSteps() {
    // Act
    let points = GuideGeometry.tickSteps(unitsPerPoint: 1)
    let pixels = GuideGeometry.tickSteps(unitsPerPoint: 2)

    // Assert
    #expect(points.minor == 5)
    #expect(points.major == 100)
    #expect(pixels.minor == 10)
    #expect(pixels.major == 200)
  }

  @Test("puts zero at the origin and counts negative before it")
  func ticksAroundOrigin() {
    // Act
    let ticks = GuideGeometry.ticks(length: 300, origin: 100, unitsPerPoint: 1)

    // Assert
    #expect(ticks.first?.value == -100)
    #expect(ticks.first?.offset == 0)
    #expect(ticks.last?.value == 200)
    #expect(ticks.last?.offset == 300)
    #expect(ticks.first { $0.value == 0 }?.kind == .major)
    #expect(ticks.first { $0.value == 50 }?.kind == .medium)
    #expect(ticks.first { $0.value == 5 }?.kind == .minor)
    #expect(ticks.count == 61)
  }

  @Test("measures the frame edges from the start of the visible area")
  func rulerMarksFromVisibleArea() {
    // Arrange
    let visible = CGRect(x: 100, y: 25, width: 1500, height: 900)
    let frame = CGRect(x: 300, y: 125, width: 960, height: 540)

    // Act
    let marks = GuideGeometry.rulerMarks(frame: frame, visible: visible, unitsPerPoint: 2)

    // Assert
    #expect(marks == RulerMarks(left: 400, top: 200, right: 2_320, bottom: 1_280))
  }

  @Test("centers an exact size guide on the screen")
  func guideFrameForSize() {
    // Arrange
    let visible = CGRect(x: 0, y: 25, width: 1512, height: 920)

    // Act
    let frame = GuideGeometry.frame(for: .size(width: 1920, height: 1080), window: nil, visible: visible, unitsPerPoint: 2)

    // Assert
    #expect(frame == CGRect(x: 276, y: 215, width: 960, height: 540))
  }

  @Test("puts the guide at whole points, because windows move only by whole points")
  func guideFrameAtWholePoints() {
    // Arrange
    let visible = CGRect(x: 0, y: 1472, width: 1512, height: 951)

    // Act
    let frame = GuideGeometry.frame(for: .size(width: 1920, height: 1080), window: nil, visible: visible, unitsPerPoint: 2)

    // Assert
    #expect(frame == CGRect(x: 276, y: 1678, width: 960, height: 540))
  }

  @Test("moves the guide by the units, rounded up to whole points", arguments: [
    (units: 1, unitsPerPoint: 2.0, points: 1.0),
    (units: -1, unitsPerPoint: 2.0, points: -1.0),
    (units: 10, unitsPerPoint: 2.0, points: 5.0),
    (units: 1, unitsPerPoint: 1.0, points: 1.0),
    (units: -10, unitsPerPoint: 1.0, points: -10.0),
  ])
  func nudgePoints(units: Int, unitsPerPoint: Double, points: Double) {
    // Act
    let result = GuideGeometry.nudgePoints(units: units, unitsPerPoint: unitsPerPoint)

    // Assert
    #expect(result == CGFloat(points))
  }

  @Test("sizes a ratio guide from the window")
  func guideFrameForRatio() {
    // Arrange
    let visible = CGRect(x: 0, y: 0, width: 2000, height: 1000)
    let window = CGRect(x: 0, y: 0, width: 800, height: 600)

    // Act
    let frame = GuideGeometry.frame(for: .ratio(AspectRatio(16, 9)), window: window, visible: visible, unitsPerPoint: 1)

    // Assert
    #expect(frame == CGRect(x: 600, y: 275, width: 800, height: 450))
  }

  @Test("sizes a ratio guide with the fit mode")
  func guideFrameForRatioWithFitMode() {
    // Arrange
    let visible = CGRect(x: 0, y: 0, width: 2000, height: 1000)
    let window = CGRect(x: 0, y: 0, width: 800, height: 600)

    // Act
    let frame = GuideGeometry.frame(
      for: .ratio(AspectRatio(16, 9)), window: window, visible: visible, unitsPerPoint: 1, mode: .keepHeight)

    // Assert
    #expect(frame == CGRect(x: 467, y: 200, width: 1067, height: 600))
  }
}

@Suite("GuideKeyCommand")
struct GuideKeyCommandTests {
  @Test("hides the guide with the Escape key")
  func escapeHides() {
    // Act
    let command = GuideKeyCommand(keyCode: 53, shift: false)

    // Assert
    #expect(command == .hide)
  }

  @Test("moves the guide by one unit with an arrow key")
  func arrowMovesByOne() {
    // Act
    let left = GuideKeyCommand(keyCode: 123, shift: false)
    let right = GuideKeyCommand(keyCode: 124, shift: false)
    let down = GuideKeyCommand(keyCode: 125, shift: false)
    let up = GuideKeyCommand(keyCode: 126, shift: false)

    // Assert
    #expect(left == .move(dx: -1, dy: 0))
    #expect(right == .move(dx: 1, dy: 0))
    #expect(down == .move(dx: 0, dy: 1))
    #expect(up == .move(dx: 0, dy: -1))
  }

  @Test("moves the guide by ten units with Shift and an arrow key")
  func shiftArrowMovesByTen() {
    // Act
    let command = GuideKeyCommand(keyCode: 123, shift: true)

    // Assert
    #expect(command == .move(dx: -10, dy: 0))
  }

  @Test("ignores Escape when Escape is off")
  func escapeOff() {
    // Act
    let command = GuideKeyCommand(keyCode: 53, shift: false, keys: [.arrows])

    // Assert
    #expect(command == nil)
  }

  @Test("ignores the arrow keys when the arrow keys are off")
  func arrowsOff() {
    // Act
    let command = GuideKeyCommand(keyCode: 123, shift: false, keys: [.escape])

    // Assert
    #expect(command == nil)
  }

  @Test("ignores other keys")
  func otherKeys() {
    // Act
    let command = GuideKeyCommand(keyCode: 0, shift: false)

    // Assert
    #expect(command == nil)
  }
}
