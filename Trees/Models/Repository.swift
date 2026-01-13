import Foundation

/// Represents a git repository in the developer directory
struct Repository: Identifiable, Equatable, Hashable {
    let id: UUID
    let name: String
    let path: URL

    init(id: UUID = UUID(), name: String, path: URL) {
        self.id = id
        self.name = name
        self.path = path
    }

    /// The base path for worktrees (sibling directory with .worktrees suffix)
    var worktreesBasePath: URL {
        path.deletingLastPathComponent().appendingPathComponent("\(name).worktrees")
    }
}
