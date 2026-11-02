#!/usr/bin/env bash
set -euo pipefail
context="${1:?uso: mise run flux-status -- <kube-context>}"
kubectl --context "$context" -n flux-system get fluxinstance
flux --context "$context" get all -A
