import ResizerCore
import SwiftUI

/**
 The tag above the frame. Drag it to move the frame.

 The tag keeps the arrow cursor. The guide panels never become the key window, and macOS ignores cursor changes
 from them, so a hand cursor would not show. The arrows icon shows that the tag moves.
 */
struct GuideTagView: View {
  let guide: GuideController

  var body: some View {
    let size = guide.sizeInUnits
    HStack(spacing: 5) {
      Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
        .font(.system(size: 9, weight: .bold))
      Text(verbatim: "\(guide.title) · \(size.width) × \(size.height) \(guide.settings.units.symbol)")
        .font(.system(size: 11, weight: .semibold, design: .monospaced))
    }
    .foregroundStyle(Brand.ink)
    .padding(.horizontal, 7)
    .padding(.vertical, 3)
    .background(guide.settings.guideColor.color, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
    .padding(2)
    .fixedSize()
    .contentShape(Rectangle())
    .gesture(
      DragGesture(minimumDistance: 0)
        .onChanged { _ in guide.dragChanged() }
        .onEnded { _ in guide.dragEnded() }
    )
    .help("Drag to move the guide")
    .accessibilityElement(children: .combine)
    .accessibilityHint("Drag to move the guide")
  }
}

// The bar under the frame with the live readout and the actions.
struct GuideHUDView: View {
  let guide: GuideController

  var body: some View {
    let size = guide.sizeInUnits
    let unit = guide.settings.units.symbol
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 1) {
        Text(verbatim: "\(size.width) × \(size.height) \(unit)")
          .font(.system(size: 12, weight: .semibold, design: .monospaced))
        Text(guide.target?.ratioLabel ?? "")
          .font(.system(size: 10.5))
          .foregroundStyle(.secondary)
      }
      .fixedSize()

      Divider().frame(height: 22)

      status
        .frame(maxWidth: .infinity, alignment: .leading)

      HStack(spacing: 4) {
        nudgeButton("arrow.left", dx: -1, dy: 0)
        nudgeButton("arrow.up", dx: 0, dy: -1)
        nudgeButton("arrow.down", dx: 0, dy: 1)
        nudgeButton("arrow.right", dx: 1, dy: 0)
      }

      Button("Snap") { guide.snap() }
        .buttonStyle(AccentButtonStyle())
        .disabled(!guide.permission.isGranted)
        .hudHover(String(localized: "Move and resize the front window to the frame"), highlight: false)

      Button {
        guide.center()
      } label: {
        Image(systemName: "align.horizontal.center")
          .frame(width: 24, height: 22)
      }
      .buttonStyle(HUDIconButtonStyle())
      .hudHover(String(localized: "Center the frame on the screen"), tipEdge: .trailing)
      .accessibilityLabel("Center the frame on the screen")

      Button {
        guide.hide()
      } label: {
        Image(systemName: "xmark")
          .frame(width: 24, height: 22)
      }
      .buttonStyle(HUDIconButtonStyle())
      .hudHover(
        guide.settings.escapeHidesGuide ? String(localized: "Hide the guide (Esc)") : String(localized: "Hide the guide"),
        tipEdge: .trailing)
      .accessibilityLabel("Hide the guide")
    }
    .padding(.horizontal, 14)
    .frame(height: 44)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(.white.opacity(0.14), lineWidth: 0.5))
    .shadow(color: .black.opacity(0.3), radius: 8, y: 3)
    .padding(.horizontal, 10)
    .frame(height: GuideController.hudSize.height - GuideController.hudTipSpace)
    .frame(width: GuideController.hudSize.width, height: GuideController.hudSize.height, alignment: .bottom)
  }

  @ViewBuilder
  private var status: some View {
    if !guide.permission.isGranted {
      Button("Allow access for a live readout") { guide.onRequestPermission() }
        .buttonStyle(.link)
        .font(.system(size: 11.5))
    } else if let match = guide.match {
      HStack(spacing: 6) {
        Circle()
          .fill(match.isExact ? GuideOverlayView.matchColor : guide.settings.guideColor.offColor)
          .frame(width: 7, height: 7)
        Text(Self.describe(match, appName: guide.windowAppName, unit: guide.settings.units.symbol))
          .font(.system(size: 11.5))
          .lineLimit(2)
          .fixedSize(horizontal: false, vertical: true)
      }
    } else {
      Text("No window found")
        .font(.system(size: 11.5))
        .foregroundStyle(.secondary)
    }
  }

  private func nudgeButton(_ symbol: String, dx: Int, dy: Int) -> some View {
    Button {
      guide.nudge(dx: dx, dy: dy)
    } label: {
      Image(systemName: symbol)
        .font(.system(size: 9, weight: .semibold))
        .frame(width: 20, height: 20)
    }
    .buttonStyle(HUDIconButtonStyle())
    .hudHover(nudgeTip(dx: dx, dy: dy))
    .accessibilityLabel(Self.nudgeLabel(dx: dx, dy: dy))
  }

  // The tooltip names the arrow keys only when they move the guide.
  private func nudgeTip(dx: Int, dy: Int) -> String {
    let unit = guide.settings.units.symbol
    guard guide.settings.arrowKeysMoveGuide else {
      if dx < 0 { return String(localized: "Move the frame left by 1 \(unit)") }
      if dx > 0 { return String(localized: "Move the frame right by 1 \(unit)") }
      return dy < 0 ? String(localized: "Move the frame up by 1 \(unit)") : String(localized: "Move the frame down by 1 \(unit)")
    }
    if dx < 0 { return String(localized: "Move the frame left: ← 1 \(unit), ⇧← 10 \(unit)") }
    if dx > 0 { return String(localized: "Move the frame right: → 1 \(unit), ⇧→ 10 \(unit)") }
    return dy < 0
      ? String(localized: "Move the frame up: ↑ 1 \(unit), ⇧↑ 10 \(unit)")
      : String(localized: "Move the frame down: ↓ 1 \(unit), ⇧↓ 10 \(unit)")
  }

  private static func nudgeLabel(dx: Int, dy: Int) -> LocalizedStringKey {
    if dx < 0 { return "Move the frame left" }
    if dx > 0 { return "Move the frame right" }
    return dy < 0 ? "Move the frame up" : "Move the frame down"
  }

  // The numbers are passed as text, so that they show without digit grouping, as all sizes in the app.
  static func describe(_ match: GuideMatch, appName: String?, unit: String) -> String {
    let name = appName ?? String(localized: "Window")
    if match.isExact { return String(localized: "\(name) matches") }
    var parts: [String] = []
    if match.width > 0 { parts.append(String(localized: "\(String(match.width)) \(unit) too wide")) }
    if match.width < 0 { parts.append(String(localized: "\(String(-match.width)) \(unit) too narrow")) }
    if match.height > 0 { parts.append(String(localized: "\(String(match.height)) \(unit) too tall")) }
    if match.height < 0 { parts.append(String(localized: "\(String(-match.height)) \(unit) too short")) }
    if parts.isEmpty { parts.append(String(localized: "size matches, move it into the frame")) }
    return "\(name): " + parts.joined(separator: ", ")
  }
}

// A filled accent button. The system style turns gray in a panel that is not key.
struct AccentButtonStyle: ButtonStyle {
  @Environment(\.isEnabled) private var isEnabled

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 12, weight: .semibold))
      .foregroundStyle(.white)
      .padding(.horizontal, 12)
      .padding(.vertical, 4)
      .background(Color.accentColor.opacity(configuration.isPressed ? 0.75 : 1), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
      .opacity(isEnabled ? 1 : 0.4)
  }
}

// An icon button in the bar. It is darker while it is pressed. The hover modifier gives it the hover background.
struct HUDIconButtonStyle: ButtonStyle {
  @Environment(\.isEnabled) private var isEnabled

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .foregroundStyle(.primary)
      .contentShape(Rectangle())
      .background(.primary.opacity(configuration.isPressed ? 0.2 : 0), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
      .opacity(isEnabled ? 1 : 0.4)
  }
}

extension View {
  /**
   Adds a hover state and a tooltip above the control. The highlight is a background, or else a brighter control.
   A control at the right end of the bar aligns the tooltip at its trailing edge, so that it stays in the panel.
   */
  func hudHover(_ tip: String, highlight: Bool = true, tipEdge: HorizontalAlignment = .center) -> some View {
    modifier(HUDHover(tip: tip, highlight: highlight, tipEdge: tipEdge))
  }
}

// Hover and tooltip for the controls in the guide panels. System tooltips do not show while the app is inactive.
private struct HUDHover: ViewModifier {
  let tip: String
  let highlight: Bool
  let tipEdge: HorizontalAlignment

  @State private var hovered = false
  @State private var showsTip = false
  @State private var tipTask: Task<Void, Never>?

  func body(content: Content) -> some View {
    content
      .background {
        if highlight {
          RoundedRectangle(cornerRadius: 5, style: .continuous).fill(.primary.opacity(hovered ? 0.12 : 0))
        }
      }
      .brightness(!highlight && hovered ? 0.08 : 0)
      .onHover(perform: hover)
      .overlay(alignment: Alignment(horizontal: tipEdge, vertical: .top)) {
        if showsTip {
          Text(verbatim: tip)
            .font(.system(size: 11))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color(white: 0.14).opacity(0.96), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            .fixedSize()
            .offset(y: -32)
            .allowsHitTesting(false)
            .transition(.opacity)
        }
      }
      .onDisappear { hover(false) }
  }

  private func hover(_ inside: Bool) {
    hovered = inside
    tipTask?.cancel()
    guard inside else {
      showsTip = false
      return
    }
    tipTask = Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(500))
      guard !Task.isCancelled else { return }
      withAnimation(.easeOut(duration: 0.12)) { showsTip = true }
    }
  }
}
