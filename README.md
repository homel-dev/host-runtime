# Host Runtime

Host Runtime provides host-level telemetry collectors and shared object storage for a single-host Kubernetes/lab environment.

It is intentionally independent from application runtimes such as RR, LLM Runtime, Memory Steward, and from the shared observability UI. Standard telemetry is shipped to the OCO shared observability backend instead of being stored in a namespace-local Prometheus.

## Components

- Grafana Alloy as the namespace-local telemetry collector/shipper
- Node Exporter for host CPU, memory, filesystem, disk, network, load, and uptime
- Process Exporter for process/application-group visibility
- MinIO for shared S3-compatible object storage
- Grafana/OCO dashboard definition
- Namespace-local RBAC allowing the OCO service account to read the dashboard definition

## Architecture

```text
host-runtime namespace
├── alloy
├── node-exporter
├── process-exporter
├── minio
└── oco-consumer
    ├── dashboard ConfigMap
    └── read-only RBAC

alloy.host-runtime
├── metrics ──> alloy.observability-backend:12347 ──> VictoriaMetrics
├── logs    ──> alloy.observability-backend:12348 ──> VictoriaLogs
└── OTLP    ──> alloy.observability-backend:4317  ──> VictoriaMetrics / VictoriaLogs / Tempo
```

There is no Prometheus, VictoriaMetrics, VictoriaLogs, Loki, or Tempo backend in `host-runtime`.

MinIO is a shared platform service. Consumer buckets and credentials belong to the consuming project, not to this repository.

## Prerequisites

- Kubernetes cluster with a default StorageClass
- `kubectl`
- [Task](https://taskfile.dev/)
- OCO `observability-backend` deployed with central Alloy ingress
- MinIO AIStor Free license file for the object-store deployment

## Deploy

For an isolated local/lab deployment, put the AIStor license at `./minio.license` and start MinIO:

```bash
task minio:start
```

On the first run the task automatically creates local `minio.env` from the committed `minio.env.example`. Both `minio.env` and `minio.license` are ignored by Git. The example credentials are `minioadmin` / `minioadmin-change-me`; edit `minio.env` before using MinIO outside an isolated local environment. No shell exports are required.

Deploy the complete Host Runtime:

```bash
task deploy
```

`task deploy` waits for namespace-local Alloy to become ready before deleting legacy `prometheus` resources from older Host Runtime revisions.

`task delete` removes workloads and configuration but intentionally retains persistent MinIO data PVCs and the MinIO bootstrap Secret. Destructive namespace/data removal requires `HOST_RUNTIME_PURGE=YES task purge`.

## Status

```bash
task status
task telemetry-status
task logs-alloy
```

MinIO-specific operations:

```bash
task minio:start
task minio:stop
task minio:restart
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

Host Runtime publishes only its Grafana dashboard contract. The dashboard uses the shared OCO datasource UID `victoriametrics`; it does not publish a Host Runtime datasource.

The `host-runtime` namespace is labeled `observability.homel.dev/telemetry-consumer=true`, allowing its Alloy instance to send telemetry to central Alloy in `observability-backend`.

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
- telemetry storage backends (VictoriaMetrics, VictoriaLogs, Tempo) owned by OCO;
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
