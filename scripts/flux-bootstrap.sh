#!/usr/bin/env bash
set -euo pipefail
env="${1:-}"
context="${2:-}"
case "$env" in
  dev|preprod|prod) ;;
  *) echo "uso: GIT_TOKEN=... mise run flux-bootstrap -- <dev|preprod|prod> <kube-context>" >&2; exit 1 ;;
esac
if [ -z "$context" ]; then
  echo "Falta el kube-context: uso: GIT_TOKEN=... mise run flux-bootstrap -- $env <kube-context>" >&2
  exit 1
fi
if grep -rl "REEMPLAZAME" "clusters/$env"; then
  echo "Hay marcadores REEMPLAZAME sin rellenar en los archivos anteriores" >&2
  exit 1
fi
keyfile="$HOME/.config/sops/age/projects/$PROJECT_NAME/clusters/$env.txt"
if [ ! -f "$keyfile" ]; then
  echo "No existe $keyfile: ejecuta mise run flux-keygen -- $env" >&2
  exit 1
fi
url="$(sed -nE 's|^\s*url: (.*)$|\1|p' "clusters/$env/flux-instance.yaml")"
case "$url" in
  ssh://*)
    if [ ! -f "${GIT_SSH_KEY_FILE:-}" ]; then
      echo "Define GIT_SSH_KEY_FILE con una clave privada sin contrasena, registrada como deploy key de solo lectura" >&2
      exit 1
    fi
    ;;
  *)
    if [ -z "${GIT_TOKEN:-}" ]; then
      echo "Define GIT_TOKEN con un token de solo lectura del repositorio" >&2
      exit 1
    fi
    ;;
esac

version="$(sed -nE 's/.*tag: "?([^"]+)"?$/\1/p' "infrastructure/$env/kustomization.yaml")"
helm upgrade --install flux-operator oci://ghcr.io/controlplaneio-fluxcd/charts/flux-operator \
  --kube-context "$context" --namespace flux-system --create-namespace --version "$version" --wait
kubectl --context "$context" -n flux-system create secret generic sops-age \
  --from-file=age.agekey="$keyfile" --dry-run=client -o yaml | kubectl --context "$context" apply -f -
case "$url" in
  ssh://*)
    flux --context "$context" -n flux-system create secret git flux-system \
      --url="$url" --private-key-file="$GIT_SSH_KEY_FILE"
    ;;
  *)
    printf '%s' "$GIT_TOKEN" | flux-operator --kube-context "$context" -n flux-system \
      create secret basic-auth flux-system --username="${GIT_USERNAME:-git}" --password-stdin
    ;;
esac
kubectl --context "$context" apply -f "clusters/$env/flux-instance.yaml"
kubectl --context "$context" -n flux-system wait fluxinstance/flux --for=condition=Ready --timeout=5m
