import Foundation

/// Supported LLM agents to launch in a terminal
enum LLMAgent: String, CaseIterable, Identifiable {
    case codex = "Codex"
    case claude = "Claude"

    var id: String { rawValue }

    var launchCommand: String {
        switch self {
        case .codex:
            return "codex"
        case .claude:
            return "cld"
        }
    }
}
