#!/usr/bin/env bash
set -euo pipefail

# 取得這個腳本所在的目錄
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PISTON_PORT="${PISTON_PORT:-2000}"

echo "======================================================="
echo "       Piston 程式碼執行環境啟動與語言套件安裝"
echo "======================================================="

# 1. 檢查 Docker
if ! command -v docker >/dev/null 2>&1; then
    echo "❌ 錯誤：找不到 Docker！請先安裝並啟動 Docker Desktop。"
    exit 1
fi

# 2. 啟動 Piston 容器
echo "=> 啟動 Piston 容器 (Port: $PISTON_PORT)..."
docker compose -f "$SCRIPT_DIR/docker-compose.yaml" up -d

# 3. 等待 Piston API 就緒
echo -n "=> 等待 Piston 服務就緒..."
PISTON_URL="http://localhost:$PISTON_PORT"
READY=false
for i in {1..30}; do
    if curl -s -f "$PISTON_URL/api/v2/runtimes" >/dev/null 2>&1; then
        READY=true
        break
    fi
    echo -n "."
    sleep 1
done
echo ""

if [ "$READY" != "true" ]; then
    echo "❌ 錯誤：等待 Piston API 啟動逾時 (超過 30 秒)，請檢查容器狀態：docker logs ntut-piston"
    exit 1
fi
echo "✅ Piston API 已就緒 ($PISTON_URL)"

# 4. 安裝指定語言套件
# 預設安裝 python 與 gcc，或可自訂傳入參數：./piston.sh python gcc java
LANGUAGES=("${@:-python gcc}")
# 若傳入為空陣列或預設字串，拆解成個別項目
if [ $# -eq 0 ]; then
    LANGS=(python gcc)
else
    LANGS=("$@")
fi

echo "=> 正在檢查與安裝語言套件: ${LANGS[*]}"

for lang in "${LANGS[@]}"; do
    echo -n "   - 安裝 $lang ... "
    # 發送 POST 請求至 Piston 套件安裝 API
    RESP=$(curl -s -w "\n%{http_code}" -X POST "$PISTON_URL/api/v2/packages" \
        -H "Content-Type: application/json" \
        -d "{\"language\":\"$lang\",\"version\":\"*\"}" 2>&1)
    
    HTTP_CODE=$(echo "$RESP" | tail -n1)
    BODY=$(echo "$RESP" | head -n -1)

    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
        echo "✅ 完成 ($BODY)"
    else
        # 若已安裝或報錯，顯示訊息
        if echo "$BODY" | grep -q "already installed"; then
            echo "✅ 已安裝過"
        else
            echo "⚠️ 回應代碼 $HTTP_CODE: $BODY"
        fi
    fi
done

# 5. 輸出已安裝語言清單
echo ""
echo "=== 已安裝的語言環境清單 ==="
RUNTIMES=$(curl -s "$PISTON_URL/api/v2/runtimes" || echo "[]")
if command -v node >/dev/null 2>&1; then
    node -e "
    const runtimes = JSON.parse(process.argv[1] || '[]');
    if (runtimes.length === 0) {
        console.log('   (無任何語言套件)');
    } else {
        runtimes.forEach(r => console.log('   • ' + r.language.padEnd(12) + ' 版本: ' + r.version + (r.aliases && r.aliases.length ? ' (別名: ' + r.aliases.join(', ') + ')' : '')));
    }
    " "$RUNTIMES"
else
    echo "$RUNTIMES"
fi

echo "======================================================="
echo "✅ Piston 設定完成！"
echo "======================================================="
