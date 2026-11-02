#!/usr/bin/env bash
set -euo pipefail

pre-commit install

if grep -q '^PROJECT_NAME = "REEMPLAZAME"$' mise.toml || grep -q "@REEMPLAZAME" CODEOWNERS || grep -q "REEMPLAZAME" clusters/*/flux-instance.yaml; then
  if [ -t 0 ]; then
    mise run configure
  else
    echo "Sin terminal interactiva: ejecuta mise run configure para rellenar los valores del proyecto"
  fi
fi

helm plugin list 2>/dev/null | grep -q "^diff" || helm plugin install --verify=false https://github.com/databus23/helm-diff
helm plugin list 2>/dev/null | grep -q "^secrets" || helm plugin install --verify=false https://github.com/jkroepke/helm-secrets

echo "Entorno listo."
