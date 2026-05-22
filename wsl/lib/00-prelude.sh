#!/usr/bin/env bash
# Helpers compartilhados entre todos os blocos lib/.
# Carregar via: source "$(dirname "$0")/00-prelude.sh"

set -euo pipefail

log()  { printf '\033[1;34m[%s]\033[0m %s\n' "$(date +%H:%M:%S)" "$*"; }
step() { printf '\n\033[1;32m▶ %s\033[0m\n' "$*"; }
skip() { printf '  \033[1;33m[skip]\033[0m %s\n' "$*"; }
fail() { printf '  \033[1;31m[fail]\033[0m %s\n' "$*" >&2; exit 1; }
ok()   { printf '  \033[1;32m[ok]\033[0m %s\n' "$*"; }

# Retorna 0 se QUALQUER um dos checks passar (OR lógico)
already_installed() {
  for check in "$@"; do
    if eval "$check" >/dev/null 2>&1; then return 0; fi
  done
  return 1
}

# DOTFILES_DIR aponta pra raiz do repo clonado
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
export DOTFILES_DIR
