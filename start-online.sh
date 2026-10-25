#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! command -v node >/dev/null 2>&1; then
    echo "❌ 找不到 Node.js，請先完成 host 安裝。" >&2
    exit 1
fi
exec node "$SCRIPT_DIR/start-online.mjs" "$@"
