import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.system(size: 13, weight: .semibold))

            // Developer Path
            VStack(alignment: .leading, spacing: 4) {
                Text("Developer Folder")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    TextField("Path", text: $settings.developerPath)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))

                    Button("Browse") {
                        selectFolder()
                    }
                    .controlSize(.small)
                }
            }

            // Command to Run
            VStack(alignment: .leading, spacing: 4) {
                Text("Command")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                TextField("e.g. cld", text: $settings.commandToRun)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
            }

            // Terminal App
            VStack(alignment: .leading, spacing: 4) {
                Text("Terminal")
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
        }
        .padding(16)
        .frame(width: 280)
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
