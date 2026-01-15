import Foundation

/// Service for git operations
final class GitService: GitServiceProtocol {

    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func pullMain(at repoPath: URL) async throws {
        let gitPath = repoPath.appendingPathComponent(".git")
        guard fileManager.fileExists(atPath: gitPath.path) else {
            throw GitError.notAGitRepository
        }

        guard await hasRemote(named: "origin", in: repoPath) else {
            return
        }

        let defaultBranch = await defaultBranchName(in: repoPath)
        let result = try await runGitCommand(
            ["pull", "origin", defaultBranch],
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

        if fileManager.fileExists(atPath: worktreePath.path) {
            throw GitError.worktreeCreationFailed("Worktree path already exists.")
        }

        let defaultBranch = await defaultBranchName(in: repoPath)
        let branchExists = await branchExists(featureName, in: repoPath)

        // Create the worktree with a new branch (or attach existing)
        let result = try await runGitCommand(
            branchExists
                ? ["worktree", "add", worktreePath.path, featureName]
                : ["worktree", "add", "-b", featureName, worktreePath.path, defaultBranch],
            in: repoPath
        )

        if result.exitCode != 0 {
            let stderr = result.stderr.lowercased()
            if stderr.contains("already exists") || stderr.contains("already checked out") {
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

    func listWorktrees(at repoPath: URL) async throws -> [Worktree] {
        let result = try await runGitCommand(
            ["worktree", "list", "--porcelain"],
            in: repoPath
        )

        if result.exitCode != 0 {
            throw GitError.notAGitRepository
        }

        var worktrees: [Worktree] = []
        var currentPath: URL?
        var currentBranch: String?

        func finalizeEntry() {
            guard let path = currentPath else { return }
            let branch = currentBranch ?? "detached"
            let isMain = path.standardizedFileURL == repoPath.standardizedFileURL
            worktrees.append(Worktree(path: path, branch: branch, isMain: isMain))
        }

        for line in result.stdout.split(separator: "\n") {
            if line.hasPrefix("worktree ") {
                finalizeEntry()
                let pathString = line.dropFirst("worktree ".count)
                currentPath = URL(fileURLWithPath: String(pathString))
                currentBranch = nil
            } else if line.hasPrefix("branch ") {
                let ref = line.dropFirst("branch ".count)
                currentBranch = String(ref).replacingOccurrences(of: "refs/heads/", with: "")
            } else if line.hasPrefix("detached") {
                currentBranch = "detached"
            }
        }

        finalizeEntry()
        return worktrees
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

    private func hasRemote(named name: String, in repoPath: URL) async -> Bool {
        guard let result = try? await runGitCommand(
            ["remote", "get-url", name],
            in: repoPath
        ) else {
            return false
        }
        return result.exitCode == 0
    }

    private func defaultBranchName(in repoPath: URL) async -> String {
        if let result = try? await runGitCommand(
            ["symbolic-ref", "--short", "refs/remotes/origin/HEAD"],
            in: repoPath
        ),
        result.exitCode == 0 {
            let value = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            if value.hasPrefix("origin/") {
                return String(value.dropFirst("origin/".count))
            }
        }

        if let result = try? await runGitCommand(
            ["symbolic-ref", "--short", "HEAD"],
            in: repoPath
        ),
        result.exitCode == 0 {
            let branch = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            if !branch.isEmpty {
                return branch
            }
        }

        if await branchExists("main", in: repoPath) {
            return "main"
        }

        if await branchExists("master", in: repoPath) {
            return "master"
        }

        return "main"
    }

    private func branchExists(_ branch: String, in repoPath: URL) async -> Bool {
        guard let result = try? await runGitCommand(
            ["show-ref", "--verify", "--quiet", "refs/heads/\(branch)"],
            in: repoPath
        ) else {
            return false
        }
        return result.exitCode == 0
    }
}
