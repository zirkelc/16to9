import AppKit
import SwiftUI

struct Toast: Equatable {
  enum Kind {
    case success
    case warning
    case failure
  }

  var kind: Kind
  var title: String
  var detail: String?
  var canUndo = false
}

/**
 Shows a short message near the top of a screen after an action. The message closes itself.
 */
final class ToastController {
  private let panel = FloatingPanel(clickThrough: false)
  private var hideTask: Task<Void, Never>?
  // Counts the shown toasts, so that the fade-out of an old toast does not remove a new toast.
  private var generation = 0
  var onUndo: () -> Void = {}

  func show(_ toast: Toast, on screen: ScreenInfo?) {
    generation += 1
    let host = FirstMouseHostingView(
      rootView: ToastView(toast: toast) { [weak self] in
        self?.hide()
        self?.onUndo()
      })
    let size = host.fittingSize
    panel.contentView = host
    panel.level = .statusBar

    let visible = (screen?.screen ?? NSScreen.main)?.visibleFrame ?? .zero
    let origin = CGPoint(x: visible.midX - size.width / 2, y: visible.maxY - size.height - 24)
    panel.setFrame(CGRect(origin: origin, size: size), display: true)
    panel.alphaValue = 0
    panel.orderFrontRegardless()
    NSAnimationContext.runAnimationGroup { context in
      context.duration = 0.18
      panel.animator().alphaValue = 1
    }

    hideTask?.cancel()
    hideTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(toast.canUndo ? 4 : 2.5))
      guard !Task.isCancelled else { return }
      self?.hide()
    }
  }

  func hide() {
    hideTask?.cancel()
    let panel = panel
    let shown = generation
    NSAnimationContext.runAnimationGroup { context in
      context.duration = 0.2
      panel.animator().alphaValue = 0
    } completionHandler: { [weak self] in
      MainActor.assumeIsolated {
        guard self?.generation == shown else { return }
        panel.orderOut(nil)
      }
    }
  }
}

struct ToastView: View {
  let toast: Toast
  let undo: () -> Void

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: symbol)
        .font(.system(size: 18, weight: .semibold))
        .foregroundStyle(color)
      VStack(alignment: .leading, spacing: 1) {
        Text(toast.title).font(.system(size: 12.5, weight: .medium))
        if let detail = toast.detail {
          Text(detail).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
        }
      }
      if toast.canUndo {
        Spacer(minLength: 12)
        Button("Undo", action: undo)
          .buttonStyle(.plain)
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(Color.accentColor)
      }
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .frame(minWidth: 220)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.white.opacity(0.12), lineWidth: 0.5))
    .padding(16)
    .fixedSize()
  }

  private var symbol: String {
    switch toast.kind {
    case .success: "checkmark.circle.fill"
    case .warning: "exclamationmark.circle.fill"
    case .failure: "xmark.circle.fill"
    }
  }

  private var color: Color {
    switch toast.kind {
    case .success: .green
    case .warning: .orange
    case .failure: .secondary
    }
  }
}
