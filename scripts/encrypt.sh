#!/usr/bin/env bash
set -euo pipefail
find . -type f \( -iname "*.secret.yaml" -o -iname "*.secret.yml" -o -iname "*.secrets.yaml" -o -iname "*.secrets.yml" \) -not -path "./.git/*" | while read -r f; do
  if grep -q "sops:" "$f" 2>/dev/null; then
    echo "skip (ya encriptado): $f"
    continue
  fi
  echo "encriptando: $f"
  sops --encrypt --in-place "$f"
done
