import Foundation

/// Service for git operations
final class GitService: GitServiceProtocol {

    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func pullMain(at repoPath: URL) async throws {
        let result = try await runGitCommand(
            ["pull", "origin", "main"],
            in: repoPath
        )

        if result.exitCode != 0 {
            throw GitError.pullFailed(result.stderr)
        }
    }

    func createWorktree(at repoPath: URL, featureName: String) async throws -> URL {
        // Verify it's a git repository
        let gitPath = repoPath.appendingPathComponent(".git")
        guard fileManager.fileExists(atPath: gitPath.path) else {
            throw GitError.notAGitRepository
        }

        let worktreePath = calculateWorktreePath(for: repoPath, featureName: featureName)

        // Create the worktrees base directory if needed
        let worktreesBase = worktreePath.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: worktreesBase.path) {
            try fileManager.createDirectory(
                at: worktreesBase,
                withIntermediateDirectories: true
            )
        }

        // Create the worktree with a new branch
        let result = try await runGitCommand(
            ["worktree", "add", "-b", featureName, worktreePath.path, "main"],
            in: repoPath
        )

        if result.exitCode != 0 {
            let stderr = result.stderr.lowercased()
            if stderr.contains("already exists") {
                throw GitError.branchAlreadyExists(featureName)
            }
            throw GitError.worktreeCreationFailed(result.stderr)
        }

        return worktreePath
    }

    /// Calculate the worktree path for a given repo and feature name
    func calculateWorktreePath(for repoPath: URL, featureName: String) -> URL {
        let repoName = repoPath.lastPathComponent
        let parentDir = repoPath.deletingLastPathComponent()
        return parentDir
            .appendingPathComponent("\(repoName).worktrees")
            .appendingPathComponent(featureName)
    }

    // MARK: - Private

    private struct CommandResult {
        let stdout: String
        let stderr: String
        let exitCode: Int32
    }

    private func runGitCommand(_ arguments: [String], in directory: URL) async throws -> CommandResult {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
                process.arguments = arguments
                process.currentDirectoryURL = directory

                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe

                do {
                    try process.run()
                    process.waitUntilExit()

                    let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                    let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

                    let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
                    let stderr = String(data: stderrData, encoding: .utf8) ?? ""

                    continuation.resume(returning: CommandResult(
                        stdout: stdout,
                        stderr: stderr,
                        exitCode: process.terminationStatus
                    ))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
