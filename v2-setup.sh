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


clone_or_update "https://github.com/Rduanchen/ntut-exam-v2" "host"
clone_or_update "https://github.com/engineer-man/piston.git" "piston"

# Inject piston environment variables into docker-compose.yaml
PISTON_COMPOSE="$SCRIPT_DIR/piston/docker-compose.yaml"
if [ -f "$PISTON_COMPOSE" ]; then
  # Only inject if environment block doesn't already exist
  if ! grep -q "PISTON_RUN_TIMEOUT" "$PISTON_COMPOSE"; then
    echo "Injecting Piston environment variables into docker-compose.yaml ..."
    # Use a temp file for portable sed (works on both macOS and Linux)
    cat >> "$PISTON_COMPOSE" <<'ENVBLOCK'
        environment:
            - PISTON_RUN_TIMEOUT=30000
            - PISTON_RUN_CPU_TIME=30000
            - PISTON_COMPILE_TIMEOUT=10000
            - PISTON_COMPILE_CPU_TIME=10000
            - PISTON_OUTPUT_MAX_SIZE=10240
            - PISTON_RUN_MEMORY_LIMIT=-1
            - PISTON_COMPILE_MEMORY_LIMIT=-1
ENVBLOCK
    echo "Piston environment variables injected."
  else
    echo "Piston environment variables already present, skipping injection."
  fi
fi

./host/deploy.sh
./piston.sh
