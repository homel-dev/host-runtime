# Shared Object Storage

## Purpose

`host-runtime` owns a single-node MinIO object store as a shared platform storage primitive.

The service is intentionally consumer-neutral. RR, Memory Steward, and future workloads can use separate buckets and credentials without owning separate object-store deployments.

MinIO is not part of the observability presentation layer and is not coupled to Grafana/OCO.

## Placement

The object store runs in the `host-runtime` namespace:

```text
minio.host-runtime.svc.cluster.local:9000
```

The Console is cluster-local on:

```text
minio-console.host-runtime.svc.cluster.local:9001
```

Use `task minio:console` for local administrative access instead of exposing the Console with a NodePort or LoadBalancer.

## Distribution and license

The deployment uses MinIO AIStor Free in a single-node topology compatible with the Free-tier limits. It intentionally uses a direct StatefulSet rather than installing the AIStor Kubernetes Operator, keeping the local platform footprint small. Current upstream Community Edition binaries and container images are no longer maintained; the old `minio/minio` image is intentionally not used here.

AIStor Free requires a MinIO license file. Keep the license and root credentials outside Git and load them into the `minio-bootstrap` Kubernetes Secret.

Official documentation:

- https://docs.min.io/aistor/operations/licenses/
- https://docs.min.io/aistor/installation/kubernetes/install/deploy-aistor-on-kubernetes/

## Local configuration and bootstrap Secret

The operator-facing configuration lives in local `minio.env`, which is ignored by Git. The repository contains `minio.env.example` with lab defaults:

```text
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=minioadmin-change-me
MINIO_LICENSE_FILE=./minio.license
```

The normal first-run path is simply:

```bash
# Put the AIStor license at ./minio.license, then:
task minio:start
```

If `minio.env` does not exist, `minio:start` creates it automatically from `minio.env.example`. `task minio:restart` and the full `task deploy` path use the same local file; no shell exports are required. Change `MINIO_LICENSE_FILE` in `minio.env` only if the license lives somewhere else. Both `minio.env` and `minio.license` are ignored by Git. `task minio:init` remains available when you only want to materialize/edit the local file without starting MinIO.

The committed credentials are examples for an isolated local/lab deployment. Change them before exposing MinIO outside that environment. Applications must never use these root credentials.

The bootstrap task materializes the local values into Kubernetes:

```bash
task minio:bootstrap-secret
```

The resulting `minio-bootstrap` Secret contains:

```text
root-user
root-password
minio.license
```

No credential or license value is committed to the repository.

## Storage

The StatefulSet creates one `ReadWriteOnce` PVC requesting `50Gi` from the cluster default StorageClass.

The PVC is generated from the StatefulSet `volumeClaimTemplates`. `task delete` intentionally removes workloads/configuration without deleting the namespace, generated PVC, or MinIO bootstrap Secret. The destructive `task purge` path requires `HOST_RUNTIME_PURGE=YES` and deletes the entire namespace, including object data.

Change the requested capacity in `k8s/minio/statefulset.yml` before first deployment if a different size is required.

This topology is intended for a single-node lab/platform runtime. It is not an HA object-storage design.

## Consumer isolation

Do not give applications the MinIO root credentials.

Each consumer should own:

- its bucket namespace;
- a dedicated MinIO user/access key;
- an IAM policy limited to the required bucket prefixes;
- its own Kubernetes Secret in the consumer namespace.

Example ownership model:

```text
rr
  bucket: rr-artifacts

memory-steward
  bucket: memory-steward
```

Application bucket names remain consumer contracts, not Host Runtime configuration. `source-controller` serves Flux artifacts directly; it does not mirror them into MinIO.

`k8s/minio-consumers/networkpolicy.yml` permits S3 traffic for the RR runner and OCO consumers, without granting Flux `source-controller` access.

## Observability

MinIO exposes Prometheus metrics on the internal S3 service. This deployment sets `MINIO_PROMETHEUS_AUTH_TYPE=public` and does not expose the service outside the cluster.

Host Runtime Prometheus scrapes:

```text
http://minio.host-runtime.svc.cluster.local:9000/minio/metrics/v3
```

If the cluster later adopts namespace default-deny policies or externally exposes the S3 API, replace public metrics with a dedicated Prometheus credential/token.

## Operations

```bash
task minio:init
task minio:start
task minio:stop
task minio:restart
task minio:status
task minio:logs
task minio:console
task minio:api
```

`minio:start` creates/updates the bootstrap Secret, applies `k8s/minio` plus the MinIO consumer NetworkPolicy, waits for the MinIO StatefulSet to become ready, and prints status. `minio:restart` refreshes the Secret, restarts the existing StatefulSet, and waits for readiness; if MinIO is absent, it deploys it. `minio:stop` removes the MinIO workload and Services while deliberately preserving the data PVC and bootstrap Secret.

`minio:console` and `minio:api` use `kubectl port-forward`; they do not create persistent host-facing services.


## RR run-artifact integration

`task minio:rr-artifacts` provisions the `rr-artifacts` bucket, an RR writer identity scoped to that bucket, and an OCO read-only identity. It publishes the writer S3 configuration as Secret `rr/rr-artifact-store` and the reader configuration as Secret `observability-console/oco-artifact-store`. It also applies `k8s/minio-consumers/networkpolicy.yml`, which permits S3 access from the trusted RR runner and the Observability Console while keeping MinIO itself ClusterIP-only.

Anonymous bucket access is explicitly disabled. OCO authenticates to MinIO with the read-only identity and is the browser-facing authenticated proxy. RR runners write `runs/<run-id>/...` after every terminal worker invocation. The source `workspace/` tree is deliberately excluded from run-artifact publication.

Host Runtime still owns only storage. RR owns artifact meaning and publication; OCO owns presentation.
