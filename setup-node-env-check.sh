#!/usr/bin/env bash
# 由 setup.sh 以 source 載入，共用設定並在任一步驟失敗時停止。

# 檢查 Node.js 版本 (要求 >= 20.19.0)
if ! command -v node >/dev/null 2>&1; then
    echo "❌ 錯誤：找不到 Node.js！請安裝 Node.js >= 20.19.0。"
    exit 1
fi

NODE_VERSION=$(node -v | sed 's/^v//')
NODE_MAJOR=$(echo "$NODE_VERSION" | cut -d. -f1)
NODE_MINOR=$(echo "$NODE_VERSION" | cut -d. -f2)

if [ "$NODE_MAJOR" -lt 20 ] || { [ "$NODE_MAJOR" -eq 20 ] && [ "$NODE_MINOR" -lt 19 ]; }; then
    echo "❌ 錯誤：Node.js 版本過舊 (目前為 v$NODE_VERSION)！"
    echo "   host 系統要求 Node.js >= 20.19.0 (因 CommonJS require ESM-only p-limit@7 需求)。"
    echo "   請前往 https://nodejs.org/ 下載更新 Node.js。"
    exit 1
fi
echo "✅ Node.js 版本檢核通過: v$NODE_VERSION"

# 檢查 pnpm
if ! command -v pnpm >/dev/null 2>&1; then
    echo "=> 找不到 pnpm，正在為您全域安裝 pnpm..."
    npm install -g pnpm
fi
