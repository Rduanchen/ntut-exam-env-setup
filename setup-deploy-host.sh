#!/usr/bin/env bash
# 由 setup.sh 以 source 載入，共用設定並在任一步驟失敗時停止。

echo "--- [階段 3] 本機 Node.js 安裝與建置 ---"
# 安裝與建置主系統
echo "=> 正在安裝主系統 (host) 相依套件..."
cd "$HOST_DIR"
pnpm install

echo "=> 正在建置主系統 (前端與後端編譯)..."
pnpm build
cd "$SCRIPT_DIR"

HOST_BUILT=true
echo "✅ 主系統建置完成，最後將統一透過 start-host.sh 啟動。"
echo ""
