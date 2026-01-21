import AppKit
import SwiftUI

// MARK: - Popover Menu View

struct RepoMenuView: View {
    @ObservedObject var appState: AppState
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    private let headerTitleSize: CGFloat = 15
    private let headerSubtitleSize: CGFloat = 11
    private let searchFontSize: CGFloat = 13
    private let headerIconSize: CGFloat = 28
    @State private var deleteTarget: WorktreeDeleteTarget?

    var body: some View {
        ZStack {
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
                .frame(maxHeight: 460)

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

            if let deleteTarget = deleteTarget {
                DeleteWorktreeModal(
                    worktree: deleteTarget.worktree,
                    repository: deleteTarget.repository,
                    appState: appState
                ) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        self.deleteTarget = nil
                    }
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image("MenuBarIcon")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: headerIconSize, height: headerIconSize)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Trees")
                        .font(.system(size: headerTitleSize, weight: .semibold))
                    Text("\(appState.filteredRepositories.count) folders")
                        .font(.system(size: headerSubtitleSize))
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
                    .font(.system(size: searchFontSize))
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
                    RepoRowView(
                        repo: repo,
                        appState: appState,
                        onDeleteRequest: { worktree, repository in
                            withAnimation(.easeInOut(duration: 0.15)) {
                                deleteTarget = WorktreeDeleteTarget(
                                    worktree: worktree,
                                    repository: repository
                                )
                            }
                        }
                    )
                }
            }
        }
    }
}

// MARK: - Repo Row

struct RepoRowView: View {
    let repo: Repository
    @ObservedObject var appState: AppState
    let onDeleteRequest: (Worktree, Repository) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var isHovering = false
    @State private var isExpanded = false
    @State private var showDetails = false
    @State private var expandTask: DispatchWorkItem?
    @State private var newWorktreeName = ""
    @State private var showCreateField = false
    @FocusState private var isCreateFieldFocused: Bool
    private let actionIconSize: CGFloat = 14
    private let repoIconSize: CGFloat = 12
    private let repoNameSize: CGFloat = 13

    private var actionIconFont: Font {
        .system(size: actionIconSize, weight: .regular)
    }

    private func actionSymbol(_ name: String) -> some View {
        Image(systemName: name)
            .font(actionIconFont)
            .frame(height: actionIconSize)
    }

    private func submitCreateWorktree() {
        let featureName = newWorktreeName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !featureName.isEmpty else { return }
        Task {
            let success = await appState.createWorktree(
                for: repo,
                featureName: featureName
            )
            if success {
                newWorktreeName = ""
                showCreateField = false
            }
        }
    }

    var body: some View {
        let repoWorktrees = appState.worktreesForRepo(repo)
        let canExpand = repo.isGitRepository
        let toggleExpand = {
            guard canExpand else { return }

            if isExpanded {
                expandTask?.cancel()
                showDetails = false
                showCreateField = false
                newWorktreeName = ""
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded = false
                }
            } else {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded = true
                }

                expandTask?.cancel()
                let task = DispatchWorkItem {
                    guard isExpanded else { return }
                    withAnimation(.easeInOut(duration: 0.15)) {
                        showDetails = true
                    }
                }
                expandTask = task
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: task)
            }
        }

        VStack(spacing: 0) {
            HStack(spacing: 8) {
                if repo.isGitRepository {
                    Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                        .font(.system(size: repoIconSize))
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: "folder")
                        .font(.system(size: repoIconSize))
                        .foregroundStyle(.secondary)
                }

                Text(repo.name)
                    .font(.system(size: repoNameSize, weight: .medium))
                    .lineLimit(1)

                Spacer()

                if isHovering {
                    HStack(spacing: 8) {
                        Button(action: {
                            appState.openInFinder(repo)
                            dismiss()
                        }) {
                            actionSymbol("folder")
                        }
                        .buttonStyle(.plain)
                        .help("Open in Finder")

                        Button(action: {
                            appState.openInTerminal(repo)
                            dismiss()
                        }) {
                            actionSymbol("terminal")
                        }
                        .buttonStyle(.plain)
                        .help("Open in Terminal")
                    }
                }

                if canExpand && isHovering {
                    Button(action: {
                        toggleExpand()
                    }) {
                        actionSymbol("chevron.down")
                    }
                    .buttonStyle(.plain)
                    .help("Worktrees")
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
            .onTapGesture {
                toggleExpand()
            }
            .onHover { hovering in
                isHovering = hovering
            }

            if canExpand, isExpanded {
                VStack(spacing: 0) {
                    if showCreateField {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                                .font(.system(size: repoNameSize))
                                .foregroundStyle(.secondary)

                            TextField("feature/my-branch", text: $newWorktreeName)
                                .textFieldStyle(.plain)
                                .font(.system(size: repoNameSize, weight: .medium))
                                .foregroundStyle(.secondary)
                                .disableAutocorrection(true)
                                .lineLimit(1)
                                .focused($isCreateFieldFocused)
                                .onSubmit {
                                    submitCreateWorktree()
                                }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(NSColor.textBackgroundColor))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                                )

                            if appState.isCreatingWorktree {
                                ProgressView()
                                    .controlSize(.mini)
                            } else {
                                Button("Create") {
                                    submitCreateWorktree()
                                }
                                .buttonStyle(.plain)
                                .font(.system(size: repoNameSize, weight: .medium))
                                .keyboardShortcut(.defaultAction)
                                .disabled(newWorktreeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        }
                        .padding(.horizontal, 24)
                        .frame(height: 26)
                        .opacity(showDetails ? 1 : 0)
                    } else {
                        Button(action: {
                            showCreateField = true
                            DispatchQueue.main.async {
                                isCreateFieldFocused = true
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "plus")
                                    .font(.system(size: repoNameSize))
                                    .foregroundStyle(.secondary)

                                Text("Create Worktree...")
                                    .font(.system(size: repoNameSize, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 24)
                        .frame(height: 24)
                        .opacity(showDetails ? 1 : 0)
                    }

                    Divider()
                        .padding(.horizontal, 20)
                        .padding(.vertical, 4)
                        .opacity(showDetails ? 1 : 0)

                    ForEach(repoWorktrees) { worktree in
                        WorktreeRowView(
                            worktree: worktree,
                            repository: repo,
                            appState: appState,
                            textSize: repoNameSize,
                            onDeleteRequest: onDeleteRequest
                        )
                            .opacity(showDetails ? 1 : 0)
                    }
                }
                .padding(.bottom, 6)
                .transition(.move(edge: .top))
            }
        }
    }
}

struct WorktreeRowView: View {
    let worktree: Worktree
    let repository: Repository
    @ObservedObject var appState: AppState
    let textSize: CGFloat
    let onDeleteRequest: (Worktree, Repository) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var isHovering = false
    private let actionIconSize: CGFloat = 14

    private func actionSymbol(_ name: String) -> some View {
        Image(systemName: name)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(height: actionIconSize)
    }

    var body: some View {
        ZStack {
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: textSize))
                    .foregroundStyle(.secondary)

                Text(worktree.name)
                    .font(.system(size: textSize, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                if isHovering {
                    HStack(spacing: 10) {
                        Button(action: {
                            appState.openWorktreeInFinder(worktree)
                            dismiss()
                        }) {
                            actionSymbol("folder")
                        }
                        .buttonStyle(.plain)
                        .help("Open in Finder")

                        Button(action: {
                            appState.copyWorktreeURL(worktree)
                            dismiss()
                        }) {
                            actionSymbol("doc.on.doc")
                        }
                        .buttonStyle(.plain)
                        .help("Copy Path")

                        Button(action: {
                            appState.openWorktreeInTerminal(worktree)
                            dismiss()
                        }) {
                            actionSymbol("terminal")
                        }
                        .buttonStyle(.plain)
                        .help("Open in Terminal")

                        Button(action: {
                            onDeleteRequest(worktree, repository)
                        }) {
                            actionSymbol("xmark.circle")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                        .help("Delete Worktree")
                    }
                }
            }
            .padding(.leading, 24)
            .padding(.trailing, 12)
            .frame(height: 24)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovering ? Color.primary.opacity(0.06) : Color.clear)
            )
            .padding(.leading, 5)
            .padding(.trailing, 2)
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

private struct WorktreeDeleteTarget {
    let worktree: Worktree
    let repository: Repository
}

private struct DeleteWorktreeModal: View {
    let worktree: Worktree
    let repository: Repository
    @ObservedObject var appState: AppState
    let onDismiss: () -> Void
    private let popoverWidth: CGFloat = 320
    private let buttonFontSize: CGFloat = 14

    private func handleDelete(deleteBranch: Bool) {
        onDismiss()
        Task {
            _ = await appState.deleteWorktree(
                worktree,
                from: repository,
                deleteBranch: deleteBranch
            )
        }
    }

    var body: some View {
        let includesBranchDelete = worktree.branch != "detached"
        let labels = includesBranchDelete
            ? ["Remove Worktree", "Remove + Delete Branch", "Cancel"]
            : ["Remove Worktree", "Cancel"]
        let buttonFont = NSFont.systemFont(ofSize: buttonFontSize, weight: .semibold)
        let maxLabelWidth = labels.map {
            ($0 as NSString).size(withAttributes: [.font: buttonFont]).width
        }.max() ?? 0
        let maxButtonWidth = popoverWidth - 40
        let textWidth = min(maxLabelWidth, max(maxButtonWidth, 0))

        return ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            VStack(alignment: .trailing, spacing: 6) {
                Button {
                    handleDelete(deleteBranch: false)
                } label: {
                    Text("Remove Worktree")
                        .font(.system(size: buttonFontSize, weight: .semibold))
                        .foregroundStyle(Color.red)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .frame(width: textWidth)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.red.opacity(0.14))
                        )
                }
                .buttonStyle(.plain)

                if includesBranchDelete {
                    Button {
                        handleDelete(deleteBranch: true)
                    } label: {
                        Text("Remove + Delete Branch")
                            .font(.system(size: buttonFontSize, weight: .semibold))
                            .foregroundStyle(Color.red)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                            .frame(width: textWidth)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.red.opacity(0.14))
                            )
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    onDismiss()
                } label: {
                    Text("Cancel")
                        .font(.system(size: buttonFontSize, weight: .semibold))
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .frame(width: textWidth)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.2))
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(NSColor.windowBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
