# WSL Bootstrap

Replica o ambiente de dev do Mac no Ubuntu 26.04 do WSL.

## Pré-requisitos

- Windows 10/11 com WSL2 habilitado
- Ubuntu-26.04 já instalado (`wsl --install -d Ubuntu-26.04`)
- PowerShell rodado como Administrador
- Browser disponível (gh auth login + claude login usam fluxo OAuth web)

## Setup (primeira vez)

No PowerShell, como Administrador:

```powershell
iwr -useb https://raw.githubusercontent.com/pablowinck/dotfiles/main/wsl/setup-wsl.ps1 -OutFile $env:TEMP\setup-wsl.ps1
powershell -ExecutionPolicy Bypass -File $env:TEMP\setup-wsl.ps1
```

> Se preferir habilitar scripts permanentemente (em vez de Bypass a cada execução), rode uma única vez como Administrador:
> ```powershell
> Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
> ```
> Depois você pode chamar `& $env:TEMP\setup-wsl.ps1` direto.

O que acontece:

1. Verifica WSL + Ubuntu-26.04
2. Instala Postman Desktop e Docker Desktop via winget
3. Pede para você habilitar WSL Integration no Docker Desktop
4. Dentro do WSL, clona este repo em `~/.dotfiles` e roda `wsl/install.sh`
5. `install.sh` executa cada bloco `lib/*.sh` em ordem
6. No bloco `02-gh.sh`, pausa para `gh auth login --web`
7. No bloco `03-ssh.sh`, gera chave ed25519 e cadastra via `gh ssh-key add`
8. Final: instrui rodar `claude login`

## Update

```bash
# dentro do WSL
dotup
```

(alias definido no `~/.zshrc` que faz `git pull && ./wsl/install.sh`)

## Rodar um bloco isolado (debug)

```bash
cd ~/.dotfiles
./wsl/install.sh --only 08-awscli
./wsl/install.sh --from 10-claude   # retoma a partir desse
```

## Testar localmente em container

```bash
docker run -it --rm ubuntu:26.04 bash
# dentro do container:
apt-get update && apt-get install -y sudo git curl
useradd -m -s /bin/bash test && echo 'test ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers
su - test
git clone https://github.com/pablowinck/dotfiles.git ~/.dotfiles
~/.dotfiles/wsl/install.sh
```

## O que NÃO está incluso

- Hooks de TTS do Mac (`say -v Luciana` é macOS-only)
- `clauder` é instalado em `~/.local/bin/clauder` via symlink (`13-configs.sh`); veja [`../claude/CLAUDER.md`](../claude/CLAUDER.md)
- MCP `agentmemory` (depende de daemon launchd)
- MCPs `sequential-thinking`, `memory`, `chrome-devtools` (não foram pedidos)
- `statusline.sh` do Mac (Fase 2)

## Troubleshooting

- **`gh auth login` falha**: rode `gh auth login --hostname github.com --git-protocol ssh` manualmente
- **`chsh -s zsh` não muda o shell**: feche e reabra o WSL completamente (`wsl --shutdown` no PowerShell)
- **`docker` não funciona dentro do WSL**: confirme integração no Docker Desktop > Settings > Resources > WSL Integration
- **Tema spaceship feio (sem ícones)**: configure fonte powerline-compatible no Windows Terminal (Nerd Font recomendada)
