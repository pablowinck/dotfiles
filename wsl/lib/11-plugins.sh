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

command -v claude >/dev/null 2>&1 || fail "claude nao instalado (rode 10-claude.sh primeiro)"

MARKETPLACE="claude-plugins-official"

log "atualizando catalogo do marketplace $MARKETPLACE"
claude plugin marketplace update "$MARKETPLACE" 2>/dev/null || {
  log "marketplace nao listado; adicionando via 'claude plugin marketplace add'"
  claude plugin marketplace add "$MARKETPLACE" || fail "falha ao adicionar marketplace $MARKETPLACE"
  claude plugin marketplace update "$MARKETPLACE" || fail "falha ao atualizar marketplace $MARKETPLACE apos add"
}

install_plugin() {
  local plugin="$1"
  if claude plugin list 2>/dev/null | grep -q "$plugin"; then
    skip "plugin ja instalado: $plugin"
  else
    log "instalando plugin: $plugin"
    claude plugin install "$plugin"
    ok "plugin instalado: $plugin"
  fi
}

install_plugin "superpowers@${MARKETPLACE}"
install_plugin "frontend-design@${MARKETPLACE}"
