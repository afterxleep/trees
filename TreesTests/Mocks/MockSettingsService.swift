import Foundation
@testable import Trees

final class MockSettingsService: SettingsServiceProtocol {
    var developerPathURL: URL
    var terminalApp: TerminalApp

    init(
        developerPathURL: URL = URL(fileURLWithPath: "/Users/test/Developer"),
        terminalApp: TerminalApp = .terminal
    ) {
        self.developerPathURL = developerPathURL
        self.terminalApp = terminalApp
    }
}
