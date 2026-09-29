#!/usr/bin/env bash
set -euo pipefail

FLUX_TOOLKIT_VERSION="${FLUX_TOOLKIT_VERSION:-v2.9.5}"
FLUX_GITHUB_OWNER="${FLUX_GITHUB_OWNER:-homel-dev}"
FLUX_GITHUB_REPOSITORY="${FLUX_GITHUB_REPOSITORY:-host-runtime}"
FLUX_GITHUB_BRANCH="${FLUX_GITHUB_BRANCH:-main}"
FLUX_CLUSTER_PATH="${FLUX_CLUSTER_PATH:-clusters/minikube}"
FLUX_EXPECT_CONTEXT="${FLUX_EXPECT_CONTEXT:-minikube}"

command -v kubectl >/dev/null 2>&1 || {
  printf '%s\n' 'required command not found: kubectl' >&2
  exit 1
}

current_context="$(kubectl config current-context)"
if [ "$current_context" != "$FLUX_EXPECT_CONTEXT" ] && [ "${FLUX_ALLOW_CONTEXT_MISMATCH:-0}" != "1" ]; then
  printf '%s\n' "refusing Flux bootstrap: current context '$current_context', expected '$FLUX_EXPECT_CONTEXT'" >&2
  printf '%s\n' 'set FLUX_ALLOW_CONTEXT_MISMATCH=1 only if the target cluster is intentional' >&2
  exit 1
fi

if [ -z "${GITHUB_TOKEN:-}" ] && [ -n "${FLUX_GITHUB_TOKEN:-}" ]; then
  export GITHUB_TOKEN="$FLUX_GITHUB_TOKEN"
fi
: "${GITHUB_TOKEN:?GITHUB_TOKEN is required; use the dedicated Flux organization user PAT}"

GITHUB_TOKEN="$GITHUB_TOKEN" ./scripts/kex-run.sh bash -lc '
set -euo pipefail
owner="$1"
repository="$2"
branch="$3"
path="$4"
version="$5"

flux version --client
flux check --pre
flux bootstrap github \
  --owner="$owner" \
  --repository="$repository" \
  --branch="$branch" \
  --path="$path" \
  --version="$version" \
  --personal=false \
  --token-auth=false \
  --reconcile
flux check
flux get all -A
' -- \
  "$FLUX_GITHUB_OWNER" \
  "$FLUX_GITHUB_REPOSITORY" \
  "$FLUX_GITHUB_BRANCH" \
  "$FLUX_CLUSTER_PATH" \
  "$FLUX_TOOLKIT_VERSION"
