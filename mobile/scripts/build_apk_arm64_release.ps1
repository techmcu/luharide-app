# Smaller APK: arm64-v8a only (most phones). Run from repo: mobile\
# Uses --split-per-abi so output is named app-arm64-v8a-release.apk (~smaller than universal).
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot\..

flutter build apk --release `
  --split-per-abi `
  --target-platform android-arm64 `
  --dart-define=STABLE_RELEASE=true

Write-Host ""
Write-Host "APK: $(Join-Path (Get-Location) 'build\app\outputs\flutter-apk\app-arm64-v8a-release.apk')"
