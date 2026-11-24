import KeyboardShortcuts
import ResizerCore
import SwiftUI

// A small rectangle with the ratio of a preset.
struct RatioGlyph: View {
  let ratio: Double
  var box = CGSize(width: 18, height: 13)
  var lineWidth: CGFloat = 1.5

  var body: some View {
    let size = fittedSize
    RoundedRectangle(cornerRadius: 2, style: .continuous)
      .strokeBorder(lineWidth: lineWidth)
      .frame(width: size.width, height: size.height)
      .frame(width: box.width, height: box.height)
      .accessibilityHidden(true)
  }

  private var fittedSize: CGSize {
    var width = box.width
    var height = width / ratio
    if height > box.height {
      height = box.height
      width = height * ratio
    }
    return CGSize(width: max(width, 4), height: max(height, 4))
  }
}

struct EntryRow: View {
  let entry: MenuEntry
  let preview: EntryPreview
  let isHighlighted: Bool
  let onHover: () -> Void
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 10) {
        RatioGlyph(ratio: entry.target.ratioValue)
          .frame(width: 20)
        Text(entry.name)
          .lineLimit(1)
          .truncationMode(.tail)
        Spacer(minLength: 8)
        Text(preview.text)
          .font(.system(size: 11.5, design: .monospaced))
          .foregroundStyle(isHighlighted ? .white.opacity(0.9) : .secondary)
          .lineLimit(1)
        if !shortcut.isEmpty {
          Text(shortcut)
            .font(.system(size: 11))
            .foregroundStyle(isHighlighted ? .white.opacity(0.85) : .secondary.opacity(0.7))
        }
      }
      .padding(.horizontal, 10)
      .frame(height: 28)
      .foregroundStyle(isHighlighted ? .white : .primary)
      .background(isHighlighted ? Color.accentColor : .clear, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(!preview.isEnabled)
    .opacity(preview.isEnabled ? 1 : 0.4)
    .onHover { inside in if inside { onHover() } }
    .accessibilityLabel(Text(entry.name))
    .accessibilityValue(Text(preview.text.replacingOccurrences(of: "→ ", with: "")))
  }

  private var shortcut: String {
    guard let id = entry.preset?.id else { return "" }
    return KeyboardShortcuts.getShortcut(for: .preset(id))?.description ?? ""
  }
}

struct EntryTile: View {
  let entry: MenuEntry
  let preview: EntryPreview
  let isHighlighted: Bool
  let onHover: () -> Void
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(spacing: 4) {
        RatioGlyph(ratio: entry.target.ratioValue, box: CGSize(width: 34, height: 24))
          .frame(maxHeight: .infinity)
        Text(entry.name)
          .font(.system(size: 11.5, weight: .medium))
          .lineLimit(1)
          .truncationMode(.tail)
        Text(PresetTarget.compactLabel(preview.text))
          .font(.system(size: 10, design: .monospaced))
          .foregroundStyle(isHighlighted ? .white.opacity(0.9) : .secondary)
          .lineLimit(1)
      }
      .padding(.horizontal, 4)
      .padding(.vertical, 8)
      .frame(maxWidth: .infinity)
      .frame(height: PopoverMetrics.tileHeight)
      .foregroundStyle(isHighlighted ? .white : .primary)
      .background(
        isHighlighted ? Color.accentColor : Color.primary.opacity(0.06),
        in: RoundedRectangle(cornerRadius: 9, style: .continuous)
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(!preview.isEnabled)
    .opacity(preview.isEnabled ? 1 : 0.4)
    .onHover { inside in if inside { onHover() } }
    .accessibilityLabel(Text(entry.name))
    .accessibilityValue(Text(preview.text.replacingOccurrences(of: "→ ", with: "")))
  }
}

struct SectionHeader: View {
  let title: String
  var isCollapsed: Bool?
  var isHighlighted = false
  var onHover: (() -> Void)?
  var toggle: (() -> Void)?

  var body: some View {
    Button {
      toggle?()
    } label: {
      HStack(spacing: 4) {
        Text(title)
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(isHighlighted ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
        if let isCollapsed {
          Image(systemName: "chevron.right")
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(isHighlighted ? AnyShapeStyle(.white.opacity(0.85)) : AnyShapeStyle(.tertiary))
            .rotationEffect(.degrees(isCollapsed ? 0 : 90))
        }
        Spacer()
      }
      .padding(.horizontal, 10)
      .frame(height: PopoverMetrics.headerHeight)
      .background(isHighlighted ? Color.accentColor : .clear, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(toggle == nil)
    .onHover { inside in if inside { onHover?() } }
    .accessibilityAddTraits(.isHeader)
    .accessibilityValue(isCollapsed.map { $0 ? Text("Collapsed") : Text("Expanded") } ?? Text(verbatim: ""))
  }
}

enum PopoverMetrics {
  static let width: CGFloat = 340
  static let rowHeight: CGFloat = 28
  static let headerHeight: CGFloat = 24
  static let tileHeight: CGFloat = 80
  static let tileSpacing: CGFloat = 6
  static let maxContentHeight: CGFloat = 430
}
