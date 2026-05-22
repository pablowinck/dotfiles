#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/00-prelude.sh"

step "12-mcps: MCP servers (playwright + atlassian)"

export NVM_DIR="$HOME/.nvm"
# shellcheck source=/dev/null
set +u
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
nvm use default >/dev/null 2>&1 || true
set -u

command -v claude >/dev/null 2>&1 || fail "claude não instalado (rode 10-claude.sh primeiro)"

mcp_exists() {
  claude mcp list 2>/dev/null | grep -qw "$1"
}

if mcp_exists playwright; then
  skip "MCP playwright já adicionado"
else
  log "adicionando MCP playwright"
  claude mcp add playwright -- npx -y @playwright/mcp@latest
  ok "MCP playwright adicionado"
fi

if mcp_exists atlassian; then
  skip "MCP atlassian já adicionado"
else
  log "adicionando MCP atlassian (SSE)"
  claude mcp add --transport sse atlassian https://mcp.atlassian.com/v1/sse
  ok "MCP atlassian adicionado"
fi
