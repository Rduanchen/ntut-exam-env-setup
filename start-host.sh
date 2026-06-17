#!/usr/bin/env bash
set -euo pipefail

# 取得這個 bash 檔所在的目錄
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1. 切換到 host 目錄
cd "$SCRIPT_DIR/host"
pnpm install
pnpm production

echo "host setup done."
