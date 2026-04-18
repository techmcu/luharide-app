# Build LuhaRide for web (same UI as APK) — run from repo: mobile\
# Usage:  .\scripts\build_web_production.ps1
# Then upload folder mobile\build\web\* to VPS: /var/www/luharide-web/

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot\..

flutter build web --release `
  --base-href /app/ `
  --dart-define=API_BASE_URL=https://luharide.cloud/api `
  --dart-define=SOCKET_URL=https://luharide.cloud `
  --dart-define=STABLE_RELEASE=true

Write-Host ""
Write-Host "Output: $(Join-Path (Get-Location) 'build\web')"
Write-Host "Deploy: scp -r build/web/* user@YOUR_VPS:/var/www/luharide-web/"
Write-Host "Then on VPS (repo clone): sudo bash infra/scripts/setup-root-website-nginx.sh"
