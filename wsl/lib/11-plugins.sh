#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/00-prelude.sh"

step "11-plugins: plugins do Claude Code (superpowers + frontend-design)"

# claude precisa estar no PATH
export NVM_DIR="$HOME/.nvm"
# shellcheck source=/dev/null
set +u
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
nvm use default >/dev/null 2>&1 || true
set -u

command -v claude >/dev/null 2>&1 || fail "claude não instalado (rode 10-claude.sh primeiro)"

install_plugin() {
  local plugin="$1"
  if claude plugin list 2>/dev/null | grep -q "$plugin"; then
    skip "plugin já instalado: $plugin"
  else
    log "instalando plugin: $plugin"
    claude plugin install "$plugin"
    ok "plugin instalado: $plugin"
  fi
}

install_plugin "superpowers@claude-plugins-official"
install_plugin "frontend-design@claude-plugins-official"
