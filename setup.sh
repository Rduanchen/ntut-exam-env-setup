#!/bin/bash

net session > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "======================================================="
    echo "❌ 錯誤：權限不足！請使用「系統管理員身分」執行此腳本。"
    echo "-------------------------------------------------------"
    echo "原因：本腳本需要管理員權限以自動設定 Windows 防火牆規則。"
    echo "請關閉此視窗，並對 Git Bash 圖示點擊右鍵，選擇「以系統管理員身分執行」。"
    echo "======================================================="
    read -p "按任意鍵結束..."
    exit 1
fi

# 確保腳本在 ntut-exam-env-setup 目錄下執行
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "======================================================="
echo "    NTUT Exam System - 快速部署與環境設定腳本"
echo "    (專為 Windows + Git Bash 環境設計)"
echo "======================================================="
echo ""

# ------------------------------------------------------------------
# 檢查必要專案結構
# ------------------------------------------------------------------
if [ ! -d "host" ]; then
    echo "=> 找不到 host 專案資料夾，自動幫您 clone 主系統..."
    git clone https://github.com/Rduanchen/ntut-exam-v2 host
fi

# ------------------------------------------------------------------
# 階段 1. 安裝環境
# ------------------------------------------------------------------
echo "--- [階段 1] 系統環境安裝與設定 ---"

read -p "請輸入後端 API Port (預設: 3000): " APP_PORT
APP_PORT=${APP_PORT:-3000}

read -p "請輸入前端網站 Port (預設: 5173): " FRONTEND_PORT
FRONTEND_PORT=${FRONTEND_PORT:-5173}

read -p "請問是否要使用 Docker 來部署主系統 (前端與後端)? (y/n): " USE_DOCKER
USE_DOCKER=${USE_DOCKER:-n}

if [[ "$USE_DOCKER" =~ ^[Nn]$ ]]; then
    echo "=> 選擇不使用 Docker，正在檢查 Node.js 環境..."
    # 檢查 Node.js 環境
    if ! command -v node >/dev/null 2>&1; then
        echo "❌ 錯誤：找不到 Node.js！請先至 https://nodejs.org/ 安裝 Node.js。"
        exit 1
    else
        NODE_VER=$(node -v)
        echo "✅ Node.js 已安裝 ($NODE_VER)。"
    fi

    # 檢查 pnpm
    if ! command -v pnpm >/dev/null 2>&1; then
        echo "=> 找不到 pnpm，正在為您全域安裝 pnpm..."
        npm install -g pnpm
    fi

    echo "=> 正在安裝主系統 (host) 的相依套件..."
    cd host
    pnpm install
    cd ..
else
    echo "=> 選擇使用 Docker 部署主系統。"
fi

# 設定 Windows 防火牆 (開放區域網路連線)
echo ""
echo "--- 區域網路連線與 Windows 防火牆設定 ---"
read -p "是否要自動設定 Windows 防火牆以允許區域網路內的其他電腦連線? (y/n): " ALLOW_FIREWALL
ALLOW_FIREWALL=${ALLOW_FIREWALL:-y}

if [[ "$ALLOW_FIREWALL" =~ ^[Yy]$ ]]; then
    # 檢查是否具有系統管理員權限
    net session > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "=> 已取得管理員權限，正在設定防火牆規則..."
        # 開放後端 Port
        netsh advfirewall firewall add rule name="NTUT Backend API ($APP_PORT)" dir=in action=allow protocol=TCP localport=$APP_PORT >/dev/null
        # 開放前端 Port
        netsh advfirewall firewall add rule name="NTUT Frontend ($FRONTEND_PORT)" dir=in action=allow protocol=TCP localport=$FRONTEND_PORT >/dev/null
        echo "✅ Windows 防火牆設定完成！(已允許 TCP Port $APP_PORT 與 $FRONTEND_PORT)"
    else
        echo "⚠️ 警告：權限不足！"
        echo "   無法自動設定防火牆，您必須對 Git Bash 右鍵點擊「以系統管理員身分執行」才能自動加入防火牆規則。"
        echo "   或是請手動前往「具有進階安全性的 Windows Defender 防火牆」開啟 Inbound TCP Port $APP_PORT 與 $FRONTEND_PORT。"
    fi
fi

echo ""

# ------------------------------------------------------------------
# 階段 2. Piston 部署
# ------------------------------------------------------------------
echo "--- [階段 2] Piston 程式碼執行環境部署 ---"
read -p "請問是否要部署 Piston? (需要已安裝 Docker Desktop) (y/n): " DEPLOY_PISTON
DEPLOY_PISTON=${DEPLOY_PISTON:-y}

read -p "請輸入 Piston 執行服務 Port (預設: 2000): " PISTON_PORT
PISTON_PORT=${PISTON_PORT:-2000}

if [[ "$DEPLOY_PISTON" =~ ^[Yy]$ ]]; then
    if ! command -v docker >/dev/null 2>&1; then
        echo "❌ 錯誤：找不到 Docker 命令！部署 Piston 必須依賴 Docker，請先安裝 Docker Desktop。"
    else
        if [ ! -d "piston" ]; then
            echo "=> 正在 clone Piston 專案..."
            git clone https://github.com/engineer-man/piston.git piston
        fi

        echo "=> 正在注入 Piston 環境變數..."
        PISTON_COMPOSE="piston/docker-compose.yaml"
        if [ -f "$PISTON_COMPOSE" ]; then
          if ! grep -q "PISTON_RUN_TIMEOUT" "$PISTON_COMPOSE"; then
            cat >> "$PISTON_COMPOSE" <<'ENVBLOCK'
        environment:
            - PISTON_RUN_TIMEOUT=30000
            - PISTON_RUN_CPU_TIME=30000
            - PISTON_COMPILE_TIMEOUT=10000
            - PISTON_COMPILE_CPU_TIME=10000
            - PISTON_OUTPUT_MAX_SIZE=10240
            - PISTON_RUN_MEMORY_LIMIT=-1
            - PISTON_COMPILE_MEMORY_LIMIT=-1
ENVBLOCK
          fi
        fi

        # 如果 PISTON_PORT 不是 2000，我們使用 sed 來替換 port
        if [ "$PISTON_PORT" != "2000" ]; then
            sed -i "s/2000:2000/$PISTON_PORT:2000/g" "$PISTON_COMPOSE"
        fi

        echo "=> 正在背景啟動 Piston 容器..."
        cd piston
        docker compose up -d
        cd ..
        echo "✅ Piston 部署完成！"
    fi
else
    echo "=> 略過 Piston 部署。"
fi

# ------------------------------------------------------------------
# 階段 3. 寫入變數與啟動系統
# ------------------------------------------------------------------
echo ""
echo "--- [階段 3] 產生環境變數與啟動系統 ---"

read -p "請設定 Admin Secret (直接 Enter 將自動產生隨機密碼): " ADMIN_SECRET
if [ -z "$ADMIN_SECRET" ]; then
    ADMIN_SECRET=$(LC_ALL=C tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 32 || echo "admin_secret_default_123")
    echo "=> 已自動產生 Admin Secret: $ADMIN_SECRET"
fi

# 設定後端 PISTON_URL (如果主系統用 Docker，則使用 host.docker.internal 連接本機的 Piston 容器)
if [[ "$USE_DOCKER" =~ ^[Yy]$ ]]; then
    BACKEND_PISTON_URL="http://host.docker.internal:$PISTON_PORT"
else
    BACKEND_PISTON_URL="http://localhost:$PISTON_PORT"
fi

echo "=> 正在寫入 host/.env 設定檔..."
cat > host/backend/.env <<EOF
PORT=$APP_PORT
PISTON_URL=$BACKEND_PISTON_URL
ADMIN_SECRET=$ADMIN_SECRET
EOF

cat > host/frontend/.env <<EOF
VITE_BACKEND_URL=http://localhost:$APP_PORT
EOF

if [[ "$USE_DOCKER" =~ ^[Yy]$ ]]; then
    echo "=> 正在使用 Docker Compose 啟動主系統..."
    cat > host/docker-compose.yml <<EOF
version: '3.8'

services:
  backend:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: ntut-backend
    command: pnpm --filter backend run start
    ports:
      - "$APP_PORT:3000"
    environment:
      - PORT=3000
      - PISTON_URL=$BACKEND_PISTON_URL
      - ADMIN_SECRET=$ADMIN_SECRET
      - DB_STORAGE=/app/data/database.sqlite
    volumes:
      - ./data:/app/data
    restart: unless-stopped

  frontend:
    build:
      context: .
      dockerfile: Dockerfile
      args:
        - VITE_BACKEND_URL=http://localhost:$APP_PORT
    container_name: ntut-frontend
    command: npx --yes serve -s frontend/dist -l 5173
    ports:
      - "$FRONTEND_PORT:5173"
    depends_on:
      - backend
    restart: unless-stopped
EOF
    cd host
    docker compose up -d --build
    cd ..
    echo "✅ Docker 系統啟動完成！"
else
    echo "=> 系統準備完成！"
    echo "=> 請開啟兩個獨立的 Git Bash 終端機，並先執行 'cd host'，然後分別執行以下指令來啟動伺服器："
    echo "   請使用以下的指令來啟動後端 API 服務："
    echo "   cd host"
    echo "   pnpm production"
fi

echo ""
echo "======================================================="
echo " 🎉 系統部署設定已順利完成！"
echo " 🌐 前端網站: http://localhost:$FRONTEND_PORT (若防火牆已開，可透過 IP 給區域網路內其他電腦連線)"
echo " 🔌 後端 API: http://localhost:$APP_PORT"
echo " 🔑 Admin Secret: $ADMIN_SECRET"
echo "======================================================="

# ------------------------------------------------------------------
# 階段 4. Piston 語言環境安裝 (需花費較長時間)
# ------------------------------------------------------------------
if [[ "$DEPLOY_PISTON" =~ ^[Yy]$ ]] && [ -d "piston" ]; then
    echo ""
    echo "--- [階段 4] Piston 語言環境安裝 ---"
    echo "現在系統與 Piston 已經啟動。接著可以選擇安裝 Piston 的語言環境 (如 gcc, python)。"
    echo "注意：安裝過程可能會花費非常長的時間！"
    echo "1) 安裝 Python"
    echo "2) 安裝 GCC (C/C++)"
    echo "3) 兩者皆安裝"
    echo "4) 跳過"
    read -p "請選擇您要安裝的語言 (1/2/3/4) [預設: 3]: " LANG_CHOICE
    LANG_CHOICE=${LANG_CHOICE:-3}

    if [ "$LANG_CHOICE" != "4" ]; then
        echo "=> 正在準備 Piston CLI 工具..."
        cd piston/cli
        npm install >/dev/null 2>&1
        cd ..

        if [ "$LANG_CHOICE" == "1" ] || [ "$LANG_CHOICE" == "3" ]; then
            echo "=> 正在安裝 Python (可能需數分鐘)..."
            node cli/index.js ppman install python
        fi
        if [ "$LANG_CHOICE" == "2" ] || [ "$LANG_CHOICE" == "3" ]; then
            echo "=> 正在安裝 GCC (可能需十數分鐘以上)..."
            node cli/index.js ppman install gcc
        fi
        
        cd ..
        echo "✅ Piston 語言環境安裝完成！"
    else
        echo "=> 已跳過語言安裝。"
    fi
fi
