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

    // MARK: - List Worktrees Tests

    func testListWorktrees_returnsMainWorktreeForNewRepo() async throws {
        let repoPath = createGitRepo(named: "newrepo")

        let worktrees = try await sut.listWorktrees(at: repoPath)

        XCTAssertEqual(worktrees.count, 1)
        XCTAssertTrue(worktrees[0].isMain)
        XCTAssertEqual(worktrees[0].branch, "main")
    }

    func testListWorktrees_returnsAllWorktrees() async throws {
        let repoPath = createGitRepo(named: "multitree")

        // Create a worktree
        _ = try await sut.createWorktree(at: repoPath, featureName: "feature-one")

        let worktrees = try await sut.listWorktrees(at: repoPath)

        XCTAssertEqual(worktrees.count, 2)

        let branches = worktrees.map { $0.branch }
        XCTAssertTrue(branches.contains("main"))
        XCTAssertTrue(branches.contains("feature-one"))
    }

    func testListWorktrees_returnsCorrectPaths() async throws {
        let repoPath = createGitRepo(named: "pathtest")

        _ = try await sut.createWorktree(at: repoPath, featureName: "my-feature")

        let worktrees = try await sut.listWorktrees(at: repoPath)

        let featureWorktree = worktrees.first { $0.branch == "my-feature" }
        XCTAssertNotNil(featureWorktree)

        let expectedPath = testDirectory.appendingPathComponent("pathtest.worktrees/my-feature")
        XCTAssertEqual(featureWorktree?.path.standardizedFileURL, expectedPath.standardizedFileURL)
    }

    func testListWorktrees_identifiesMainWorktree() async throws {
        let repoPath = createGitRepo(named: "maintest")

        _ = try await sut.createWorktree(at: repoPath, featureName: "feature")

        let worktrees = try await sut.listWorktrees(at: repoPath)

        let mainWorktree = worktrees.first { $0.isMain }
        let featureWorktree = worktrees.first { !$0.isMain }

        XCTAssertNotNil(mainWorktree)
        XCTAssertNotNil(featureWorktree)
        XCTAssertEqual(mainWorktree?.path.standardizedFileURL, repoPath.standardizedFileURL)
    }

    func testListWorktrees_throwsErrorForNonGitRepo() async {
        let nonGitPath = testDirectory.appendingPathComponent("not-git")
        try? FileManager.default.createDirectory(at: nonGitPath, withIntermediateDirectories: true)

        do {
            _ = try await sut.listWorktrees(at: nonGitPath)
            XCTFail("Expected error for non-git repo")
        } catch {
            // Expected
        }
    }

    // MARK: - Pull Error Parsing Tests

    func testParsePullError_detectsLocalChanges() {
        let stderr = """
        error: Your local changes to the following files would be overwritten by merge:
        \tPackage.resolved
        \tproject.pbxproj
        Please commit your changes or stash them before you merge.
        Aborting
        """

        let error = sut.parsePullError(stderr)

        guard case .pullBlockedByLocalChanges(let files) = error else {
            XCTFail("Expected local changes error")
            return
        }
        XCTAssertEqual(files, ["Package.resolved", "project.pbxproj"])
    }

    func testParsePullError_detectsAuthFailure() {
        let stderr = "fatal: Authentication failed for 'https://github.com/example/repo.git'"

        let error = sut.parsePullError(stderr)

        guard case .pullAuthFailed = error else {
            XCTFail("Expected auth failure error")
            return
        }
    }

    func testParsePullError_detectsRemoteNotFound() {
        let stderr = """
        remote: Repository not found.
        fatal: repository 'https://github.com/example/missing.git/' not found
        """

        let error = sut.parsePullError(stderr)

        guard case .pullRemoteNotFound = error else {
            XCTFail("Expected remote not found error")
            return
        }
    }

    func testParsePullError_detectsNetworkError() {
        let stderr = "fatal: unable to access 'https://github.com/example/repo/': Could not resolve host: github.com"

        let error = sut.parsePullError(stderr)

        guard case .pullNetworkError = error else {
            XCTFail("Expected network error")
            return
        }
    }

    func testParsePullError_detectsMergeConflicts() {
        let stderr = """
        CONFLICT (content): Merge conflict in Sources/App.swift
        Automatic merge failed; fix conflicts and then commit the result.
        """

        let error = sut.parsePullError(stderr)

        guard case .pullConflicts(let files) = error else {
            XCTFail("Expected merge conflict error")
            return
        }
        XCTAssertEqual(files, ["Sources/App.swift"])
    }

    func testParsePullError_detectsMissingRemoteBranch() {
        let stderr = "fatal: couldn't find remote ref main"

        let error = sut.parsePullError(stderr)

        guard case .pullBranchNotFound(let branch) = error else {
            XCTFail("Expected missing branch error")
            return
        }
        XCTAssertEqual(branch, "main")
    }

    func testParseWorktreeError_detectsInvalidBranchName() {
        let stderr = "fatal: 'bad branch' is not a valid branch name."

        let error = sut.parseWorktreeError(
            stderr,
            featureName: "bad branch",
            baseBranch: "main"
        )

        guard case .invalidBranchName(let branch) = error else {
            XCTFail("Expected invalid branch name error")
            return
        }
        XCTAssertEqual(branch, "bad branch")
    }

    func testParseWorktreeError_detectsMissingBaseBranch() {
        let stderr = "fatal: invalid reference: main"

        let error = sut.parseWorktreeError(
            stderr,
            featureName: "feature",
            baseBranch: "main"
        )

        guard case .baseBranchNotFound(let branch) = error else {
            XCTFail("Expected base branch not found error")
            return
        }
        XCTAssertEqual(branch, "main")
    }
}
