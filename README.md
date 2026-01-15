# Trees

Trees is a lightweight macOS menu bar app for managing git repositories and worktrees under your developer folder.

## Features

- Lists repositories from a configurable developer folder.
- Creates git worktrees and opens them in your preferred terminal.
- Quick actions to open repositories and worktrees in Finder or Terminal.

## Requirements

- macOS 14.0+
- Xcode 15+ (Swift 5.9)
- Git installed and available at `/usr/bin/git`

## Getting Started

1. Open `Trees.xcodeproj` in Xcode.
2. Select the `Trees` scheme and run on `My Mac`.
3. Open Settings and choose your developer folder and preferred terminal.

## Usage

1. Click the Trees menu bar icon.
2. Find a repository in the list.
3. Use the actions menu to create a worktree or open the repo.

## Release Checklist

1. Update version numbers in `Trees/Info.plist`.
2. Run tests: `xcodebuild test -scheme Trees -destination 'platform=macOS'`.
3. Archive the app from Xcode for distribution.

## Notes

- Terminal support includes Terminal, iTerm, Ghostty, Warp, and Alacritty.
- If a terminal app is not installed, Trees will show an error message.
