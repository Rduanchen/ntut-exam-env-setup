#!/usr/bin/env bash
set -euo pipefail

# 取得這個 bash 檔所在的目錄
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "$SCRIPT_DIR/backend"

echo "Starting backend service ..."

# 使用 npm 啟動服務
npm install
npm run dev

echo "Backend service started."