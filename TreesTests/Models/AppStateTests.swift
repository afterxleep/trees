import XCTest
@testable import Trees

@MainActor
final class AppStateTests: XCTestCase {

    func testLoadRepositoriesAsync_populatesRepositoriesAndWorktrees() async {
        let repoId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let repoPath = URL(fileURLWithPath: "/Users/test/Developer/sample")
        let repo = Repository(id: repoId, name: "sample", path: repoPath, isGitRepository: true)
        let nonRepo = Repository(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            name: "notes",
            path: URL(fileURLWithPath: "/Users/test/Developer/notes"),
            isGitRepository: false
        )

        let fileService = MockFileService()
        fileService.repositoriesToReturn = [repo, nonRepo]

        let gitService = MockGitService()
        let worktreePath = repoPath.deletingLastPathComponent()
            .appendingPathComponent("sample.worktrees/feature")
        gitService.worktreesToReturn = [
            Worktree(path: repoPath, branch: "main", isMain: true),
            Worktree(path: worktreePath, branch: "feature", isMain: false)
        ]

        let settings = MockSettingsService()
        let appState = AppState(
            settings: settings,
            fileService: fileService,
            gitService: gitService,
            terminalService: MockTerminalService()
        )

        await appState.loadRepositoriesAsync()

        XCTAssertEqual(appState.repositories, [repo, nonRepo])
        XCTAssertEqual(fileService.scanRepositoriesCalledWith, settings.developerPathURL)
        XCTAssertEqual(gitService.listWorktreesCalledWith, repoPath)
        XCTAssertEqual(appState.worktrees[repoId]?.first?.path, worktreePath)
    }

    func testCreateWorktree_successOpensTerminal() async {
        let repoPath = URL(fileURLWithPath: "/Users/test/Developer/sample")
        let repo = Repository(name: "sample", path: repoPath, isGitRepository: true)
        let settings = MockSettingsService(terminalApp: .iterm)
        let fileService = MockFileService()
        let gitService = MockGitService()
        let terminalService = MockTerminalService()

        let worktreePath = repoPath.deletingLastPathComponent()
            .appendingPathComponent("sample.worktrees/feature-login")
        gitService.createdWorktreePath = worktreePath

        let appState = AppState(
            settings: settings,
            fileService: fileService,
            gitService: gitService,
            terminalService: terminalService
        )

        let success = await appState.createWorktree(for: repo, featureName: "feature-login")

        XCTAssertTrue(success)
        XCTAssertEqual(gitService.pullMainCalledWith, repoPath)
        XCTAssertEqual(gitService.createWorktreeCalledWith?.featureName, "feature-login")
        XCTAssertEqual(terminalService.openTerminalCalledWith?.directory, worktreePath)
        XCTAssertEqual(terminalService.openTerminalCalledWith?.command, "")
        XCTAssertEqual(terminalService.openTerminalCalledWith?.terminalApp, .iterm)
    }

    func testCreateWorktree_emptyFeatureShowsError() async {
        let repo = Repository(name: "sample", path: URL(fileURLWithPath: "/Users/test/Developer/sample"))
        let appState = AppState(
            settings: MockSettingsService(),
            fileService: MockFileService(),
            gitService: MockGitService(),
            terminalService: MockTerminalService()
        )

        let success = await appState.createWorktree(for: repo, featureName: "   ")

        XCTAssertFalse(success)
        XCTAssertTrue(appState.showError)
        XCTAssertEqual(
            appState.errorMessage,
            GitError.worktreeCreationFailed("Feature name cannot be empty.").localizedDescription
        )
    }

    func testCopyRepositoryURL_usesFileService() {
        let fileService = MockFileService()
        let repoPath = URL(fileURLWithPath: "/Users/test/Developer/sample")
        let repo = Repository(name: "sample", path: repoPath, isGitRepository: true)

        let appState = AppState(
            settings: MockSettingsService(),
            fileService: fileService,
            gitService: MockGitService(),
            terminalService: MockTerminalService()
        )

        appState.copyRepositoryURL(repo)

        XCTAssertEqual(fileService.copyToClipboardCalledWith, repoPath)
    }
}
