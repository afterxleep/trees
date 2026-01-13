import Foundation
@testable import Trees

final class MockGitService: GitServiceProtocol {
    var pullMainError: GitError?
    var createWorktreeError: GitError?
    var listWorktreesError: GitError?
    var createdWorktreePath: URL?
    var worktreesToReturn: [Worktree] = []

    var pullMainCalledWith: URL?
    var createWorktreeCalledWith: (repoPath: URL, featureName: String)?
    var listWorktreesCalledWith: URL?

    func pullMain(at repoPath: URL) async throws {
        pullMainCalledWith = repoPath
        if let error = pullMainError {
            throw error
        }
    }

    func createWorktree(at repoPath: URL, featureName: String) async throws -> URL {
        createWorktreeCalledWith = (repoPath, featureName)
        if let error = createWorktreeError {
            throw error
        }
        return createdWorktreePath ?? repoPath.deletingLastPathComponent()
            .appendingPathComponent("\(repoPath.lastPathComponent).worktrees")
            .appendingPathComponent(featureName)
    }

    func listWorktrees(at repoPath: URL) async throws -> [Worktree] {
        listWorktreesCalledWith = repoPath
        if let error = listWorktreesError {
            throw error
        }
        return worktreesToReturn
    }
}
