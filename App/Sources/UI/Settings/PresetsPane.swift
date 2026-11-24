import KeyboardShortcuts
import ResizerCore
import SwiftUI

struct PresetsPane: View {
  let model: AppModel
  let shortcuts: ShortcutCenter
  @State private var section = PresetsPane.initialSection
  @State private var selection: Set<String> = []
  @State private var editing: Preset?
  @State private var isAdding = false
  // The measured widths of the cells, by column and by row. A column is as wide as its widest cell.
  @State private var cellWidths: [MeasuredColumn: [String: CGFloat]] = [:]

  private var settings: AppSettings { model.settings }

  private static var initialSection: String {
    #if DEBUG
      if let section = ProcessInfo.processInfo.environment["APP_DEBUG_SECTION"] { return section }
    #endif
    return "favorites"
  }

  // The parts of a row. The columns between the name and the star get the width of their widest cell.
  private enum Column {
    static let star: CGFloat = 18
    // The same gap between all columns.
    static let spacing: CGFloat = 20
    static let inset: CGFloat = 12
  }

  private enum MeasuredColumn: Hashable { case size, ratio, shortcut }
  private static let headerKey = "header"

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      pills
      heading
      card
      bottomBar
    }
    .padding(.horizontal, SettingsView.contentInset)
    .padding(.bottom, 14)
    .onChange(of: section) { selection = [] }
    #if DEBUG
      // Opens the sheet for a new preset at once, for screenshots.
      .onAppear { if ProcessInfo.processInfo.environment["APP_DEBUG_EDITOR"] != nil { isAdding = true } }
    #endif
    .sheet(isPresented: $isAdding) {
      PresetEditor(preset: nil, unit: settings.units.symbol) { name, target in
        let preset = settings.presets.addCustom(name: name, target: target)
        shortcuts.syncPresets()
        section = PresetGroup.custom.rawValue
        selection = [preset.id]
      }
    }
    .sheet(item: $editing) { preset in
      PresetEditor(preset: preset, unit: settings.units.symbol) { name, target in
        var updated = preset
        updated.name = name
        updated.target = target
        settings.presets.updateCustom(updated)
      }
    }
  }

  // The groups as a row of pills, so that the window has only one sidebar.
  private var pills: some View {
    ScrollView(.horizontal, showsIndicators: false) { pillRow }
      .scrollBounceBehavior(.basedOnSize)
  }

  private var pillRow: some View {
    HStack(spacing: 4) {
      pill(id: "favorites", title: String(localized: "Favorites"), symbol: "star.fill")
      ForEach(PresetGroup.allCases, id: \.self) { group in
        pill(id: group.rawValue, title: group.displayTitle, symbol: nil)
      }
    }
  }

  private func pill(id: String, title: String, symbol: String?) -> some View {
    let isSelected = section == id
    return HStack(spacing: 5) {
      if let symbol { Image(systemName: symbol).font(.system(size: 9.5)) }
      Text(title)
    }
    .font(.system(size: 11.5))
    .padding(.horizontal, 10)
    .frame(height: 24)
    .foregroundStyle(isSelected ? .white : .primary)
    .background(Capsule().fill(isSelected ? Color.accentColor : Color.primary.opacity(0.07)))
    .contentShape(Capsule())
    .onLongPressGesture(minimumDuration: 0, perform: {}, onPressingChanged: { isDown in
      if isDown { section = id }
    })
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    .accessibilityAction { section = id }
  }

  private var group: PresetGroup? { PresetGroup(rawValue: section) }

  private var presets: [Preset] {
    group.map { settings.presets.presets(in: $0) } ?? settings.presets.favorites
  }

  // One line about the selected group, above the card. The selected pill shows the name of the group.
  private var heading: some View {
    Text(description)
      .font(.system(size: 11.5))
      .foregroundStyle(.secondary)
      .padding(.horizontal, 2)
  }

  private var description: LocalizedStringKey {
    switch group {
    case nil: "The presets at the top of the menu. Drag a row to change the order."
    case .ratios: "Change only the shape of the window, with the smallest change in size."
    case .screens: "Common screen and video sizes."
    case .social: "Sizes for posts, covers and images on social networks."
    case .appStore: "Screenshot sizes for the Mac App Store."
    case .custom: "Your own sizes and ratios. Double-click a preset to edit it."
    }
  }

  // One rounded card with a header row and the presets, without empty rows.
  private var card: some View {
    Group {
      if presets.isEmpty {
        emptyState
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        // The card ends below the last row, so that it shows no empty rows.
        list
      }
    }
    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.05)))
    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
    .frame(maxHeight: .infinity, alignment: .top)
  }

  @ViewBuilder
  private var emptyState: some View {
    if group == .custom {
      ContentUnavailableView {
        Label("No custom presets", systemImage: "plus.rectangle.on.rectangle")
      } description: {
        Text("Add a size or ratio that you use often, for example 1400x600 for a blog header.")
      } actions: {
        Button("Add Preset") { isAdding = true }
      }
    } else {
      ContentUnavailableView("No favorites", systemImage: "star", description: Text("Click the star of a preset to add it here."))
    }
  }

  /**
   The header and the rows, laid out by this view and not by a system list. A system list gives
   selectable rows other margins than the header, so the columns would not line up.
   */
  private var list: some View {
    let rows = presets
    return VStack(spacing: 0) {
      headerRow
      ScrollView {
        VStack(spacing: 0) {
          ForEach(rows) { preset in
            interactiveRow(preset)
          }
        }
      }
      .scrollBounceBehavior(.basedOnSize)
      // The card is only as tall as its rows. It scrolls only when the rows do not fit.
      .frame(maxHeight: CGFloat(rows.count) * Self.rowHeight)
    }
    // Forgets the widths of rows that are no longer in the list, so that a column can get narrower again.
    .onChange(of: rows.map(\.id)) { _, ids in
      let keys = Set(ids + [Self.headerKey])
      cellWidths = cellWidths.mapValues { $0.filter { keys.contains($0.key) } }
    }
  }

  /**
   A cell of a measured column. The cell reports the width of its content, and the column gets
   the width of its widest cell. So all columns have the same gap, also for long German titles and
   for long shortcuts.
   */
  private func cell<Content: View>(_ column: MeasuredColumn, _ key: String, @ViewBuilder content: () -> Content) -> some View {
    content()
      .fixedSize()
      .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
        cellWidths[column, default: [:]][key] = width
      }
      .frame(width: cellWidths[column]?.values.max(), alignment: .leading)
  }

  @ViewBuilder
  private func interactiveRow(_ preset: Preset) -> some View {
    let base = row(preset)
      .background {
        if selection.contains(preset.id) {
          RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(Color.accentColor.opacity(0.25))
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
        }
      }
      .overlay(alignment: .top) { Divider().opacity(0.6) }
      .contentShape(Rectangle())
    if group == nil {
      // Favorites can be dragged to a new place.
      base
        .draggable(preset.id)
        .dropDestination(for: String.self) { ids, _ in
          guard let id = ids.first else { return false }
          withAnimation(.easeOut(duration: 0.15)) { settings.presets.moveFavorite(id, to: preset.id) }
          return true
        }
    } else if preset.isCustom {
      // Custom presets can be selected, edited and deleted.
      base
        .onTapGesture(count: 2) { editing = preset }
        .onTapGesture { selection = [preset.id] }
        .contextMenu {
          Button("Edit…") { editing = preset }
          Button("Delete", role: .destructive) { remove([preset.id]) }
        }
    } else {
      base
    }
  }

  private static let rowHeight: CGFloat = 32
  private static let headerHeight: CGFloat = 28

  private var headerRow: some View {
    HStack(spacing: Column.spacing) {
      Text("Preset").frame(maxWidth: .infinity, alignment: .leading)
      cell(.size, Self.headerKey) { Text("Size") }
      cell(.ratio, Self.headerKey) { Text("Ratio") }
      cell(.shortcut, Self.headerKey) { Text("Shortcut") }
      Image(systemName: "star")
        .frame(width: Column.star)
        .help("Favorites")
        .accessibilityLabel("Favorites")
    }
    .font(.system(size: 11.5))
    .foregroundStyle(.secondary)
    .lineLimit(1)
    .padding(.horizontal, Column.inset)
    .frame(height: Self.headerHeight)
  }

  // All values start at the left edge of their column, below the column title.
  private func row(_ preset: Preset) -> some View {
    let target = preset.target
    return HStack(spacing: Column.spacing) {
      HStack(spacing: 9) {
        RatioGlyph(ratio: target.ratioValue)
          .frame(width: 20)
        Text(preset.displayName)
          .lineLimit(1)
          .truncationMode(.tail)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      Group {
        cell(.size, preset.id) { Text(verbatim: Self.sizeLabel(target)) }
        cell(.ratio, preset.id) { Text(verbatim: target.ratioLabel) }
      }
      .font(.system(size: 12).monospacedDigit())
      .foregroundStyle(.secondary)
      cell(.shortcut, preset.id) {
        ShortcutField(name: .preset(preset.id), keySize: 18, showsButtons: false)
      }
      starButton(preset)
        .frame(width: Column.star)
    }
    .font(.system(size: 13))
    .padding(.horizontal, Column.inset)
    .frame(height: Self.rowHeight)
    .contentShape(Rectangle())
    .tag(preset.id)
  }

  // A ratio preset has no fixed size, so its size cell is empty.
  private static func sizeLabel(_ target: PresetTarget) -> String {
    if case .size = target { return target.label }
    return ""
  }

  private func starButton(_ preset: Preset) -> some View {
    let isFavorite = settings.presets.isFavorite(preset.id)
    return Button {
      settings.presets.setFavorite(preset.id, !isFavorite)
    } label: {
      Image(systemName: isFavorite ? "star.fill" : "star")
        .font(.system(size: 13))
        .foregroundStyle(isFavorite ? Color.yellow : Color.secondary)
        .frame(width: Column.star, height: Column.star)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .help(isFavorite ? "Remove from favorites" : "Add to favorites")
    .accessibilityLabel(isFavorite ? "Remove from favorites" : "Add to favorites")
  }

  private var bottomBar: some View {
    let selectedCustom = selection.filter { settings.presets.preset(id: $0)?.isCustom == true }
    let isCustom = section == PresetGroup.custom.rawValue
    let hasCustom = !settings.presets.presets(in: .custom).isEmpty
    return HStack(spacing: 8) {
      Button {
        isAdding = true
      } label: {
        Label("Add Preset", systemImage: "plus")
      }
      .buttonStyle(.borderedProminent)
      if isCustom && hasCustom {
        Button(role: .destructive) {
          remove(selectedCustom)
        } label: {
          Label("Delete", systemImage: "trash")
        }
        .disabled(selectedCustom.isEmpty)
        .help("Delete the selected custom preset")
      }
      Spacer()
      Button("Restore Defaults") { settings.presets.restoreDefaults() }
    }
  }

  private func remove(_ ids: Set<String>) {
    for id in ids { settings.presets.removeCustom(id) }
    selection = []
    shortcuts.syncPresets()
  }
}

// Adds or changes a custom preset. The value is a size (width and height) or a ratio.
struct PresetEditor: View {
  enum Kind { case size, ratio }

  let preset: Preset?
  // The unit of sizes, for example "px".
  let unit: String
  let save: (String, PresetTarget) -> Void
  @Environment(\.dismiss) private var dismiss
  @State private var name: String
  @State private var kind: Kind
  @State private var first: String
  @State private var second: String

  init(preset: Preset?, unit: String, save: @escaping (String, PresetTarget) -> Void) {
    self.preset = preset
    self.unit = unit
    self.save = save
    var kind = Kind.size
    var first = ""
    var second = ""
    switch preset?.target {
    case .size(let width, let height):
      first = String(width)
      second = String(height)
    case .ratio(let ratio):
      kind = .ratio
      // The full values, not the rounded label, so that a save without a change keeps the ratio.
      first = Self.text(ratio.width)
      second = Self.text(ratio.height)
    case nil:
      break
    }
    #if DEBUG
      if ProcessInfo.processInfo.environment["APP_DEBUG_EDITOR"] == "ratio" { kind = .ratio }
    #endif
    _name = State(initialValue: preset?.name ?? "")
    _kind = State(initialValue: kind)
    _first = State(initialValue: first)
    _second = State(initialValue: second)
  }

  private static func text(_ value: Double) -> String {
    value == value.rounded() ? String(format: "%.0f", value) : String(value)
  }

  private var target: PresetTarget? {
    switch kind {
    case .size: SizeInput.size(width: first, height: second)
    case .ratio: SizeInput.ratio(width: first, height: second)
    }
  }

  private var isComplete: Bool {
    !first.trimmingCharacters(in: .whitespaces).isEmpty && !second.trimmingCharacters(in: .whitespaces).isEmpty
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(preset == nil ? "New preset" : "Edit preset").font(.headline)
      Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 10, verticalSpacing: 12) {
        GridRow {
          Text("Name").gridColumnAlignment(.trailing)
          TextField("Name", text: $name, prompt: Text("Blog header"))
            .labelsHidden()
        }
        GridRow {
          Text("Type")
          Picker("Type", selection: $kind) {
            Text("Size").tag(Kind.size)
            Text("Ratio").tag(Kind.ratio)
          }
          .labelsHidden()
          .pickerStyle(.segmented)
          .fixedSize()
          .onChange(of: kind) {
            first = ""
            second = ""
          }
        }
        GridRow {
          // Both labels take space, so that the label column keeps its width when the type changes.
          ZStack(alignment: .trailing) {
            Text("Size").opacity(kind == .size ? 1 : 0)
            Text("Ratio").opacity(kind == .ratio ? 1 : 0)
          }
          HStack(spacing: 6) {
            numberField("Width", text: $first, prompt: kind == .size ? "1400" : "21")
            Text(verbatim: kind == .size ? "×" : ":")
              .foregroundStyle(.secondary)
              .frame(width: 10)
            numberField("Height", text: $second, prompt: kind == .size ? "600" : "9")
            // The unit keeps its space for a ratio too, so that nothing moves.
            Text(verbatim: unit)
              .foregroundStyle(.secondary)
              .opacity(kind == .size ? 1 : 0)
          }
        }
        GridRow {
          Text("Result")
          result
            .lineLimit(1)
        }
      }
      HStack {
        Spacer()
        Button("Cancel") { dismiss() }
          .keyboardShortcut(.cancelAction)
        Button(preset == nil ? "Add" : "Save") {
          guard let target else { return }
          let trimmed = name.trimmingCharacters(in: .whitespaces)
          save(trimmed.isEmpty ? target.label : trimmed, target)
          dismiss()
        }
        .keyboardShortcut(.defaultAction)
        .disabled(target == nil)
      }
    }
    .padding(20)
    .frame(width: 400)
  }

  private func numberField(_ label: LocalizedStringKey, text: Binding<String>, prompt: String) -> some View {
    TextField(label, text: text, prompt: Text(verbatim: prompt))
      .labelsHidden()
      .multilineTextAlignment(.center)
      .monospacedDigit()
      .frame(width: 64)
  }

  @ViewBuilder
  private var result: some View {
    if let target {
      HStack(spacing: 6) {
        RatioGlyph(ratio: target.ratioValue)
        Text(target.isRatio ? "Ratio \(target.label)" : "\(target.label) · \(target.ratioLabel)")
      }
    } else if isComplete {
      Text(kind == .size ? "Use whole numbers from 50 to 20000." : "Use a ratio between 1:10 and 10:1.")
        .foregroundStyle(.red)
    } else {
      Text(kind == .size ? "Type the width and the height." : "Type the two numbers of the ratio.")
        .foregroundStyle(.secondary)
    }
  }
}
