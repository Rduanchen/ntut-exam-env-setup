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


# create an RSA key pair for SSH authentication under backend/keys

mkdir -p backend/keys
if [ ! -f "backend/keys/private.pem" ] || [ ! -f "backend/keys/public.pem" ]; then
  echo "Generating RSA key pair for SSH authentication..."
  ssh-keygen -t rsa -b 2048 -m PEM -f backend/keys/private.pem -N ""
  openssl rsa -in backend/keys/private.pem -pubout -outform PEM -out backend/keys/public.pem
else
  echo "RSA key pair already exists. Skipping generation."
fi

# Create a .env file for the backend and put 256 bit AES key in it
if [ ! -f "backend/.env" ]; then
  echo "Creating .env file for the backend..."
  SYSTEM_AES_KEY=$(openssl rand -hex 32)
  cat > backend/.env <<EOL
# AES key for encrypting sensitive data (256 bits)
SYSTEM_AES_KEY=$SYSTEM_AES_KEY
EOL
else
  echo ".env file already exists for the backend. Skipping creation."
fi

if [ ! -d "backend/src/upload/" ]; then
  mkdir -p backend/src/upload/
fi

echo "Done."
