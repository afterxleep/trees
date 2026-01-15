import SwiftUI

@main
struct TreesApp: App {
    @StateObject private var settings: SettingsService
    @StateObject private var appState: AppState

    init() {
        let settings = SettingsService()
        _settings = StateObject(wrappedValue: settings)

        let state = AppState(settings: settings)
        state.loadRepositories()
        _appState = StateObject(wrappedValue: state)
    }

    var body: some Scene {
        MenuBarExtra {
            RepoMenuView(appState: appState)
        } label: {
            Label("Trees", image: "MenuBarIcon")
                .labelStyle(.iconOnly)
        }
        .menuBarExtraStyle(.window)

        Window("Settings", id: "settings") {
            SettingsView(settings: settings)
        }
        .windowResizability(.contentSize)

        Window("New Worktree", id: "worktree") {
            WorktreeWindowView(appState: appState)
        }
        .windowResizability(.contentSize)
    }
}
