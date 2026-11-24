import CoreGraphics
import Foundation

public struct RulerTick: Equatable, Sendable {
  public enum Kind: Sendable {
    case minor
    case medium
    case major
  }

  // Distance from the start of the ruler, in points.
  public var offset: CGFloat
  // Value in units, counted from the zero point of the ruler.
  public var value: Int
  public var kind: Kind
}

/**
 How a window matches the guide frame. Each value is a difference in units.
 Positive values mean the window edge is right of or below the guide edge.
 */
public struct GuideMatch: Equatable, Sendable {
  public var left: Int
  public var top: Int
  public var right: Int
  public var bottom: Int
  public var width: Int
  public var height: Int

  public var isExact: Bool { left == 0 && top == 0 && right == 0 && bottom == 0 }
  public var sizeMatches: Bool { width == 0 && height == 0 }
}

// The positions of the frame edges on the rulers, in units from the start of the visible area.
public struct RulerMarks: Equatable, Sendable {
  public let left: Int
  public let top: Int
  public let right: Int
  public let bottom: Int

  public init(left: Int, top: Int, right: Int, bottom: Int) {
    self.left = left
    self.top = top
    self.right = right
    self.bottom = bottom
  }
}

public enum GuideGeometry {
  static let steps = [1, 2, 5, 10, 20, 25, 50, 100, 200, 250, 500, 1_000, 2_000, 5_000, 10_000]

  // Minimum space between two ticks and between two labels, in points.
  static let minorSpacing: CGFloat = 5
  static let majorSpacing: CGFloat = 70

  public static func tickSteps(unitsPerPoint: Double) -> (minor: Int, major: Int) {
    let minor = steps.first { CGFloat($0) / unitsPerPoint >= minorSpacing } ?? steps.last!
    let major = steps.first { $0 % minor == 0 && $0 > minor && CGFloat($0) / unitsPerPoint >= majorSpacing } ?? minor * 10
    return (minor, major)
  }

  /**
   The ticks of a ruler with the given length in points. The value zero is at `origin` points from
   the start of the ruler. Values before the origin are negative.
   */
  public static func ticks(length: CGFloat, origin: CGFloat, unitsPerPoint: Double) -> [RulerTick] {
    let (minor, major) = tickSteps(unitsPerPoint: unitsPerPoint)
    let first = Int((-origin * unitsPerPoint / Double(minor)).rounded(.up)) * minor
    let last = Int(((length - origin) * unitsPerPoint / Double(minor)).rounded(.down)) * minor
    guard first <= last else { return [] }

    let half = major % 2 == 0 && (major / 2) % minor == 0 ? major / 2 : nil
    return stride(from: first, through: last, by: minor).map { value in
      let kind: RulerTick.Kind
      if value % major == 0 {
        kind = .major
      } else if let half, value % half == 0 {
        kind = .medium
      } else {
        kind = .minor
      }
      return RulerTick(offset: origin + CGFloat(value) / unitsPerPoint, value: value, kind: kind)
    }
  }

  // The rulers start with zero at the top left corner of the visible area, so they stay in place when the frame moves.
  public static func rulerMarks(frame: CGRect, visible: CGRect, unitsPerPoint: Double) -> RulerMarks {
    func units(_ points: CGFloat) -> Int { Int((points * unitsPerPoint).rounded()) }
    return RulerMarks(
      left: units(frame.minX - visible.minX),
      top: units(frame.minY - visible.minY),
      right: units(frame.maxX - visible.minX),
      bottom: units(frame.maxY - visible.minY)
    )
  }

  public static func compare(window: CGRect, guide: CGRect, unitsPerPoint: Double) -> GuideMatch {
    func units(_ points: CGFloat) -> Int { Int((points * unitsPerPoint).rounded()) }
    return GuideMatch(
      left: units(window.minX - guide.minX),
      top: units(window.minY - guide.minY),
      right: units(window.maxX - guide.maxX),
      bottom: units(window.maxY - guide.maxY),
      width: units(window.width - guide.width),
      height: units(window.height - guide.height)
    )
  }

  /**
   The guide frame for a target on a screen. A size uses its exact value. A ratio uses the given
   window size and fit mode when there is a window, else 60 percent of the visible area. The frame is centered.
   */
  public static func frame(
    for target: PresetTarget, window: CGRect?, visible: CGRect, unitsPerPoint: Double, mode: FitMode = .smallestChange
  ) -> CGRect {
    let size: CGSize
    switch target {
    case .size(let width, let height):
      size = FitCalculator.sizeInPoints(width: width, height: height, unitsPerPoint: unitsPerPoint)
    case .ratio(let ratio):
      if let window {
        let context = FitContext(window: window, visible: visible, unitsPerPoint: unitsPerPoint, mode: mode)
        size = FitCalculator.candidates(for: target, in: context).first ?? window.size
      } else {
        let area = visible.insetBy(dx: visible.width * 0.2, dy: visible.height * 0.2)
        size = FitCalculator.largest(ratio: ratio.value, in: area, unitsPerPoint: unitsPerPoint)
      }
    }
    let x = FitCalculator.snap(visible.midX - size.width / 2, unitsPerPoint)
    let y = FitCalculator.snap(visible.midY - size.height / 2, unitsPerPoint)
    return CGRect(x: x, y: y, width: size.width, height: size.height)
  }
}

// The keys that control the guide while it shows.
public struct GuideKeys: OptionSet, Sendable {
  public let rawValue: Int
  public init(rawValue: Int) { self.rawValue = rawValue }

  public static let escape = GuideKeys(rawValue: 1 << 0)
  public static let arrows = GuideKeys(rawValue: 1 << 1)
}

/**
 A key press that controls the guide: Escape hides it, an arrow key moves it by one unit, or by ten units with
 Shift. A key that is not in `keys` gives no command.
 */
public enum GuideKeyCommand: Equatable, Sendable {
  case hide
  case move(dx: Int, dy: Int)

  public init?(keyCode: UInt16, shift: Bool, keys: GuideKeys = [.escape, .arrows]) {
    let step = shift ? 10 : 1
    switch keyCode {
    case 53 where keys.contains(.escape): self = .hide
    case 123 where keys.contains(.arrows): self = .move(dx: -step, dy: 0)
    case 124 where keys.contains(.arrows): self = .move(dx: step, dy: 0)
    case 125 where keys.contains(.arrows): self = .move(dx: 0, dy: step)
    case 126 where keys.contains(.arrows): self = .move(dx: 0, dy: -step)
    default: return nil
    }
  }
}
