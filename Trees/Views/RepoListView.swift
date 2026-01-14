import SwiftUI

// MARK: - Popover Menu View

struct RepoMenuView: View {
    @ObservedObject var appState: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            // Scrollable repo list
            ScrollView {
                LazyVStack(spacing: 0) {
                    if appState.repositories.isEmpty {
                        Text("No folders found")
                            .foregroundStyle(.secondary)
                            .padding()
                    } else {
                        ForEach(appState.repositories) { repo in
                            RepoRowView(repo: repo, appState: appState)
                        }
                    }
                }
                .padding(.vertical, 6)
            }
            .frame(maxHeight: 400)

            Divider()
                .padding(.top, 4)

            // Footer buttons
            HStack(spacing: 16) {
                Button(action: { appState.loadRepositories() }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .help("Refresh")

                Button(action: { openWindow(id: "settings") }) {
                    Image(systemName: "gear")
                }
                .buttonStyle(.plain)
                .help("Settings")

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(width: 280)
    }
}

// MARK: - Repo Row

struct RepoRowView: View {
    let repo: Repository
    @ObservedObject var appState: AppState
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            Text(repo.name)
                .lineLimit(1)

            Spacer()

            if isHovering {
                HStack(spacing: 8) {
                    Button(action: {
                        appState.openInFinder(repo)
                        dismiss()
                    }) {
                        Image(systemName: "folder")
                    }
                    .buttonStyle(.plain)
                    .help("Open in Finder")

                    Button(action: {
                        appState.openInTerminal(repo)
                        dismiss()
                    }) {
                        Image(systemName: "terminal")
                    }
                    .buttonStyle(.plain)
                    .help("Open in Terminal")

                    if repo.isGitRepository {
                        Menu {
                            let repoWorktrees = appState.worktreesForRepo(repo)
                            if !repoWorktrees.isEmpty {
                                ForEach(repoWorktrees) { worktree in
                                    Menu(worktree.name) {
                                        Button("Open in Finder") {
                                            appState.openWorktreeInFinder(worktree)
                                            dismiss()
                                        }
                                        Button("Open in Terminal") {
                                            appState.openWorktreeInTerminal(worktree)
                                            dismiss()
                                        }
                                    }
                                }
                                Divider()
                            }
                            Button("Create Worktree...") {
                                appState.selectedRepository = repo
                                openWindow(id: "worktree")
                                dismiss()
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .menuStyle(.borderlessButton)
                        .frame(width: 20)
                        .help("Git options")
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 26)
        .background(isHovering ? Color.primary.opacity(0.1) : Color.clear)
        .cornerRadius(4)
        .padding(.horizontal, 5)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
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
