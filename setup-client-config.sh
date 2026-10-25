#!/usr/bin/env bash
# 由 setup.sh 以 source 載入，共用設定並在任一步驟失敗時停止。

# ------------------------------------------------------------------
# 學生端派送設定產生
# ------------------------------------------------------------------
echo "--- [階段 6] 學生端派送設定產生 ---"

source "$SCRIPT_DIR/setup-server-ip.sh"
confirm_server_ip || exit 1

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

echo ""
