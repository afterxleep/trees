import Foundation
import SwiftUI

/// Service for managing user preferences
final class SettingsService: ObservableObject {

    private let userDefaults: UserDefaults

    private enum Keys {
        static let developerPath = "developerPath"
        static let terminalApp = "terminalApp"
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        registerDefaults()
    }

    private func registerDefaults() {
        let defaults: [String: Any] = [
            Keys.developerPath: NSHomeDirectory() + "/Developer",
            Keys.terminalApp: TerminalApp.ghostty.rawValue
        ]
        userDefaults.register(defaults: defaults)
    }

    // MARK: - Developer Path

    var developerPath: String {
        get { userDefaults.string(forKey: Keys.developerPath) ?? NSHomeDirectory() + "/Developer" }
        set {
            userDefaults.set(newValue, forKey: Keys.developerPath)
            objectWillChange.send()
        }
    }

    var developerPathURL: URL {
        let path = (developerPath as NSString).expandingTildeInPath
        return URL(fileURLWithPath: path)
    }

    // MARK: - Terminal App

    var terminalApp: TerminalApp {
        get {
            guard let rawValue = userDefaults.string(forKey: Keys.terminalApp),
                  let app = TerminalApp(rawValue: rawValue) else {
                return .ghostty
            }
            return app
        }
        set {
            userDefaults.set(newValue.rawValue, forKey: Keys.terminalApp)
            objectWillChange.send()
        }
    }

}
