#!/usr/bin/env bash
set -euo pipefail
keyfile="$HOME/.config/sops/age/keys.txt"
mkdir -p "$(dirname "$keyfile")"
if [ -f "$keyfile" ]; then
  echo "$keyfile ya existe, no se sobreescribe"
else
  age-keygen -o "$keyfile"
  echo "Clave generada en $keyfile"
fi

pubkey="$(grep "public key" "$keyfile" | sed 's/.*: //')"
echo "Clave publica: $pubkey"

# Solo las reglas del equipo: la clave personal no debe entrar en prod
if grep -q "<age1REEMPLAZAME_TEAM>" .sops.yaml; then
  sed -i "s|<age1REEMPLAZAME_TEAM>|$pubkey|g" .sops.yaml
  echo ".sops.yaml actualizado con la public key"
else
  echo ".sops.yaml ya tiene la public key del equipo configurada, no se modifica"
fi
