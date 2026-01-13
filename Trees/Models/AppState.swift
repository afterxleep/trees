import Foundation
import SwiftUI

/// Main application state container
@MainActor
final class AppState: ObservableObject {
    @Published var repositories: [Repository] = []
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
        isLoading = false
    }

    func openInFinder(_ repository: Repository) {
        fileService.openInFinder(repository.path)
    }

    func openInTerminal(_ repository: Repository) {
        try? terminalService.openTerminal(
            at: repository.path,
            command: "",
            using: settings.terminalApp
        )
    }

    func createWorktree(for repository: Repository, featureName: String) async {
        isCreatingWorktree = true
        errorMessage = nil

        do {
            // Pull latest from main
            try await gitService.pullMain(at: repository.path)

            // Create the worktree
            let worktreePath = try await gitService.createWorktree(
                at: repository.path,
                featureName: featureName
            )

            // Open terminal at worktree and run command
            try terminalService.openTerminal(
                at: worktreePath,
                command: settings.commandToRun,
                using: settings.terminalApp
            )

            // Refresh repositories list
            loadRepositories()

        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isCreatingWorktree = false
        showWorktreeSheet = false
        self.featureName = ""
    }
}
