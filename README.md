# Host Runtime

Host Runtime provides host-level telemetry and shared object storage for a single-host Kubernetes/lab environment.

It is intentionally independent from application runtimes such as RR, LLM Runtime, Memory Steward, and from the shared observability UI. Consumer projects can use Host Runtime services without owning those services themselves.

## Components

- Prometheus for namespace-local metrics storage
- Node Exporter for host CPU, memory, filesystem, disk, network, load, and uptime
- Process Exporter for process/application-group visibility
- MinIO for shared S3-compatible object storage
- Grafana/OCO datasource and dashboard definitions
- Namespace-local RBAC allowing the OCO service account to read those definitions

## Architecture

```text
host-runtime namespace
├── prometheus
├── node-exporter
├── process-exporter
├── minio
└── oco-consumer
    ├── datasource ConfigMap
    ├── dashboard ConfigMap
    └── read-only RBAC
```

MinIO is a shared platform service. Consumer buckets and credentials belong to the consuming project, not to this repository.

## Prerequisites

- Kubernetes cluster with a default StorageClass
- `kubectl`
- [Task](https://taskfile.dev/)
- MinIO AIStor Free license file for the object-store deployment

## Deploy

Create the MinIO bootstrap Secret first:

```bash
export MINIO_ROOT_USER='replace-with-a-long-random-access-key'
export MINIO_ROOT_PASSWORD='replace-with-a-long-random-secret-key'
export MINIO_LICENSE_FILE='/absolute/path/to/minio.license'
task minio:bootstrap-secret
```

Deploy Host Runtime:

```bash
task deploy
```

`task delete` removes workloads and configuration but intentionally retains persistent data PVCs and the MinIO bootstrap Secret. Destructive namespace/data removal requires `HOST_RUNTIME_PURGE=YES task purge`.

## Status

```bash
task status
task targets
task up
```

MinIO-specific operations:

```bash
task minio:status
task minio:logs
task minio:console
task minio:api
```

## Validation

Render all Kustomize manifests without touching a cluster:

```bash
task validate
```

The same validation runs in GitHub Actions.

## OCO wiring

Host Runtime publishes the OCO consumer contract in its own namespace. The shared observability-console deployment must watch `host-runtime` for labeled datasource and dashboard ConfigMaps.

The repository includes an OCO-side patch at:

```text
oco-patches/observability-console-watch-host-runtime.patch
```

See [docs/02_oco_wiring.md](docs/02_oco_wiring.md).

## Object storage

The S3 endpoint is cluster-local:

```text
http://minio.host-runtime.svc.cluster.local:9000
```

The MinIO Console is not externally exposed. Use `task minio:console` when administrative UI access is required.

See [docs/04_object_storage.md](docs/04_object_storage.md) for storage, credentials, consumer isolation, and licensing details.

## Scope boundaries

Host Runtime does not own:

- application-specific telemetry;
- GPU/DCGM metrics owned by LLM Runtime;
- consumer bucket policies or credentials;
- public ingress/NodePort exposure;
- Grafana/OCO deployment lifecycle.

## Documentation

- [Overview](docs/01_overview.md)
- [OCO wiring](docs/02_oco_wiring.md)
- [Metrics](docs/03_metrics.md)
- [Shared object storage](docs/04_object_storage.md)

## License

No repository license is currently declared. Choose and add the intended open-source license before making the repository public if redistribution/contribution rights should be granted.
