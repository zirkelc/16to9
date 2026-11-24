import ResizerCore
import ServiceManagement
import SwiftUI

struct GeneralPane: View {
  let model: AppModel
  /**
   The login item state. Reading it from macOS can take more than 100 ms, so the pane starts with the
   last known value and reads the state in the background. The user can also change it in System Settings.
   */
  @MainActor private static var lastLaunchAtLogin = false
  @State private var launchAtLogin = GeneralPane.lastLaunchAtLogin
  // True while the pane shows the state that it read, so that the change does not register the app again.
  @State private var isReadingLaunchAtLogin = false
  @State private var launchError: String?

  var body: some View {
    @Bindable var settings = model.settings
    VStack(spacing: 0) {
      if !model.permission.isGranted {
        PermissionCallout { model.openOnboarding() }
          .padding(.horizontal, SettingsView.contentInset)
          .transition(.opacity)
      }
      Form {
        Section("App") {
          Toggle("Launch at login", isOn: $launchAtLogin)
            .onChange(of: launchAtLogin) {
              if isReadingLaunchAtLogin {
                isReadingLaunchAtLogin = false
              } else {
                setLaunchAtLogin(launchAtLogin)
              }
            }
          if let launchError {
            Text(launchError).font(.caption).foregroundStyle(.red)
          }
          Picker("Menu layout", selection: $settings.popoverLayout) {
            ForEach(PopoverLayout.allCases) { Text($0.title).tag($0) }
          }
          .pickerStyle(.segmented)
          Toggle(isOn: $settings.showsSizePreview) {
            Text("Show a preview of the new size")
            Text("While you point at a size in the menu, a frame on the screen shows the new size of the window.")
          }
          Toggle(isOn: $settings.showToasts) {
            Text("Show a message after each resize")
            Text("A short message with the new size and an Undo button.")
          }
        }

        Section {
          Picker("Units", selection: $settings.units) {
            Text("Screenshot pixels").tag(SizeUnit.pixels)
            Text("Screen points").tag(SizeUnit.points)
          }
          Picker(selection: $settings.fitMode) {
            Text("Smallest change").tag(FitMode.smallestChange)
            Text("Keep width").tag(FitMode.keepWidth)
            Text("Keep height").tag(FitMode.keepHeight)
          } label: {
            Text("Ratio fit")
            Text("How a ratio such as 16:9 changes the window.")
          }
          Picker("After resize", selection: $settings.anchor) {
            Text("Keep top-left corner").tag(ResizeAnchor.topLeft)
            Text("Keep center").tag(ResizeAnchor.center)
          }
        } header: {
          Text("Sizes")
        } footer: {
          Text(unitsHelp).font(.caption).foregroundStyle(.secondary)
        }
      }
    }
    .animation(.easeOut(duration: 0.2), value: model.permission.isGranted)
    .formStyle(.grouped)
    .scrollContentBackground(.hidden)
    .task {
      let enabled = await Task.detached { SMAppService.mainApp.status == .enabled }.value
      Self.lastLaunchAtLogin = enabled
      if launchAtLogin != enabled {
        isReadingLaunchAtLogin = true
        launchAtLogin = enabled
      }
    }
    .task {
      // Checks the permission each second while the pane shows, because the user can change it at any time.
      while !Task.isCancelled {
        model.permission.refresh()
        try? await Task.sleep(for: .seconds(1))
      }
    }
  }

  private var unitsHelp: String {
    let scale = Int(ScreenInfo.main?.scale ?? 2)
    return String(
      localized: """
        Pixels are the size of a window screenshot. Points are the size macOS uses for windows. \
        On this screen, 1 pt = \(scale) px. A window screenshot (⇧⌘4, then Space) has the size of the window. \
        Hold ⌥ when you click to leave out the shadow.
        """)
  }

  private func setLaunchAtLogin(_ enabled: Bool) {
    do {
      if enabled {
        try SMAppService.mainApp.register()
      } else {
        try SMAppService.mainApp.unregister()
      }
      launchError = nil
      Self.lastLaunchAtLogin = enabled
    } catch {
      launchError = error.localizedDescription
      let enabled = SMAppService.mainApp.status == .enabled
      Self.lastLaunchAtLogin = enabled
      if launchAtLogin != enabled {
        isReadingLaunchAtLogin = true
        launchAtLogin = enabled
      }
    }
  }
}

// A warning above the settings while the app cannot control windows.
struct PermissionCallout: View {
  let setUp: () -> Void

  var body: some View {
    HStack(alignment: .center, spacing: 12) {
      Image(systemName: "exclamationmark.triangle.fill")
        .font(.system(size: 17))
        .foregroundStyle(.orange)
      VStack(alignment: .leading, spacing: 2) {
        Brand.text("16to9 cannot resize windows yet", size: 13).font(.system(size: 13, weight: .semibold))
        Text("Allow window control in System Settings. The guide works without it.")
          .font(.system(size: 12))
          .foregroundStyle(.secondary)
      }
      Spacer(minLength: 8)
      Button("Set Up…", action: setUp)
        .buttonStyle(.borderedProminent)
        .tint(.orange)
    }
    .padding(12)
    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.orange.opacity(0.12)))
    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.orange.opacity(0.35), lineWidth: 0.5))
  }
}
