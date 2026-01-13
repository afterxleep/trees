import Foundation
@testable import Trees

final class MockFileService: FileServiceProtocol {
    var repositoriesToReturn: [Repository] = []
    var isGitRepositoryResult: Bool = true
    var openInFinderCalledWith: URL?
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
}
