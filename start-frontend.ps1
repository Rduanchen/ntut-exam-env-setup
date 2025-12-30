$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

Set-Location (Join-Path $ScriptDir "frontend")
Write-Host "Starting frontend service ..."

npm install
npm run dev
Write-Host "Frontend service started."
