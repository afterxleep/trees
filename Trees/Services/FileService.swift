import Foundation
import AppKit

/// Service for scanning directories and file operations
final class FileService: FileServiceProtocol, @unchecked Sendable {

    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func scanRepositories(in directory: URL) -> [Repository] {
        guard fileManager.fileExists(atPath: directory.path) else {
            return []
        }

        do {
            let contents = try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )

            return contents
                .filter { isValidDirectory($0) }
                .map { Repository(
                    name: $0.lastPathComponent,
                    path: $0,
                    isGitRepository: isGitRepository($0)
                )}
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        } catch {
            return []
        }
    }

    func isGitRepository(_ directory: URL) -> Bool {
        let gitPath = directory.appendingPathComponent(".git")
        // .git can be a directory (normal repo) or a file (worktree/submodule)
        return fileManager.fileExists(atPath: gitPath.path)
    }

    func openInFinder(_ directory: URL) {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: directory.path)
    }

    func copyToClipboard(_ url: URL) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.absoluteString, forType: .string)
    }

    // MARK: - Private

    private func isValidDirectory(_ url: URL) -> Bool {
        // Must be a directory
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return false
        }

        let name = url.lastPathComponent

        // Exclude .worktrees folders
        if name.hasSuffix(".worktrees") {
            return false
        }

        return true
    }
}
