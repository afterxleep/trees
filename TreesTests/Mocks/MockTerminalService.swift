import Foundation
@testable import Trees

final class MockTerminalService: TerminalServiceProtocol {
    var openTerminalError: Error?
    var openTerminalCalledWith: (directory: URL, command: String, terminalApp: TerminalApp)?

    func openTerminal(at directory: URL, command: String, using terminalApp: TerminalApp) throws {
        openTerminalCalledWith = (directory, command, terminalApp)
        if let error = openTerminalError {
            throw error
        }
    }
}
