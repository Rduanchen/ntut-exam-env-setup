#!/usr/bin/env bash
# 由 setup.sh 以 source 載入，共用設定並在任一步驟失敗時停止。

echo "--- [階段 1] 檢查專案結構 ---"

# 定位 host 專案
HOST_DIR=""
if [ -d "$SCRIPT_DIR/host" ]; then
    HOST_DIR="$SCRIPT_DIR/host"
elif [ -d "$SCRIPT_DIR/../host" ]; then
    HOST_DIR="$(cd "$SCRIPT_DIR/../host" && pwd)"
fi

if [ -z "$HOST_DIR" ]; then
    echo "=> 找不到 host 主系統專案資料夾。"
    read -p "是否自動 clone host 專案至此目錄？(y/n) [預設: y]: " CLONE_HOST
    CLONE_HOST=${CLONE_HOST:-y}
    if [[ "$CLONE_HOST" =~ ^[Yy]$ ]]; then
        git clone --branch develop --single-branch https://github.com/Rduanchen/ntut-exam-v2.git "$SCRIPT_DIR/host"
        HOST_DIR="$SCRIPT_DIR/host"
    else
        echo "❌ 錯誤：找不到 host 專案，無法繼續部署。"
        exit 1
    fi
fi
echo "✅ 已定位 host 專案: $HOST_DIR"

# The default host branch still uses one public API port. This installer needs
# the split admin/student API contract provided by the develop branch.
if [ ! -f "$HOST_DIR/backend/src/index.ts" ] ||
   [ ! -d "$HOST_DIR/frontend/src" ] ||
   ! grep -q 'USER_PORT' "$HOST_DIR/backend/src/index.ts" ||
   ! grep -rq 'VITE_ADMIN_TOKEN' "$HOST_DIR/frontend/src"; then
    echo "❌ 錯誤：host 版本與此部署工具不相容（需要雙 API Port 與管理端 Token）。"
    echo "   請使用 ntut-exam-v2 的 develop 分支，或移開舊版 host 後重新執行 setup.sh。"
    exit 1
fi

# 定位 desktop 專案 (選配)
DESKTOP_DIR=""
if [ -d "$SCRIPT_DIR/desktop" ]; then
    DESKTOP_DIR="$SCRIPT_DIR/desktop"
elif [ -d "$SCRIPT_DIR/../desktop" ]; then
    DESKTOP_DIR="$(cd "$SCRIPT_DIR/../desktop" && pwd)"
fi

if [ -n "$DESKTOP_DIR" ]; then
    echo "✅ 已定位 desktop 專案: $DESKTOP_DIR"
else
    echo "ℹ️ 未偵測到 desktop 專案資料夾 (將使用 client-setting/ 下既有設定)。"
fi
echo ""
