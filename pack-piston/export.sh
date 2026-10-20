#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTAINER="ntut-piston"
ARCHIVE="$SCRIPT_DIR/piston-packages.tar.gz"

if ! command -v docker >/dev/null 2>&1; then
    echo "錯誤：找不到 docker 指令。" >&2
    exit 1
fi
if [ "$(docker inspect --format '{{.State.Running}}' "$CONTAINER" 2>/dev/null)" != "true" ]; then
    echo "錯誤：${CONTAINER} 容器未運行。請先啟動 Piston。" >&2
    exit 1
fi

TMP_ARCHIVE="$(mktemp "$SCRIPT_DIR/.piston-packages.XXXXXX")"
trap 'rm -f "$TMP_ARCHIVE"' EXIT

echo "正在從 ${CONTAINER} 匯出 /piston/packages ..."
docker exec "$CONTAINER" tar -C /piston/packages -czf - . > "$TMP_ARCHIVE"
tar -tzf "$TMP_ARCHIVE" >/dev/null
mv -f "$TMP_ARCHIVE" "$ARCHIVE"

echo "完成：${ARCHIVE}"
echo "可將此檔案複製到 USB。"
