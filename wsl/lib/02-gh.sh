#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/00-prelude.sh"

step "02-gh: GitHub CLI + autenticação"

if ! command -v gh >/dev/null 2>&1; then
  log "instalando gh CLI via repositório oficial"
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
    sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
  sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | \
    sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
  sudo apt-get update -qq
  sudo apt-get install -y gh
  ok "gh instalado: $(gh --version | head -1)"
else
  skip "gh já instalado"
fi

if gh auth status >/dev/null 2>&1; then
  skip "gh já autenticado: $(gh api user --jq .login)"
else
  log "abrindo gh auth login --web (acesse o link no browser)"
  gh auth login --web --git-protocol ssh --hostname github.com
  ok "gh autenticado: $(gh api user --jq .login)"
fi
