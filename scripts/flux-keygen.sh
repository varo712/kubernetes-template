#!/usr/bin/env bash
set -euo pipefail
env="${1:-}"
case "$env" in
  dev|preprod|prod) ;;
  *) echo "uso: mise run flux-keygen -- <dev|preprod|prod>" >&2; exit 1 ;;
esac
case "$PROJECT_NAME" in
  ""|*REEMPLAZAME*|*/*) echo "Define PROJECT_NAME en mise.toml con el nombre del proyecto, sin barras" >&2; exit 1 ;;
esac

keyfile="$HOME/.config/sops/age/projects/$PROJECT_NAME/clusters/$env.txt"
mkdir -p "$(dirname "$keyfile")"
if [ -f "$keyfile" ]; then
  echo "$keyfile ya existe, no se sobreescribe"
else
  (umask 077; age-keygen -o "$keyfile")
  echo "AVISO: guarda $keyfile en un gestor de secretos. Si se pierde, no podras descifrar los secretos de $env."
fi
mise run add-recipient -- "$env" "$(grep "public key" "$keyfile" | sed 's/.*: //')"
