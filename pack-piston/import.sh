
#!/usr/bin/env bash
set -Eeuo pipefail

# 腳本所在目錄
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

# 設定
CONTAINER="ntut-piston"
ARCHIVE="$SCRIPT_DIR/piston-packages.tar.gz"
PISTON_PORT="${PISTON_PORT:-2000}"

# 檢查備份檔
if [[ ! -f "$ARCHIVE" ]]; then
    echo "錯誤：找不到 ${ARCHIVE}。" >&2
    echo "請先將 USB 中的備份檔複製到 pack-piston 目錄。" >&2
    exit 1
fi

# 檢查 Docker
if ! command -v docker >/dev/null 2>&1; then
    echo "錯誤：找不到 docker 指令，請確認 Docker Desktop 已安裝並啟動。" >&2
    exit 1
fi

# 檢查容器是否運行
RUNNING="$(docker inspect --format '{{.State.Running}}' "$CONTAINER" 2>/dev/null || true)"

if [[ "$RUNNING" != "true" ]]; then
    echo "錯誤：${CONTAINER} 容器未運行，請先啟動 Piston。" >&2
    exit 1
fi

# 驗證壓縮檔
echo "正在檢查壓縮檔..."

if ! tar -tzf "$ARCHIVE" > /dev/null; then
    echo "錯誤：壓縮檔損壞或格式不正確，已中止匯入。" >&2
    exit 1
fi

# 匯入語言套件
echo "正在將語言套件匯入 ${CONTAINER} ..."

if ! MSYS_NO_PATHCONV=1 docker exec -i -u 0 "$CONTAINER" \
    tar -C /piston/packages -xzf - < "$ARCHIVE"; then
    echo "錯誤：語言套件匯入失敗。" >&2
    exit 1
fi

# 重啟 Piston
echo "正在重啟 Piston ..."

if ! MSYS_NO_PATHCONV=1 docker restart "$CONTAINER" > /dev/null; then
    echo "錯誤：容器重啟失敗。" >&2
    exit 1
fi

# 等待 API 恢復
echo "正在等待 Piston API 就緒 ..."

for ((i = 1; i <= 30; i++)); do
    if curl -fsS "http://localhost:${PISTON_PORT}/api/v2/runtimes"; then
        echo
        echo "匯入完成！Piston 已重新啟動，API 運作正常。"
        exit 0
    fi

    sleep 1
done

echo "錯誤：Piston 尚未就緒，請稍後檢查容器日誌：" >&2
echo "docker logs ${CONTAINER}" >&2
exit 1
