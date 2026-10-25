#!/bin/bash
set -eo pipefail

# 集中設定環境變數預設值；可在執行 setup.sh 前透過環境變數覆寫。
ADMIN_PORT=${ADMIN_PORT:-3001}
USER_PORT=${USER_PORT:-3000}
FRONTEND_PORT=${FRONTEND_PORT:-5173}
PISTON_PORT=${PISTON_PORT:-2000}
SERVER_IP=${SERVER_IP:-0.0.0.0}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "======================================================="
echo "       NTUT Exam System - 環境設定與系統部署工具"
echo "======================================================="
echo ""

# ------------------------------------------------------------------
# 檢查作業系統與管理員權限
# ------------------------------------------------------------------
IS_WINDOWS=false
IS_ADMIN=false
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "win32" ]]; then
    IS_WINDOWS=true
    if net session > /dev/null 2>&1; then
        IS_ADMIN=true
    fi
fi

if [ "$IS_WINDOWS" = true ] && [ "$IS_ADMIN" = false ]; then
    echo "⚠️ 提示：未以「系統管理員身分」執行此視窗。"
    echo "   將無法自動設定 Windows 防火牆規則。若需要開放區網連線，部署後需手動開放 Port。"
    read -p "是否繼續執行設定？(y/n) [預設: y]: " CONT
    CONT=${CONT:-y}
    if [[ ! "$CONT" =~ ^[Yy]$ ]]; then
        exit 1
    fi
    echo ""
fi

# ------------------------------------------------------------------
# 檢查與定位關聯專案 (host 與 desktop)
# ------------------------------------------------------------------
echo "--- [階段 1] 檢查專案結構 ---"

# 定位 host 專案
HOST_DIR=""
if [ -d "$SCRIPT_DIR/host" ]; then
    HOST_DIR="$SCRIPT_DIR/host"
elif [ -d "$SCRIPT_DIR/../host" ]; then
    HOST_DIR="$(cd "$SCRIPT_DIR/../host" && pwd)"
fi

if [ -z "$HOST_DIR" ]; then
    echo "=> 找不到 host 主系統專案資料夾。"
    read -p "是否自動 clone host 專案至此目錄？(y/n) [預設: y]: " CLONE_HOST
    CLONE_HOST=${CLONE_HOST:-y}
    if [[ "$CLONE_HOST" =~ ^[Yy]$ ]]; then
        git clone --branch develop --single-branch https://github.com/Rduanchen/ntut-exam-v2.git "$SCRIPT_DIR/host"
        HOST_DIR="$SCRIPT_DIR/host"
    else
        echo "❌ 錯誤：找不到 host 專案，無法繼續部署。"
        exit 1
    fi
fi
echo "✅ 已定位 host 專案: $HOST_DIR"

# The default host branch still uses one public API port. This installer needs
# the split admin/student API contract provided by the develop branch.
if [ ! -f "$HOST_DIR/backend/src/index.ts" ] ||
   [ ! -f "$HOST_DIR/docker-compose.yml" ] ||
   ! grep -q 'USER_PORT' "$HOST_DIR/backend/src/index.ts" ||
   ! grep -q 'VITE_ADMIN_TOKEN' "$HOST_DIR/docker-compose.yml"; then
    echo "❌ 錯誤：host 版本與此部署工具不相容（需要雙 API Port 與管理端 Token）。"
    echo "   請使用 ntut-exam-v2 的 develop 分支，或移開舊版 host 後重新執行 setup.sh。"
    exit 1
fi

# 定位 desktop 專案 (選配)
DESKTOP_DIR=""
if [ -d "$SCRIPT_DIR/desktop" ]; then
    DESKTOP_DIR="$SCRIPT_DIR/desktop"
elif [ -d "$SCRIPT_DIR/../desktop" ]; then
    DESKTOP_DIR="$(cd "$SCRIPT_DIR/../desktop" && pwd)"
fi

if [ -n "$DESKTOP_DIR" ]; then
    echo "✅ 已定位 desktop 專案: $DESKTOP_DIR"
else
    echo "ℹ️ 未偵測到 desktop 專案資料夾 (將使用 client-setting/ 下既有設定)。"
fi
echo ""

# ------------------------------------------------------------------
# 網路與連線組態
# ------------------------------------------------------------------
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
for PORT_VALUE in "$ADMIN_PORT" "$USER_PORT" "$FRONTEND_PORT" "$PISTON_PORT"; do
    if [[ ! "$PORT_VALUE" =~ ^[0-9]+$ ]] || [ "$PORT_VALUE" -lt 1 ] || [ "$PORT_VALUE" -gt 65535 ]; then
        echo "❌ 錯誤：Port 必須是 1–65535 的整數。"
        exit 1
    fi
    if [[ " $SEEN_PORTS " == *" $PORT_VALUE "* ]]; then
        echo "❌ 錯誤：管理、學生、前端與 Piston Port 必須各不相同。"
        exit 1
    fi
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
        ADMIN_TOKEN=$(LC_ALL=C tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 32 || echo "ntut_exam_token_$(date +%s)")
    fi
    echo "=> 已自動產生 Admin Token（儲存在環境檔中）。"
fi
if [[ ! "$ADMIN_TOKEN" =~ ^[A-Za-z0-9_-]{16,}$ ]] || [[ "$ADMIN_TOKEN" == "admin-secret" ]]; then
    echo "❌ 錯誤：Admin Token 至少需 16 字元，且只能包含英數字、底線或連字號。"
    exit 1
fi
echo ""

# ------------------------------------------------------------------
# 選擇部署模式 (Docker vs 本機 Node.js)
# ------------------------------------------------------------------
echo "--- [階段 3] 選擇系統部署模式 ---"
echo "1) Docker 完整部署 (推薦：前端、後端與 Piston 均以容器運行，隔離且免配置相依性)"
echo "2) 本機 Node.js 部署 (在本地 Node 環境執行主系統，Piston 評測機以 Docker 運行)"
read -p "請選擇部署模式 (1/2) [預設: 1]: " DEPLOY_MODE
DEPLOY_MODE=${DEPLOY_MODE:-1}
if [[ "$DEPLOY_MODE" != "1" && "$DEPLOY_MODE" != "2" ]]; then
    echo "❌ 錯誤：部署模式只能選 1 或 2。"
    exit 1
fi

FRONTEND_BACKEND_URL="http://127.0.0.1:${ADMIN_PORT}"

if [ "$DEPLOY_MODE" = "1" ]; then
    echo ""
    echo "=> 選擇 [1] Docker 完整部署..."
    if ! command -v docker >/dev/null 2>&1; then
        echo "❌ 錯誤：找不到 Docker！請先安裝並啟動 Docker Desktop。"
        exit 1
    fi

    # 寫入 host/.env 供 docker compose 讀取
    echo "=> 正在寫入 host/.env 設定檔..."
    cat > "$HOST_DIR/.env" <<EOF
ADMIN_PORT=$ADMIN_PORT
USER_PORT=$USER_PORT
FRONTEND_PORT=$FRONTEND_PORT
PISTON_PORT=$PISTON_PORT
PISTON_URL=http://host.docker.internal:$PISTON_PORT
ADMIN_TOKEN=$ADMIN_TOKEN
ADMIN_BIND_HOST=127.0.0.1
FRONTEND_BIND_HOST=127.0.0.1
VITE_BACKEND_URL=$FRONTEND_BACKEND_URL
EOF

    echo "=> 啟動部署工具的 Piston 容器..."
    PISTON_PORT="$PISTON_PORT" docker compose -f "$SCRIPT_DIR/docker-compose.yaml" up -d
    echo "=> 正在使用 host Docker Compose 建置並啟動前後端..."
    docker compose --project-directory "$HOST_DIR" -f "$HOST_DIR/docker-compose.yml" up -d --build --no-deps backend frontend
    echo "✅ Docker 堆疊啟動指令已送出！"

else
    echo ""
    echo "=> 選擇 [2] 本機 Node.js 部署..."

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

    # 啟動 Piston 容器
    echo "=> 確保 Piston 評測機容器在背景運行..."
    if ! command -v docker >/dev/null 2>&1; then
        echo "❌ 錯誤：Piston 沙盒評測機仍需 Docker Desktop 運行！請先啟動 Docker。"
        exit 1
    fi
    PISTON_PORT=$PISTON_PORT docker compose -f "$SCRIPT_DIR/docker-compose.yaml" up -d

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
fi
echo ""

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

# ------------------------------------------------------------------
# Piston 語言環境安裝
# ------------------------------------------------------------------
echo "--- [階段 5] Piston 程式碼評測語言環境安裝 ---"
echo "正在等待 Piston 服務就緒..."
PISTON_URL="http://localhost:$PISTON_PORT"
READY=false
for i in {1..60}; do
    if curl -s -f "$PISTON_URL/api/v2/runtimes" >/dev/null 2>&1; then
        READY=true
        break
    fi
    sleep 1
done

if [ "$READY" = "true" ]; then
    echo "✅ Piston 服務連線正常 ($PISTON_URL)"
    echo "1) 安裝 Python (3.12.0)"
    echo "2) 安裝 GCC (C/C++ 10.2.0)"
    echo "3) Python 與 GCC 均安裝 (推薦)"
    echo "4) 跳過語言套件安裝"
    read -p "請選擇欲安裝的語言 (1/2/3/4) [預設: 3]: " LANG_CHOICE
    LANG_CHOICE=${LANG_CHOICE:-3}

    case "$LANG_CHOICE" in
        1)
            PISTON_PORT="$PISTON_PORT" bash "$SCRIPT_DIR/piston.sh" --no-start python
            ;;
        2)
            PISTON_PORT="$PISTON_PORT" bash "$SCRIPT_DIR/piston.sh" --no-start gcc
            ;;
        3)
            PISTON_PORT="$PISTON_PORT" bash "$SCRIPT_DIR/piston.sh" --no-start python gcc
            ;;
        *)
            echo "=> 跳過語言套件安裝。"
            ;;
    esac
else
    echo "❌ Piston API 未就緒 ($PISTON_URL)，部署驗證失敗。"
    exit 1
fi
echo ""

if [ "$DEPLOY_MODE" = "1" ] || { [ "$DEPLOY_MODE" = "2" ] && [[ "${USE_PM2:-n}" =~ ^[Yy]$ ]]; }; then
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

# ------------------------------------------------------------------
# 完成摘要報告
# ------------------------------------------------------------------
echo "======================================================="
echo " 🎉 NTUT Exam System 部署設定已完成！"
echo " 🌐 前端管理介面 (僅本機): http://127.0.0.1:${FRONTEND_PORT}"
echo " 🔒 管理 API (僅本機): http://127.0.0.1:${ADMIN_PORT}"
echo " 🔌 學生 API: http://${SERVER_IP}:${USER_PORT}"
echo " ⚙️ Piston 評測機: http://localhost:${PISTON_PORT}"
echo " 🔑 Admin Token 已寫入主系統環境檔"
echo "======================================================="
echo " 📁 學生端部署包位置: client-setting/"
echo "    包含已設定的 pre_settings.json 與部署腳本 test-deploy-v2.bat"
echo "======================================================="
