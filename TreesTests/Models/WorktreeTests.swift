import XCTest
@testable import Trees

final class WorktreeTests: XCTestCase {

    func testWorktreeInitialization() {
        let path = URL(fileURLWithPath: "/Users/test/project.worktrees/feature-login")
        let worktree = Worktree(path: path, branch: "feature-login", isMain: false)

        XCTAssertEqual(worktree.path, path)
        XCTAssertEqual(worktree.branch, "feature-login")
        XCTAssertFalse(worktree.isMain)
    }

    func testWorktreeIsIdentifiable() {
        let path = URL(fileURLWithPath: "/Users/test/project.worktrees/feature-login")
        let worktree = Worktree(path: path, branch: "feature-login", isMain: false)

        XCTAssertEqual(worktree.id, path.standardizedFileURL.path)
    }

    func testWorktreeNameReturnsBranchName() {
        let path = URL(fileURLWithPath: "/Users/test/project.worktrees/feature-login")
        let worktree = Worktree(path: path, branch: "feature-login", isMain: false)

        XCTAssertEqual(worktree.name, "feature-login")
    }

    func testMainWorktree() {
        let path = URL(fileURLWithPath: "/Users/test/project")
        let worktree = Worktree(path: path, branch: "main", isMain: true)

        XCTAssertTrue(worktree.isMain)
        XCTAssertEqual(worktree.branch, "main")
    }

    func testWorktreeEquatable() {
        let path = URL(fileURLWithPath: "/Users/test/project.worktrees/feature")
        let worktree1 = Worktree(path: path, branch: "feature", isMain: false)
        let worktree2 = Worktree(path: path, branch: "feature", isMain: false)

        XCTAssertEqual(worktree1, worktree2)
    }
}
