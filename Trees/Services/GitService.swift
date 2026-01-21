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
            if let error = parsePullError(result.stderr) {
                throw error
            }
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
            if let error = parseWorktreeError(
                result.stderr,
                featureName: featureName,
                baseBranch: defaultBranch
            ) {
                throw error
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

    func removeWorktree(
        at repoPath: URL,
        worktree: Worktree,
        deleteBranch: Bool
    ) async throws {
        let gitPath = repoPath.appendingPathComponent(".git")
        guard fileManager.fileExists(atPath: gitPath.path) else {
            throw GitError.notAGitRepository
        }

        let removeArguments = ["worktree", "remove", "--force", worktree.path.path]

        let removeResult = try await runGitCommand(
            removeArguments,
            in: repoPath
        )

        if removeResult.exitCode != 0 {
            throw GitError.worktreeRemovalFailed(removeResult.stderr)
        }

        guard deleteBranch, worktree.branch != "detached" else { return }

        let branchResult = try await runGitCommand(
            ["branch", "-d", worktree.branch],
            in: repoPath
        )

        if branchResult.exitCode != 0 {
            throw GitError.branchDeletionFailed(worktree.branch, branchResult.stderr)
        }
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

    func parsePullError(_ stderr: String) -> GitError? {
        let lowercased = stderr.lowercased()

        if let files = parseLocalChangesFromPullError(stderr) {
            return GitError.pullBlockedByLocalChanges(files)
        }

        if containsAny(lowercased, patterns: [
            "authentication failed",
            "permission denied",
            "could not read from remote repository",
            "requested url returned error: 401",
            "requested url returned error: 403"
        ]) {
            return GitError.pullAuthFailed
        }

        if lowercased.contains("repository not found")
            || (lowercased.contains("fatal: repository") && lowercased.contains("not found")) {
            return GitError.pullRemoteNotFound
        }

        if containsAny(lowercased, patterns: [
            "could not resolve host",
            "failed to connect",
            "connection timed out",
            "network is unreachable"
        ]) {
            return GitError.pullNetworkError
        }

        if let missingBranch = parseMissingRemoteBranch(stderr) {
            return GitError.pullBranchNotFound(missingBranch)
        }

        if lowercased.contains("need to specify how to reconcile divergent branches") {
            return GitError.pullDiverged
        }

        if lowercased.contains("refusing to merge unrelated histories") {
            return GitError.pullUnrelatedHistories
        }

        let conflictFiles = parseMergeConflicts(stderr)
        if !conflictFiles.isEmpty
            || lowercased.contains("automatic merge failed")
            || lowercased.contains("merge conflict") {
            return GitError.pullConflicts(conflictFiles)
        }

        return nil
    }

    func parseWorktreeError(
        _ stderr: String,
        featureName: String,
        baseBranch: String
    ) -> GitError? {
        let lowercased = stderr.lowercased()

        if lowercased.contains("not a valid branch name") {
            return GitError.invalidBranchName(featureName)
        }

        if lowercased.contains("invalid reference")
            || lowercased.contains("not a valid object name") {
            if lowercased.contains(baseBranch.lowercased()) {
                return GitError.baseBranchNotFound(baseBranch)
            }
        }

        return nil
    }

    private func parseLocalChangesFromPullError(_ stderr: String) -> [String]? {
        let lines = stderr.split(separator: "\n", omittingEmptySubsequences: false)
        var capture = false
        var files: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let lowercased = trimmed.lowercased()

            if lowercased.contains("would be overwritten by merge")
                || lowercased.contains("would be overwritten by checkout") {
                capture = true
                continue
            }

            if capture {
                if lowercased.hasPrefix("please commit")
                    || lowercased.hasPrefix("aborting")
                    || lowercased.hasPrefix("error:") {
                    break
                }

                if trimmed.isEmpty {
                    continue
                }

                files.append(trimmed)
            }
        }

        return capture ? files : nil
    }

    private func parseMergeConflicts(_ stderr: String) -> [String] {
        let lines = stderr.split(separator: "\n", omittingEmptySubsequences: true)
        var files: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.contains("CONFLICT") {
                if let range = trimmed.range(of: " in ") {
                    let file = trimmed[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
                    if !file.isEmpty {
                        files.append(file)
                    }
                }
            }
        }

        return files
    }

    private func parseMissingRemoteBranch(_ stderr: String) -> String? {
        let lines = stderr.split(separator: "\n", omittingEmptySubsequences: true)

        for line in lines {
            let trimmed = String(line).trimmingCharacters(in: .whitespacesAndNewlines)
            let lowercased = trimmed.lowercased()

            if let range = lowercased.range(of: "couldn't find remote ref ") {
                let branch = trimmed[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
                return branch
            }

            if lowercased.contains("remote branch") && lowercased.contains("not found") {
                if let start = lowercased.range(of: "remote branch ")?.upperBound,
                   let end = lowercased.range(of: " not found")?.lowerBound {
                    let branch = trimmed[start..<end].trimmingCharacters(in: .whitespacesAndNewlines)
                    if !branch.isEmpty {
                        return branch
                    }
                }
            }
        }

        return nil
    }

    private func containsAny(_ value: String, patterns: [String]) -> Bool {
        for pattern in patterns {
            if value.contains(pattern) {
                return true
            }
        }
        return false
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
