#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/00-prelude.sh"

step "06-java: SDKMAN + Java 21 Temurin"

export SDKMAN_DIR="$HOME/.sdkman"

if [ -d "$SDKMAN_DIR" ]; then
  skip "SDKMAN já instalado"
else
  log "instalando SDKMAN"
  curl -s "https://get.sdkman.io?rcupdate=false" | bash
  ok "SDKMAN instalado"
fi

# shellcheck source=/dev/null
set +u
source "$SDKMAN_DIR/bin/sdkman-init.sh"
set -u

if sdk current java 2>/dev/null | grep -qE '21\.[0-9]+\.[0-9]+-tem'; then
  skip "Java 21 Temurin já é o atual ($(sdk current java | awk '{print $NF}'))"
else
  log "instalando Java 21 Temurin"
  JAVA_VERSION=$(sdk list java 2>/dev/null | grep -oE '21\.[0-9]+\.[0-9]+-tem' | sort -V | tail -1)
  [ -z "$JAVA_VERSION" ] && fail "nenhuma versão Java 21 Temurin disponível no SDKMAN"
  sdk install java "$JAVA_VERSION" </dev/null
  sdk default java "$JAVA_VERSION"
  ok "Java $JAVA_VERSION instalado e setado como default"
fi
