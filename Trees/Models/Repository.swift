import Foundation

/// Represents a folder in the developer directory
struct Repository: Identifiable, Equatable, Hashable {
    let id: UUID
    let name: String
    let path: URL
    let isGitRepository: Bool

    init(id: UUID = UUID(), name: String, path: URL, isGitRepository: Bool = true) {
        self.id = id
        self.name = name
        self.path = path
        self.isGitRepository = isGitRepository
    }

    /// The base path for worktrees (sibling directory with .worktrees suffix)
    var worktreesBasePath: URL {
        path.deletingLastPathComponent().appendingPathComponent("\(name).worktrees")
    }
}
