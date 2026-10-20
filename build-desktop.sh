#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "======================================================="
echo "       NTUT Exam Desktop Client 打包與同步工具"
echo "======================================================="

# 1. 尋找 desktop 專案
DESKTOP_DIR=""
if [ -d "$SCRIPT_DIR/desktop" ]; then
    DESKTOP_DIR="$SCRIPT_DIR/desktop"
elif [ -d "$SCRIPT_DIR/../desktop" ]; then
    DESKTOP_DIR="$(cd "$SCRIPT_DIR/../desktop" && pwd)"
fi

if [ -z "$DESKTOP_DIR" ]; then
    echo "❌ 錯誤：找不到 desktop 專案目錄！"
    echo "   請確認 desktop 專案位於 $SCRIPT_DIR/desktop 或 $SCRIPT_DIR/../desktop"
    exit 1
fi
echo "=> 使用 desktop 目錄: $DESKTOP_DIR"

# 2. 詢問是否進行編譯
echo ""
echo "請選擇操作："
echo "1) 在 desktop 專案執行 Windows 安裝檔打包 (npm run build:win) 並同步"
echo "2) 僅同步既有的 desktop/dist/ 安裝檔至 client-setting/"
echo "3) 將 client-setting 打包為 client-deploy.zip (方便透過廣播軟體分派)"
read -p "請選擇 (1/2/3) [預設: 1]: " ACTION
ACTION=${ACTION:-1}

if [ "$ACTION" = "1" ]; then
    echo "=> 正在進入 desktop 專案進行建置與打包..."
    cd "$DESKTOP_DIR"
    
    if ! command -v npm >/dev/null 2>&1; then
        echo "❌ 錯誤：找不到 npm 指令！請先安裝 Node.js。"
        exit 1
    fi

    echo "=> 安裝相依套件..."
    npm install

    echo "=> 執行 Windows 安裝檔打包 (electron-builder --win)..."
    npm run build:win
    cd "$SCRIPT_DIR"
fi

# 3. 尋找與同步安裝檔
DIST_DIR="$DESKTOP_DIR/dist"
INSTALLER=$(find "$DIST_DIR" -maxdepth 1 -name "ntut-code-tester-*-setup.exe" 2>/dev/null | sort -V | tail -n1 || true)

if [ -n "$INSTALLER" ] && [ -f "$INSTALLER" ]; then
    echo "=> 找到安裝檔: $(basename "$INSTALLER")"
    cp -f "$INSTALLER" "$SCRIPT_DIR/client-setting/ntut-code-tester.exe"
    echo "✅ 成功複製為 $SCRIPT_DIR/client-setting/ntut-code-tester.exe"
else
    if [ "$ACTION" != "3" ]; then
        echo "⚠️ 警告：在 $DIST_DIR 下未找到 ntut-code-tester-*-setup.exe！"
        echo "   請確認是否有成功打包，或將產出的安裝檔手動放置於 client-setting/ntut-code-tester.exe。"
    fi
fi

# 4. 若選擇打包 zip
if [ "$ACTION" = "3" ]; then
    ZIP_NAME="client-deploy.zip"
    echo "=> 正在將 client-setting/ 打包至 $ZIP_NAME ..."
    rm -f "$SCRIPT_DIR/$ZIP_NAME"
    cd "$SCRIPT_DIR"
    if command -v zip >/dev/null 2>&1; then
        zip -r "$ZIP_NAME" client-setting/ -x "*.DS_Store"
    elif command -v 7z >/dev/null 2>&1; then
        7z a "$ZIP_NAME" client-setting/
    elif command -v powershell >/dev/null 2>&1; then
        powershell -Command "Compress-Archive -Path 'client-setting' -DestinationPath '$ZIP_NAME' -Force"
    else
        echo "⚠️ 找不到 zip 工具，請手動壓縮 client-setting 資料夾。"
    fi
    if [ -f "$SCRIPT_DIR/$ZIP_NAME" ]; then
        echo "✅ 打包完成: $SCRIPT_DIR/$ZIP_NAME"
    fi
fi

echo "======================================================="
echo "學生端同步作業完成！"
echo "======================================================="
