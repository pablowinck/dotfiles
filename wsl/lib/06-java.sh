#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/00-prelude.sh"

step "06-java: SDKMAN + Java 21 Temurin"

export SDKMAN_DIR="$HOME/.sdkman"

if [ -d "$SDKMAN_DIR" ]; then
  skip "SDKMAN ja instalado"
else
  log "instalando SDKMAN"
  curl -s "https://get.sdkman.io?rcupdate=false" | bash
  ok "SDKMAN instalado"
fi

# garante que `sdk install` nao espera prompt interativo
mkdir -p "$SDKMAN_DIR/etc"
if ! grep -q '^sdkman_auto_answer=true' "$SDKMAN_DIR/etc/config" 2>/dev/null; then
  echo "sdkman_auto_answer=true" >> "$SDKMAN_DIR/etc/config"
fi

# shellcheck source=/dev/null
set +u
source "$SDKMAN_DIR/bin/sdkman-init.sh"
set -u

# checa Java atual sem deixar pipefail confundir grep miss
current_java="$(sdk current java 2>/dev/null || true)"
if echo "$current_java" | grep -qE '21\.[0-9]+\.[0-9]+-tem'; then
  skip "Java 21 Temurin ja e o atual"
else
  log "descobrindo versao mais recente de Java 21 Temurin"
  # pipefail off pra essa secao porque grep retorna 1 quando nao acha
  set +o pipefail
  sdk_list="$(sdk list java 2>/dev/null || true)"
  JAVA_VERSION="$(echo "$sdk_list" | grep -oE '21\.[0-9]+\.[0-9]+-tem' | sort -V | tail -1)"
  set -o pipefail

  if [ -z "$JAVA_VERSION" ]; then
    log "parsing de 'sdk list java' falhou; tentando fallback 21.0.5-tem"
    JAVA_VERSION="21.0.5-tem"
  fi

  log "instalando Java $JAVA_VERSION"
  sdk install java "$JAVA_VERSION" </dev/null || fail "sdk install java $JAVA_VERSION falhou"
  sdk default java "$JAVA_VERSION" </dev/null || fail "sdk default java $JAVA_VERSION falhou"
  ok "Java $JAVA_VERSION instalado e setado como default"
fi
