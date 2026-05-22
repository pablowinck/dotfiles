#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/00-prelude.sh"

step "04-zsh: oh-my-zsh + spaceship + chsh"

if [ -d "$HOME/.oh-my-zsh" ]; then
  skip "oh-my-zsh já instalado"
else
  log "instalando oh-my-zsh (unattended)"
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  ok "oh-my-zsh instalado"
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

if [ -d "$ZSH_CUSTOM/themes/spaceship-prompt" ]; then
  skip "spaceship-prompt já instalado"
else
  log "clonando spaceship-prompt"
  git clone --depth=1 https://github.com/spaceship-prompt/spaceship-prompt.git "$ZSH_CUSTOM/themes/spaceship-prompt"
  ln -sf "$ZSH_CUSTOM/themes/spaceship-prompt/spaceship.zsh-theme" "$ZSH_CUSTOM/themes/spaceship.zsh-theme"
  ok "spaceship instalado"
fi

if [ -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
  skip "zsh-autosuggestions já instalado"
else
  log "clonando zsh-autosuggestions"
  git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
  ok "zsh-autosuggestions instalado"
fi

if [ "$(getent passwd "$USER" | cut -d: -f7)" = "$(command -v zsh)" ]; then
  skip "shell padrão já é zsh"
else
  log "alterando shell padrão para zsh"
  sudo chsh -s "$(command -v zsh)" "$USER"
  ok "shell padrão alterado (efetivo no próximo login)"
fi
