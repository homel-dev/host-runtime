#!/usr/bin/env bash
set -euo pipefail

KEX_NAMESPACE="${KEX_NAMESPACE:-kex}"
KEX_DEPLOYMENT="${KEX_DEPLOYMENT:-kex-toolbox}"
KEX_IMAGE="${KEX_IMAGE:-ghcr.io/homel-dev/host-runtime-kex-toolbox:main}"
KEX_IMAGE_PULL_SECRET="${KEX_IMAGE_PULL_SECRET:-}"

command -v kubectl >/dev/null 2>&1 || {
  printf '%s\n' 'required command not found: kubectl' >&2
  exit 1
}

kubectl get namespace "$KEX_NAMESPACE" >/dev/null 2>&1 || kubectl create namespace "$KEX_NAMESPACE" >/dev/null

{
  cat <<EOF_DEPLOY_HEAD
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${KEX_DEPLOYMENT}
  namespace: ${KEX_NAMESPACE}
  labels:
    app.kubernetes.io/name: ${KEX_DEPLOYMENT}
    app.kubernetes.io/component: toolbox
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: ${KEX_DEPLOYMENT}
  template:
    metadata:
      labels:
        app.kubernetes.io/name: ${KEX_DEPLOYMENT}
        app.kubernetes.io/component: toolbox
    spec:
      automountServiceAccountToken: false
EOF_DEPLOY_HEAD

  if [ -n "$KEX_IMAGE_PULL_SECRET" ]; then
    cat <<EOF_PULL_SECRET
      imagePullSecrets:
        - name: ${KEX_IMAGE_PULL_SECRET}
EOF_PULL_SECRET
  fi

  cat <<EOF_DEPLOY_TAIL
      containers:
        - name: toolbox
          image: ${KEX_IMAGE}
          imagePullPolicy: Always
          command: ["sleep", "infinity"]
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
EOF_DEPLOY_TAIL
} | kubectl apply -f - >/dev/null

kubectl -n "$KEX_NAMESPACE" rollout status "deployment/${KEX_DEPLOYMENT}" --timeout=180s
