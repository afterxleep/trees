import AppKit
import SwiftUI

// MARK: - Popover Menu View

struct RepoMenuView: View {
    @ObservedObject var appState: AppState
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            // Scrollable repo list
            ScrollView {
                LazyVStack(spacing: 0) {
                    contentRows
                }
                .padding(.vertical, 8)
            }
            .frame(maxHeight: 400)

            Divider()
                .padding(.top, 4)

            // Footer buttons
            HStack(spacing: 16) {
                Button(action: {
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    openWindow(id: "settings")
                    dismiss()
                }) {
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
        .frame(width: 320)
        .alert("Error", isPresented: $appState.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(appState.errorMessage ?? "Something went wrong.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image("MenuBarIcon")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 14, height: 14)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Trees")
                        .font(.system(size: 14, weight: .semibold))
                    Text("\(appState.filteredRepositories.count) folders")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: { appState.loadRepositories() }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .help("Refresh")
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search folders", text: $appState.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.textBackgroundColor))
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var contentRows: some View {
        Group {
            if appState.isLoading {
                ProgressView()
                    .controlSize(.small)
                    .padding(.vertical, 20)
            } else if appState.filteredRepositories.isEmpty {
                Text(appState.searchText.isEmpty ? "No folders found" : "No matches")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 18)
            } else {
                ForEach(appState.filteredRepositories) { repo in
                    RepoRowView(repo: repo, appState: appState)
                }
            }
        }
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
            if repo.isGitRepository {
                Image("MenuBarIcon")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 11, height: 11)
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "folder")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Text(repo.name)
                .font(.system(size: 12, weight: .medium))
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

                    Button(action: {
                        appState.copyRepositoryURL(repo)
                        dismiss()
                    }) {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.plain)
                    .help("Copy URL")

                    if repo.isGitRepository {
                        Menu {
                            let repoWorktrees = appState.worktreesForRepo(repo)
                            if !repoWorktrees.isEmpty {
                                ForEach(repoWorktrees) { worktree in
                                    Menu(worktree.name) {
                                        Button("Copy URL") {
                                            appState.copyWorktreeURL(worktree)
                                            dismiss()
                                        }
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
                                NSApplication.shared.activate(ignoringOtherApps: true)
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
        .frame(height: 28)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovering ? Color.primary.opacity(0.08) : Color.clear)
        )
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
                .font(.system(size: 16, weight: .semibold))

            if let repo = appState.selectedRepository {
                Text(repo.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Branch name")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                TextField("feature/my-branch", text: $appState.featureName)
                    .textFieldStyle(.roundedBorder)
                    .focused($isTextFieldFocused)
            }

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
                            let success = await appState.createWorktree(
                                for: repo,
                                featureName: appState.featureName
                            )
                            if success {
                                dismiss()
                            }
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(appState.featureName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .padding(20)
        .frame(width: 320)
        .onAppear {
            isTextFieldFocused = true
        }
        .alert("Error", isPresented: $appState.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(appState.errorMessage ?? "Something went wrong.")
        }
    }
}
