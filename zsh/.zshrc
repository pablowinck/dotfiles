# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="spaceship"

plugins=(git zsh-autosuggestions)
source $ZSH/oh-my-zsh.sh

# zsh-syntax-highlighting (instalado via zinit ou apt)
[ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ] && \
  source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# SDKMAN (Java)
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"

# NVM (Node)
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# AWS CLI completion (se disponível)
[ -f /usr/local/bin/aws_completer ] && complete -C '/usr/local/bin/aws_completer' aws

# kubectl completion
command -v kubectl >/dev/null && source <(kubectl completion zsh)

# Node IPv4-first (corrige issues de DNS em redes corporativas)
export NODE_OPTIONS="--dns-result-order=ipv4first"

# Aliases
alias dotup='cd ~/.dotfiles && git pull && ./wsl/install.sh'

# fcommit: add + commit + push (cria upstream se faltar)
fcommit() {
    if [ -z "$1" ]; then
        echo "Erro: Forneça uma mensagem para o commit"
        echo "Uso: fcommit \"sua mensagem aqui\""
        return 1
    fi
    git add . && git commit -m "$1"
    if [ $? -eq 0 ]; then
        git push 2>/dev/null || git push -u origin $(git branch --show-current)
    fi
}

# Local overrides (não versionado)
[ -f ~/.zshrc.local ] && source ~/.zshrc.local
