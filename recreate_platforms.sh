#!/usr/bin/env bash
set -e
cd "$(dirname -- "${BASH_SOURCE[0]}")"

rm -rf linux macos windows
flutter --suppress-analytics create . --platforms=linux,macos,windows --org net.alkatrazstudio --empty --no-pub
git apply init_platforms.diff

# https://learn.microsoft.com/en-us/windows/apps/design/style/iconography/app-icon-construction#icon-scaling
convert icon.png -resize 256x256 -define icon:auto-resize="256,48,32,24,16" windows/runner/resources/app_icon.ico

for size in 16 32 64 128 256 512 1024
do
    PNG_FILENAME="macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_${size}.png"
    convert icon.png -resize "${size}x${size}" "$PNG_FILENAME"
    pngcrush -ow -brute -reduce -noforce -nolimits -rem alla -rem tRNS "$PNG_FILENAME"
done
