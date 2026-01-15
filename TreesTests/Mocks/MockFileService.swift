import Foundation
@testable import Trees

final class MockFileService: FileServiceProtocol, @unchecked Sendable {
    var repositoriesToReturn: [Repository] = []
    var isGitRepositoryResult: Bool = true
    var openInFinderCalledWith: URL?
    var copyToClipboardCalledWith: URL?
    var scanRepositoriesCalledWith: URL?

    func scanRepositories(in directory: URL) -> [Repository] {
        scanRepositoriesCalledWith = directory
        return repositoriesToReturn
    }

    func isGitRepository(_ directory: URL) -> Bool {
        return isGitRepositoryResult
    }

    func openInFinder(_ directory: URL) {
        openInFinderCalledWith = directory
    }

    func copyToClipboard(_ url: URL) {
        copyToClipboardCalledWith = url
    }
}
