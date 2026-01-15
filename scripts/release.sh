#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
PROJECT_PATH="$ROOT_DIR/Trees.xcodeproj"
SCHEME="Trees"
INFO_PLIST="$ROOT_DIR/Trees/Info.plist"
BUILD_DIR="$ROOT_DIR/build"
ARCHIVE_PATH="$BUILD_DIR/Trees.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"
APP_PATH="$EXPORT_PATH/Trees.app"

VERSION=${1:-}
if [[ -z "$VERSION" ]]; then
  echo "Usage: scripts/release.sh <version>" >&2
  exit 1
fi

if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Version must be in the form X.Y.Z" >&2
  exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Working tree is not clean. Commit or stash changes before releasing." >&2
  exit 1
fi

: "${NOTARY_PROFILE:?Set NOTARY_PROFILE to your notarytool keychain profile name}"

if ! command -v gh >/dev/null 2>&1; then
  echo "Missing GitHub CLI (gh). Install it and run 'gh auth login'." >&2
  exit 1
fi

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$INFO_PLIST"

git add "$INFO_PLIST"
git commit -m "Release $VERSION"
git tag -a "v$VERSION" -m "v$VERSION"

echo "Building archive..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

xcodebuild archive \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH"

EXPORT_OPTIONS_PLIST="$BUILD_DIR/exportOptions.plist"
cat > "$EXPORT_OPTIONS_PLIST" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>developer-id</string>
  <key>signingStyle</key>
  <string>automatic</string>
</dict>
</plist>
PLIST

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS_PLIST"

ZIP_PATH="$BUILD_DIR/Trees-$VERSION.zip"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

echo "Notarizing..."
xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$APP_PATH"

NOTE_FILE="$BUILD_DIR/release-notes.txt"
cat > "$NOTE_FILE" <<'EOF_NOTES'
Trees VERSION_PLACEHOLDER

- Notarized build
EOF_NOTES

sed -i '' "s/VERSION_PLACEHOLDER/$VERSION/g" "$NOTE_FILE"

git push origin main --tags

echo "Creating GitHub release..."
gh release create "v$VERSION" "$ZIP_PATH" \
  --title "v$VERSION" \
  --notes-file "$NOTE_FILE" \
  --latest

echo "Release complete: v$VERSION"
