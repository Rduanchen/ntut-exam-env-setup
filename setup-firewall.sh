#!/usr/bin/env bash
# 由 setup.sh 以 source 載入，共用設定並在任一步驟失敗時停止。

# ------------------------------------------------------------------
# Windows 防火牆設定
# ------------------------------------------------------------------
if [ "$IS_WINDOWS" = true ] && [ "$IS_ADMIN" = true ]; then
    echo "--- [階段 4] Windows 防火牆設定 ---"
    read -p "是否自動開放學生 API Port $USER_PORT？管理 Port 不會開放給學生 (y/n) [預設: y]: " ALLOW_FIREWALL
    ALLOW_FIREWALL=${ALLOW_FIREWALL:-y}
    if [[ "$ALLOW_FIREWALL" =~ ^[Yy]$ ]]; then
        netsh advfirewall firewall delete rule name="NTUT Student API ($USER_PORT)" >/dev/null 2>&1 || true
        netsh advfirewall firewall add rule name="NTUT Student API ($USER_PORT)" dir=in action=allow protocol=TCP localport="$USER_PORT" >/dev/null
        echo "✅ Windows 防火牆設定完成！"
    fi
    echo ""
fi
