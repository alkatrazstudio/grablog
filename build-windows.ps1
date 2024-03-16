Push-Location "$PSScriptRoot"
try {
    flutter --suppress-analytics config --enable-windows-desktop
    flutter --suppress-analytics clean
    flutter --suppress-analytics pub get
    dart run build_runner build --delete-conflicting-outputs
    flutter --suppress-analytics analyze --no-pub

    $ts = Get-Date -UFormat %s
    $git_hash = git rev-parse HEAD
    flutter --suppress-analytics build windows `
        --release `
        --verbose `
        --dart-define=APP_BUILD_TIMESTAMP=$ts `
        --dart-define=APP_GIT_HASH=$git_hash
} finally {
    Pop-Location
}
