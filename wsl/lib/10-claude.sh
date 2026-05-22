#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/00-prelude.sh"

step "10-claude: Claude Code CLI"

# garante Node 22 ativo
export NVM_DIR="$HOME/.nvm"
# shellcheck source=/dev/null
set +u
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
nvm use default >/dev/null 2>&1 || true
set -u

if command -v claude >/dev/null 2>&1; then
  skip "claude já instalado ($(claude --version 2>/dev/null | head -1))"
else
  log "instalando @anthropic-ai/claude-code globalmente"
  npm install -g @anthropic-ai/claude-code
  ok "claude instalado ($(claude --version 2>/dev/null | head -1))"
fi
