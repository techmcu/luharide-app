@echo off
setlocal EnableExtensions
where gh >nul 2>&1
if errorlevel 1 (
  echo.
  echo [ERROR] GitHub CLI ^(gh^) nahi mila.
  echo Install:  winget install GitHub.cli
  echo Phir dubara ye file chalao.
  echo.
  pause
  exit /b 1
)

echo.
echo === GitHub login ===
echo Prompts follow karo ^(browser / token^). Ho jaane ke baad Git push theek chalega.
echo.
gh auth login
if errorlevel 1 (
  echo Login cancel / fail.
  pause
  exit /b 1
)

gh auth setup-git
echo.
echo === Ho gaya. Ab git push / Cursor se push chal sakta hai. ===
echo.
pause
