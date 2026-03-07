set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

cd "$SCRIPT_DIR/frontend"
echo "Starting frontend service ..."
# 使用 npm 啟動服務
npm install
npm run dev
echo "Frontend service started."