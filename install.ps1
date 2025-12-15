# 等同 set -euo pipefail：遇到錯誤就停（PowerShell 沒有 pipefail 的完全等價，但 Stop 已足夠）
$ErrorActionPreference = "Stop"

# 取得腳本所在目錄並切過去（等同 SCRIPT_DIR + cd）
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

function Clone-Or-Update {
  param(
    [Parameter(Mandatory=$true)][string]$Url,
    [Parameter(Mandatory=$true)][string]$Dir
  )

  $GitDir = Join-Path $Dir ".git"

  if (Test-Path $GitDir) {
    Write-Host "Updating $Dir ..."
    git -C $Dir pull --rebase
  }
  else {
    Write-Host "Cloning $Url into $Dir ..."
    git clone $Url $Dir
  }
}

Clone-Or-Update -Url "https://github.com/Rduanchen/ntut-exam-system-backend.git" -Dir "backend"
Clone-Or-Update -Url "https://github.com/Rduanchen/ntut-exam-system-ta-frontend.git" -Dir "frontend"
Clone-Or-Update -Url "https://github.com/engineer-man/piston.git" -Dir "piston"

Write-Host "Done."