#!/usr/bin/env bash
set -euo pipefail

# 取得這個 bash 檔所在的目錄
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1. 切換到 piston 目錄
cd "$SCRIPT_DIR/piston"

# 2. 進入 cli，安裝 npm 套件，再回到 piston
cd cli
npm install
cd -

# 3. 執行 ppman 安裝 python
node cli/index.js ppman install python

echo "Piston setup done."
