#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/00-prelude.sh"

step "03-ssh: chave ed25519 + cadastro via gh"

SSH_KEY="$HOME/.ssh/id_ed25519"
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

if [ -f "$SSH_KEY" ]; then
  skip "chave ed25519 ja existe em $SSH_KEY"
else
  log "gerando chave ed25519 sem passphrase"
  ssh-keygen -t ed25519 -N '' -f "$SSH_KEY" -C "wsl-$(hostname)-$(date +%Y%m%d)"
  ok "chave gerada"
fi

# ssh -T git@github.com sempre retorna exit code 1 (GitHub nao da shell),
# mesmo quando autenticacao funciona. Capturamos o output e checamos o texto
# pra nao deixar pipefail confundir sucesso com falha.
test_github_ssh() {
  local output
  output="$(ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1 || true)"
  echo "$output" | grep -q "successfully authenticated"
}

if test_github_ssh; then
  skip "SSH ao GitHub ja funciona"
else
  KEY_PUB="${SSH_KEY}.pub"
  KEY_FINGERPRINT="$(awk '{print $2}' "$KEY_PUB")"
  if gh ssh-key list 2>/dev/null | grep -qF "$KEY_FINGERPRINT"; then
    skip "chave publica ja cadastrada no GitHub"
  else
    log "cadastrando chave publica no GitHub via gh"
    KEY_TITLE="wsl-$(hostname)-$(date +%Y%m%d)"
    gh ssh-key add "$KEY_PUB" --title "$KEY_TITLE" --type authentication
    ok "chave cadastrada: $KEY_TITLE"
  fi
  log "testando SSH ao GitHub apos cadastro"
  if test_github_ssh; then
    ok "SSH ao GitHub funcionando"
  else
    fail "SSH ao GitHub falhou apos cadastro da chave"
  fi
fi
