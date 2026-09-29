#!/usr/bin/env bash
set -euo pipefail

kubectl -n flux-system get deployments
printf '\n'
kubectl -n flux-system get gitrepositories
printf '\n'
kubectl -n flux-system get kustomizations
printf '\n'
kubectl -n flux-system get events --sort-by=.lastTimestamp | tail -50
