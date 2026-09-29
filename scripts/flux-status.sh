#!/usr/bin/env bash
set -euo pipefail

exec ./scripts/kex-run.sh bash -lc '
set -euo pipefail
flux check
printf "\n"
flux get sources git -A
printf "\n"
flux get kustomizations -A
printf "\n"
kubectl -n flux-system get pods -o wide
printf "\n"
kubectl -n flux-system get events --sort-by=.lastTimestamp | tail -50
'
