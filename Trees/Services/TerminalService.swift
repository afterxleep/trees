import Foundation
import AppKit

/// Error that can occur when launching terminal
enum TerminalError: Error, LocalizedError {
    case launchFailed(String)
    case terminalNotInstalled(TerminalApp)

    var errorDescription: String? {
        switch self {
        case .launchFailed(let message):
            return "Failed to launch terminal: \(message)"
        case .terminalNotInstalled(let app):
            return "\(app.rawValue) is not installed"
        }
    }
}

/// Service for launching terminal applications
final class TerminalService: TerminalServiceProtocol {

    func openTerminal(at directory: URL, command: String, using terminalApp: TerminalApp) throws {
        let script: String

        if command.isEmpty {
            script = buildOpenAtPathScript(for: terminalApp, directory: directory)
        } else {
            script = buildAppleScript(for: terminalApp, directory: directory, command: command)
        }

        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(&error)

            if let error = error {
                let message = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
                throw TerminalError.launchFailed(message)
            }
        } else {
            throw TerminalError.launchFailed("Failed to create AppleScript")
        }
    }

    /// Builds script to just open terminal at a path (no command)
    private func buildOpenAtPathScript(for terminalApp: TerminalApp, directory: URL) -> String {
        let path = directory.path

        switch terminalApp {
        case .terminal:
            return """
            tell application "Terminal"
                activate
                do script "cd '\(path)'"
            end tell
            """
        case .iterm:
            return """
            tell application "iTerm"
                activate
                create window with default profile
                tell current session of current window
                    write text "cd '\(path)'"
                end tell
            end tell
            """
        case .ghostty:
            return """
            do shell script "open -na Ghostty --args --working-directory='\(path)'"
            """
        case .warp:
            return """
            do shell script "open -na Warp --args '\(path)'"
            """
        case .alacritty:
            return """
            do shell script "open -na Alacritty --args --working-directory '\(path)'"
            """
        }
    }

    /// Builds the AppleScript to launch the terminal with a command
    func buildAppleScript(for terminalApp: TerminalApp, directory: URL, command: String) -> String {
        let path = directory.path

        switch terminalApp {
        case .terminal:
            return """
            tell application "Terminal"
                activate
                do script "cd '\(path)' && \(command)"
            end tell
            """
        case .iterm:
            return """
            tell application "iTerm"
                activate
                create window with default profile
                tell current session of current window
                    write text "cd '\(path)' && \(command)"
                end tell
            end tell
            """
        case .ghostty:
            return """
            do shell script "open -na Ghostty --args --working-directory='\(path)'"
            delay 1
            tell application "System Events"
                tell process "Ghostty"
                    keystroke "\(command)"
                    keystroke return
                end tell
            end tell
            """
        case .warp:
            return """
            do shell script "open -na Warp --args '\(path)'"
            delay 0.5
            tell application "System Events"
                tell process "Warp"
                    keystroke "\(command)"
                    keystroke return
                end tell
            end tell
            """
        case .alacritty:
            return """
            do shell script "open -na Alacritty --args --working-directory '\(path)' -e '\(command)'"
            """
        }
    }
}
