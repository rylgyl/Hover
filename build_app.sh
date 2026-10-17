#!/bin/zsh
# Builds Hover.app into dist/ and ad-hoc signs it.
set -e
cd "$(dirname "$0")"

swift build -c release

APP=dist/Hover.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Hover "$APP/Contents/MacOS/Hover"
cp Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
echo "Built $APP"
