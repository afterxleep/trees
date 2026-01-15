# Trees

<p align="center">
  <img src="screenshot.png" alt="Trees menu bar app" width="420">
</p>

<p align="center">
  A macOS menu bar app for browsing repositories and creating git worktrees.
</p>

<p align="center">
  <a href="https://github.com/afterxleep/trees/releases/latest">Latest download</a>
</p>

## Overview

Trees scans your developer folder, shows your repos, and lets you open or create worktrees with a couple of clicks. It stays out of your way and lives in the menu bar.

## Features

- Fast repository list with search and git detection.
- One-click worktree creation.
- Open repositories and worktrees in Finder or your preferred terminal.

## Download

Get the notarized build from the latest release:

- https://github.com/afterxleep/trees/releases/latest

## Requirements

- macOS 14.0+
- Git available at `/usr/bin/git`

## Quick Start

1. Open `Trees.xcodeproj` in Xcode.
2. Select the `Trees` scheme and run on `My Mac`.
3. Open Settings and set your developer folder and preferred terminal.

## Usage

1. Click the Trees menu bar icon.
2. Search or select a repository.
3. Use the actions menu to create a worktree or open the repo.

## Development

- Run tests: `xcodebuild test -scheme Trees -destination 'platform=macOS'`
- The app runs as a menu bar extra and does not appear in the Dock.

## Release

Use the release script (requires Developer ID signing and notarization setup):

- `scripts/release.sh <version>`

Required environment variables:

- `SIGNING_IDENTITY` (Developer ID Application)
- `TEAM_ID`
- `NOTARIZE_PROFILE`

Optional local setup script (not committed): `scripts/setup-notarization.local.sh`

## Notes

- Terminal support includes Terminal, iTerm, Ghostty, Warp, and Alacritty.
- If the selected terminal is not installed, Trees shows an error message.
