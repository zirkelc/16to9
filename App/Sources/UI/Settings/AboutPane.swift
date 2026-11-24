import SwiftUI

enum AppLinks {
  static let website = URL(string: "https://github.com/zirkelc/16to9")!
  static let privacy = URL(string: "https://github.com/zirkelc/16to9/blob/main/PRIVACY.md")!
  static let support = URL(string: "https://github.com/zirkelc/16to9/issues")!
}

struct AboutPane: View {
  let model: AppModel
  @State private var showsAcknowledgments = false

  private var updater: Updater { model.updater }

  private var version: String {
    let info = Bundle.main.infoDictionary
    let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
    let build = info?["CFBundleVersion"] as? String ?? "1"
    return String(localized: "Version \(short) (\(build))")
  }

  var body: some View {
    VStack(spacing: 0) {
      header
      Form {
        Section {
          LabeledContent("Updates") {
            if updater.isConfigured {
              Button("Check for Updates…") { updater.checkForUpdates() }
                .disabled(!updater.canCheck)
            } else {
              Text("Not available in this build").foregroundStyle(.secondary)
            }
          }
          if updater.isConfigured {
            Toggle("Check for updates automatically", isOn: Bindable(updater).checksAutomatically)
          }
        }

        Section("Links") {
          link("Website", symbol: "globe", url: AppLinks.website)
          link("Privacy Policy", symbol: "hand.raised", url: AppLinks.privacy)
          link("Support", symbol: "questionmark.bubble", url: AppLinks.support)
        }

        Section {
          LabeledContent {
            Button("Show") { model.openTour() }
          } label: {
            Text("Welcome tour")
            Text("The short introduction from the first launch.")
          }
        } footer: {
          HStack {
            Spacer()
            Button("Acknowledgments") { showsAcknowledgments = true }
              .buttonStyle(.link)
              .font(.caption)
          }
        }
      }
      .formStyle(.grouped)
      .scrollContentBackground(.hidden)
    }
    .sheet(isPresented: $showsAcknowledgments) { AcknowledgmentsView() }
  }

  private var header: some View {
    VStack(spacing: 4) {
      Image(nsImage: NSApp.applicationIconImage)
        .resizable()
        .frame(width: 84, height: 84)
      Brand.nameText(size: 22)
        .padding(.top, 4)
      Text(version)
        .font(.system(size: 11.5))
        .foregroundStyle(.secondary)
      Text(verbatim: "© 2026 Chris Cook")
        .font(.system(size: 10.5))
        .foregroundStyle(.tertiary)
        .padding(.top, 2)
    }
    .frame(maxWidth: .infinity)
    .padding(.bottom, 4)
  }

  private func link(_ title: LocalizedStringKey, symbol: String, url: URL) -> some View {
    Link(destination: url) {
      HStack(spacing: 10) {
        Image(systemName: symbol)
          .frame(width: 18)
          .foregroundStyle(.secondary)
        Text(title).foregroundStyle(.primary)
        Spacer()
        Image(systemName: "arrow.up.right")
          .font(.system(size: 10, weight: .semibold))
          .foregroundStyle(.tertiary)
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}

// The open source parts and ideas that the app uses, with their licences.
private struct AcknowledgmentsView: View {
  @Environment(\.dismiss) private var dismiss

  private struct Item: Identifiable {
    let id = UUID()
    let name: String
    let detail: LocalizedStringKey
    let url: URL
  }

  private let items = [
    Item(
      name: "KeyboardShortcuts", detail: "Global shortcuts. MIT licence, © Sindre Sorhus.",
      url: URL(string: "https://github.com/sindresorhus/KeyboardShortcuts")!),
    Item(
      name: "Sparkle", detail: "Updates. MIT licence, © the Sparkle Project contributors.",
      url: URL(string: "https://github.com/sparkle-project/Sparkle")!),
    Item(
      name: "JetBrains Mono", detail: "The font of the app name. SIL Open Font License 1.1, © the JetBrains Mono Project Authors.",
      url: URL(string: "https://github.com/JetBrains/JetBrainsMono")!),
    Item(
      name: "Scrawl", detail: "The idea for the permission card and the welcome tour. MIT licence, © Kit Langton.",
      url: URL(string: "https://github.com/kitlangton/scrawl")!),
  ]

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("Acknowledgments").font(.headline)
      ForEach(items) { item in
        VStack(alignment: .leading, spacing: 2) {
          Link(item.name, destination: item.url).font(.system(size: 13, weight: .semibold))
          Text(item.detail).font(.system(size: 12)).foregroundStyle(.secondary)
        }
      }
      HStack {
        Spacer()
        Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
      }
    }
    .padding(20)
    .frame(width: 380)
  }
}
