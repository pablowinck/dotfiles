#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/00-prelude.sh"

step "03-ssh: chave ed25519 + cadastro via gh"

SSH_KEY="$HOME/.ssh/id_ed25519"
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

if [ -f "$SSH_KEY" ]; then
  skip "chave ed25519 já existe em $SSH_KEY"
else
  log "gerando chave ed25519 sem passphrase"
  ssh-keygen -t ed25519 -N '' -f "$SSH_KEY" -C "wsl-$(hostname)-$(date +%Y%m%d)"
  ok "chave gerada"
fi

if ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
  skip "SSH ao GitHub já funciona"
else
  log "cadastrando chave pública no GitHub via gh"
  KEY_TITLE="wsl-$(hostname)-$(date +%Y%m%d)"
  gh ssh-key add "${SSH_KEY}.pub" --title "$KEY_TITLE" --type authentication
  ok "chave cadastrada: $KEY_TITLE"
  log "testando SSH ao GitHub"
  ssh -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1 | grep "successfully" || fail "SSH ao GitHub falhou"
fi
