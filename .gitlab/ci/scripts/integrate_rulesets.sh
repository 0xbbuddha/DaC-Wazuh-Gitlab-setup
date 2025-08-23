#!/usr/bin/env bash
set -euo pipefail

# Variables attendues (avec valeurs par défaut raisonnables)
: "${WAZUH_HOST:?Variable WAZUH_HOST manquante}"
: "${WAZUH_USER:?Variable WAZUH_USER manquante}"
WAZUH_SSH_PORT=${WAZUH_SSH_PORT:-22}
REPO_DIR=${REPO_DIR:-/var/ossec/etc}
WAZUH_RESTART_CMD=${WAZUH_RESTART_CMD:-"sudo systemctl restart wazuh-agent"}
SSH_STRICT=${SSH_STRICT:-"no"}

echo "==> Préparation de la clé SSH"
mkdir -p ~/.ssh
chmod 700 ~/.ssh

if [[ -z "${WAZUH_SSH_PRIVATE_KEY:-}" ]]; then
  echo "[ERROR] WAZUH_SSH_PRIVATE_KEY non défini dans les variables CI."
  exit 2
fi

echo "$WAZUH_SSH_PRIVATE_KEY" > ~/.ssh/id_ed25519
chmod 600 ~/.ssh/id_ed25519

if [[ -n "${WAZUH_HOST_FINGERPRINT:-}" ]]; then
  echo "${WAZUH_HOST_FINGERPRINT}" >> ~/.ssh/known_hosts
else
  if [[ "$SSH_STRICT" == "yes" ]]; then
    echo "[ERROR] SSH_STRICT=yes mais WAZUH_HOST_FINGERPRINT est manquant."
    exit 3
  fi
  echo "==> Désactivation de la vérification stricte (host key scanning auto)"
fi

SSH_OPTS=(
  -p "$WAZUH_SSH_PORT"
  -o StrictHostKeyChecking=${SSH_STRICT}
  -o UserKnownHostsFile=~/.ssh/known_hosts
)

echo "==> Pull du dépôt GitHub dans ${REPO_DIR}"
ssh -i ~/.ssh/id_ed25519 ${SSH_OPTS[*]} "${WAZUH_USER}@${WAZUH_HOST}" "cd ${REPO_DIR} && git pull"

echo "==> Redémarrage du service Wazuh"
ssh -i ~/.ssh/id_ed25519 ${SSH_OPTS[*]} "${WAZUH_USER}@${WAZUH_HOST}" "$WAZUH_RESTART_CMD"

echo "==> Mise à jour terminée"
