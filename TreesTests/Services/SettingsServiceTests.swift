import XCTest
@testable import Trees

final class SettingsServiceTests: XCTestCase {

    var sut: SettingsService!
    var userDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        // Use a separate suite for testing to avoid polluting real preferences
        userDefaults = UserDefaults(suiteName: "com.afterxleep.trees.tests")!
        userDefaults.removePersistentDomain(forName: "com.afterxleep.trees.tests")
        sut = SettingsService(userDefaults: userDefaults)
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: "com.afterxleep.trees.tests")
        userDefaults = nil
        sut = nil
        super.tearDown()
    }

    // MARK: - Default Values

    func testDefaultDeveloperPath() {
        let expected = NSHomeDirectory() + "/Developer"
        XCTAssertEqual(sut.developerPath, expected)
    }

    func testDefaultTerminalApp() {
        XCTAssertEqual(sut.terminalApp, .ghostty)
    }

    // MARK: - Persistence

    func testDeveloperPathPersists() {
        sut.developerPath = "/custom/path"

        // Create new instance with same UserDefaults
        let newInstance = SettingsService(userDefaults: userDefaults)
        XCTAssertEqual(newInstance.developerPath, "/custom/path")
    }

    func testTerminalAppPersists() {
        sut.terminalApp = .iterm

        let newInstance = SettingsService(userDefaults: userDefaults)
        XCTAssertEqual(newInstance.terminalApp, .iterm)
    }

    // MARK: - URL Conversion

    func testDeveloperPathURL() {
        sut.developerPath = "/Users/test/Developer"
        XCTAssertEqual(sut.developerPathURL, URL(fileURLWithPath: "/Users/test/Developer"))
    }

    func testDeveloperPathURLExpandsTilde() {
        sut.developerPath = "~/Developer"
        let expected = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Developer")
        XCTAssertEqual(sut.developerPathURL, expected)
    }

    // MARK: - All Terminal Apps Available

    func testAllTerminalAppsAreAvailable() {
        XCTAssertEqual(TerminalApp.allCases.count, 5)
        XCTAssertTrue(TerminalApp.allCases.contains(.ghostty))
        XCTAssertTrue(TerminalApp.allCases.contains(.terminal))
        XCTAssertTrue(TerminalApp.allCases.contains(.iterm))
        XCTAssertTrue(TerminalApp.allCases.contains(.warp))
        XCTAssertTrue(TerminalApp.allCases.contains(.alacritty))
    }
}
