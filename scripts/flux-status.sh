#!/usr/bin/env bash
set -euo pipefail

declare -F kex >/dev/null 2>&1 || {
  printf '%s\n' 'required shell helper not found: kex (load the Oh My Bash git plugin)' >&2
  exit 1
}

kex bash -lc '
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
