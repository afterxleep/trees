import XCTest
@testable import Trees

final class RepositoryTests: XCTestCase {

    // MARK: - Initialization Tests

    func testRepositoryInitialization() {
        let url = URL(fileURLWithPath: "/Users/test/Developer/myproject")
        let repo = Repository(name: "myproject", path: url)

        XCTAssertEqual(repo.name, "myproject")
        XCTAssertEqual(repo.path, url)
        XCTAssertNotNil(repo.id)
    }

    func testRepositoryHasUniqueId() {
        let url = URL(fileURLWithPath: "/Users/test/Developer/myproject")
        let repo1 = Repository(name: "myproject", path: url)
        let repo2 = Repository(name: "myproject", path: url)

        XCTAssertNotEqual(repo1.id, repo2.id)
    }

    // MARK: - Identifiable Conformance

    func testRepositoryIsIdentifiable() {
        let url = URL(fileURLWithPath: "/Users/test/Developer/myproject")
        let repo = Repository(name: "myproject", path: url)

        // Identifiable requires an id property
        let _: UUID = repo.id
    }

    // MARK: - Equatable Conformance

    func testRepositoriesWithSameIdAreEqual() {
        let url = URL(fileURLWithPath: "/Users/test/Developer/myproject")
        let id = UUID()
        let repo1 = Repository(id: id, name: "myproject", path: url)
        let repo2 = Repository(id: id, name: "myproject", path: url)

        XCTAssertEqual(repo1, repo2)
    }

    func testRepositoriesWithDifferentIdsAreNotEqual() {
        let url = URL(fileURLWithPath: "/Users/test/Developer/myproject")
        let repo1 = Repository(name: "myproject", path: url)
        let repo2 = Repository(name: "myproject", path: url)

        XCTAssertNotEqual(repo1, repo2)
    }

    // MARK: - Hashable Conformance

    func testRepositoryCanBeUsedInSet() {
        let url = URL(fileURLWithPath: "/Users/test/Developer/myproject")
        let repo = Repository(name: "myproject", path: url)

        var repoSet: Set<Repository> = []
        repoSet.insert(repo)

        XCTAssertTrue(repoSet.contains(repo))
    }

    // MARK: - Computed Properties

    func testWorktreePathReturnsCorrectSiblingPath() {
        let url = URL(fileURLWithPath: "/Users/test/Developer/flowdeck")
        let repo = Repository(name: "flowdeck", path: url)

        let expected = URL(fileURLWithPath: "/Users/test/Developer/flowdeck.worktrees")
        XCTAssertEqual(repo.worktreesBasePath, expected)
    }
}
