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

# SDKMAN nao e compativel com `set -u` (usa variaveis nao setadas
# internamente, ex: sdkman-main.sh line 30). Desabilitamos nounset
# e pipefail por todo o resto do script enquanto manipulamos sdk.
set +u
set +o pipefail

log "sourcing $SDKMAN_DIR/bin/sdkman-init.sh"
# shellcheck source=/dev/null
source "$SDKMAN_DIR/bin/sdkman-init.sh"

current_java="$(sdk current java 2>/dev/null)"
log "sdk current java: '$current_java'"

if echo "$current_java" | grep -qE '21\.[0-9]+\.[0-9]+-tem'; then
  skip "Java 21 Temurin ja e o atual"
  exit 0
fi

log "descobrindo versao mais recente de Java 21 Temurin"
sdk_list="$(sdk list java 2>&1)"
JAVA_VERSION="$(echo "$sdk_list" | grep -oE '21\.[0-9]+\.[0-9]+-tem' | sort -V | tail -1)"

if [ -z "$JAVA_VERSION" ]; then
  log "parsing de 'sdk list java' nao encontrou versao 21.x-tem; usando fallback 21.0.5-tem"
  echo "$sdk_list" | head -30
  JAVA_VERSION="21.0.5-tem"
fi

log "vai instalar Java $JAVA_VERSION"
echo "--- BEGIN sdk install java $JAVA_VERSION ---"
sdk install java "$JAVA_VERSION" </dev/null
INSTALL_RC=$?
echo "--- END sdk install java $JAVA_VERSION (exit $INSTALL_RC) ---"
if [ $INSTALL_RC -ne 0 ]; then
  fail "sdk install java $JAVA_VERSION falhou (exit $INSTALL_RC)"
fi

log "setando $JAVA_VERSION como default"
sdk default java "$JAVA_VERSION" </dev/null
DEFAULT_RC=$?
if [ $DEFAULT_RC -ne 0 ]; then
  fail "sdk default java $JAVA_VERSION falhou (exit $DEFAULT_RC)"
fi

ok "Java $JAVA_VERSION instalado e setado como default"
