#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION=$(sed -n 's/.*MARKETING_VERSION: "\(.*\)"/\1/p' project.yml)
BUILD=$(mktemp -d)
APP="$BUILD/Build/Products/Release/Keepset.app"

xcodebuild -project Keepset.xcodeproj -scheme Keepset -configuration Release \
    -derivedDataPath "$BUILD" build

# The demo seed must hold only images: the working copy's trash and marker are local state.
rm -rf "$APP/Contents/Resources/photos/.Trash" "$APP/Contents/Resources/photos/.keepset-sandbox"
codesign --force --sign - --options runtime --entitlements Keepset/Keepset.entitlements "$APP"
codesign --verify --deep --strict "$APP"

mkdir -p release
ZIP="release/Keepset-$VERSION.zip"
rm -f "$ZIP"
ditto -c -k --norsrc --noextattr --keepParent "$APP" "$ZIP"
rm -rf "$BUILD"
echo "built $ZIP"
