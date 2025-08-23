#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob
echo "==> Lint XML: decoders/*.xml rules/*.xml"
fail=0
lint_dir() {
  local dir="$1"
  if [[ -d "$dir" ]]; then
    for f in "$dir"/*.xml; do
      if ! xmllint --noout "$f"; then
        echo "[ERROR] xmllint failed: $f"
        fail=1
      else
        echo "[OK] $f"
      fi
    done
  else
    echo "[WARN] Directory not found: $dir"
  fi
}
lint_dir "decoders"
lint_dir "rules"
exit $fail
