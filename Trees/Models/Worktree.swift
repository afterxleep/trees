import Foundation

/// Represents a git worktree
struct Worktree: Identifiable, Equatable {
    let id: UUID
    let path: URL
    let branch: String
    let isMain: Bool

    var name: String {
        branch
    }

    init(path: URL, branch: String, isMain: Bool) {
        self.id = UUID()
        self.path = path
        self.branch = branch
        self.isMain = isMain
    }

    static func == (lhs: Worktree, rhs: Worktree) -> Bool {
        lhs.path == rhs.path && lhs.branch == rhs.branch && lhs.isMain == rhs.isMain
    }
}
