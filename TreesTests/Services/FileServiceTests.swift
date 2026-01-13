import XCTest
@testable import Trees

final class FileServiceTests: XCTestCase {

    var sut: FileService!
    var testDirectory: URL!

    override func setUp() {
        super.setUp()
        sut = FileService()

        // Create a temporary test directory
        testDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TreesTests-\(UUID().uuidString)")

        try? FileManager.default.createDirectory(
            at: testDirectory,
            withIntermediateDirectories: true
        )
    }

    override func tearDown() {
        // Clean up test directory
        try? FileManager.default.removeItem(at: testDirectory)
        testDirectory = nil
        sut = nil
        super.tearDown()
    }

    // MARK: - Helper Methods

    private func createDirectory(_ name: String, isGitRepo: Bool = false) {
        let dir = testDirectory.appendingPathComponent(name)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        if isGitRepo {
            let gitDir = dir.appendingPathComponent(".git")
            try? FileManager.default.createDirectory(at: gitDir, withIntermediateDirectories: true)
        }
    }

    private func createFile(_ name: String) {
        let file = testDirectory.appendingPathComponent(name)
        FileManager.default.createFile(atPath: file.path, contents: nil)
    }

    // MARK: - isGitRepository Tests

    func testIsGitRepository_withGitFolder_returnsTrue() {
        createDirectory("myproject", isGitRepo: true)
        let projectPath = testDirectory.appendingPathComponent("myproject")

        XCTAssertTrue(sut.isGitRepository(projectPath))
    }

    func testIsGitRepository_withoutGitFolder_returnsFalse() {
        createDirectory("myproject", isGitRepo: false)
        let projectPath = testDirectory.appendingPathComponent("myproject")

        XCTAssertFalse(sut.isGitRepository(projectPath))
    }

    func testIsGitRepository_nonexistentDirectory_returnsFalse() {
        let nonExistent = testDirectory.appendingPathComponent("nonexistent")
        XCTAssertFalse(sut.isGitRepository(nonExistent))
    }

    // MARK: - scanRepositories Tests

    func testScanRepositories_findsGitRepos() {
        createDirectory("project1", isGitRepo: true)
        createDirectory("project2", isGitRepo: true)
        createDirectory("not-a-repo", isGitRepo: false)

        let repos = sut.scanRepositories(in: testDirectory)

        XCTAssertEqual(repos.count, 2)
        let names = repos.map { $0.name }.sorted()
        XCTAssertEqual(names, ["project1", "project2"])
    }

    func testScanRepositories_excludesWorktreesFolders() {
        createDirectory("project", isGitRepo: true)
        createDirectory("project.worktrees", isGitRepo: false)

        let repos = sut.scanRepositories(in: testDirectory)

        XCTAssertEqual(repos.count, 1)
        XCTAssertEqual(repos.first?.name, "project")
    }

    func testScanRepositories_excludesHiddenFolders() {
        createDirectory(".hidden-project", isGitRepo: true)
        createDirectory("visible-project", isGitRepo: true)

        let repos = sut.scanRepositories(in: testDirectory)

        XCTAssertEqual(repos.count, 1)
        XCTAssertEqual(repos.first?.name, "visible-project")
    }

    func testScanRepositories_excludesFiles() {
        createDirectory("project", isGitRepo: true)
        createFile("somefile.txt")

        let repos = sut.scanRepositories(in: testDirectory)

        XCTAssertEqual(repos.count, 1)
    }

    func testScanRepositories_emptyDirectory_returnsEmptyArray() {
        let repos = sut.scanRepositories(in: testDirectory)
        XCTAssertTrue(repos.isEmpty)
    }

    func testScanRepositories_nonexistentDirectory_returnsEmptyArray() {
        let nonExistent = testDirectory.appendingPathComponent("nonexistent")
        let repos = sut.scanRepositories(in: nonExistent)
        XCTAssertTrue(repos.isEmpty)
    }

    func testScanRepositories_setsCorrectPath() {
        createDirectory("myproject", isGitRepo: true)

        let repos = sut.scanRepositories(in: testDirectory)

        // Standardize paths to handle /var -> /private/var symlink
        let expectedPath = testDirectory.appendingPathComponent("myproject").standardizedFileURL
        let actualPath = repos.first?.path.standardizedFileURL
        XCTAssertEqual(actualPath, expectedPath)
    }

    func testScanRepositories_sortsByName() {
        createDirectory("zebra", isGitRepo: true)
        createDirectory("alpha", isGitRepo: true)
        createDirectory("middle", isGitRepo: true)

        let repos = sut.scanRepositories(in: testDirectory)

        XCTAssertEqual(repos.map { $0.name }, ["alpha", "middle", "zebra"])
    }
}
