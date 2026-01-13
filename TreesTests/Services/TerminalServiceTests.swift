import XCTest
@testable import Trees

final class TerminalServiceTests: XCTestCase {

    var sut: TerminalService!

    override func setUp() {
        super.setUp()
        sut = TerminalService()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Command Building Tests

    func testBuildCommand_ghostty() {
        let directory = URL(fileURLWithPath: "/Users/test/project")
        let command = "cld"

        let script = sut.buildAppleScript(
            for: .ghostty,
            directory: directory,
            command: command
        )

        XCTAssertTrue(script.contains("Ghostty"))
        XCTAssertTrue(script.contains("/Users/test/project"))
        XCTAssertTrue(script.contains("cld"))
    }

    func testBuildCommand_terminal() {
        let directory = URL(fileURLWithPath: "/Users/test/project")
        let command = "cld"

        let script = sut.buildAppleScript(
            for: .terminal,
            directory: directory,
            command: command
        )

        XCTAssertTrue(script.contains("Terminal"))
        XCTAssertTrue(script.contains("/Users/test/project"))
        XCTAssertTrue(script.contains("cld"))
    }

    func testBuildCommand_iterm() {
        let directory = URL(fileURLWithPath: "/Users/test/project")
        let command = "cld"

        let script = sut.buildAppleScript(
            for: .iterm,
            directory: directory,
            command: command
        )

        XCTAssertTrue(script.contains("iTerm"))
        XCTAssertTrue(script.contains("/Users/test/project"))
        XCTAssertTrue(script.contains("cld"))
    }

    func testBuildCommand_warp() {
        let directory = URL(fileURLWithPath: "/Users/test/project")
        let command = "cld"

        let script = sut.buildAppleScript(
            for: .warp,
            directory: directory,
            command: command
        )

        XCTAssertTrue(script.contains("Warp"))
        XCTAssertTrue(script.contains("/Users/test/project"))
        XCTAssertTrue(script.contains("cld"))
    }

    func testBuildCommand_alacritty() {
        let directory = URL(fileURLWithPath: "/Users/test/project")
        let command = "cld"

        let script = sut.buildAppleScript(
            for: .alacritty,
            directory: directory,
            command: command
        )

        XCTAssertTrue(script.contains("Alacritty"))
        XCTAssertTrue(script.contains("/Users/test/project"))
        XCTAssertTrue(script.contains("cld"))
    }

    func testBuildCommand_escapesSpecialCharacters() {
        let directory = URL(fileURLWithPath: "/Users/test/my project")
        let command = "echo 'hello'"

        let script = sut.buildAppleScript(
            for: .terminal,
            directory: directory,
            command: command
        )

        // Should handle paths with spaces
        XCTAssertTrue(script.contains("my project") || script.contains("my\\ project"))
    }

    // MARK: - Terminal App Properties

    func testTerminalAppBundleIdentifiers() {
        XCTAssertEqual(TerminalApp.ghostty.bundleIdentifier, "com.mitchellh.ghostty")
        XCTAssertEqual(TerminalApp.terminal.bundleIdentifier, "com.apple.Terminal")
        XCTAssertEqual(TerminalApp.iterm.bundleIdentifier, "com.googlecode.iterm2")
        XCTAssertEqual(TerminalApp.warp.bundleIdentifier, "dev.warp.Warp-Stable")
        XCTAssertEqual(TerminalApp.alacritty.bundleIdentifier, "org.alacritty")
    }

    func testTerminalAppDisplayNames() {
        XCTAssertEqual(TerminalApp.ghostty.rawValue, "Ghostty")
        XCTAssertEqual(TerminalApp.terminal.rawValue, "Terminal")
        XCTAssertEqual(TerminalApp.iterm.rawValue, "iTerm")
        XCTAssertEqual(TerminalApp.warp.rawValue, "Warp")
        XCTAssertEqual(TerminalApp.alacritty.rawValue, "Alacritty")
    }
}
