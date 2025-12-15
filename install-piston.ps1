# 等同 set -euo pipefail：遇到錯誤就停
$ErrorActionPreference = "Stop"

# 取得這個 PowerShell 腳本所在的目錄（等同 SCRIPT_DIR）
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# 1. 切換到 piston 目錄
$PistonDir = Join-Path $ScriptDir "piston"
Set-Location $PistonDir

# 2. 進入 cli，安裝 npm 套件，再回到 piston
$CliDir = Join-Path $PistonDir "cli"
Push-Location $CliDir
npm install
Pop-Location

# 3. 執行 ppman 安裝 python
node (Join-Path $CliDir "index.js") ppman install python

Write-Host "Piston setup done."