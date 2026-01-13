import Foundation

/// Errors that can occur during git operations
enum GitError: Error, LocalizedError {
    case pullFailed(String)
    case worktreeCreationFailed(String)
    case notAGitRepository
    case branchAlreadyExists(String)

    var errorDescription: String? {
        switch self {
        case .pullFailed(let message):
            return "Failed to pull from main: \(message)"
        case .worktreeCreationFailed(let message):
            return "Failed to create worktree: \(message)"
        case .notAGitRepository:
            return "Not a git repository"
        case .branchAlreadyExists(let branch):
            return "Branch '\(branch)' already exists"
        }
    }
}

/// Protocol for git operations
protocol GitServiceProtocol {
    /// Pulls the latest changes from main branch
    /// - Parameter repoPath: Path to the git repository
    /// - Throws: GitError if pull fails
    func pullMain(at repoPath: URL) async throws

    /// Creates a new worktree with the given feature name
    /// - Parameters:
    ///   - repoPath: Path to the git repository
    ///   - featureName: Name for the feature branch
    /// - Returns: URL to the created worktree directory
    /// - Throws: GitError if worktree creation fails
    func createWorktree(at repoPath: URL, featureName: String) async throws -> URL
}
