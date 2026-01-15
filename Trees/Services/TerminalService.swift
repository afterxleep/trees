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
        try ensureAppInstalled(terminalApp)
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
        let shellCommand = "cd \(shellQuoted(path))"

        switch terminalApp {
        case .terminal:
            return """
            tell application "Terminal"
                activate
                do script "\(appleScriptEscaped(shellCommand))"
            end tell
            """
        case .iterm:
            return """
            tell application "iTerm"
                activate
                create window with default profile
                tell current session of current window
                    write text "\(appleScriptEscaped(shellCommand))"
                end tell
            end tell
            """
        case .ghostty:
            let openCommand = openCommand(
                for: terminalApp,
                arguments: ["--working-directory=\(path)"],
                openNewInstance: false
            )
            return """
            do shell script "\(appleScriptEscaped(openCommand))"
            """
        case .warp:
            let openCommand = openCommand(
                for: terminalApp,
                arguments: [path],
                openNewInstance: false
            )
            return """
            do shell script "\(appleScriptEscaped(openCommand))"
            """
        case .alacritty:
            let openCommand = openCommand(
                for: terminalApp,
                arguments: ["--working-directory", path],
                openNewInstance: false
            )
            return """
            do shell script "\(appleScriptEscaped(openCommand))"
            """
        }
    }

    /// Builds the AppleScript to launch the terminal with a command
    func buildAppleScript(for terminalApp: TerminalApp, directory: URL, command: String) -> String {
        let path = directory.path
        let shellCommand = "cd \(shellQuoted(path)) && \(command)"

        switch terminalApp {
        case .terminal:
            return """
            tell application "Terminal"
                activate
                do script "\(appleScriptEscaped(shellCommand))"
            end tell
            """
        case .iterm:
            return """
            tell application "iTerm"
                activate
                create window with default profile
                tell current session of current window
                    write text "\(appleScriptEscaped(shellCommand))"
                end tell
            end tell
            """
        case .ghostty:
            let openCommand = openCommand(
                for: terminalApp,
                arguments: ["--working-directory=\(path)", "-e", command],
                openNewInstance: false
            )
            return """
            do shell script "\(appleScriptEscaped(openCommand))"
            """
        case .warp:
            let openCommand = openCommand(
                for: terminalApp,
                arguments: [path, "--command", command],
                openNewInstance: false
            )
            return """
            do shell script "\(appleScriptEscaped(openCommand))"
            """
        case .alacritty:
            let openCommand = openCommand(
                for: terminalApp,
                arguments: ["--working-directory", path, "-e", "/bin/zsh", "-lc", command],
                openNewInstance: false
            )
            return """
            do shell script "\(appleScriptEscaped(openCommand))"
            """
        }
    }

    private func ensureAppInstalled(_ terminalApp: TerminalApp) throws {
        guard NSWorkspace.shared.urlForApplication(withBundleIdentifier: terminalApp.bundleIdentifier) != nil else {
            throw TerminalError.terminalNotInstalled(terminalApp)
        }
    }

    private func openCommand(
        for terminalApp: TerminalApp,
        arguments: [String],
        openNewInstance: Bool = true
    ) -> String {
        let argString = arguments.map { shellQuoted($0) }.joined(separator: " ")
        let newInstanceFlag = openNewInstance ? "-n " : ""
        return "open \(newInstanceFlag)-b \(terminalApp.bundleIdentifier) --args \(argString)"
    }

    private func shellQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private func appleScriptEscaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
