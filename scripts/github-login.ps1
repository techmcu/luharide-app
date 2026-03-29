# GitHub par login (interactive). CMD se:  scripts\github-login.cmd
# PowerShell se:  powershell -ExecutionPolicy Bypass -File .\scripts\github-login.ps1

$ErrorActionPreference = "Stop"

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Host ""
    Write-Host "GitHub CLI (gh) nahi mila. Pehle install karo:" -ForegroundColor Yellow
    Write-Host "  winget install GitHub.cli" -ForegroundColor Cyan
    Write-Host ""
    exit 1
}

Write-Host ""
Write-Host "GitHub login — prompts follow karo (browser / token)." -ForegroundColor Cyan
gh auth login
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

gh auth setup-git
Write-Host ""
Write-Host "Ho gaya. Ab git push theek chalega is machine par." -ForegroundColor Green
Write-Host ""
