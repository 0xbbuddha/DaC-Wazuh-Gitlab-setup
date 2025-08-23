#!/usr/bin/env bash
set -euo pipefail

echo "==> Vérification des IDs de règles via check_rule_ids.py"

if [[ ! -f "check_rule_ids.py" ]]; then
  echo "[ERROR] Fichier check_rule_ids.py introuvable à la racine du repo"
  exit 2
fi

python -m pip install --upgrade pip >/dev/null 2>&1 || true
python -m pip install lxml >/dev/null 2>&1 || true

python check_rule_ids.py
