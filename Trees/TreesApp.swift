import SwiftUI

@main
struct TreesApp: App {
    @StateObject private var appState: AppState = {
        let state = AppState()
        state.loadRepositories()
        return state
    }()

    var body: some Scene {
        MenuBarExtra("Trees", systemImage: "tree") {
            RepoMenuView(appState: appState)
        }
        .menuBarExtraStyle(.menu)

        Window("Settings", id: "settings") {
            SettingsView(settings: appState.settings)
        }
        .windowResizability(.contentSize)

        Window("New Worktree", id: "worktree") {
            WorktreeWindowView(appState: appState)
        }
        .windowResizability(.contentSize)
    }
}
