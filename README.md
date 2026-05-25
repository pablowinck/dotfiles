# dotfiles

Configs portáveis (zsh + Claude Code + tmux) e bootstrap WSL.

## Estrutura

```
claude/          configs do Claude Code (CLAUDE.md, settings.json, skills, commands)
claude/clauder   wrapper de auto-retry pro Claude Code (ver claude/CLAUDER.md)
tmux/            config do tmux (necessário pro clauder)
zsh/             .zshrc compartilhado
wsl/             bootstrap WSL (PowerShell + bash + lib/*.sh)
```

## Setup no WSL (Windows)

Veja [`wsl/README.md`](wsl/README.md). O `install.sh` instala dependências (incluindo `tmux`) e cria todos os symlinks automaticamente.

## Setup no Mac

Symlinks manuais por enquanto. Roadmap: `mac/setup-mac.sh`.

```bash
brew install tmux
mkdir -p ~/.local/bin
ln -sf ~/projects/dotfiles/claude/CLAUDE.md     ~/.claude/CLAUDE.md
ln -sf ~/projects/dotfiles/claude/settings.json ~/.claude/settings.json
ln -sf ~/projects/dotfiles/claude/clauder       ~/.local/bin/clauder
ln -sf ~/projects/dotfiles/tmux/.tmux.conf      ~/.tmux.conf
ln -sf ~/projects/dotfiles/zsh/.zshrc           ~/.zshrc
```

## Ferramentas

- [`claude/CLAUDER.md`](claude/CLAUDER.md) — wrapper `clauder` com auto-retry de socket error
