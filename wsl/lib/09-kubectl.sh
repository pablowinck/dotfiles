#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/00-prelude.sh"

step "09-kubectl: kubectl stable"

if command -v kubectl >/dev/null 2>&1; then
  skip "kubectl já instalado ($(kubectl version --client --output=yaml 2>/dev/null | grep gitVersion | head -1 | awk '{print $2}'))"
  exit 0
fi

log "baixando kubectl stable"
ARCH="$(dpkg --print-architecture)"
KUBECTL_VERSION="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
curl -fsSL "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl" -o "$TMP_DIR/kubectl"
chmod +x "$TMP_DIR/kubectl"
sudo install -o root -g root -m 0755 "$TMP_DIR/kubectl" /usr/local/bin/kubectl
ok "kubectl $KUBECTL_VERSION instalado"
