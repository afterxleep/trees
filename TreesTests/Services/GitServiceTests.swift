import XCTest
@testable import Trees

final class GitServiceTests: XCTestCase {

    var sut: GitService!
    var testDirectory: URL!

    override func setUp() {
        super.setUp()
        sut = GitService()

        // Create a temporary test directory
        testDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TreesGitTests-\(UUID().uuidString)")

        try? FileManager.default.createDirectory(
            at: testDirectory,
            withIntermediateDirectories: true
        )
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: testDirectory)
        testDirectory = nil
        sut = nil
        super.tearDown()
    }

    // MARK: - Helper Methods

    private func createGitRepo(named name: String) -> URL {
        let repoPath = testDirectory.appendingPathComponent(name)
        try? FileManager.default.createDirectory(at: repoPath, withIntermediateDirectories: true)

        // Initialize git repo
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["init"]
        process.currentDirectoryURL = repoPath
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()

        // Create initial commit so we have a branch
        let configName = Process()
        configName.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        configName.arguments = ["config", "user.name", "Test"]
        configName.currentDirectoryURL = repoPath
        configName.standardOutput = FileHandle.nullDevice
        configName.standardError = FileHandle.nullDevice
        try? configName.run()
        configName.waitUntilExit()

        let configEmail = Process()
        configEmail.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        configEmail.arguments = ["config", "user.email", "test@test.com"]
        configEmail.currentDirectoryURL = repoPath
        configEmail.standardOutput = FileHandle.nullDevice
        configEmail.standardError = FileHandle.nullDevice
        try? configEmail.run()
        configEmail.waitUntilExit()

        // Create and commit a file
        let testFile = repoPath.appendingPathComponent("README.md")
        try? "# Test".write(to: testFile, atomically: true, encoding: .utf8)

        let add = Process()
        add.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        add.arguments = ["add", "."]
        add.currentDirectoryURL = repoPath
        add.standardOutput = FileHandle.nullDevice
        add.standardError = FileHandle.nullDevice
        try? add.run()
        add.waitUntilExit()

        let commit = Process()
        commit.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        commit.arguments = ["commit", "-m", "Initial commit"]
        commit.currentDirectoryURL = repoPath
        commit.standardOutput = FileHandle.nullDevice
        commit.standardError = FileHandle.nullDevice
        try? commit.run()
        commit.waitUntilExit()

        // Rename branch to main
        let rename = Process()
        rename.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        rename.arguments = ["branch", "-M", "main"]
        rename.currentDirectoryURL = repoPath
        rename.standardOutput = FileHandle.nullDevice
        rename.standardError = FileHandle.nullDevice
        try? rename.run()
        rename.waitUntilExit()

        return repoPath
    }

    // MARK: - Worktree Path Calculation

    func testWorktreePath_calculatesCorrectSiblingPath() {
        let repoPath = URL(fileURLWithPath: "/Users/test/Developer/flowdeck")
        let featureName = "my-feature"

        let expected = URL(fileURLWithPath: "/Users/test/Developer/flowdeck.worktrees/my-feature")
        let result = sut.calculateWorktreePath(for: repoPath, featureName: featureName)

        XCTAssertEqual(result, expected)
    }

    func testWorktreePath_handlesSpacesInFeatureName() {
        let repoPath = URL(fileURLWithPath: "/Users/test/Developer/project")
        let featureName = "my feature"

        // Spaces should be preserved (git handles them)
        let expected = URL(fileURLWithPath: "/Users/test/Developer/project.worktrees/my feature")
        let result = sut.calculateWorktreePath(for: repoPath, featureName: featureName)

        XCTAssertEqual(result, expected)
    }

    // MARK: - Create Worktree Integration Tests

    func testCreateWorktree_createsWorktreeDirectory() async throws {
        let repoPath = createGitRepo(named: "testproject")

        let worktreePath = try await sut.createWorktree(at: repoPath, featureName: "test-feature")

        XCTAssertTrue(FileManager.default.fileExists(atPath: worktreePath.path))
    }

    func testCreateWorktree_returnsCorrectPath() async throws {
        let repoPath = createGitRepo(named: "myproject")

        let worktreePath = try await sut.createWorktree(at: repoPath, featureName: "new-feature")

        let expectedPath = testDirectory.appendingPathComponent("myproject.worktrees/new-feature")
        XCTAssertEqual(
            worktreePath.standardizedFileURL,
            expectedPath.standardizedFileURL
        )
    }

    func testCreateWorktree_throwsErrorForDuplicateBranch() async {
        let repoPath = createGitRepo(named: "project")

        // Create first worktree
        _ = try? await sut.createWorktree(at: repoPath, featureName: "duplicate")

        // Try to create duplicate
        do {
            _ = try await sut.createWorktree(at: repoPath, featureName: "duplicate")
            XCTFail("Expected error for duplicate branch")
        } catch let error as GitError {
            if case .branchAlreadyExists = error {
                // Expected
            } else if case .worktreeCreationFailed = error {
                // Also acceptable
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func testCreateWorktree_throwsErrorForNonGitRepo() async {
        let nonGitPath = testDirectory.appendingPathComponent("not-a-repo")
        try? FileManager.default.createDirectory(at: nonGitPath, withIntermediateDirectories: true)

        do {
            _ = try await sut.createWorktree(at: nonGitPath, featureName: "feature")
            XCTFail("Expected error for non-git repo")
        } catch let error as GitError {
            if case .notAGitRepository = error {
                // Expected
            } else if case .worktreeCreationFailed = error {
                // Also acceptable
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
}
