#!/usr/bin/env bash
set -euo pipefail

# Expected variables (with reasonable default values)
: "${WAZUH_HOST:?Variable WAZUH_HOST missing}"
: "${WAZUH_USER:?Variable WAZUH_USER missing}"
WAZUH_SSH_PORT=${WAZUH_SSH_PORT:-22}
REPO_DIR=${REPO_DIR:-/var/ossec/etc}
WAZUH_RESTART_CMD=${WAZUH_RESTART_CMD:-"sudo systemctl restart wazuh-manager"}
SSH_STRICT=${SSH_STRICT:-"no"}

echo "==> Preparing SSH key"
mkdir -p ~/.ssh
chmod 700 ~/.ssh

if [[ -z "${WAZUH_SSH_PRIVATE_KEY:-}" ]]; then
  echo "[ERROR] WAZUH_SSH_PRIVATE_KEY not defined in CI variables."
  exit 2
fi

echo "$WAZUH_SSH_PRIVATE_KEY" > ~/.ssh/id_ed25519
chmod 600 ~/.ssh/id_ed25519

if [[ -n "${WAZUH_HOST_FINGERPRINT:-}" ]]; then
  echo "${WAZUH_HOST_FINGERPRINT}" >> ~/.ssh/known_hosts
else
  if [[ "$SSH_STRICT" == "yes" ]]; then
    echo "[ERROR] SSH_STRICT=yes but WAZUH_HOST_FINGERPRINT is missing."
    exit 3
  fi
  echo "==> Disabling strict verification (auto host key scanning)"
fi

SSH_OPTS=(
  -p "$WAZUH_SSH_PORT"
  -o StrictHostKeyChecking=${SSH_STRICT}
  -o UserKnownHostsFile=~/.ssh/known_hosts
)

echo "==> Pulling GitHub repository in ${REPO_DIR}"
ssh -i ~/.ssh/rac ${SSH_OPTS[*]} "${WAZUH_USER}@${WAZUH_HOST}" "cd ${REPO_DIR} && git pull"

echo "==> Restarting Wazuh service"
ssh -i ~/.ssh/rac ${SSH_OPTS[*]} "${WAZUH_USER}@${WAZUH_HOST}" "$WAZUH_RESTART_CMD"

echo "==> Update completed"
