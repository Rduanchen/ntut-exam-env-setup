#!/usr/bin/env bash
# 由 setup.sh 以 source 載入，共用設定並在任一步驟失敗時停止。

if [[ "${USE_PM2:-n}" =~ ^[Yy]$ ]]; then
    echo "=> 確認管理與學生 API 均已就緒..."
    for API_PORT in "$ADMIN_PORT" "$USER_PORT"; do
        API_READY=false
        for i in {1..60}; do
            if curl -s -f "http://127.0.0.1:$API_PORT/health" >/dev/null 2>&1; then
                API_READY=true
                break
            fi
            sleep 1
        done
        if [ "$API_READY" != "true" ]; then
            echo "❌ Port $API_PORT 的 API 未通過健康檢查，部署驗證失敗。"
            exit 1
        fi
    done
    echo "✅ 管理與學生 API 均已就緒。"
    FRONTEND_READY=false
    for i in {1..60}; do
        if curl -s -f "http://127.0.0.1:$FRONTEND_PORT/" >/dev/null 2>&1; then
            FRONTEND_READY=true
            break
        fi
        sleep 1
    done
    if [ "$FRONTEND_READY" != "true" ]; then
        echo "❌ 管理前端 Port $FRONTEND_PORT 未就緒，部署驗證失敗。"
        exit 1
    fi
    echo "✅ 管理前端已就緒。"
else
    echo "ℹ️ 未選擇 PM2；主系統已建置但尚未啟動，請執行 ./start-host.sh。"
fi
