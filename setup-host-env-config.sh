#!/usr/bin/env bash
# 由 setup.sh 以 source 載入，共用設定並在任一步驟失敗時停止。

echo "--- [階段 2] 網路與連線組態 ---"

read -p "請輸入管理 API Port (預設: $ADMIN_PORT): " INPUT_ADMIN_PORT
ADMIN_PORT=${INPUT_ADMIN_PORT:-$ADMIN_PORT}

read -p "請輸入學生 API Port (預設: $USER_PORT): " INPUT_USER_PORT
USER_PORT=${INPUT_USER_PORT:-$USER_PORT}

read -p "請輸入前端網站 Port (預設: $FRONTEND_PORT): " INPUT_FRONTEND_PORT
FRONTEND_PORT=${INPUT_FRONTEND_PORT:-$FRONTEND_PORT}

read -p "請輸入 Piston 執行服務 Port (預設: $PISTON_PORT): " INPUT_PISTON_PORT
PISTON_PORT=${INPUT_PISTON_PORT:-$PISTON_PORT}

SEEN_PORTS=""
for PORT_NAME in ADMIN_PORT USER_PORT FRONTEND_PORT PISTON_PORT; do
    PORT_VALUE=${!PORT_NAME}
    if [[ ! "$PORT_VALUE" =~ ^[0-9]{1,5}$ ]]; then
        echo "❌ 錯誤：Port 必須是 1–65535 的整數。"
        exit 1
    fi
    PORT_VALUE=$((10#$PORT_VALUE))
    if [ "$PORT_VALUE" -lt 1 ] || [ "$PORT_VALUE" -gt 65535 ]; then
        echo "❌ 錯誤：Port 必須是 1–65535 的整數。"
        exit 1
    fi
    if [[ " $SEEN_PORTS " == *" $PORT_VALUE "* ]]; then
        echo "❌ 錯誤：管理、學生、前端與 Piston Port 必須各不相同。"
        exit 1
    fi
    printf -v "$PORT_NAME" '%s' "$PORT_VALUE"
    SEEN_PORTS="$SEEN_PORTS $PORT_VALUE"
done

echo "💡 提示：伺服器 IP 只會寫入學生端 pre_settings.json；管理端預設僅供本機使用。"
read -p "請輸入伺服器對外/區網 IP (預設: $SERVER_IP): " INPUT_SERVER_IP
SERVER_IP=${INPUT_SERVER_IP:-$SERVER_IP}

read -p "請設定 Admin Token (直接 Enter 將自動產生隨機安全金鑰): " ADMIN_TOKEN
if [ -z "$ADMIN_TOKEN" ]; then
    if command -v openssl >/dev/null 2>&1; then
        ADMIN_TOKEN=$(openssl rand -hex 16)
    else
        ADMIN_TOKEN=$(od -An -N16 -tx1 /dev/urandom | tr -d ' \n')
    fi
    echo "=> 已自動產生 Admin Token（儲存在環境檔中）。"
fi
if [[ ! "$ADMIN_TOKEN" =~ ^[A-Za-z0-9_-]{16,}$ ]] || [[ "$ADMIN_TOKEN" == "admin-secret" ]]; then
    echo "❌ 錯誤：Admin Token 至少需 16 字元，且只能包含英數字、底線或連字號。"
    exit 1
fi
echo ""

FRONTEND_BACKEND_URL="http://127.0.0.1:${ADMIN_PORT}"

# 寫入後端與前端環境變數
echo "=> 寫入後端設定 (backend/.env)..."
cat > "$HOST_DIR/backend/.env" <<EOF
ADMIN_PORT=$ADMIN_PORT
USER_PORT=$USER_PORT
FRONTEND_PORT=$FRONTEND_PORT
PISTON_PORT=$PISTON_PORT
ADMIN_LISTEN_HOST=127.0.0.1
PISTON_URL=http://localhost:$PISTON_PORT
ADMIN_TOKEN=$ADMIN_TOKEN
EOF

echo "=> 寫入前端設定 (frontend/.env)..."
cat > "$HOST_DIR/frontend/.env" <<EOF
VITE_BACKEND_URL=$FRONTEND_BACKEND_URL
VITE_ADMIN_TOKEN=$ADMIN_TOKEN
EOF
