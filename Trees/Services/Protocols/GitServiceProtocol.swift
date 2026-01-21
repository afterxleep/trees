import Foundation

/// Errors that can occur during git operations
enum GitError: Error, LocalizedError {
    case pullFailed(String)
    case pullBlockedByLocalChanges([String])
    case pullAuthFailed
    case pullRemoteNotFound
    case pullNetworkError
    case pullConflicts([String])
    case pullBranchNotFound(String)
    case pullDiverged
    case pullUnrelatedHistories
    case worktreeCreationFailed(String)
    case worktreeRemovalFailed(String)
    case invalidBranchName(String)
    case baseBranchNotFound(String)
    case notAGitRepository
    case branchAlreadyExists(String)
    case branchDeletionFailed(String, String)

    var errorDescription: String? {
        switch self {
        case .pullFailed(let message):
            return "Failed to pull from default branch: \(message)"
        case .pullBlockedByLocalChanges(let files):
            if files.isEmpty {
                return "Cannot pull because local changes would be overwritten. Commit or stash your changes first."
            }
            let fileList = files.joined(separator: "\n")
            return """
            Cannot pull because local changes would be overwritten. Commit or stash your changes first.

            Files:
            \(fileList)
            """
        case .pullAuthFailed:
            return "Authentication failed when pulling. Check your credentials or access permissions."
        case .pullRemoteNotFound:
            return "Remote repository not found. Check the remote URL and your access."
        case .pullNetworkError:
            return "Network error while contacting the remote. Check your connection and try again."
        case .pullConflicts(let files):
            if files.isEmpty {
                return "Pull resulted in merge conflicts. Resolve conflicts and commit before retrying."
            }
            let fileList = files.joined(separator: "\n")
            return """
            Pull resulted in merge conflicts. Resolve conflicts and commit before retrying.

            Conflicts:
            \(fileList)
            """
        case .pullBranchNotFound(let branch):
            return "Remote branch '\(branch)' was not found. Check that it exists on the remote."
        case .pullDiverged:
            return "Local and remote branches have diverged. Configure pull strategy or reconcile manually."
        case .pullUnrelatedHistories:
            return "Cannot pull because the histories are unrelated. Check the remote branch or merge manually."
        case .worktreeCreationFailed(let message):
            return "Failed to create worktree: \(message)"
        case .worktreeRemovalFailed(let message):
            return "Failed to remove worktree: \(message)"
        case .invalidBranchName(let branch):
            return "Branch name '\(branch)' is invalid. Use a valid branch name and try again."
        case .baseBranchNotFound(let branch):
            return "Base branch '\(branch)' was not found. Check your repository branches and try again."
        case .notAGitRepository:
            return "Not a git repository"
        case .branchAlreadyExists(let branch):
            return "Branch '\(branch)' already exists"
        case .branchDeletionFailed(let branch, let message):
            return "Failed to delete branch '\(branch)': \(message)"
        }
    }
}

/// Protocol for git operations
protocol GitServiceProtocol {
    /// Pulls the latest changes from the default branch when a remote is present
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

    /// Lists all worktrees for a repository
    /// - Parameter repoPath: Path to the git repository
    /// - Returns: Array of Worktree objects
    /// - Throws: GitError if listing fails
    func listWorktrees(at repoPath: URL) async throws -> [Worktree]

    /// Removes a worktree and optionally deletes its branch
    /// - Parameters:
    ///   - repoPath: Path to the git repository
    ///   - worktree: Worktree to remove
    ///   - deleteBranch: Whether to delete the worktree branch
    /// - Throws: GitError if removal fails
    func removeWorktree(
        at repoPath: URL,
        worktree: Worktree,
        deleteBranch: Bool
    ) async throws
}
