#!/usr/bin/env bash
set -euo pipefail
scope="${1:-}"
newkey="${2:-}"
case "$scope" in
  dev|preprod|prod) dirs=("apps/$scope" "infrastructure/$scope" "clusters/$scope") ;;
  local) dirs=("local") ;;
  *) echo "uso: mise run add-recipient -- <dev|preprod|prod|local> age1..." >&2; exit 1 ;;
esac
case "$newkey" in
  age1*) ;;
  *) echo "uso: mise run add-recipient -- <dev|preprod|prod|local> age1..." >&2; exit 1 ;;
esac

rule="path_regex:.*[/^]$scope/"
age_line="$(sed -nE "\|$rule|,/^\s*age:/{/^\s*age:/p}" .sops.yaml)"
if grep -qF "$newkey" <<< "$age_line"; then
  echo "La clave ya esta en la regla $scope, no se modifica"
elif grep -q "REEMPLAZAME" <<< "$age_line"; then
  sed -i -E "\|$rule|,/^\s*age:/{/^\s*age:/s|<age1REEMPLAZAME[^>]*>|$newkey|}" .sops.yaml
  echo "Regla $scope actualizada con la nueva public key"
else
  sed -i -E "\|$rule|,/^\s*age:/{/^\s*age:/s|$|,$newkey|}" .sops.yaml
  echo "Regla $scope actualizada con la nueva public key"
fi

for dir in "${dirs[@]}"; do
  [ -d "$dir" ] || continue
  find "$dir" -type f \( -iname "*.secret.yaml" -o -iname "*.secret.yml" -o -iname "*.secrets.yaml" -o -iname "*.secrets.yml" \) | while read -r f; do
    if grep -q "^sops:" "$f"; then
      echo "actualizando recipients en: $f"
      sops updatekeys -y "$f"
    else
      echo "skip (no encriptado): $f"
    fi
  done
done
