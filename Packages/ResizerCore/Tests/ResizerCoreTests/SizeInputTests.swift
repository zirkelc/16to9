import Testing

@testable import ResizerCore

@Suite("SizeInput")
struct SizeInputTests {
  @Test("reads sizes in different forms", arguments: ["1280x720", "1280 x 720", "1280×720", "1280 720", "1280*720", " 1280X720 "])
  func readsSizes(text: String) {
    // Act
    let target = SizeInput.parse(text)

    // Assert
    #expect(target == .size(width: 1280, height: 720))
  }

  @Test("reads ratios with whole and decimal numbers")
  func readsRatios() {
    // Act
    let whole = SizeInput.parse("16:9")
    let decimal = SizeInput.parse("1.91 : 1")
    let slash = SizeInput.parse("4/3")

    // Assert
    #expect(whole == .ratio(AspectRatio(16, 9)))
    #expect(decimal == .ratio(AspectRatio(1.91, 1)))
    #expect(slash == .ratio(AspectRatio(4, 3)))
  }

  @Test("refuses text that is not a size or ratio", arguments: ["", "abc", "1280", "10x10", "99999x720", "0:1", "100:1", "16:9:2"])
  func refusesInvalidInput(text: String) {
    // Act
    let target = SizeInput.parse(text)

    // Assert
    #expect(target == nil)
  }
}

@Suite("SizeInput with two fields")
struct SizeInputFieldsTests {
  @Test("reads a size from a width field and a height field")
  func readsSize() {
    // Act
    let target = SizeInput.size(width: " 1400 ", height: "600")

    // Assert
    #expect(target == .size(width: 1400, height: 600))
  }

  @Test("refuses a size that is empty, not a number or out of range", arguments: [("", "600"), ("abc", "600"), ("1400", "10"), ("99999", "600"), ("14.5", "600")])
  func refusesSize(width: String, height: String) {
    // Act
    let target = SizeInput.size(width: width, height: height)

    // Assert
    #expect(target == nil)
  }

  @Test("reads a ratio with whole numbers, a decimal point or a decimal comma")
  func readsRatio() {
    // Act
    let whole = SizeInput.ratio(width: "21", height: "9")
    let point = SizeInput.ratio(width: "1.91", height: "1")
    let comma = SizeInput.ratio(width: "1,91", height: " 1 ")

    // Assert
    #expect(whole == .ratio(AspectRatio(21, 9)))
    #expect(point == .ratio(AspectRatio(1.91, 1)))
    #expect(comma == .ratio(AspectRatio(1.91, 1)))
  }

  @Test("refuses a ratio that is empty, zero or too extreme", arguments: [("", "9"), ("16", "0"), ("0", "9"), ("100", "1"), ("x", "9")])
  func refusesRatio(width: String, height: String) {
    // Act
    let target = SizeInput.ratio(width: width, height: height)

    // Assert
    #expect(target == nil)
  }
}

@Suite("AspectRatio")
struct AspectRatioTests {
  @Test("describes sizes as short ratios", arguments: [
    (1600, 900, "16:9"),
    (1584, 396, "4:1"),
    (1200, 627, "1.91:1"),
    (1270, 760, "1.67:1"),
    (1080, 1350, "4:5"),
    (1000, 1910, "1:1.91"),
  ])
  func describesSizes(width: Int, height: Int, expected: String) {
    // Act
    let label = AspectRatio.describe(width: width, height: height)

    // Assert
    #expect(label == expected)
  }

  @Test("formats decimal ratios without trailing zeros")
  func formatsLabel() {
    // Arrange
    let ratio = AspectRatio(1.9, 1)

    // Act
    let label = ratio.label

    // Assert
    #expect(label == "1.9:1")
  }

  @Test("formats whole numbers that are too large for an integer")
  func formatsLargeLabel() {
    // Arrange
    let ratio = AspectRatio(1e20, 1e20)

    // Act
    let label = ratio.label

    // Assert
    #expect(label == "100000000000000000000:100000000000000000000")
  }
}

@Suite("PresetTarget")
struct PresetTargetTests {
  @Test("removes the spaces of a size for the small tiles and keeps the spaces between words", arguments: [
    (text: "1920 × 1080", compact: "1920×1080"),
    (text: "→ 1920 × 1080", compact: "→1920×1080"),
    (text: "too large", compact: "too large"),
    (text: "zu groß", compact: "zu groß"),
  ])
  func compactLabel(text: String, compact: String) {
    // Act
    let result = PresetTarget.compactLabel(text)

    // Assert
    #expect(result == compact)
  }
}
