#!/usr/bin/env bash
set -euo pipefail
kubeconform_args=(
  -summary
  -schema-location default
  -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json'
)
for env in dev preprod prod; do
  echo "== $env =="
  kubeconform "${kubeconform_args[@]}" "clusters/$env"
  for dir in "infrastructure/$env" "apps/$env"; do
    kustomize build "$dir" | kubeconform "${kubeconform_args[@]}"
  done
done
