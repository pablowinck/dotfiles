#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/00-prelude.sh"

step "07-newman: Newman CLI global"

# garante que nvm está carregado e Node 22 ativo
export NVM_DIR="$HOME/.nvm"
# shellcheck source=/dev/null
set +u
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
nvm use default >/dev/null 2>&1 || true
set -u

if command -v newman >/dev/null 2>&1; then
  skip "newman já instalado ($(newman --version))"
else
  log "instalando newman globalmente"
  npm install -g newman
  ok "newman instalado ($(newman --version))"
fi
