#!/usr/bin/env bash
set -e
cd "$(dirname -- "${BASH_SOURCE[0]}")"

if [[ "$(uname)" == "Darwin" ]]
then
    PLATFORM=macos
    flutter --suppress-analytics config --enable-macos-desktop
else
    PLATFORM=linux
    flutter --suppress-analytics config --enable-linux-desktop
fi

flutter --suppress-analytics clean
flutter --suppress-analytics pub get
dart run build_runner build --delete-conflicting-outputs
flutter --suppress-analytics analyze --no-pub

flutter --suppress-analytics build "$PLATFORM" \
    --release \
    --verbose \
    --dart-define=APP_BUILD_TIMESTAMP="$(date +%s)" \
    --dart-define=APP_GIT_HASH="$(git rev-parse HEAD)"
