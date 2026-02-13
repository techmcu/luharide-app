# Kill all node processes
Write-Host "🔧 Stopping all node processes..." -ForegroundColor Yellow
Get-Process -Name node -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

# Wait a bit
Start-Sleep -Seconds 2

# Check if port 3000 is free
$port3000 = netstat -ano | findstr :3000
if ($port3000) {
    Write-Host "⚠️  Port 3000 still in use, killing..." -ForegroundColor Yellow
    $port3000 | ForEach-Object {
        if ($_ -match '\s+(\d+)$') {
            Stop-Process -Id $matches[1] -Force -ErrorAction SilentlyContinue
        }
    }
    Start-Sleep -Seconds 1
}

Write-Host "✅ All processes stopped" -ForegroundColor Green
Write-Host ""
Write-Host "🚀 Starting backend server..." -ForegroundColor Cyan
Write-Host ""

# Start server
npm start
