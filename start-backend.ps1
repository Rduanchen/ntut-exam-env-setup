
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

# 切換到 backend 目錄 並啟動服務
Set-Location (Join-Path $ScriptDir "backend")
Write-Host "Starting backend service ..."

# 使用 npm 啟動服務
npm install
npm run dev
Write-Host "Backend service started."