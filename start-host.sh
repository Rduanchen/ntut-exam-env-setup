#!/usr/bin/env bash
set -euo pipefail

SKIP_BUILD=false
case "${1:-}" in
    "") ;;
    --skip-build) SKIP_BUILD=true ;;
    *) echo "用法：bash start-host.sh [--skip-build]" >&2; exit 1 ;;
esac

# 取得這個腳本所在的目錄
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "======================================================="
echo "            NTUT Exam System - 啟動主系統"
echo "======================================================="

# 1. 尋找 host 專案目錄 (支援子目錄與同層目錄)
if [ -d "$SCRIPT_DIR/host" ]; then
    HOST_DIR="$SCRIPT_DIR/host"
elif [ -d "$SCRIPT_DIR/../host" ]; then
    HOST_DIR="$(cd "$SCRIPT_DIR/../host" && pwd)"
else
    echo "❌ 錯誤：找不到 host 專案目錄！請先執行 ./setup.sh 進行設定。"
    exit 1
fi
echo "=> 使用 host 目錄: $HOST_DIR"

if [ ! -f "$HOST_DIR/backend/.env" ] || [ ! -f "$HOST_DIR/frontend/.env" ]; then
    echo "❌ 缺少主系統環境設定檔，請先執行 setup.sh 設定環境。"
    exit 1
fi

# 只讀取連接埠數字，不執行 .env 中的任意內容。
FRONTEND_PORT=$(sed -n 's/^FRONTEND_PORT=//p' "$HOST_DIR/backend/.env" | tail -n1)
FRONTEND_PORT=${FRONTEND_PORT:-5173}
ADMIN_PORT=$(sed -n 's/^ADMIN_PORT=//p' "$HOST_DIR/backend/.env" | tail -n1)
ADMIN_PORT=${ADMIN_PORT:-3001}
USER_PORT=$(sed -n 's/^USER_PORT=//p' "$HOST_DIR/backend/.env" | tail -n1)
USER_PORT=${USER_PORT:-3000}
PISTON_PORT=$(sed -n 's/^PISTON_PORT=//p' "$HOST_DIR/backend/.env" | tail -n1)
PISTON_PORT=${PISTON_PORT:-2000}

# 3. 檢查 Node.js 版本 (要求 >= 20.19.0)
if ! command -v node >/dev/null 2>&1; then
    echo "❌ 錯誤：找不到 Node.js！請安裝 Node.js >= 20.19.0。"
    exit 1
fi

NODE_VERSION=$(node -v | sed 's/^v//')
NODE_MAJOR=$(echo "$NODE_VERSION" | cut -d. -f1)
NODE_MINOR=$(echo "$NODE_VERSION" | cut -d. -f2)

if [ "$NODE_MAJOR" -lt 20 ] || { [ "$NODE_MAJOR" -eq 20 ] && [ "$NODE_MINOR" -lt 19 ]; }; then
    echo "❌ 錯誤：Node.js 版本過舊 (v$NODE_VERSION)！"
    echo "   host 系統要求 Node.js >= 20.19.0 (因 CommonJS 載入 ESM 套件需支援)。"
    exit 1
fi
echo "✅ Node.js 版本符合要求: v$NODE_VERSION"

# 4. 安裝套件、建置與啟動
cd "$HOST_DIR"

if ! command -v pnpm >/dev/null 2>&1; then
    echo "=> 找不到 pnpm，正在全域安裝 pnpm..."
    npm install -g pnpm
fi

if [ "$SKIP_BUILD" = false ]; then
    echo "=> 安裝相依套件..."
    pnpm install

    echo "=> 建置系統..."
    pnpm build
fi

echo "=> 啟動後端與本機管理前端..."
pnpm --filter backend start &
BACKEND_PID=$!
FRONTEND_PID=""
cleanup() {
    trap - EXIT
    kill "$BACKEND_PID" ${FRONTEND_PID:+"$FRONTEND_PID"} 2>/dev/null || true
    wait "$BACKEND_PID" ${FRONTEND_PID:+"$FRONTEND_PID"} 2>/dev/null || true
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
pnpm --filter frontend exec vite preview --host 127.0.0.1 --port "$FRONTEND_PORT" --strictPort &
FRONTEND_PID=$!

source "$SCRIPT_DIR/setup-verify-services.sh"
echo "✅ 主系統已啟動，按 Ctrl+C 停止前後端。"
# 任一服務結束時一併收尾，避免只剩另一個服務繼續運行。
while kill -0 "$BACKEND_PID" 2>/dev/null && kill -0 "$FRONTEND_PID" 2>/dev/null; do
    sleep 1
done
if ! kill -0 "$BACKEND_PID" 2>/dev/null; then
    wait "$BACKEND_PID"
else
    wait "$FRONTEND_PID"
fi
