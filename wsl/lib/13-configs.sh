#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/00-prelude.sh"

step "13-configs: symlinks de claude/* e zsh/.zshrc"

mkdir -p "$HOME/.claude/commands" "$HOME/.claude/skills"

link_if_needed() {
  local src="$1"
  local dst="$2"
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    skip "symlink já correto: $dst"
    return 0
  fi
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    log "backup do arquivo existente: $dst -> $dst.bak.$(date +%s)"
    mv "$dst" "$dst.bak.$(date +%s)"
  fi
  ln -sf "$src" "$dst"
  ok "linked: $dst -> $src"
}

# Claude
link_if_needed "$DOTFILES_DIR/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
link_if_needed "$DOTFILES_DIR/claude/settings.json" "$HOME/.claude/settings.json"

# commands (arquivo por arquivo pra permitir adicionar locais futuros)
for f in "$DOTFILES_DIR"/claude/commands/*.md; do
  [ -f "$f" ] || continue
  link_if_needed "$f" "$HOME/.claude/commands/$(basename "$f")"
done

# skills (arquivo e diretório)
for entry in "$DOTFILES_DIR"/claude/skills/*; do
  [ -e "$entry" ] || continue
  link_if_needed "$entry" "$HOME/.claude/skills/$(basename "$entry")"
done

# zsh
link_if_needed "$DOTFILES_DIR/zsh/.zshrc" "$HOME/.zshrc"
