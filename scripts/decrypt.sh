#!/usr/bin/env bash
set -euo pipefail
failed=0
while read -r f; do
  grep -q "^sops:" "$f" || continue
  echo "desencriptando: $f"
  sops --decrypt --in-place "$f" 2>/dev/null || { echo "skip (sin clave valida): $f"; failed=$((failed + 1)); }
done < <(find "${1:-.}" -type f \( -iname "*.secret.yaml" -o -iname "*.secret.yml" -o -iname "*.secrets.yaml" -o -iname "*.secrets.yml" \) -not -path "./.git/*")
echo "Archivos sin desencriptar: $failed"
