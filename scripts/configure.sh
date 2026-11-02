#!/usr/bin/env bash
set -euo pipefail
if [ ! -t 0 ]; then
  echo "mise run configure necesita una terminal interactiva" >&2
  exit 1
fi

# ask <texto> <valor por defecto> <regex>: repite hasta que la respuesta sea valida
ask() {
  local answer
  while true; do
    read -rp "$1 [$2]: " answer
    answer="${answer:-$2}"
    if [[ "$answer" =~ $3 ]]; then
      printf '%s\n' "$answer"
      return
    fi
    echo "Valor no valido: $answer" >&2
  done
}

current_url="$(sed -nE 's|^\s*url: (.*)$|\1|p' clusters/dev/flux-instance.yaml)"
if grep -q "REEMPLAZAME" <<< "$current_url"; then
  current_url="$(git remote get-url origin 2>/dev/null || true)"
fi
current_project="$(sed -nE 's/^PROJECT_NAME = "(.*)"$/\1/p' mise.toml)"
if [ "$current_project" = "REEMPLAZAME" ]; then
  current_project="$(basename "$PWD")"
fi
current_branch="$(sed -nE 's|^\s*ref: refs/heads/(.*)$|\1|p' clusters/dev/flux-instance.yaml)"
current_owners="$(sed -nE 's|^/CODEOWNERS\s+@(.*)$|\1|p' CODEOWNERS)"
if grep -q "REEMPLAZAME" <<< "$current_owners"; then
  current_owners="org/prod-approvers"
fi

project="$(ask "Nombre del proyecto" "$current_project" '^[A-Za-z0-9._-]+$')"
repo="$(ask "URL del repositorio (https o ssh)" "$current_url" '^(https://[^/[:space:]|]+/|ssh://[^@/[:space:]|]+@[^/[:space:]|]+/|[^@/:[:space:]|]+@[^:/[:space:]|]+:)[^[:space:]|]+$')"

# Separa protocolo, usuario y host/ruta, sea cual sea la forma en que se escribio la URL
case "$repo" in
  https://*)
    source_protocol=https
    ssh_user=git
    host_path="${repo#https://}"
    ;;
  ssh://*)
    source_protocol=ssh
    ssh_user="${repo#ssh://}"
    ssh_user="${ssh_user%%@*}"
    host_path="${repo#ssh://*@}"
    ;;
  *)
    source_protocol=ssh
    ssh_user="${repo%%@*}"
    host_path="${repo#*@}"
    host_path="${host_path/://}"
    ;;
esac

protocol="$(ask "Protocolo de Flux para Git (https/ssh)" "$source_protocol" '^(https|ssh)$')"
if [ "$protocol" != "$source_protocol" ]; then
  # El puerto de un protocolo no sirve para el otro
  host="${host_path%%/*}"
  host_path="${host%%:*}/${host_path#*/}"
  echo "Protocolo cambiado: revisa la URL, algunos servidores usan otra ruta o puerto para cada uno" >&2
fi
if [ "$protocol" = "https" ]; then
  url="https://$host_path"
else
  url="ssh://$ssh_user@$host_path"
fi

branch="$(ask "Rama que sincroniza Flux" "${current_branch:-main}" '^[A-Za-z0-9._/-]+$')"
owners="$(ask "Aprobadores de prod en CODEOWNERS (org/equipo o usuario, sin @)" "$current_owners" '^[A-Za-z0-9._/-]+$')"

echo
echo "Proyecto:     $project"
echo "Repositorio:  $url"
echo "Rama:         $branch"
echo "Aprobadores:  @$owners"
read -rp "Aplicar estos valores? [s/N]: " confirm
case "$confirm" in
  s|S) ;;
  *) echo "Sin cambios"; exit 0 ;;
esac

sed -i -E "s|^PROJECT_NAME = .*|PROJECT_NAME = \"$project\"|" mise.toml
sed -i -E "s|^(\s*url: ).*|\1$url|; s|^(\s*ref: refs/heads/).*|\1$branch|" clusters/*/flux-instance.yaml
sed -i -E "/^\//s|@\S+$|@$owners|" CODEOWNERS
echo "Valores aplicados. Credenciales de Git para flux-bootstrap:"
if [ "$protocol" = "https" ]; then
  echo "  GIT_TOKEN con un token de solo lectura (y GIT_USERNAME si tu servidor exige un usuario concreto)"
else
  echo "  GIT_SSH_KEY_FILE con una clave privada sin contrasena, registrada como deploy key de solo lectura"
fi
