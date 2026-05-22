#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/00-prelude.sh"

step "08-awscli: AWS CLI v2"

if command -v aws >/dev/null 2>&1 && aws --version 2>&1 | grep -q "aws-cli/2"; then
  skip "AWS CLI v2 já instalado ($(aws --version))"
  exit 0
fi

log "baixando AWS CLI v2"
ARCH="$(uname -m)"
case "$ARCH" in
  x86_64) AWS_URL="https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" ;;
  aarch64) AWS_URL="https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" ;;
  *) fail "arquitetura não suportada: $ARCH" ;;
esac

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
curl -fsSL "$AWS_URL" -o "$TMP_DIR/awscliv2.zip"
unzip -q "$TMP_DIR/awscliv2.zip" -d "$TMP_DIR"

if command -v aws >/dev/null 2>&1; then
  log "atualizando instalação existente"
  sudo "$TMP_DIR/aws/install" --update
else
  sudo "$TMP_DIR/aws/install"
fi

ok "AWS CLI instalado ($(aws --version))"
