import SwiftUI

// MARK: - Native Menu View

struct RepoMenuView: View {
    @ObservedObject var appState: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if appState.repositories.isEmpty {
            Text("No repositories found")
                .foregroundStyle(.secondary)
        } else {
            ForEach(appState.repositories) { repo in
                Menu(repo.name) {
                    Button("Open in Finder") {
                        appState.openInFinder(repo)
                    }
                    Button("Open in Terminal") {
                        appState.openInTerminal(repo)
                    }
                    Divider()
                    Button("Create Worktree...") {
                        appState.selectedRepository = repo
                        openWindow(id: "worktree")
                    }
                }
            }
        }

        Divider()

        Button("Refresh") {
            appState.loadRepositories()
        }

        Button("Settings...") {
            openWindow(id: "settings")
        }
        .keyboardShortcut(",", modifiers: .command)

        Divider()

        Button("Quit Trees") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}

// MARK: - Worktree Window

struct WorktreeWindowView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Worktree")
                .font(.headline)

            if let repo = appState.selectedRepository {
                Text("Repository: \(repo.name)")
                    .foregroundStyle(.secondary)
            }

            TextField("Feature name", text: $appState.featureName)
                .textFieldStyle(.roundedBorder)
                .focused($isTextFieldFocused)

            HStack {
                Button("Cancel") {
                    appState.featureName = ""
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                if appState.isCreatingWorktree {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button("Create") {
                        guard let repo = appState.selectedRepository else { return }
                        Task {
                            await appState.createWorktree(for: repo, featureName: appState.featureName)
                            dismiss()
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(appState.featureName.isEmpty)
                }
            }
        }
        .padding(20)
        .frame(width: 300)
        .onAppear {
            isTextFieldFocused = true
        }
    }
}
