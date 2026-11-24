import AppKit
import KeyboardShortcuts
import Observation
import SwiftUI

// The state of the onboarding tour.
@Observable
final class OnboardingFlow {
  enum Step: Int, CaseIterable {
    case welcome, howItWorks, permission, tryIt, tryGuide, done
  }

  var step = Step.welcome {
    didSet { onStepChange(step) }
  }
  // The first resize: the app and the new size.
  var result: ResizeSummary?
  // True when the window opened only to set up the permission, not for the full tour.
  var isPermissionOnly = false
  @ObservationIgnored var onStepChange: (Step) -> Void = { _ in }
}

/**
 The tour on the first launch: welcome, a short demo, the permission, a first resize, the guide and a summary.
 The window also opens on the permission step when the user wants to give the permission later.
 */
final class OnboardingWindowController: NSWindowController, NSWindowDelegate {
  static let size = NSSize(width: 620, height: 500)

  private let model: AppModel
  private let flow = OnboardingFlow()
  private let pointer = MenuBarPointer()

  init(model: AppModel) {
    self.model = model
    let window = NSWindow(
      contentRect: NSRect(origin: .zero, size: Self.size),
      styleMask: [.titled, .closable, .fullSizeContentView],
      backing: .buffered, defer: false
    )
    window.title = String(localized: "Welcome to 16to9")
    window.titlebarAppearsTransparent = true
    window.titleVisibility = .hidden
    window.isMovableByWindowBackground = true
    window.isReleasedWhenClosed = false
    window.appearance = NSAppearance(named: .darkAqua)
    super.init(window: window)
    window.delegate = self

    let view = OnboardingView(model: model, flow: flow, close: { [weak self] in self?.close() }, openSettings: { [weak self] in
      self?.close()
      model.openSettings(.general)
    })
    let host = NSHostingView(rootView: view.frame(width: Self.size.width, height: Self.size.height))
    host.safeAreaRegions = []
    host.sizingOptions = []
    window.contentView = host
    window.setContentSize(Self.size)

    flow.onStepChange = { [weak self] step in self?.stepChanged(step) }
    model.onResize = { [weak self] summary in
      guard let self, self.window?.isVisible == true, self.flow.step == .tryIt else { return }
      self.flow.result = summary
      self.flow.step = .tryGuide
      self.showAgainIfOpen()
    }
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

  // Shows the full tour, or only the permission step.
  func show(_ step: OnboardingFlow.Step = .welcome) {
    model.settings.hasSeenOnboarding = true
    model.permission.refresh()
    model.permission.startWatching()
    flow.isPermissionOnly = step == .permission
    flow.result = nil
    flow.step = step
    NSApp.setActivationPolicy(.regular)
    NSApp.activate()
    if window?.isVisible != true { window?.center() }
    showWindow(nil)
    window?.makeKeyAndOrderFront(nil)
  }

  // Brings the window back after the user gave the permission, if it is still open.
  func showAgainIfOpen() {
    guard window?.isVisible == true else { return }
    NSApp.activate()
    window?.makeKeyAndOrderFront(nil)
  }

  func windowWillClose(_ notification: Notification) {
    pointer.hide()
    NSApp.hideDockIconUnlessWindowOpen(closing: window)
  }

  private func stepChanged(_ step: OnboardingFlow.Step) {
    Log.app.info("Tour step: \(String(describing: step), privacy: .public)")
    guard step == .tryIt else { return pointer.hide() }
    // The menu bar icon gets its position a short time after launch. Until then, try again.
    // A placed icon is in the menu bar, which is above the usable area of its screen.
    let isPlaced = { (frame: NSRect) in
      NSScreen.screens.contains { $0.frame.contains(NSPoint(x: frame.midX, y: frame.midY)) && frame.minY >= $0.visibleFrame.maxY - 2 }
    }
    guard let frame = model.statusItemFrame(), frame.width > 0, isPlaced(frame) else {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
        guard let self, self.flow.step == .tryIt, self.window?.isVisible == true else { return }
        self.stepChanged(.tryIt)
      }
      return
    }
    pointer.show(below: frame)
  }
}

// MARK: - View

struct OnboardingView: View {
  let model: AppModel
  let flow: OnboardingFlow
  let close: () -> Void
  let openSettings: () -> Void

  static let accent = Brand.amber
  // A brighter tone of the icon navy, so that the glow shows on the dark background.
  static let glow = Color(red: 0.20, green: 0.45, blue: 0.95)

  var body: some View {
    ZStack {
      Brand.night
      RadialGradient(
        colors: [glowColor.opacity(0.32), .clear], center: UnitPoint(x: 0.5, y: 0.2), startRadius: 0, endRadius: 320)
      VStack(spacing: 0) {
        Group {
          switch flow.step {
          case .welcome: welcome
          case .howItWorks: howItWorks
          case .permission: permission
          case .tryIt: tryIt
          case .tryGuide: tryGuide
          case .done: done
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        footer
      }
      .padding(.top, 34)
      .padding(.horizontal, 40)
      .padding(.bottom, 22)
    }
    .foregroundStyle(.white)
    .animation(.spring(duration: 0.35, bounce: 0), value: flow.step)
  }

  private var glowColor: Color { flow.step == .done ? .green : Self.glow }

  // MARK: Steps

  private var welcome: some View {
    VStack(spacing: 0) {
      Spacer()
      Image(nsImage: NSApp.applicationIconImage)
        .resizable()
        .frame(width: 112, height: 112)
        .shadow(color: Self.glow.opacity(0.5), radius: 30)
      title("Welcome to 16to9").padding(.top, 26)
      text("Resize any window to an exact size or aspect ratio.")
      Spacer()
      Button("Get Started") { flow.step = .howItWorks }
        .buttonStyle(OnboardingButtonStyle(kind: .primary))
        .keyboardShortcut(.defaultAction)
    }
  }

  private var howItWorks: some View {
    VStack(spacing: 0) {
      title("How 16to9 works")
      OnboardingDemo()
        .frame(height: 244)
        .padding(.top, 18)
      HStack(spacing: 6) {
        Text("Show the guide at any time with")
        Keycaps(labels: guideKeys)
      }
      .font(.system(size: 13))
      .foregroundStyle(.white.opacity(0.65))
      .padding(.top, 16)
      Spacer()
      Button("Continue") { flow.step = .permission }
        .buttonStyle(OnboardingButtonStyle(kind: .secondary))
        .keyboardShortcut(.defaultAction)
    }
  }

  private var permission: some View {
    let granted = model.permission.isGranted
    return VStack(spacing: 0) {
      title("16to9 needs one permission").padding(.top, 10)
      HStack(spacing: 14) {
        Image(systemName: "macwindow.on.rectangle")
          .font(.system(size: 17))
          .frame(width: 40, height: 40)
          .background(Circle().fill(.white.opacity(0.08)))
        VStack(alignment: .leading, spacing: 3) {
          Text("Window control").font(.system(size: 14, weight: .semibold))
          Text("Resize and move the windows of other apps").font(.system(size: 12.5)).foregroundStyle(.white.opacity(0.6))
        }
        Spacer()
        if granted {
          Label("Allowed", systemImage: "checkmark.circle.fill")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.green)
            .transition(.scale.combined(with: .opacity))
        } else {
          Button("Allow") { model.requestPermission() }
            .buttonStyle(OnboardingButtonStyle(kind: .pill))
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 14)
      .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.white.opacity(0.05)))
      .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.white.opacity(0.1), lineWidth: 0.5))
      .padding(.top, 26)
      text(granted ? "16to9 can now resize windows." : "Allow opens System Settings. Drag 16to9 from the small card into the list.")
        .padding(.top, 14)
      text("The guide works without this permission.")
        .padding(.top, 2)
        .opacity(granted ? 0 : 1)
      Spacer()
      Button(flow.isPermissionOnly && granted ? "Done" : "Continue") {
        if flow.isPermissionOnly { close() } else { flow.step = .tryIt }
      }
      .buttonStyle(OnboardingButtonStyle(kind: granted ? .primary : .disabled))
      .disabled(!granted)
      .keyboardShortcut(.defaultAction)
      Button(flow.isPermissionOnly ? "Close" : "Set up later") {
        if flow.isPermissionOnly { close() } else { flow.step = .tryGuide }
      }
      .buttonStyle(OnboardingButtonStyle(kind: .link))
      .padding(.top, 8)
      .opacity(granted ? 0 : 1)
    }
  }

  private var tryIt: some View {
    VStack(spacing: 0) {
      title("Resize your first window").padding(.top, 10)
      text("Click the app icon in the menu bar and pick a size. The window that was in front gets this size.")
      MenuBarSketch()
        .padding(.top, 28)
      Spacer()
      HStack(spacing: 6) {
        ProgressView().controlSize(.small)
        Text("Waiting for a resize…").font(.system(size: 12)).foregroundStyle(.white.opacity(0.55))
      }
      Button("Skip") { flow.step = .tryGuide }
        .buttonStyle(OnboardingButtonStyle(kind: .link))
        .padding(.top, 10)
    }
  }

  // The step ends when the user shows the guide with the shortcut. The guide works without the permission.
  private var tryGuide: some View {
    let isVisible = model.guide.isVisible
    return VStack(spacing: 0) {
      title("Show the guide").padding(.top, 10)
      HStack(spacing: 6) {
        Text("Press")
        Keycaps(labels: guideKeys)
        Text("in any app.")
      }
      .font(.system(size: 13.5))
      .foregroundStyle(.white.opacity(0.65))
      .padding(.top, 10)
      text("A frame with rulers shows on the screen. Move the window into the frame until its edges are green.")
        .padding(.top, 4)
      GuideDemo()
        .frame(height: 200)
        .padding(.top, 18)
      Spacer()
      if isVisible {
        Label("The guide is on the screen. Press the keys again to hide it.", systemImage: "checkmark.circle.fill")
          .font(.system(size: 12.5, weight: .medium))
          .foregroundStyle(.white.opacity(0.8), .green)
          .transition(.opacity)
        Button("Continue") { flow.step = .done }
          .buttonStyle(OnboardingButtonStyle(kind: .primary))
          .keyboardShortcut(.defaultAction)
          .padding(.top, 10)
      } else {
        HStack(spacing: 6) {
          ProgressView().controlSize(.small)
          Text("Waiting for the guide…").font(.system(size: 12)).foregroundStyle(.white.opacity(0.55))
        }
        Button("Skip") { flow.step = .done }
          .buttonStyle(OnboardingButtonStyle(kind: .link))
          .padding(.top, 10)
      }
    }
  }

  private var done: some View {
    VStack(spacing: 0) {
      Spacer()
      if let result = flow.result {
        // The app that 16to9 resized, with a check mark.
        Image(nsImage: result.app.icon ?? NSApp.applicationIconImage)
          .resizable()
          .frame(width: 104, height: 104)
          .overlay(alignment: .bottomTrailing) { checkBadge.offset(x: 6, y: 6) }
          .shadow(color: .green.opacity(0.3), radius: 30)
        title("Done: \(result.size)").padding(.top, 22)
        text("16to9 resized “\(result.appName)”.")
      } else {
        Image(systemName: "checkmark")
          .font(.system(size: 40, weight: .bold))
          .foregroundStyle(Color(red: 0.37, green: 0.88, blue: 0.54))
          .frame(width: 104, height: 104)
          .background(Circle().fill(Color.green.opacity(0.14)))
          .overlay(Circle().strokeBorder(Color.green.opacity(0.55), lineWidth: 1.5))
          .shadow(color: .green.opacity(0.3), radius: 30)
        title("You are ready").padding(.top, 26)
      }
      HStack(spacing: 5) {
        Brand.text("16to9 stays in the menu bar. Press", size: 13.5)
        Keycaps(labels: guideKeys)
        Text("for the guide.")
      }
      .font(.system(size: 13.5))
      .foregroundStyle(.white.opacity(0.65))
      .padding(.top, 10)
      text("Add your own sizes and shortcuts in Settings.").padding(.top, 2)
      Spacer()
      Button("Done", action: close)
        .buttonStyle(OnboardingButtonStyle(kind: .primary))
        .keyboardShortcut(.defaultAction)
      Button("Open Settings", action: openSettings)
        .buttonStyle(OnboardingButtonStyle(kind: .link))
        .padding(.top, 8)
    }
  }

  // MARK: Parts

  private var checkBadge: some View {
    Image(systemName: "checkmark")
      .font(.system(size: 15, weight: .heavy))
      .foregroundStyle(.white)
      .frame(width: 34, height: 34)
      .background(Circle().fill(Color.green))
      .overlay(Circle().strokeBorder(Brand.night, lineWidth: 3))
  }

  private var guideKeys: [String] {
    guard let shortcut = KeyboardShortcuts.getShortcut(for: .toggleGuide) else { return ["⌃", "⌥", "G"] }
    return ShortcutField.symbols(shortcut.modifiers) + [ShortcutField.keyLabel(shortcut)]
  }

  // Page dots for the tour and a Back button. The last step and the permission-only window have none.
  @ViewBuilder
  private var footer: some View {
    let showsDots = flow.step != .done && !flow.isPermissionOnly
    ZStack {
      if showsDots {
        HStack(spacing: 6) {
          ForEach(0..<OnboardingFlow.Step.done.rawValue, id: \.self) { index in
            Capsule()
              .fill(index == flow.step.rawValue ? Self.accent : .white.opacity(0.22))
              .frame(width: index == flow.step.rawValue ? 18 : 6, height: 6)
          }
        }
      }
      HStack {
        if showsDots && flow.step != .welcome {
          Button("Back") {
            if let previous = OnboardingFlow.Step(rawValue: flow.step.rawValue - 1) { flow.step = previous }
          }
          .buttonStyle(OnboardingButtonStyle(kind: .link))
        }
        Spacer()
      }
    }
    .frame(height: 24)
    .padding(.top, 14)
  }

  private func title(_ key: LocalizedStringResource) -> some View {
    Brand.text(key, size: 26)
      .font(.system(size: 26, weight: .bold))
      .multilineTextAlignment(.center)
  }

  private func text(_ key: LocalizedStringResource) -> some View {
    Brand.text(key, size: 13.5)
      .font(.system(size: 13.5))
      .foregroundStyle(.white.opacity(0.65))
      .multilineTextAlignment(.center)
      .frame(maxWidth: 440)
      .padding(.top, 10)
      .fixedSize(horizontal: false, vertical: true)
  }
}

struct OnboardingButtonStyle: ButtonStyle {
  enum Kind { case primary, secondary, disabled, pill, link }
  let kind: Kind

  func makeBody(configuration: Configuration) -> some View {
    let pressed = configuration.isPressed
    switch kind {
    case .primary, .secondary, .disabled:
      configuration.label
        .font(.system(size: 14, weight: kind == .primary ? .bold : .semibold))
        .foregroundStyle(kind == .primary ? Brand.ink : .white.opacity(kind == .disabled ? 0.3 : 0.9))
        .frame(width: 210, height: 38)
        .background(
          RoundedRectangle(cornerRadius: 11, style: .continuous)
            .fill(kind == .primary
              ? AnyShapeStyle(LinearGradient(colors: [Brand.amber, Brand.amberDeep], startPoint: .top, endPoint: .bottom))
              : AnyShapeStyle(Color.white.opacity(kind == .disabled ? 0.04 : 0.09)))
        )
        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(.white.opacity(kind == .primary ? 0.25 : 0.12), lineWidth: 0.5))
        .shadow(color: kind == .primary ? OnboardingView.accent.opacity(0.35) : .clear, radius: 14)
        .opacity(pressed ? 0.8 : 1)
        .contentShape(Rectangle())
    case .pill:
      configuration.label
        .font(.system(size: 13, weight: .bold))
        .foregroundStyle(Brand.ink)
        .padding(.horizontal, 16)
        .frame(height: 30)
        .background(Capsule().fill(OnboardingView.accent))
        .opacity(pressed ? 0.8 : 1)
    case .link:
      configuration.label
        .font(.system(size: 12.5, weight: .medium))
        .foregroundStyle(.white.opacity(pressed ? 0.85 : 0.55))
        .contentShape(Rectangle())
    }
  }
}

// Keys as small keycaps, for example ⌃ ⌥ G.
struct Keycaps: View {
  let labels: [String]

  var body: some View {
    HStack(spacing: 3) {
      ForEach(Array(labels.enumerated()), id: \.offset) { _, label in
        Text(verbatim: label)
          .font(.system(size: 11.5, weight: .semibold))
          .foregroundStyle(.white)
          .frame(minWidth: 21, minHeight: 21)
          .padding(.horizontal, label.count > 1 ? 4 : 0)
          .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
              .fill(LinearGradient(colors: [Color(white: 0.3), Color(white: 0.23)], startPoint: .top, endPoint: .bottom))
              .shadow(color: .black.opacity(0.6), radius: 0, y: 1)
          )
      }
    }
    .accessibilityElement()
    .accessibilityLabel(Text(verbatim: labels.joined()))
  }
}

// A drawing of the menu bar with the 16to9 icon and its menu.
private struct MenuBarSketch: View {
  var body: some View {
    VStack(alignment: .trailing, spacing: 6) {
      HStack(spacing: 14) {
        Spacer()
        Image(systemName: "wifi")
        Image(nsImage: MenuBarIcon.image)
          .renderingMode(.template)
          .padding(.horizontal, 5)
          .padding(.vertical, 2)
          .background(RoundedRectangle(cornerRadius: 4).fill(OnboardingView.accent.opacity(0.3)))
          .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(OnboardingView.accent, lineWidth: 1.5))
        Text(verbatim: "Mon 9:41")
      }
      .font(.system(size: 11))
      .foregroundStyle(.white.opacity(0.8))
      .padding(.horizontal, 12)
      .frame(height: 26)
      .background(RoundedRectangle(cornerRadius: 7).fill(.white.opacity(0.07)))
      VStack(spacing: 2) {
        menuRow("Full HD", "1920 × 1080", highlighted: false)
        menuRow("16:9", "→ 1200 × 675", highlighted: true)
        menuRow("Open Graph", "1200 × 630", highlighted: false)
      }
      .padding(5)
      .frame(width: 230)
      .background(RoundedRectangle(cornerRadius: 10).fill(Color(white: 0.17)))
      .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.white.opacity(0.12), lineWidth: 0.5))
      .padding(.trailing, 40)
    }
    .frame(width: 440)
    .accessibilityHidden(true)
  }

  private func menuRow(_ name: String, _ size: String, highlighted: Bool) -> some View {
    HStack {
      Text(verbatim: name)
      Spacer()
      Text(verbatim: size).font(.system(size: 11, design: .monospaced)).opacity(0.7)
    }
    .font(.system(size: 12.5))
    .padding(.horizontal, 9)
    .frame(height: 26)
    .background(RoundedRectangle(cornerRadius: 6).fill(highlighted ? Color.accentColor : .clear))
  }
}

// MARK: - Pointer to the menu bar icon

// A bobbing arrow below the menu bar icon, while the tour waits for the first resize.
final class MenuBarPointer {
  private var panel: FloatingPanel?

  func show(below icon: NSRect) {
    hide()
    let size = NSSize(width: 120, height: 64)
    let panel = FloatingPanel(clickThrough: true)
    panel.level = .statusBar
    panel.setRootView(MenuBarPointerView())
    panel.setFrame(NSRect(x: icon.midX - size.width / 2, y: icon.minY - size.height - 2, width: size.width, height: size.height), display: true)
    panel.orderFrontRegardless()
    self.panel = panel
  }

  func hide() {
    panel?.orderOut(nil)
    panel = nil
  }
}

// The arrow moves with a clock, not with a repeating animation, which would also repeat the fade-in of the label.
private struct MenuBarPointerView: View {
  var body: some View {
    VStack(spacing: 4) {
      TimelineView(.animation) { timeline in
        let phase = timeline.date.timeIntervalSinceReferenceDate * .pi / 0.6
        Image(systemName: "arrow.up")
          .font(.system(size: 20, weight: .bold))
          .foregroundStyle(OnboardingView.accent)
          .offset(y: -2.5 - 2.5 * sin(phase))
      }
      Text("Click here")
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(Brand.ink)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Capsule().fill(OnboardingView.accent))
    }
    .shadow(color: .black.opacity(0.4), radius: 6, y: 2)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
  }
}
