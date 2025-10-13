#!/usr/bin/env bash
set -euo pipefail

echo "==> Checking rule IDs via check_rule_ids.py"

if [[ ! -f "check_rule_ids.py" ]]; then
  echo "[ERROR] File check_rule_ids.py not found at repository root"
  exit 2
fi

python -m pip install --upgrade pip >/dev/null 2>&1 || true
python -m pip install lxml >/dev/null 2>&1 || true

python check_rule_ids.py
