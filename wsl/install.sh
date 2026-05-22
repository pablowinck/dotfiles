#!/usr/bin/env bash
# Entrypoint: orquestra todos os blocos lib/*.sh em ordem alfabética.
# Uso:
#   ./install.sh              # roda tudo
#   ./install.sh --from 05    # retoma a partir de 05-node.sh
#   ./install.sh --only 12    # roda só 12-mcps.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
export DOTFILES_DIR

# shellcheck source=lib/00-prelude.sh
source "$SCRIPT_DIR/lib/00-prelude.sh"

MODE="all"
TARGET=""

while [ $# -gt 0 ]; do
  case "$1" in
    --from) MODE="from"; TARGET="$2"; shift 2 ;;
    --only) MODE="only"; TARGET="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,7p' "$0"
      exit 0
      ;;
    *) fail "argumento desconhecido: $1" ;;
  esac
done

current_block=""
trap 'echo; echo "✗ Falhou em $current_block. Re-execute com: $0 --from $current_block"' ERR

log "DOTFILES_DIR=$DOTFILES_DIR"
log "modo=$MODE${TARGET:+ target=$TARGET}"

for script in "$SCRIPT_DIR"/lib/*.sh; do
  block_id="$(basename "$script" .sh)"
  case "$block_id" in
    00-prelude) continue ;;
  esac
  case "$MODE" in
    from)
      if [[ "$block_id" < "$TARGET" ]]; then continue; fi
      ;;
    only)
      if [[ "$block_id" != "$TARGET"* ]]; then continue; fi
      ;;
  esac
  current_block="$block_id"
  bash "$script"
done

log "tudo OK"
