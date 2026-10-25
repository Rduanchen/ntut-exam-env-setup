#!/usr/bin/env bash
# 由 setup.sh 以 source 載入，共用設定並在任一步驟失敗時停止。

# ------------------------------------------------------------------
# 學生端 (Desktop) 配置產生與同步
# ------------------------------------------------------------------
echo "--- [階段 6] 學生端 (Desktop) 設定同步 ---"

# 更新 client-setting/pre_settings.json
PRE_SETTINGS_FILE="$SCRIPT_DIR/client-setting/pre_settings.json"
cat > "$PRE_SETTINGS_FILE" <<EOF
{
  "testTitle": "北科大程式設計考試",
  "description": "測驗時間請遵從現場監考人員指示",
  "remoteHost": "http://${SERVER_IP}:${USER_PORT}"
}
EOF
echo "✅ 已同步產生學生端設定檔: $PRE_SETTINGS_FILE"
echo "   remoteHost => http://${SERVER_IP}:${USER_PORT}"

# 若存在 desktop 專案，檢查是否已建置
if [ -n "$DESKTOP_DIR" ]; then
    DIST_DIR="$DESKTOP_DIR/dist"
    # 尋找已編譯出的安裝檔
    BUILT_EXE=$(find "$DIST_DIR" -maxdepth 1 -name "ntut-code-tester-*-setup.exe" 2>/dev/null | head -n1 || true)
    if [ -n "$BUILT_EXE" ] && [ -f "$BUILT_EXE" ]; then
        echo "=> 發現已建置的學生端安裝檔: $(basename "$BUILT_EXE")"
        cp -f "$BUILT_EXE" "$SCRIPT_DIR/client-setting/ntut-code-tester.exe"
        echo "✅ 已複製至 client-setting/ntut-code-tester.exe"
    else
        echo "ℹ️ desktop 專案尚未打包 Windows 安裝檔。"
        echo "   若需打包，請至 desktop 目錄執行: npm install && npm run build:win"
        echo "   或執行 ./build-desktop.sh 自動處理。"
    fi
fi
echo ""
