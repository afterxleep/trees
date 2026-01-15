import Foundation

/// Protocol for scanning directories for git repositories
protocol FileServiceProtocol: Sendable {
    /// Scans the given directory for git repositories
    /// - Parameter directory: The directory to scan
    /// - Returns: Array of Repository objects found
    func scanRepositories(in directory: URL) -> [Repository]

    /// Checks if a directory is a git repository
    /// - Parameter directory: The directory to check
    /// - Returns: true if the directory contains a .git folder
    func isGitRepository(_ directory: URL) -> Bool

    /// Opens a directory in Finder
    /// - Parameter directory: The directory to open
    func openInFinder(_ directory: URL)

    /// Copies a URL string to the clipboard
    /// - Parameter url: The URL to copy
    func copyToClipboard(_ url: URL)
}
