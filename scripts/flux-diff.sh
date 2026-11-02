#!/usr/bin/env bash
set -euo pipefail
env="${1:-}"
context="${2:-}"
case "$env" in
  dev|preprod|prod) ;;
  *) echo "uso: mise run flux-diff -- <dev|preprod|prod> <kube-context>" >&2; exit 1 ;;
esac
if [ -z "$context" ]; then
  echo "Falta el kube-context" >&2
  exit 1
fi
# flux diff sale con 1 cuando hay diferencias, y eso no es un error
for name in infrastructure apps; do
  rc=0
  flux --context "$context" diff kustomization "$name" --path "./$name/$env" || rc=$?
  [ "$rc" -le 1 ] || exit "$rc"
done
