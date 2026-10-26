#!/usr/bin/env bash
# 由 setup.sh 以 source 載入，共用設定並在任一步驟失敗時停止。

# ------------------------------------------------------------------
# Windows 防火牆設定
# ------------------------------------------------------------------
if [ "$IS_WINDOWS" = true ] && [ "$IS_ADMIN" = true ]; then
    echo "--- [階段 4] Windows 防火牆設定 ---"
    if ! read -r -p "是否自動開放學生 API Port $USER_PORT 與管理 API Port $ADMIN_PORT？(y/n) [預設: y]: " ALLOW_FIREWALL; then
        echo "❌ 輸入已結束，未設定 Windows 防火牆。" >&2
        exit 1
    fi
    ALLOW_FIREWALL=${ALLOW_FIREWALL:-y}
    if [[ "$ALLOW_FIREWALL" =~ ^[Yy]$ ]]; then
        netsh advfirewall firewall delete rule name="NTUT Student API ($USER_PORT)" >/dev/null 2>&1 || true
        if ! netsh advfirewall firewall add rule \
            name="NTUT Student API ($USER_PORT)" dir=in action=allow \
            protocol=TCP localport="$USER_PORT"; then
            echo "❌ 無法新增學生 API Port $USER_PORT 的防火牆規則。" >&2
            exit 1
        fi

        netsh advfirewall firewall delete rule name="NTUT Admin API ($ADMIN_PORT)" >/dev/null 2>&1 || true
        if ! netsh advfirewall firewall add rule \
            name="NTUT Admin API ($ADMIN_PORT)" dir=in action=allow \
            protocol=TCP localport="$ADMIN_PORT"; then
            echo "❌ 無法新增管理 API Port $ADMIN_PORT 的防火牆規則。" >&2
            exit 1
        fi
        echo "✅ Windows 防火牆設定完成！"
    fi
    echo ""
fi
