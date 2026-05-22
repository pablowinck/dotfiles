#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/00-prelude.sh"

step "05-node: nvm + Node 22 LTS"

NVM_DIR="$HOME/.nvm"
export NVM_DIR

if [ -d "$NVM_DIR" ]; then
  skip "nvm já instalado"
else
  log "instalando nvm v0.40.1"
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
  ok "nvm instalado"
fi

# shellcheck source=/dev/null
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

if node -v 2>/dev/null | grep -q '^v22\.'; then
  skip "Node $(node -v) já ativo"
else
  log "instalando Node 22 LTS"
  nvm install 22 --lts
  nvm alias default 22
  nvm use default
  ok "Node $(node -v) instalado e setado como default"
fi
