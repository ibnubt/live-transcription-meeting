#!/bin/bash
# Build "Live Transcription.app" (butuh Command Line Tools / Xcode, macOS 26).
set -euo pipefail
cd "$(dirname "$0")"
HOME_DIR="$PWD"
APP="build/Live Transcription.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
swiftc -O -swift-version 5 -target arm64-apple-macos26.0 \
  -o "$APP/Contents/MacOS/LiveTranscription" Sources/*.swift
sed "s|__HOME__|$HOME_DIR|" Info.plist > "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
echo "OK → $APP"
