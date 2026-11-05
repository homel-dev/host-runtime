# Host Runtime

Host Runtime provides host-level telemetry collectors and shared object storage
for a single-host Kubernetes/lab environment.

It is intentionally independent from application runtimes such as RR, LLM
Runtime, Memory Steward, and from the shared observability UI. Standard
telemetry is shipped to the OCO shared observability backend instead of being
stored in a namespace-local metrics or log backend.

## Components

- Grafana Alloy as the namespace-local telemetry collector/shipper;
- Node Exporter for host CPU, memory, filesystem, disk, network, and load;
- Process Exporter for process/application-group visibility;
- MinIO AIStor for shared S3-compatible object storage;
- an Argo CronWorkflow for credentialed offsite MinIO object copies;
- a Kubernetes execution toolbox image for external operator shell tooling;
- a Grafana/OCO dashboard definition;
- namespace-local RBAC allowing the OCO service account to read the dashboard
  definition.

## Architecture

~~~text
host-runtime namespace
├── alloy
├── node-exporter
├── process-exporter
├── minio
├── minio-offsite-backup CronWorkflow
└── oco-consumer
    ├── dashboard ConfigMap
    └── read-only RBAC

alloy.host-runtime
├── metrics ──> alloy.observability-backend:12347 ──> VictoriaMetrics
├── logs    ──> alloy.observability-backend:12348 ──> VictoriaLogs
└── OTLP    ──> alloy.observability-backend:4317  ──> VictoriaMetrics / VictoriaLogs / Tempo
~~~

There is no Prometheus, VictoriaMetrics, VictoriaLogs, Loki, or Tempo backend
in `host-runtime`.

MinIO is a shared platform service. Application buckets, policies, and
credentials remain contracts of the consuming projects. Host Runtime owns the
MinIO service, its persistent storage, network boundary, the RR artifact-store
provisioning workflow, and the offsite object-copy CronWorkflow, which is credentialed separately.

## Prerequisites

- Kubernetes cluster with a default StorageClass;
- `kubectl`;
- [Task](https://taskfile.dev/);
- the Oh My Bash Git plugin `kex` helper loaded in the operator shell;
- access to `ghcr.io/homel-dev/host-runtime-kex-toolbox`;
- OCO `observability-backend` deployed with central Alloy ingress;
- a dedicated Flux GitHub organization user with repository admin access and a
  bootstrap PAT;
- a MinIO AIStor Free license file for the object-store deployment.

## Deploy

For an isolated local/lab deployment, put the AIStor license at
`./minio.license` and start MinIO:

~~~bash
task minio:start
~~~

On the first run the task automatically creates local `minio.env` from the
committed `minio.env.example`. Both `minio.env` and `minio.license` are ignored
by Git. The example credentials are `minioadmin` / `minioadmin-change-me`; edit
`minio.env` before using MinIO outside an isolated local environment. No shell
exports are required.

Bootstrap Flux once for the Minikube cluster:

~~~bash
export GITHUB_TOKEN=...
task flux:bootstrap
~~~

After bootstrap, Git is the desired-state deployment path. `task deploy`
refreshes the external MinIO bootstrap Secret and requests Flux reconciliation;
it does not apply the Host Runtime Kustomization directly.

`task delete` remains an explicit operator command and is not part of normal
reconciliation. It deletes labeled Deployments, DaemonSets, StatefulSets,
Services, ConfigMaps, Roles, and RoleBindings. It does not delete the namespace,
MinIO PVCs, the MinIO bootstrap Secret, CronWorkflows, ServiceAccounts, or
NetworkPolicies. Destructive namespace/data removal requires
`HOST_RUNTIME_PURGE=YES task purge`.

See [Flux GitOps](docs/05_flux_gitops.md) for bootstrap, authentication,
repository mapping, reconciliation, and recovery. See
[Kubernetes execution toolbox image](docs/06_kex_toolbox.md) for the image
contract; the shell Git plugin owns `kex` execution and RBAC.

## Status

~~~bash
task status
task events
task logs-alloy
~~~

MinIO-specific operations:

~~~bash
task minio:start
task minio:stop
task minio:restart
task minio:status
task minio:logs
task minio:console
task minio:api
~~~

## Validation

Render the repository-owned Kustomize roots and syntax-check operator scripts
without mutating a cluster:

~~~bash
task validate
~~~

GitHub Actions additionally runs organization repository standards, semantic
repository checks, the toolbox image smoke test, and toolbox publication on
pushes to `main`.

## OCO wiring

Host Runtime publishes only its Grafana dashboard contract. The dashboard uses
the shared OCO datasource UID `victoriametrics`; it does not publish a Host
Runtime datasource.

The `host-runtime` namespace is labeled
`observability.homel.dev/telemetry-consumer=true`, allowing its Alloy instance
to send telemetry to central Alloy in `observability-backend`.

See [docs/02_oco_wiring.md](docs/02_oco_wiring.md).

## Object storage

The S3 endpoint is cluster-local:

~~~text
http://minio.host-runtime.svc.cluster.local:9000
~~~

The MinIO Console is not externally exposed. Use `task minio:console` when
administrative UI access is required.

See [docs/04_object_storage.md](docs/04_object_storage.md) for storage,
credentials, consumer isolation, offsite backup, and licensing details.

## Scope boundaries

Host Runtime does not own:

- application-specific telemetry;
- GPU/DCGM metrics owned by LLM Runtime;
- telemetry storage backends (VictoriaMetrics, VictoriaLogs, Tempo) owned by
  OCO;
- application semantics for objects stored in MinIO;
- public ingress/NodePort exposure;
- Grafana/OCO deployment lifecycle.

## Documentation

- [Overview](docs/01_overview.md)
- [OCO wiring](docs/02_oco_wiring.md)
- [Metrics](docs/03_metrics.md)
- [Shared object storage](docs/04_object_storage.md)
- [Flux GitOps](docs/05_flux_gitops.md)
- [Kubernetes execution toolbox image](docs/06_kex_toolbox.md)
- [MinIO offsite backup](k8s/minio/BACKUP.md)

## License

Host Runtime is licensed under the [MIT License](LICENSE).
