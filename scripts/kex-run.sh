#!/usr/bin/env bash
set -euo pipefail

KEX_NAMESPACE="${KEX_NAMESPACE:-kex}"
KEX_IMAGE="${KEX_IMAGE:-ghcr.io/homel-dev/host-runtime-kex-toolbox:main}"
KEX_IMAGE_PULL_SECRET="${KEX_IMAGE_PULL_SECRET:-}"
KEX_TIMEOUT="${KEX_TIMEOUT:-180s}"

command -v kubectl >/dev/null 2>&1 || {
  printf '%s\n' 'required command not found: kubectl' >&2
  exit 1
}

suffix="$$-$(date +%s)"
service_account="kex-admin-${suffix}"
binding="kex-admin-${suffix}"
pod="kex-admin-${suffix}"
env_secret="kex-env-${suffix}"
env_file="$(mktemp)"

cleanup() {
  rm -f "$env_file"
  kubectl -n "$KEX_NAMESPACE" delete pod "$pod" --ignore-not-found --wait=false >/dev/null 2>&1 || true
  kubectl -n "$KEX_NAMESPACE" delete secret "$env_secret" --ignore-not-found >/dev/null 2>&1 || true
  kubectl delete clusterrolebinding "$binding" --ignore-not-found >/dev/null 2>&1 || true
  kubectl -n "$KEX_NAMESPACE" delete serviceaccount "$service_account" --ignore-not-found >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

kubectl get namespace "$KEX_NAMESPACE" >/dev/null 2>&1 || kubectl create namespace "$KEX_NAMESPACE" >/dev/null
kubectl -n "$KEX_NAMESPACE" create serviceaccount "$service_account" >/dev/null
kubectl create clusterrolebinding "$binding" \
  --clusterrole=cluster-admin \
  --serviceaccount="${KEX_NAMESPACE}:${service_account}" >/dev/null

chmod 0600 "$env_file"
printf 'KEX_EXECUTION=1\n' >"$env_file"
if [ -n "${GITHUB_TOKEN:-}" ]; then
  printf 'GITHUB_TOKEN=%s\n' "$GITHUB_TOKEN" >>"$env_file"
fi
kubectl -n "$KEX_NAMESPACE" create secret generic "$env_secret" \
  --from-env-file="$env_file" \
  --dry-run=client -o yaml | kubectl apply -f - >/dev/null

{
  cat <<EOF_POD_HEAD
apiVersion: v1
kind: Pod
metadata:
  name: ${pod}
  namespace: ${KEX_NAMESPACE}
  labels:
    app.kubernetes.io/name: kex-toolbox
    app.kubernetes.io/component: ephemeral-admin
spec:
  restartPolicy: Never
  serviceAccountName: ${service_account}
  automountServiceAccountToken: true
EOF_POD_HEAD

  if [ -n "$KEX_IMAGE_PULL_SECRET" ]; then
    cat <<EOF_PULL_SECRET
  imagePullSecrets:
    - name: ${KEX_IMAGE_PULL_SECRET}
EOF_PULL_SECRET
  fi

  cat <<EOF_POD_TAIL
  containers:
    - name: toolbox
      image: ${KEX_IMAGE}
      imagePullPolicy: Always
      command: ["sleep", "infinity"]
      envFrom:
        - secretRef:
            name: ${env_secret}
      resources:
        requests:
          cpu: 10m
          memory: 32Mi
        limits:
          cpu: 1000m
          memory: 512Mi
      securityContext:
        runAsNonRoot: true
        allowPrivilegeEscalation: false
        capabilities:
          drop: ["ALL"]
EOF_POD_TAIL
} | kubectl apply -f - >/dev/null

if ! kubectl -n "$KEX_NAMESPACE" wait --for=condition=Ready "pod/${pod}" --timeout="$KEX_TIMEOUT" >/dev/null; then
  kubectl -n "$KEX_NAMESPACE" describe "pod/${pod}" >&2 || true
  exit 1
fi

remote_wrapper='set -euo pipefail
kubeconfig="$(mktemp)"
trap '\''rm -f "$kubeconfig"'\'' EXIT
cat >"$kubeconfig" <<'\''EOF_KUBECONFIG'\''
apiVersion: v1
kind: Config
clusters:
  - name: in-cluster
    cluster:
      server: https://kubernetes.default.svc
      certificate-authority: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
contexts:
  - name: in-cluster
    context:
      cluster: in-cluster
      user: kex
current-context: in-cluster
users:
  - name: kex
    user:
      tokenFile: /var/run/secrets/kubernetes.io/serviceaccount/token
EOF_KUBECONFIG
export KUBECONFIG="$kubeconfig"
if [ "$#" -eq 0 ]; then
  exec /bin/bash -l
fi
exec "$@"'

exec_args=(-i)
if [ -t 0 ] && [ -t 1 ]; then
  exec_args=(-it)
fi

set +e
kubectl exec "${exec_args[@]}" \
  -n "$KEX_NAMESPACE" \
  "$pod" \
  -c toolbox \
  -- /bin/bash -c "$remote_wrapper" -- "$@"
rc=$?
set -e
exit "$rc"
