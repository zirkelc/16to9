import KeyboardShortcuts
import SwiftUI

struct GuidePane: View {
  let settings: AppSettings

  var body: some View {
    @Bindable var settings = settings
    Form {
      Section {
        GuidePreview(settings: settings)
          .frame(height: 150)
          .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
      }

      Section {
        LabeledContent("Color") {
          HStack(spacing: 10) {
            ForEach(GuideColor.allCases) { color in
              Button {
                settings.guideColor = color
              } label: {
                Circle()
                  .fill(color.color)
                  .frame(width: 18, height: 18)
                  .hairlineBorder(Circle(), .black.opacity(0.15))
                  .padding(3)
                  .overlay(Circle().strokeBorder(settings.guideColor == color ? Color.primary.opacity(0.7) : .clear, lineWidth: 1.5))
              }
              .buttonStyle(.plain)
              .help(color.title)
              .accessibilityLabel(color.title)
              .accessibilityAddTraits(settings.guideColor == color ? .isSelected : [])
            }
          }
        }
        Toggle("Dim the screen outside the frame", isOn: $settings.dimOutsideGuide)
        Toggle("Show center lines", isOn: $settings.showCenterLines)
        Toggle(isOn: $settings.hideGuideInScreenshots) {
          Text("Hide the guide in screenshots")
          Text("Screenshots and screen recordings do not show the guide.")
        }
      } footer: {
        Text("The guide shows on the screen of the front window. Drag the tag above the frame to move it. Edges turn green when the window matches.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
    .scrollContentBackground(.hidden)
  }
}

// A small drawing of the guide that follows the settings: color, dim and center lines.
struct GuidePreview: View {
  let settings: AppSettings

  var body: some View {
    let color = settings.guideColor.color
    GeometryReader { geometry in
      let size = geometry.size
      let ruler: CGFloat = 12
      let frame = CGRect(x: size.width * 0.24, y: size.height * 0.28, width: size.width * 0.52, height: size.height * 0.56)
      ZStack(alignment: .topLeading) {
        LinearGradient(
          colors: [Color(red: 0.17, green: 0.24, blue: 0.40), Color(red: 0.24, green: 0.17, blue: 0.32)],
          startPoint: .topLeading, endPoint: .bottomTrailing)

        // The window that the user fits into the frame.
        VStack(spacing: 0) {
          Rectangle().fill(Color(white: 0.89)).frame(height: 9)
          Rectangle().fill(Color(white: 0.96))
        }
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .frame(width: frame.width, height: frame.height)
        .offset(x: frame.minX, y: frame.minY)
        .shadow(color: .black.opacity(0.35), radius: 6, y: 3)

        Canvas { context, canvasSize in
          if settings.dimOutsideGuide {
            var dim = Path(CGRect(origin: .zero, size: canvasSize))
            dim.addRect(frame)
            context.fill(dim, with: .color(.black.opacity(0.32)), style: FillStyle(eoFill: true))
          }
          var lines = Path()
          for x in [frame.minX, frame.maxX] {
            lines.move(to: CGPoint(x: x, y: 0))
            lines.addLine(to: CGPoint(x: x, y: canvasSize.height))
          }
          for y in [frame.minY, frame.maxY] {
            lines.move(to: CGPoint(x: 0, y: y))
            lines.addLine(to: CGPoint(x: canvasSize.width, y: y))
          }
          context.stroke(lines, with: .color(color.opacity(0.35)), lineWidth: 0.5)
          if settings.showCenterLines {
            var center = Path()
            center.move(to: CGPoint(x: frame.midX, y: frame.minY))
            center.addLine(to: CGPoint(x: frame.midX, y: frame.maxY))
            center.move(to: CGPoint(x: frame.minX, y: frame.midY))
            center.addLine(to: CGPoint(x: frame.maxX, y: frame.midY))
            context.stroke(center, with: .color(color.opacity(0.8)), style: StrokeStyle(lineWidth: 0.75, dash: [3, 3]))
          }
          context.stroke(Path(frame), with: .color(color), lineWidth: 1.5)

          // Rulers on the top and on the left.
          let rulerColor = Color(white: 0.1).opacity(0.92)
          context.fill(Path(CGRect(x: 0, y: 0, width: canvasSize.width, height: ruler)), with: .color(rulerColor))
          context.fill(Path(CGRect(x: 0, y: 0, width: ruler, height: canvasSize.height)), with: .color(rulerColor))
          var ticks = Path()
          for x in stride(from: ruler, through: canvasSize.width, by: 8) {
            let long = Int((x - ruler) / 8) % 5 == 0
            ticks.move(to: CGPoint(x: x, y: ruler))
            ticks.addLine(to: CGPoint(x: x, y: ruler - (long ? 7 : 3)))
          }
          for y in stride(from: ruler, through: canvasSize.height, by: 8) {
            let long = Int((y - ruler) / 8) % 5 == 0
            ticks.move(to: CGPoint(x: ruler, y: y))
            ticks.addLine(to: CGPoint(x: ruler - (long ? 7 : 3), y: y))
          }
          context.stroke(ticks, with: .color(.white.opacity(0.4)), lineWidth: 0.5)
          var marks = Path()
          marks.move(to: CGPoint(x: frame.minX, y: 0))
          marks.addLine(to: CGPoint(x: frame.minX, y: ruler))
          marks.move(to: CGPoint(x: frame.maxX, y: 0))
          marks.addLine(to: CGPoint(x: frame.maxX, y: ruler))
          marks.move(to: CGPoint(x: 0, y: frame.minY))
          marks.addLine(to: CGPoint(x: ruler, y: frame.minY))
          marks.move(to: CGPoint(x: 0, y: frame.maxY))
          marks.addLine(to: CGPoint(x: ruler, y: frame.maxY))
          context.stroke(marks, with: .color(color), lineWidth: 1.5)
        }

        Text(verbatim: "Full HD · 1920 × 1080 \(settings.units.symbol)")
          .font(.system(size: 9, weight: .semibold, design: .monospaced))
          .foregroundStyle(Brand.ink)
          .padding(.horizontal, 5)
          .padding(.vertical, 2)
          .background(color, in: RoundedRectangle(cornerRadius: 3, style: .continuous))
          .offset(x: frame.minX, y: frame.minY - 19)
      }
    }
    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    .animation(.easeOut(duration: 0.15), value: settings.guideColor)
    .accessibilityElement()
    .accessibilityLabel("Preview of the guide")
  }
}

// The global shortcuts and the keys of the guide, in two short groups.
struct ShortcutsPane: View {
  let settings: AppSettings

  var body: some View {
    Form {
      Section {
        ShortcutRow("Show or hide the guide", name: .toggleGuide)
        ShortcutRow("Undo the last resize", name: .undoResize)
      } header: {
        Text("Shortcuts")
      } footer: {
        Text("Give a preset its own shortcut in Presets.").font(.caption).foregroundStyle(.secondary)
      }
      GuideKeysSection(settings: settings)
    }
    .formStyle(.grouped)
    .scrollContentBackground(.hidden)
  }
}

// The keys that control the guide while it shows, each with a switch.
private struct GuideKeysSection: View {
  let settings: AppSettings

  var body: some View {
    @Bindable var settings = settings
    let unit = settings.units.symbol
    Section {
      GuideKeyRow(title: "Escape hides the guide", keys: ["esc"], isOn: $settings.escapeHidesGuide)
      GuideKeyRow(
        title: "Arrow keys move the frame", hint: "Moves the frame by 1 \(unit). Hold ⇧ to move it by 10 \(unit).",
        keys: ["←", "→", "↑", "↓"], isOn: $settings.arrowKeysMoveGuide)
    } header: {
      Text("While the guide shows")
    } footer: {
      Text("Other apps do not get these keys while the guide shows.")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }
}

// A row with a global shortcut that the user records.
struct ShortcutRow: View {
  let title: LocalizedStringKey
  let name: KeyboardShortcuts.Name

  init(_ title: LocalizedStringKey, name: KeyboardShortcuts.Name) {
    self.title = title
    self.name = name
  }

  var body: some View {
    // A row with an own stack keeps the title centered next to the taller field.
    HStack {
      Text(title)
      Spacer()
      ShortcutField(name: name)
    }
  }
}

// A fixed key of the guide with a switch and an optional hint. The keys are dim while the switch is off.
private struct GuideKeyRow: View {
  let title: LocalizedStringKey
  var hint: LocalizedStringKey?
  let keys: [String]
  @Binding var isOn: Bool

  var body: some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
        if let hint {
          Text(hint).font(.caption).foregroundStyle(.secondary)
        }
      }
      Spacer()
      KeycapRow(labels: keys, size: 20).opacity(isOn ? 1 : 0.4)
      Toggle(title, isOn: $isOn).labelsHidden().toggleStyle(.switch).controlSize(.mini)
    }
  }
}
