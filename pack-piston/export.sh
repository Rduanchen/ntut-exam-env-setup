
#!/usr/bin/env bash
set -Eeuo pipefail

# 腳本所在目錄
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

# 設定
CONTAINER="ntut-piston"
ARCHIVE="$SCRIPT_DIR/piston-packages.tar.gz"
TMP_ARCHIVE="$(mktemp "$SCRIPT_DIR/.piston-packages.XXXXXX")"

# 清理暫存檔
cleanup() {
    rm -f -- "$TMP_ARCHIVE"
}
trap cleanup EXIT

# 檢查 Docker 是否存在
if ! command -v docker >/dev/null 2>&1; then
    echo "錯誤：找不到 docker 指令，請確認 Docker Desktop 已安裝並啟動。" >&2
    exit 1
fi

# 檢查容器是否正在運行
RUNNING="$(docker inspect --format '{{.State.Running}}' "$CONTAINER" 2>/dev/null || true)"

if [[ "$RUNNING" != "true" ]]; then
    echo "錯誤：${CONTAINER} 容器未運行，請先啟動 Piston。" >&2
    exit 1
fi

echo "正在從 ${CONTAINER} 匯出 /piston/packages ..."

# 關閉 Git Bash 的 MSYS 路徑轉換
# 確保 /piston/packages 保持容器內的 Linux 路徑
if ! MSYS_NO_PATHCONV=1 docker exec "$CONTAINER" \
    tar -C /piston/packages -czf - . > "$TMP_ARCHIVE"; then
    echo "錯誤：匯出失敗，請確認容器內的 /piston/packages 目錄及 tar 指令。" >&2
    exit 1
fi

# 驗證壓縮檔
if ! tar -tzf "$TMP_ARCHIVE" > /dev/null; then
    echo "錯誤：壓縮檔驗證失敗，未覆蓋原有備份檔案。" >&2
    exit 1
fi

# 匯出成功後才取代正式備份檔
if ! mv -f -- "$TMP_ARCHIVE" "$ARCHIVE"; then
    echo "錯誤：無法儲存備份檔，請檢查資料夾權限。" >&2
    exit 1
fi

echo ""
echo "匯出完成：${ARCHIVE}"
echo "可將此檔案複製到 USB。"
