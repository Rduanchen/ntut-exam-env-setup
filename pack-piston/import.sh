#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTAINER="ntut-piston"
ARCHIVE="$SCRIPT_DIR/piston-packages.tar.gz"
PISTON_PORT="${PISTON_PORT:-2000}"

if [ ! -f "$ARCHIVE" ]; then
    echo "錯誤：找不到 ${ARCHIVE}。請先從 USB 複製到 pack-piston 目錄。" >&2
    exit 1
fi
if ! command -v docker >/dev/null 2>&1; then
    echo "錯誤：找不到 docker 指令。" >&2
    exit 1
fi
if [ "$(docker inspect --format '{{.State.Running}}' "$CONTAINER" 2>/dev/null)" != "true" ]; then
    echo "錯誤：${CONTAINER} 容器未運行。請先啟動 Piston。" >&2
    exit 1
fi

echo "正在檢查壓縮檔..."
tar -tzf "$ARCHIVE" >/dev/null

echo "正在將語言套件匯入 ${CONTAINER} ..."
docker exec -i -u 0 "$CONTAINER" tar -C /piston/packages -xzf - < "$ARCHIVE"
docker restart "$CONTAINER" >/dev/null

echo "完成。已重啟 Piston，檢查可用語言："
for _ in {1..30}; do
    if curl -fsS "http://localhost:$PISTON_PORT/api/v2/runtimes"; then
        echo
        exit 0
    fi
    sleep 1
done

echo "Piston 尚未就緒，請稍後檢查 docker logs ${CONTAINER}。" >&2
exit 1
