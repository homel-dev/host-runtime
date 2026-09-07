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

## Bootstrap secret

Set three local environment variables:

```bash
export MINIO_ROOT_USER='replace-with-a-long-random-access-key'
export MINIO_ROOT_PASSWORD='replace-with-a-long-random-secret-key'
export MINIO_LICENSE_FILE='/absolute/path/to/minio.license'
```

Create or update the Secret:

```bash
task minio:bootstrap-secret
```

If the MinIO StatefulSet already exists, the task restarts it so updated root credentials take effect.

The secret contains:

```text
root-user
root-password
minio.license
```

None of these values belong in the repository.

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

The exact bucket names are consumer contracts, not Host Runtime configuration.

## Observability

MinIO exposes Prometheus metrics on the internal S3 service. This deployment sets `MINIO_PROMETHEUS_AUTH_TYPE=public` and does not expose the service outside the cluster.

Host Runtime Prometheus scrapes:

```text
http://minio.host-runtime.svc.cluster.local:9000/minio/metrics/v3
```

If the cluster later adopts namespace default-deny policies or externally exposes the S3 API, replace public metrics with a dedicated Prometheus credential/token.

## Operations

```bash
task minio:status
task minio:logs
task minio:console
task minio:api
```

`minio:console` and `minio:api` use `kubectl port-forward`; they do not create persistent host-facing services.
