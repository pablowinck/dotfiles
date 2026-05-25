#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/00-prelude.sh"

step "01-apt: instala pacotes base via apt"

PACKAGES=(
  build-essential
  ca-certificates
  curl
  fontconfig
  git
  gnupg
  jq
  lsb-release
  postgresql-client
  tmux
  unzip
  zip
  zsh
  zsh-syntax-highlighting
)

MISSING=()
for pkg in "${PACKAGES[@]}"; do
  if ! dpkg -s "$pkg" >/dev/null 2>&1; then
    MISSING+=("$pkg")
  fi
done

if [ ${#MISSING[@]} -eq 0 ]; then
  skip "todos os pacotes já instalados"
  exit 0
fi

log "instalando: ${MISSING[*]}"
sudo apt-get update -qq
sudo apt-get install -y --no-install-recommends "${MISSING[@]}"
ok "${#MISSING[@]} pacotes instalados"
