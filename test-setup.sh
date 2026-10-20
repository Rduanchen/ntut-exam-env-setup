#!/usr/bin/env bash
set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT
mkdir -p "$TEST_DIR/installer/client-setting" "$TEST_DIR/bin" "$TEST_DIR/fixture/backend/src" "$TEST_DIR/fixture/frontend"
cp "$SOURCE_DIR/setup.sh" "$TEST_DIR/installer/"
printf '%s\n' 'const userPort = process.env.USER_PORT;' > "$TEST_DIR/fixture/backend/src/index.ts"
printf '%s\n' 'VITE_ADMIN_TOKEN' > "$TEST_DIR/fixture/docker-compose.yml"

cat > "$TEST_DIR/bin/git" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$TEST_LOG"
if [ "$1" = clone ]; then
    for last; do :; done
    cp -R "$HOST_FIXTURE" "$last"
fi
EOF
cat > "$TEST_DIR/bin/docker" <<'EOF'
#!/usr/bin/env bash
printf 'docker %s\n' "$*" >> "$TEST_LOG"
EOF
cat > "$TEST_DIR/bin/curl" <<'EOF'
#!/usr/bin/env bash
printf 'curl %s\n' "$*" >> "$TEST_LOG"
EOF
cat > "$TEST_DIR/bin/sleep" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat > "$TEST_DIR/bin/pnpm" <<'EOF'
#!/usr/bin/env bash
printf 'pnpm %s\n' "$*" >> "$TEST_LOG"
EOF
chmod +x "$TEST_DIR/bin/"*

export PATH="$TEST_DIR/bin:$PATH"
export TEST_LOG="$TEST_DIR/calls.log"
export HOST_FIXTURE="$TEST_DIR/fixture"
printf '\n\n\n\n\n\nTestToken123456789\n1\n4\n' | bash "$TEST_DIR/installer/setup.sh" > "$TEST_DIR/output.log"

grep -q 'clone --branch develop --single-branch' "$TEST_LOG"
grep -q '^ADMIN_PORT=3000$' "$TEST_DIR/installer/host/.env"
grep -q '^USER_PORT=3001$' "$TEST_DIR/installer/host/.env"
grep -q '^VITE_BACKEND_URL=http://127.0.0.1:3000$' "$TEST_DIR/installer/host/.env"
grep -Eq '"remoteHost": "http://[^\"]+:3001"' "$TEST_DIR/installer/client-setting/pre_settings.json"
grep -q 'curl -s -f http://127.0.0.1:5173/' "$TEST_LOG"
grep -q 'docker compose --project-directory' "$TEST_LOG"

mkdir -p "$TEST_DIR/local/installer/client-setting"
cp "$SOURCE_DIR/setup.sh" "$TEST_DIR/local/installer/"
cp -R "$TEST_DIR/fixture" "$TEST_DIR/local/installer/host"
printf '\n\n\n\n\nTestToken123456789\n2\nn\n4\n' | bash "$TEST_DIR/local/installer/setup.sh" > "$TEST_DIR/local-output.log"
grep -q '^ADMIN_PORT=3000$' "$TEST_DIR/local/installer/host/backend/.env"
grep -q '^USER_PORT=3001$' "$TEST_DIR/local/installer/host/backend/.env"
grep -q '^VITE_BACKEND_URL=http://127.0.0.1:3000$' "$TEST_DIR/local/installer/host/frontend/.env"
grep -q '^VITE_ADMIN_TOKEN=TestToken123456789$' "$TEST_DIR/local/installer/host/frontend/.env"
grep -q 'pnpm build' "$TEST_LOG"

mkdir -p "$TEST_DIR/old/installer/client-setting" "$TEST_DIR/old/installer/host"
cp "$SOURCE_DIR/setup.sh" "$TEST_DIR/old/installer/"
if bash "$TEST_DIR/old/installer/setup.sh" > "$TEST_DIR/old-output.log" 2>&1; then
    echo 'old host compatibility check failed' >&2
    exit 1
fi
grep -q 'host 版本與此部署工具不相容' "$TEST_DIR/old-output.log"

printf '%s\n' 'fresh clone Docker, local Node, and incompatible host smoke tests passed'
