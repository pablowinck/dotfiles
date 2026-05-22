#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/00-prelude.sh"

step "06-java: SDKMAN + Java 21 Temurin"

export SDKMAN_DIR="$HOME/.sdkman"

if [ -d "$SDKMAN_DIR" ]; then
  skip "SDKMAN ja instalado em $SDKMAN_DIR"
else
  log "instalando SDKMAN"
  curl -s "https://get.sdkman.io?rcupdate=false" | bash
  ok "SDKMAN instalado"
fi

mkdir -p "$SDKMAN_DIR/etc"
if ! grep -q '^sdkman_auto_answer=true' "$SDKMAN_DIR/etc/config" 2>/dev/null; then
  echo "sdkman_auto_answer=true" >> "$SDKMAN_DIR/etc/config"
  log "habilitado sdkman_auto_answer=true"
fi

log "sourcing $SDKMAN_DIR/bin/sdkman-init.sh"
# shellcheck source=/dev/null
set +u
source "$SDKMAN_DIR/bin/sdkman-init.sh"
set -u

log "sdk version: $(sdk version 2>&1 | head -3 | tr '\n' ' ')"

current_java="$(sdk current java 2>/dev/null || true)"
log "sdk current java: '$current_java'"

if echo "$current_java" | grep -qE '21\.[0-9]+\.[0-9]+-tem'; then
  skip "Java 21 Temurin ja e o atual"
  exit 0
fi

log "descobrindo versao mais recente de Java 21 Temurin"
set +o pipefail
sdk_list="$(sdk list java 2>&1 || true)"
JAVA_VERSION="$(echo "$sdk_list" | grep -oE '21\.[0-9]+\.[0-9]+-tem' | sort -V | tail -1)"
set -o pipefail

if [ -z "$JAVA_VERSION" ]; then
  log "parsing de 'sdk list java' nao encontrou versao 21.x-tem; tentando fallback"
  log "amostra do output de 'sdk list java' (primeiras linhas):"
  echo "$sdk_list" | head -30
  JAVA_VERSION="21.0.5-tem"
fi

log "vai instalar Java $JAVA_VERSION (output completo abaixo)"
echo "--- BEGIN sdk install java $JAVA_VERSION ---"
if ! sdk install java "$JAVA_VERSION" </dev/null; then
  echo "--- END (failed) ---"
  fail "sdk install java $JAVA_VERSION falhou (exit code $?)"
fi
echo "--- END sdk install java $JAVA_VERSION ---"

log "setando $JAVA_VERSION como default"
echo "--- BEGIN sdk default java $JAVA_VERSION ---"
if ! sdk default java "$JAVA_VERSION" </dev/null; then
  echo "--- END (failed) ---"
  fail "sdk default java $JAVA_VERSION falhou (exit code $?)"
fi
echo "--- END sdk default java $JAVA_VERSION ---"

ok "Java $JAVA_VERSION instalado e setado como default"
