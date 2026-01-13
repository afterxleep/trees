import Foundation
import AppKit

/// Service for scanning directories and file operations
final class FileService: FileServiceProtocol {

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
                .filter { isValidRepository($0) }
                .map { Repository(name: $0.lastPathComponent, path: $0) }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        } catch {
            return []
        }
    }

    func isGitRepository(_ directory: URL) -> Bool {
        let gitPath = directory.appendingPathComponent(".git")
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: gitPath.path, isDirectory: &isDirectory)
            && isDirectory.boolValue
    }

    func openInFinder(_ directory: URL) {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: directory.path)
    }

    // MARK: - Private

    private func isValidRepository(_ url: URL) -> Bool {
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

        // Must be a git repository
        return isGitRepository(url)
    }
}
