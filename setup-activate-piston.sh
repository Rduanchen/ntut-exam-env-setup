#!/usr/bin/env bash
# 由 setup.sh 以 source 載入，共用設定並在任一步驟失敗時停止。

echo "=> 確保 Piston 評測機容器在背景運行..."
if ! command -v docker >/dev/null 2>&1; then
    echo "❌ 錯誤：Piston 沙盒評測機仍需 Docker Desktop 運行！請先安裝並啟動 Docker。"
    exit 1
fi
PISTON_PORT="$PISTON_PORT" docker compose -f "$SCRIPT_DIR/docker-compose.yaml" up -d
