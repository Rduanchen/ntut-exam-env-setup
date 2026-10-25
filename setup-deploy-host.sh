#!/usr/bin/env bash
# 由 setup.sh 以 source 載入，共用設定並在任一步驟失敗時停止。

echo "--- [階段 3] 本機 Node.js 建置與啟動 ---"
# 安裝與建置主系統
echo "=> 正在安裝主系統 (host) 相依套件..."
cd "$HOST_DIR"
pnpm install

echo "=> 正在建置主系統 (前端與後端編譯)..."
pnpm build
cd "$SCRIPT_DIR"

# 詢問啟動方式
read -p "是否要使用 PM2 將系統常駐於背景運行 (推薦)? (y/n) [預設: y]: " USE_PM2
USE_PM2=${USE_PM2:-y}

if [[ "$USE_PM2" =~ ^[Yy]$ ]]; then
    if ! command -v pm2 >/dev/null 2>&1; then
        echo "=> 正在安裝 pm2..."
        npm install -g pm2
    fi
    echo "=> 使用 PM2 啟動後端與前端..."
    cd "$HOST_DIR"
    pm2 delete ntut-backend ntut-frontend 2>/dev/null || true
    pm2 start pnpm --name "ntut-backend" -- --filter backend start
    pm2 start pnpm --name "ntut-frontend" -- --filter frontend exec vite preview --host 127.0.0.1 --port "$FRONTEND_PORT" --strictPort
    pm2 save || true
    cd "$SCRIPT_DIR"
    echo "✅ 系統已於背景透過 PM2 啟動！可用 'pm2 list' 或 'pm2 logs' 檢視狀態。"
else
    echo "=> 您可以隨時執行 ./start-host.sh 啟動服務。"
fi
echo ""
