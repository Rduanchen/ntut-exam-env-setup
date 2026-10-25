#!/bin/bash
set -eo pipefail

# 集中設定環境變數預設值；可在執行 setup.sh 前透過環境變數覆寫。
ADMIN_PORT=${ADMIN_PORT:-3001}
USER_PORT=${USER_PORT:-3000}
FRONTEND_PORT=${FRONTEND_PORT:-5173}
PISTON_PORT=${PISTON_PORT:-2000}
SERVER_IP=${SERVER_IP:-}

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

# 即使略過下載階段，仍可使用已存在的專案；不進行下載或修改。
HOST_DIR=""
if [ -d "$SCRIPT_DIR/host" ]; then
    HOST_DIR="$SCRIPT_DIR/host"
elif [ -d "$SCRIPT_DIR/../host" ]; then
    HOST_DIR="$(cd "$SCRIPT_DIR/../host" && pwd)"
fi

EXECUTED_STEPS=0
SKIPPED_STEPS=0
run_setup_step() {
    local step_file="$1"
    local step_prompt="${2:-是否執行 ${step_file}？}"
    local answer
    while true; do
        if ! read -r -p "$step_prompt (y/n) [預設: y]: " answer; then
            echo "❌ 輸入已結束，設定流程停止。" >&2
            return 1
        fi
        case "$answer" in
            ""|y|Y) break ;;
            n|N)
                echo "=> 略過 $step_file"
                SKIPPED_STEPS=$((SKIPPED_STEPS + 1))
                return 0
                ;;
            *) echo "請輸入 y 或 n，或直接按 Enter 執行。" ;;
        esac
    done

    case "$step_file" in
        setup-host-env-config.sh|setup-deploy-host.sh)
            if [ -z "$HOST_DIR" ] || [ ! -d "$HOST_DIR/backend" ] || [ ! -d "$HOST_DIR/frontend" ]; then
                echo "❌ 找不到完整的 host 專案，請先執行 setup-download-host.sh 階段。" >&2
                return 1
            fi
            ;;
    esac
    if [ "$step_file" = setup-deploy-host.sh ] &&
       { [ ! -f "$HOST_DIR/backend/.env" ] || [ ! -f "$HOST_DIR/frontend/.env" ]; }; then
        echo "❌ 缺少主系統環境設定檔，請先執行 setup-host-env-config.sh 階段。" >&2
        return 1
    fi

    # 必須直接執行 source，讓階段共用變數，並保留 set -e 的失敗即停止行為。
    if [ "$step_file" = start-host.sh ]; then
        if [ "${HOST_BUILT:-false}" = true ]; then
            bash "$SCRIPT_DIR/start-host.sh" --skip-build
        else
            bash "$SCRIPT_DIR/start-host.sh"
        fi
    else
        source "$SCRIPT_DIR/$step_file"
    fi
    EXECUTED_STEPS=$((EXECUTED_STEPS + 1))
}

# 明確列出順序，避免依檔名字母排序造成相依階段顛倒。
run_setup_step setup-download-host.sh
run_setup_step setup-host-env-config.sh
run_setup_step setup-node-env-check.sh
run_setup_step setup-activate-piston.sh
run_setup_step setup-import-piston.sh "是否匯入 Piston 語言套件（執行 setup-import-piston.sh）？"
run_setup_step setup-deploy-host.sh
run_setup_step setup-firewall.sh
run_setup_step setup-piston-language.sh
run_setup_step setup-client-config.sh
run_setup_step start-host.sh "是否使用 start-host.sh 啟動主系統（前景執行，Ctrl+C 停止）？"

echo "======================================================="
echo " NTUT Exam System 設定流程結束"
echo " 已執行 $EXECUTED_STEPS 個階段，略過 $SKIPPED_STEPS 個階段。"
echo " 服務啟動與設定更新情況，請依各階段輸出確認。"
echo "======================================================="
