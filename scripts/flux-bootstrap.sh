#!/usr/bin/env bash
set -euo pipefail

EXPECTED_CONTEXT="${FLUX_EXPECT_CONTEXT:-minikube}"
AUTH_SECRET="${FLUX_AUTH_SECRET:-flux-system}"

for cmd in kubectl; do
  command -v "$cmd" >/dev/null 2>&1 || {
    printf '%s\n' "required command not found: $cmd" >&2
    exit 1
  }
done

current_context="$(kubectl config current-context)"
if [ "$current_context" != "$EXPECTED_CONTEXT" ] && [ "${FLUX_ALLOW_CONTEXT_MISMATCH:-0}" != "1" ]; then
  printf '%s\n' "refusing Flux bootstrap: current context '$current_context', expected '$EXPECTED_CONTEXT'" >&2
  printf '%s\n' "set FLUX_ALLOW_CONTEXT_MISMATCH=1 only if the target cluster is intentional" >&2
  exit 1
fi

: "${FLUX_GITHUB_TOKEN:?FLUX_GITHUB_TOKEN is required to read the private host-runtime repository}"

# Install the controllers first. gotk-sync cannot be applied before the Flux CRDs exist.
kubectl apply -k clusters/minikube/flux-system/components

kubectl wait --for=condition=Established \
  crd/gitrepositories.source.toolkit.fluxcd.io \
  crd/kustomizations.kustomize.toolkit.fluxcd.io \
  --timeout=180s

for deployment in source-controller kustomize-controller; do
  kubectl -n flux-system rollout status "deployment/$deployment" --timeout=180s
done

secret_dir="$(mktemp -d)"
trap 'rm -rf "$secret_dir"' EXIT INT TERM
umask 077
printf '%s' 'git' >"$secret_dir/username"
printf '%s' "$FLUX_GITHUB_TOKEN" >"$secret_dir/password"

kubectl -n flux-system create secret generic "$AUTH_SECRET" \
  --from-file=username="$secret_dir/username" \
  --from-file=password="$secret_dir/password" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f clusters/minikube/flux-system/gotk-sync.yaml

kubectl -n flux-system wait --for=condition=Ready gitrepository/flux-system --timeout=180s
kubectl -n flux-system wait --for=condition=Ready kustomization/flux-system --timeout=600s
kubectl -n flux-system wait --for=condition=Ready kustomization/host-runtime --timeout=600s
kubectl -n flux-system wait --for=condition=Ready kustomization/llm-runtime --timeout=900s

kubectl -n flux-system get gitrepositories,kustomizations
