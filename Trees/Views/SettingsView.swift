import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsService

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Settings")
                .font(.system(size: 16, weight: .semibold))

            GroupBox("General") {
                Toggle("Launch at login", isOn: $settings.launchAtLogin)
                    .toggleStyle(.switch)
                    .font(.system(size: 12))
                    .padding(.vertical, 4)
            }

            GroupBox("Workspace") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Developer Folder")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        TextField("Path", text: $settings.developerPath)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12))

                        Button("Browse") {
                            selectFolder()
                        }
                        .controlSize(.small)
                    }
                }
                .padding(.vertical, 4)
            }

            GroupBox("Terminal") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Preferred terminal")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    Picker("", selection: $settings.terminalApp) {
                        ForEach(TerminalApp.allCases) { app in
                            Text(app.rawValue).tag(app)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 4)
            }
        }
        .padding(20)
        .frame(width: 340)
    }

    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select your developer folder"
        panel.prompt = "Select"

        if panel.runModal() == .OK, let url = panel.url {
            settings.developerPath = url.path
        }
    }
}
