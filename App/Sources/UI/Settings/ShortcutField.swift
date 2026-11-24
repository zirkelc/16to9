import AppKit
@preconcurrency import KeyboardShortcuts
import SwiftUI

/**
 A shortcut field that shows the keys as keycaps. Click it, then type the shortcut. A popover shows
 the keys that are held, the hint and the errors, so that the field keeps its width while it listens.
 Escape cancels and Delete removes the shortcut. While the field listens, the global shortcuts of the
 app are paused, so that the field also gets a shortcut that is in use.
 */
struct ShortcutField: View {
  // Returns the name of the action that already uses a shortcut, or nil. The app sets it at launch.
  @MainActor static var findOwner: (KeyboardShortcuts.Shortcut, KeyboardShortcuts.Name) -> String? = { _, _ in nil }
  // Stops the field that listens now, so that only one field listens at a time.
  @MainActor private static var stopActive: (() -> Void)?
  #if DEBUG
    // For screenshots: the first field that appears starts to listen.
    @MainActor private static var debugListen = ProcessInfo.processInfo.environment["APP_DEBUG_RECORDING"] != nil
  #endif

  let name: KeyboardShortcuts.Name
  var keySize: CGFloat = 22
  // Shows the buttons that reset and remove the shortcut next to the field. The popover can always remove it.
  var showsButtons = true

  @State private var shortcut: KeyboardShortcuts.Shortcut?
  @State private var isListening = false
  @State private var held: NSEvent.ModifierFlags = []
  @State private var refusal: String?
  @State private var shake = 0
  @State private var monitor: Any?
  // A click on the field that closes the popover must not open it again.
  @State private var stoppedAt = Date.distantPast

  var body: some View {
    HStack(spacing: 6) {
      if showsButtons && !isListening {
        if let defaultShortcut = name.defaultShortcut, shortcut != defaultShortcut {
          smallButton("arrow.counterclockwise") { set(defaultShortcut) }
            .help(Text("Reset to \(Self.label(defaultShortcut))"))
            .accessibilityLabel(Text("Reset to \(Self.label(defaultShortcut))"))
        }
        if shortcut != nil {
          smallButton("xmark") { set(nil) }
            .help("Remove the shortcut")
            .accessibilityLabel("Remove the shortcut")
        }
      }
      Button(action: toggle) { field }
        .buttonStyle(.plain)
        .help(isListening ? Text("Type a shortcut. Escape cancels, Delete removes it.") : Text("Click to change the shortcut"))
        .accessibilityLabel(Text(verbatim: shortcut?.description ?? String(localized: "Record shortcut")))
    }
    .popover(isPresented: Binding(get: { isListening }, set: { if !$0 { stop() } }), arrowEdge: .bottom) {
      recorder
    }
    .onAppear {
      shortcut = KeyboardShortcuts.getShortcut(for: name)
      #if DEBUG
        if Self.debugListen {
          Self.debugListen = false
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { start() }
        }
      #endif
    }
    .onDisappear { stop() }
  }

  private var field: some View {
    let shape = RoundedRectangle(cornerRadius: keySize * 0.36, style: .continuous)
    // The field shows the same content while it listens, so that its width does not change.
    return HStack(spacing: 4) {
      if let shortcut {
        keycaps(Self.symbols(shortcut.modifiers) + [Self.keyLabel(shortcut)], tint: nil, size: keySize)
      } else {
        // A short text, so that the field fits in the table of presets.
        Text("Record").font(.system(size: 12)).foregroundStyle(.secondary).padding(.horizontal, 6)
      }
    }
    .padding(4)
    .frame(minHeight: keySize + 8)
    .background(shape.fill(isListening ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.07)))
    .overlay(shape.strokeBorder(isListening ? Color.accentColor : Color.primary.opacity(0.08), lineWidth: 1))
    .contentShape(shape)
  }

  // The content of the popover while the field listens.
  private var recorder: some View {
    VStack(spacing: 8) {
      Group {
        if !held.isEmpty {
          keycaps(Self.symbols(held), tint: .accentColor, size: 24)
        } else if let shortcut {
          keycaps(Self.symbols(shortcut.modifiers) + [Self.keyLabel(shortcut)], tint: nil, size: 24).opacity(0.35)
        } else {
          RoundedRectangle(cornerRadius: 24 * 0.27, style: .continuous)
            .strokeBorder(Color.secondary.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
            .frame(width: 24, height: 24)
        }
      }
      .frame(height: 28)
      .modifier(Shake(amount: CGFloat(shake)))
      .animation(.spring(duration: 0.25, bounce: 0.2), value: shake)
      Text("Recording…")
        .font(.system(size: 13, weight: .semibold))
      Group {
        if let refusal {
          Text(refusal).foregroundStyle(.red)
        } else {
          Text("Type a shortcut. Escape cancels, Delete removes it.").foregroundStyle(.secondary)
        }
      }
      .font(.system(size: 11))
      .multilineTextAlignment(.center)
      .fixedSize(horizontal: false, vertical: true)
      if shortcut != nil {
        Button("Remove the shortcut") {
          set(nil)
          stop()
        }
        .controlSize(.small)
        .padding(.top, 2)
      }
    }
    .padding(14)
    .frame(width: 210)
  }

  private func keycaps(_ labels: [String], tint: Color?, size keySize: CGFloat) -> some View {
    KeycapRow(labels: labels, tint: tint, size: keySize)
  }

  // MARK: Listening

  private func toggle() {
    if isListening {
      stop()
    } else if Date().timeIntervalSince(stoppedAt) > 0.3 {
      start()
    }
  }

  private func start() {
    Self.stopActive?()
    refusal = nil
    held = []
    isListening = true
    KeyboardShortcuts.isEnabled = false
    Self.stopActive = { stop() }
    monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
      handle(event) ? nil : event
    }
  }

  private func stop() {
    guard isListening else { return }
    isListening = false
    held = []
    stoppedAt = Date()
    if let monitor { NSEvent.removeMonitor(monitor) }
    monitor = nil
    KeyboardShortcuts.isEnabled = true
    Self.stopActive = nil
  }

  // Returns true when the field used the event.
  private func handle(_ event: NSEvent) -> Bool {
    let modifiers = event.modifierFlags.intersection([.control, .option, .shift, .command])
    if event.type == .flagsChanged {
      held = modifiers
      return false
    }
    switch event.keyCode {
    case 53 where modifiers.isEmpty:
      stop()
      return true
    case 51 where modifiers.isEmpty, 117 where modifiers.isEmpty:
      set(nil)
      stop()
      return true
    default:
      break
    }
    guard let candidate = KeyboardShortcuts.Shortcut(event: event) else { return true }
    if !modifiers.contains(.command) && !modifiers.contains(.option) && !modifiers.contains(.control) && !Self.isFunctionKey(event.keyCode) {
      refuse(String(localized: "Add ⌘, ⌥ or ⌃"))
      return true
    }
    if let owner = Self.findOwner(candidate, name) {
      refuse(String(localized: "Used by “\(owner)”"))
      return true
    }
    set(candidate)
    stop()
    return true
  }

  private func refuse(_ reason: String) {
    refusal = reason
    shake += 1
    held = []
  }

  private func set(_ value: KeyboardShortcuts.Shortcut?) {
    KeyboardShortcuts.setShortcut(value, for: name)
    shortcut = value
    refusal = nil
  }

  // A small round button next to the field, for reset and remove.
  private func smallButton(_ symbol: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: symbol)
        .font(.system(size: 9, weight: .bold))
        .foregroundStyle(.secondary)
        .frame(width: 20, height: 20)
        .background(Circle().fill(Color.primary.opacity(0.1)))
        .contentShape(Circle())
    }
    .buttonStyle(.plain)
  }

  // MARK: Labels

  // The shortcut as text, for example "⌃⌥G".
  static func label(_ shortcut: KeyboardShortcuts.Shortcut) -> String {
    (symbols(shortcut.modifiers) + [keyLabel(shortcut)]).joined()
  }

  static func symbols(_ flags: NSEvent.ModifierFlags) -> [String] {
    var result: [String] = []
    if flags.contains(.control) { result.append("⌃") }
    if flags.contains(.option) { result.append("⌥") }
    if flags.contains(.shift) { result.append("⇧") }
    if flags.contains(.command) { result.append("⌘") }
    return result
  }

  // The key without its modifiers, for example "G" or "Space".
  static func keyLabel(_ shortcut: KeyboardShortcuts.Shortcut) -> String {
    String(shortcut.description.drop { "⌃⌥⇧⌘".contains($0) })
  }

  private static func isFunctionKey(_ keyCode: UInt16) -> Bool {
    [122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111, 105, 107, 113, 106, 64, 79, 80, 90].contains(keyCode)
  }
}

// Moves the field left and right, for a shortcut that the field does not accept.
private struct Shake: GeometryEffect {
  var amount: CGFloat
  var animatableData: CGFloat {
    get { amount }
    set { amount = newValue }
  }

  func effectValue(size: CGSize) -> ProjectionTransform {
    ProjectionTransform(CGAffineTransform(translationX: 5 * sin(amount * .pi * 4), y: 0))
  }
}

// Keys as small keycaps, for example ⌃ ⌥ G.
struct KeycapRow: View {
  let labels: [String]
  var tint: Color?
  var size: CGFloat

  var body: some View {
    HStack(spacing: 3) {
      ForEach(Array(labels.enumerated()), id: \.offset) { _, label in
        Text(verbatim: label)
          .font(.system(size: size * 0.52, weight: .semibold))
          .foregroundStyle(tint ?? .primary)
          .frame(minWidth: size, minHeight: size)
          .padding(.horizontal, label.count > 1 ? 5 : 0)
          .background(
            RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
              .fill(LinearGradient(colors: [Color.primary.opacity(0.16), Color.primary.opacity(0.1)], startPoint: .top, endPoint: .bottom))
              .shadow(color: .black.opacity(0.35), radius: 0, y: 1)
          )
      }
    }
  }
}
