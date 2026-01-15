import Foundation
import SwiftUI

/// Main application state container
@MainActor
final class AppState: ObservableObject {
    @Published var repositories: [Repository] = []
    @Published var worktrees: [UUID: [Worktree]] = [:]
    @Published var searchText: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    @Published var selectedRepository: Repository?
    @Published var showWorktreeSheet: Bool = false
    @Published var featureName: String = ""
    @Published var isCreatingWorktree: Bool = false

    let settings: SettingsService
    let fileService: FileService
    let gitService: GitService
    let terminalService: TerminalService

    init(
        settings: SettingsService = SettingsService(),
        fileService: FileService = FileService(),
        gitService: GitService = GitService(),
        terminalService: TerminalService = TerminalService()
    ) {
        self.settings = settings
        self.fileService = fileService
        self.gitService = gitService
        self.terminalService = terminalService
    }

    var filteredRepositories: [Repository] {
        if searchText.isEmpty {
            return repositories
        }
        return repositories.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    func loadRepositories() {
        isLoading = true
        repositories = fileService.scanRepositories(in: settings.developerPathURL)

        // Load worktrees for git repositories only
        Task {
            for repo in repositories where repo.isGitRepository {
                if let repoWorktrees = try? await gitService.listWorktrees(at: repo.path) {
                    // Filter out the main worktree
                    let nonMainWorktrees = repoWorktrees.filter { !$0.isMain }
                    if !nonMainWorktrees.isEmpty {
                        worktrees[repo.id] = nonMainWorktrees
                    } else {
                        worktrees.removeValue(forKey: repo.id)
                    }
                }
            }
            isLoading = false
        }
    }

    func worktreesForRepo(_ repo: Repository) -> [Worktree] {
        worktrees[repo.id] ?? []
    }

    func openWorktreeInFinder(_ worktree: Worktree) {
        fileService.openInFinder(worktree.path)
    }

    func openWorktreeInTerminal(_ worktree: Worktree) {
        do {
            try terminalService.openTerminal(
                at: worktree.path,
                command: "",
                using: settings.terminalApp
            )
        } catch {
            handleError(error)
        }
    }

    func openInFinder(_ repository: Repository) {
        fileService.openInFinder(repository.path)
    }

    func openInTerminal(_ repository: Repository) {
        do {
            try terminalService.openTerminal(
                at: repository.path,
                command: "",
                using: settings.terminalApp
            )
        } catch {
            handleError(error)
        }
    }

    func createWorktree(for repository: Repository, featureName: String) async -> Bool {
        isCreatingWorktree = true
        defer { isCreatingWorktree = false }
        errorMessage = nil

        let trimmedFeature = featureName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedFeature.isEmpty else {
            handleError(GitError.worktreeCreationFailed("Feature name cannot be empty."))
            return false
        }

        do {
            // Pull latest from main
            try await gitService.pullMain(at: repository.path)

            // Create the worktree
            let worktreePath = try await gitService.createWorktree(
                at: repository.path,
                featureName: trimmedFeature
            )

            // Open terminal at worktree and run command
            try terminalService.openTerminal(
                at: worktreePath,
                command: "",
                using: settings.terminalApp
            )

            // Refresh repositories list
            loadRepositories()

        } catch {
            handleError(error)
            return false
        }
        self.featureName = ""
        return true
    }

    private func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
    }
}
