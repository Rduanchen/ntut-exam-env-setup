#!/usr/bin/env bash
# 由 setup.sh 以 source 載入，共用設定並在任一步驟失敗時停止。

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
        4)
            echo "=> 跳過語言套件安裝。"
            ;;
        *)
            echo "❌ 錯誤：語言選項只能選 1、2、3 或 4。"
            exit 1
            ;;
    esac
else
    echo "❌ Piston API 未就緒 ($PISTON_URL)，部署驗證失敗。"
    exit 1
fi
echo ""
