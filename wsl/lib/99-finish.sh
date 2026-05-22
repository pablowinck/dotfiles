#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/00-prelude.sh"

step "99-finish: instruções finais"

cat <<MSG

  Setup do WSL concluído.

  Próximos passos manuais:

  1. Rodar: claude login
     (faz login na conta Anthropic via browser)

  2. Fechar e reabrir o terminal WSL
     (para o zsh virar shell padrão e tema spaceship aplicar)

  3. Verificar Docker Desktop está rodando no Windows e tem integração com Ubuntu-26.04 habilitada
     (Settings > Resources > WSL Integration)

  4. Atualizar dotfiles no futuro: rode "dotup"

  Smoke test rápido:
    command -v zsh node java newman aws kubectl psql claude

MSG
