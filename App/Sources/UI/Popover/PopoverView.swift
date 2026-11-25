import ResizerCore
import SwiftUI

/**
 The content of the menu bar popover. The layout (list or grid) is a setting, and the button in the
 header switches it. The search field reads typed sizes and ratios and also filters the presets.
 */
struct PopoverView: View {
  let model: AppModel
  @State private var query = ""
  // The ID of the highlighted entry, or of a group header (see headerID).
  @State private var highlighted: String?
  // The size preview starts with the first hover or arrow key, so that it does not show each time the popover opens.
  @State private var previewActive = false
  // The ID of the item under the pointer, or nil when the pointer is on no item that highlights.
  @State private var hovered: String?
  @FocusState private var searchFocused: Bool

  private var settings: AppSettings { model.settings }

  var body: some View {
    @Bindable var settings = model.settings
    VStack(spacing: 0) {
      header
      Picker("Action", selection: $settings.action) {
        ForEach(PresetAction.allCases) { Text($0.title).tag($0) }
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .padding(.horizontal, 6)
      .padding(.bottom, 8)

      searchField

      if !query.isEmpty {
        searchResults
      } else if settings.popoverLayout == .list {
        listContent
      } else {
        gridContent
      }

      Divider().padding(.vertical, 6).padding(.horizontal, 6)
      footer
    }
    .padding(6)
    .frame(width: PopoverMetrics.width)
    .onAppear {
      query = ""
      previewActive = false
      highlighted = navigableEntries.first?.id
      searchFocused = true
    }
    .onDisappear { model.hidePreview() }
    .onChange(of: highlighted) { updatePreview() }
    .onChange(of: settings.action) { updatePreview() }
  }

  // MARK: Header

  @ViewBuilder
  private var header: some View {
    HStack(spacing: 10) {
      if let window = model.frontWindow {
        Image(nsImage: window.app.icon ?? NSImage())
          .resizable()
          .frame(width: 28, height: 28)
        VStack(alignment: .leading, spacing: 2) {
          Text(window.appName).font(.system(size: 13, weight: .semibold)).lineLimit(1)
          Text(windowSizeText(window))
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
      } else if !model.permission.isGranted {
        Image(systemName: "lock.shield")
          .font(.system(size: 20))
          .foregroundStyle(.orange)
          .frame(width: 28, height: 28)
        VStack(alignment: .leading, spacing: 2) {
          Text("Allow window control").font(.system(size: 13, weight: .semibold))
          Button("Set up access…") {
            model.closePopover()
            model.openOnboarding()
          }
          .buttonStyle(.link)
          .font(.system(size: 11))
        }
      } else {
        Image(systemName: "macwindow")
          .font(.system(size: 20))
          .foregroundStyle(.secondary)
          .frame(width: 28, height: 28)
        VStack(alignment: .leading, spacing: 2) {
          Text(model.frontApp?.localizedName ?? String(localized: "No app")).font(.system(size: 13, weight: .semibold))
          Text("No window").font(.system(size: 11)).foregroundStyle(.secondary)
        }
      }
      Spacer()
      let layoutHighlighted = highlighted == Self.layoutButtonID
      Button {
        toggleLayout()
      } label: {
        Image(systemName: settings.popoverLayout == .list ? PopoverLayout.grid.symbol : PopoverLayout.list.symbol)
          .font(.system(size: 12))
          .foregroundStyle(layoutHighlighted ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
          .frame(width: 24, height: 24)
          .background(layoutHighlighted ? Color.accentColor : .clear, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .onHover { inside in hover(Self.layoutButtonID, inside: inside) }
      .help(settings.popoverLayout == .list ? "Show as grid" : "Show as list")
      .accessibilityLabel(settings.popoverLayout == .list ? "Show as grid" : "Show as list")
    }
    .padding(.horizontal, 8)
    .padding(.top, 6)
    .padding(.bottom, 10)
  }

  private static let layoutButtonID = "header.layout"

  // Switches between list and grid. The highlight stays on the button, because the pointer or the keyboard is there.
  private func toggleLayout() {
    settings.popoverLayout = settings.popoverLayout == .list ? .grid : .list
  }

  private func windowSizeText(_ window: WindowSnapshot) -> String {
    let size = window.frame.size
    let points = "\(Int(size.width.rounded())) × \(Int(size.height.rounded())) pt"
    guard settings.units == .pixels else { return points }
    return "\(model.describe(size, on: window)) · \(points)"
  }

  // MARK: Search

  private var searchField: some View {
    HStack(spacing: 6) {
      Image(systemName: "magnifyingglass").foregroundStyle(.secondary).font(.system(size: 11))
      TextField("Size or ratio, e.g. 1280x720 or 4:3", text: $query)
        .textFieldStyle(.plain)
        .font(.system(size: 12))
        .focused($searchFocused)
        .onChange(of: query) { highlighted = navigableEntries.first?.id }
        .onKeyPress(.downArrow) { move(by: settings.popoverLayout == .grid && query.isEmpty ? 3 : 1) }
        .onKeyPress(.upArrow) { move(by: settings.popoverLayout == .grid && query.isEmpty ? -3 : -1) }
        .onKeyPress(.rightArrow) { query.isEmpty && settings.popoverLayout == .grid ? move(by: 1) : .ignored }
        .onKeyPress(.leftArrow) { query.isEmpty && settings.popoverLayout == .grid ? move(by: -1) : .ignored }
        .onKeyPress(.return) {
          if highlighted == Self.layoutButtonID {
            toggleLayout()
            return .handled
          }
          if let tab = gridTabs.first(where: { Self.tabID($0.id) == highlighted }) {
            settings.gridTab = tab.id
            return .handled
          }
          if let action = highlightedFooterAction {
            run(action)
            return .handled
          }
          if let group = highlightedGroup {
            toggle(group)
            return .handled
          }
          guard let entry = navigableEntries.first(where: { $0.id == highlighted }) ?? navigableEntries.first else {
            return .ignored
          }
          perform(entry)
          return .handled
        }
        .onKeyPress(.escape) {
          model.closePopover()
          return .handled
        }
      if !query.isEmpty {
        Button {
          query = ""
        } label: {
          Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Clear")
      }
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 5)
    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    .padding(.horizontal, 6)
    .padding(.bottom, 4)
  }

  private func move(by step: Int) -> KeyPress.Result {
    let entries = navigableEntries.filter { model.preview(for: $0.target).isEnabled }
    guard !entries.isEmpty else { return .ignored }
    // From the footer, the up arrow goes to the last entry, which is above the footer.
    if highlightedFooterAction != nil {
      guard step < 0, let last = entries.last else { return .handled }
      previewActive = true
      highlighted = last.id
      updatePreview()
      return .handled
    }
    // From a group header, the arrow keys go to the next entry below it or the previous entry above it.
    if let group = highlightedGroup {
      let ids = Set(entries.map(\.id))
      let order = listOrder
      guard let position = order.firstIndex(of: Self.headerID(group)) else { return .ignored }
      let candidates = step > 0 ? Array(order[(position + 1)...]) : order[..<position].reversed()
      if let next = candidates.first(where: ids.contains) { highlighted = next }
      return .handled
    }
    let index = entries.firstIndex { $0.id == highlighted } ?? -step.signum()
    let next = min(max(index + step, 0), entries.count - 1)
    previewActive = true
    highlighted = entries[next].id
    updatePreview()
    return .handled
  }

  /**
   Highlights the item under the pointer: an entry, a tab, a group header or a button. When the pointer leaves the
   item and goes to no other item, the highlight goes away. The short wait keeps the highlight while the pointer
   crosses the gap between two items, so that the preview of an entry does not blink.
   */
  private func hover(_ id: String, inside: Bool) {
    if inside {
      hovered = id
      highlighted = id
      return
    }
    guard hovered == id else { return }
    hovered = nil
    Task {
      try? await Task.sleep(for: .milliseconds(120))
      if hovered == nil, highlighted == id { highlighted = nil }
    }
  }

  // Highlights an entry under the pointer and shows its preview. The preview hides with the highlight.
  private func hover(_ entry: MenuEntry, inside: Bool) {
    if inside { previewActive = true }
    hover(entry.id, inside: inside)
    if inside { updatePreview() }
  }

  // Shows the frame of the highlighted entry on the screen, or hides it when no entry that can run is highlighted.
  private func updatePreview() {
    guard previewActive, let entry = navigableEntries.first(where: { $0.id == highlighted }),
      model.preview(for: entry.target).isEnabled
    else {
      model.hidePreview()
      return
    }
    model.showPreview(for: entry)
  }

  // The entries in the order of the screen, for the arrow keys.
  private var navigableEntries: [MenuEntry] {
    if !query.isEmpty { return searchEntries }
    if settings.popoverLayout == .grid { return gridEntries }
    var entries = model.favoriteEntries
    for group in PresetGroup.allCases where !settings.collapsedGroups.contains(group.rawValue) {
      entries += model.entries(for: settings.presets.presets(in: group))
    }
    return entries
  }

  private var searchEntries: [MenuEntry] {
    var entries: [MenuEntry] = []
    if let typed = model.typedEntry(query) { entries.append(typed) }
    entries += model.entries(for: settings.presets.search(query) { "\($0.displayName) \($0.group.displayTitle)" })
    return entries
  }

  private var searchResults: some View {
    let entries = searchEntries
    return Group {
      if entries.isEmpty {
        Text("No preset found. Type a size like `1280x720` or a ratio like `4:3`.")
          .font(.system(size: 11.5))
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .padding(16)
          .frame(maxWidth: .infinity)
      } else {
        ScrollView {
          VStack(spacing: 0) {
            ForEach(entries) { row($0) }
          }
          .padding(.top, 4)
        }
        .frame(height: min(CGFloat(entries.count) * PopoverMetrics.rowHeight + 4, PopoverMetrics.maxContentHeight))
      }
    }
  }

  // MARK: List

  private static func headerID(_ group: PresetGroup) -> String { "header.\(group.rawValue)" }

  private var highlightedGroup: PresetGroup? {
    guard query.isEmpty, settings.popoverLayout == .list else { return nil }
    return PresetGroup.allCases.first { Self.headerID($0) == highlighted }
  }

  // The IDs of the list in the order of the screen: the favorites, then each group header and its entries.
  private var listOrder: [String] {
    var ids = model.favoriteEntries.map(\.id)
    for group in PresetGroup.allCases where !settings.presets.presets(in: group).isEmpty {
      ids.append(Self.headerID(group))
      if !settings.collapsedGroups.contains(group.rawValue) {
        ids += model.entries(for: settings.presets.presets(in: group)).map(\.id)
      }
    }
    return ids
  }

  private func toggle(_ group: PresetGroup) {
    withAnimation(.easeOut(duration: 0.15)) {
      if settings.collapsedGroups.contains(group.rawValue) {
        settings.collapsedGroups.remove(group.rawValue)
      } else {
        settings.collapsedGroups.insert(group.rawValue)
      }
    }
  }

  private var listContent: some View {
    let favorites = model.favoriteEntries
    let groups = PresetGroup.allCases.filter { !settings.presets.presets(in: $0).isEmpty }
    var height: CGFloat = 0
    if !favorites.isEmpty { height += PopoverMetrics.headerHeight + CGFloat(favorites.count) * PopoverMetrics.rowHeight }
    for group in groups {
      height += PopoverMetrics.headerHeight
      if !settings.collapsedGroups.contains(group.rawValue) {
        height += CGFloat(settings.presets.presets(in: group).count) * PopoverMetrics.rowHeight
      }
    }

    return ScrollView {
      VStack(spacing: 0) {
        if !favorites.isEmpty {
          // The header cannot be clicked, so hovering it only removes the highlight from the rows.
          SectionHeader(title: String(localized: "Favorites"), onHover: { inside in if inside { highlighted = nil } })
          ForEach(favorites) { row($0) }
        }
        ForEach(groups, id: \.self) { group in
          let collapsed = settings.collapsedGroups.contains(group.rawValue)
          SectionHeader(
            title: group.displayTitle,
            isCollapsed: collapsed,
            isHighlighted: highlighted == Self.headerID(group),
            onHover: { inside in hover(Self.headerID(group), inside: inside) },
            toggle: { toggle(group) }
          )
          if !collapsed {
            ForEach(model.entries(for: settings.presets.presets(in: group))) { row($0) }
          }
        }
      }
    }
    .frame(height: min(height + 2, PopoverMetrics.maxContentHeight))
  }

  private func row(_ entry: MenuEntry) -> some View {
    EntryRow(
      entry: entry,
      preview: model.preview(for: entry.target),
      isHighlighted: highlighted == entry.id,
      onHover: { inside in hover(entry, inside: inside) },
      action: { perform(entry) }
    )
  }

  // MARK: Grid

  private var gridTabs: [(id: String, title: String)] {
    var tabs: [(String, String)] = []
    if !settings.presets.favorites.isEmpty { tabs.append(("favorites", String(localized: "Favorites"))) }
    for group in PresetGroup.allCases where !settings.presets.presets(in: group).isEmpty {
      tabs.append((group.rawValue, group.displayTitle))
    }
    return tabs
  }

  private static func tabID(_ tab: String) -> String { "tab.\(tab)" }

  private var currentGridTab: String {
    let tabs = gridTabs
    return tabs.contains { $0.id == settings.gridTab } ? settings.gridTab : (tabs.first?.id ?? "favorites")
  }

  private var gridEntries: [MenuEntry] {
    let tab = currentGridTab
    if tab == "favorites" { return model.favoriteEntries }
    guard let group = PresetGroup(rawValue: tab) else { return [] }
    return model.entries(for: settings.presets.presets(in: group))
  }

  private var gridContent: some View {
    let entries = gridEntries
    let rows = CGFloat((entries.count + 2) / 3)
    let height = rows * PopoverMetrics.tileHeight + max(rows - 1, 0) * PopoverMetrics.tileSpacing
    let columns = Array(repeating: GridItem(.flexible(), spacing: PopoverMetrics.tileSpacing), count: 3)

    return VStack(spacing: 8) {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 4) {
          ForEach(gridTabs, id: \.id) { tab in
            let isHighlighted = highlighted == Self.tabID(tab.id)
            Button {
              settings.gridTab = tab.id
            } label: {
              Text(tab.title)
                .font(.system(size: 11.5, weight: currentGridTab == tab.id ? .semibold : .regular))
                .foregroundStyle(isHighlighted ? .white : .primary)
                .padding(.horizontal, 9)
                .padding(.vertical, 3)
                .background(
                  isHighlighted ? Color.accentColor : currentGridTab == tab.id ? Color.primary.opacity(0.12) : .clear,
                  in: Capsule()
                )
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .onHover { inside in hover(Self.tabID(tab.id), inside: inside) }
          }
        }
        .padding(.horizontal, 6)
      }
      .padding(.top, 4)

      ScrollView {
        LazyVGrid(columns: columns, spacing: PopoverMetrics.tileSpacing) {
          ForEach(entries) { entry in
            EntryTile(
              entry: entry,
              preview: model.preview(for: entry.target),
              isHighlighted: highlighted == entry.id,
              onHover: { inside in hover(entry, inside: inside) },
              action: { perform(entry) }
            )
          }
        }
        .padding(.horizontal, 6)
      }
      .frame(height: min(height, PopoverMetrics.maxContentHeight))
    }
  }

  // MARK: Footer

  // The footer actions use the same highlight as the rows, so that only one item in the popover is highlighted.
  private enum FooterAction: String {
    case settings, undo, quit

    var id: String { "footer.\(rawValue)" }
  }

  private var footer: some View {
    HStack(spacing: 0) {
      footerButton("Settings…", action: .settings)
        .keyboardShortcut(",", modifiers: .command)
      footerButton("Undo", action: .undo, isEnabled: model.resizer.canUndo)
      Spacer()
      footerButton("Quit", action: .quit)
        .keyboardShortcut("q", modifiers: .command)
    }
    .font(.system(size: 12))
    .padding(.horizontal, 3)
    .padding(.bottom, 4)
  }

  private func footerButton(_ title: LocalizedStringKey, action: FooterAction, isEnabled: Bool = true) -> some View {
    let isHighlighted = isEnabled && highlighted == action.id
    return Button {
      run(action)
    } label: {
      Text(title)
        .padding(.horizontal, 7)
        .frame(height: 22)
        .foregroundStyle(isHighlighted ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
        .background(isHighlighted ? Color.accentColor : .clear, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(!isEnabled)
    .opacity(isEnabled ? 1 : 0.5)
    .onHover { inside in if isEnabled { hover(action.id, inside: inside) } }
  }

  private var highlightedFooterAction: FooterAction? {
    [FooterAction.settings, .undo, .quit].first { $0.id == highlighted }
  }

  private func run(_ action: FooterAction) {
    switch action {
    case .settings:
      model.closePopover()
      model.openSettings(.general)
    case .undo:
      model.closePopover()
      model.undo()
    case .quit:
      NSApp.terminate(nil)
    }
  }

  private func perform(_ entry: MenuEntry) {
    guard model.preview(for: entry.target).isEnabled else { return }
    model.perform(entry)
  }
}
