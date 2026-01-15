import Foundation

/// Protocol for user settings access used by AppState.
protocol SettingsServiceProtocol {
    var developerPathURL: URL { get }
    var terminalApp: TerminalApp { get }
}
