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

    func listWorktrees(at repoPath: URL) async throws -> [Worktree] {
        let result = try await runGitCommand(
            ["worktree", "list"],
            in: repoPath
        )

        if result.exitCode != 0 {
            throw GitError.notAGitRepository
        }

        // Parse output like:
        // /path/to/repo  abc1234 [main]
        // /path/to/worktree  def5678 [feature]
        var worktrees: [Worktree] = []
        let lines = result.stdout.components(separatedBy: "\n")
        var isFirst = true

        for line in lines {
            guard !line.isEmpty else { continue }

            // Extract path (everything before the first space followed by a hash)
            // Extract branch name from [branchname]
            if let bracketRange = line.range(of: "\\[([^\\]]+)\\]", options: .regularExpression) {
                let branchWithBrackets = String(line[bracketRange])
                let branch = String(branchWithBrackets.dropFirst().dropLast())

                // Path is everything up to the commit hash (7+ hex chars)
                let pathPart = line.prefix(while: { char in
                    // Stop when we hit whitespace followed by what looks like a hash
                    true
                })

                // Find the path by looking for the first whitespace followed by hex
                var pathString = ""
                var foundHash = false
                var i = line.startIndex
                while i < line.endIndex {
                    let remaining = String(line[i...])
                    if remaining.hasPrefix(" ") && remaining.count > 8 {
                        let afterSpace = remaining.dropFirst()
                        if afterSpace.prefix(7).allSatisfy({ $0.isHexDigit }) {
                            foundHash = true
                            break
                        }
                    }
                    pathString.append(line[i])
                    i = line.index(after: i)
                }

                if foundHash {
                    let path = URL(fileURLWithPath: pathString.trimmingCharacters(in: .whitespaces))
                    let worktree = Worktree(path: path, branch: branch, isMain: isFirst)
                    worktrees.append(worktree)
                }
            }
            isFirst = false
        }

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
}
