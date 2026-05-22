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

log "atualizando todos os marketplaces conhecidos"
claude plugin marketplace update 2>&1 || true

log "atualizando marketplace $MARKETPLACE (best-effort)"
claude plugin marketplace update "$MARKETPLACE" 2>&1 || true

install_plugin() {
  local plugin="$1"
  if claude plugin list 2>/dev/null | grep -q "$plugin"; then
    skip "plugin ja instalado: $plugin"
    return 0
  fi
  log "instalando plugin: $plugin"
  if claude plugin install "$plugin" 2>&1; then
    ok "plugin instalado: $plugin"
  else
    skip "falha ao instalar $plugin - rode manualmente apos 'claude login': claude plugin install $plugin"
  fi
}

install_plugin "superpowers@${MARKETPLACE}"
install_plugin "frontend-design@${MARKETPLACE}"

log "se algum plugin falhou, instale apos 'claude login' com:"
log "  claude plugin install superpowers@${MARKETPLACE}"
log "  claude plugin install frontend-design@${MARKETPLACE}"
