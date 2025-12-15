#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

clone_or_update() {
  local url="$1"
  local dir="$2"

  if [ -d "$dir/.git" ]; then
    echo "Updating $dir ..."
    git -C "$dir" pull --rebase
  else
    echo "Cloning $url into $dir ..."
    git clone "$url" "$dir"
  fi
}

clone_or_update "https://github.com/Rduanchen/ntut-exam-system-backend.git" "backend"
clone_or_update "https://github.com/Rduanchen/ntut-exam-system-ta-frontend.git" "frontend"
clone_or_update "https://github.com/engineer-man/piston.git" "piston"

echo "Done."
