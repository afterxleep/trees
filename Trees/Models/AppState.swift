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

    let settings: SettingsServiceProtocol
    let fileService: FileServiceProtocol
    let gitService: GitServiceProtocol
    let terminalService: TerminalServiceProtocol

    init(
        settings: SettingsServiceProtocol = SettingsService(),
        fileService: FileServiceProtocol = FileService(),
        gitService: GitServiceProtocol = GitService(),
        terminalService: TerminalServiceProtocol = TerminalService()
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
        Task {
            await loadRepositoriesAsync()
        }
    }

    func loadRepositoriesAsync() async {
        isLoading = true
        let developerPath = settings.developerPathURL
        let fileService = fileService
        let gitService = gitService

        let repositories = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: fileService.scanRepositories(in: developerPath))
            }
        }

        self.repositories = repositories

        var updatedWorktrees: [UUID: [Worktree]] = [:]
        for repo in repositories where repo.isGitRepository {
            if let repoWorktrees = try? await gitService.listWorktrees(at: repo.path) {
                let nonMainWorktrees = repoWorktrees.filter { !$0.isMain }
                if !nonMainWorktrees.isEmpty {
                    updatedWorktrees[repo.id] = nonMainWorktrees
                }
            }
        }
        worktrees = updatedWorktrees
        isLoading = false
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
