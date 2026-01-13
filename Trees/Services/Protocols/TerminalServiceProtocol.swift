import Foundation

/// Supported terminal applications
enum TerminalApp: String, CaseIterable, Identifiable {
    case ghostty = "Ghostty"
    case terminal = "Terminal"
    case iterm = "iTerm"
    case warp = "Warp"
    case alacritty = "Alacritty"

    var id: String { rawValue }

    var bundleIdentifier: String {
        switch self {
        case .ghostty: return "com.mitchellh.ghostty"
        case .terminal: return "com.apple.Terminal"
        case .iterm: return "com.googlecode.iterm2"
        case .warp: return "dev.warp.Warp-Stable"
        case .alacritty: return "org.alacritty"
        }
    }
}

/// Protocol for launching terminal applications
protocol TerminalServiceProtocol {
    /// Opens the specified terminal app at the given directory and runs a command
    /// - Parameters:
    ///   - directory: The directory to open the terminal in
    ///   - command: The command to run after changing to the directory
    ///   - terminalApp: The terminal application to use
    /// - Throws: Error if terminal launch fails
    func openTerminal(at directory: URL, command: String, using terminalApp: TerminalApp) throws
}
