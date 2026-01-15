import Foundation

/// Represents a git worktree
struct Worktree: Identifiable, Equatable {
    let path: URL
    let branch: String
    let isMain: Bool

    var id: String {
        path.standardizedFileURL.path
    }

    var name: String {
        branch
    }
}
