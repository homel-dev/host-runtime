# HOST RUNTIME OVERVIEW
## Runtime Boundaries and Component Ownership
### Foundational Engineering Specification (Document 01 of 06)
*Namespace: host-runtime • Owner: architecture-team*

---

## Navigation

**[README.md](../README.md) → [02_oco_wiring.md](02_oco_wiring.md)**

- [0. Status, Scope, and Authority](#0-status-scope-and-authority)
- [1. Purpose and Ownership](#1-purpose-and-ownership)
- [2. Namespace and Runtime Topology](#2-namespace-and-runtime-topology)
- [3. Telemetry Boundary](#3-telemetry-boundary)
- [4. Process Visibility](#4-process-visibility)
- [5. Shared Object Storage](#5-shared-object-storage)
- [6. Operational Entry Points](#6-operational-entry-points)
- [7. Closing Statement](#7-closing-statement)

---

## 0. Status, Scope, and Authority

**Status:** IMPLEMENTED
**Audience:** Operators, maintainers, and contributors
**Change policy:** Current-state contract. Update this document whenever the
repository changes runtime ownership, topology, or operator entry points.

The checked-in manifests, `Taskfile.yml`, and operator scripts are authoritative
for current runtime behavior.

[Back to top](#navigation)

## 1. Purpose and Ownership

`host-runtime` provides host-level telemetry collection and shared platform
storage for a single-host Kubernetes/lab environment.

The project owns:

- namespace-local Grafana Alloy collection and forwarding;
- Node Exporter and Process Exporter;
- shared MinIO AIStor object storage and its persistent volume contract;
- MinIO consumer network policy and RR artifact-store provisioning;
- the Host Runtime offsite MinIO object-copy CronWorkflow;
- the Host Runtime Grafana dashboard definition and namespaced OCO read RBAC;
- the generic Kubernetes execution toolbox image;
- the Minikube Flux cluster root stored under `clusters/minikube/`.

OCO owns the standard telemetry backends: VictoriaMetrics, VictoriaLogs, and
Tempo in `observability-backend`. Host Runtime does not deploy a local telemetry
database.

[Back to top](#navigation)

## 2. Namespace and Runtime Topology

The primary runtime namespace is:

~~~text
host-runtime
~~~

The root `k8s/kustomization.yml` deploys:

~~~text
host-runtime
  alloy
  node-exporter
  process-exporter
  minio
  minio-offsite-backup CronWorkflow
  minio-consumers NetworkPolicy
  oco-consumer dashboard/RBAC
~~~

The offsite backup CronWorkflow depends on the shared Argo Workflows controller,
which is installed from the cluster Flux root and configured to watch
`host-runtime`.

[Back to top](#navigation)

## 3. Telemetry Boundary

Namespace-local Alloy performs four current functions:

1. scrape Node Exporter and Process Exporter;
2. tail pod logs in its own namespace;
3. accept namespace-local OTLP on ports `4317` and `4318`;
4. forward telemetry to central Alloy in `observability-backend`.

Metrics are remote-written to central Alloy on port `12347`, logs use its Loki
push ingress on `12348`, and OTLP is forwarded by gRPC to `4317`.

The current Alloy configuration does **not** scrape MinIO metrics. MinIO exposes
an internal metrics endpoint, but no `prometheus.scrape` component targets it in
`k8s/observability/alloy/alloy.yml`.

[Back to top](#navigation)

## 4. Process Visibility

`process-exporter` groups host processes by configured application families and
falls back to executable/command grouping. Current explicit matchers include
vLLM, Python, Kubernetes components, container runtimes, SSH, shells, databases,
Prometheus, MinIO, and Grafana.

These matchers are telemetry categories only. A matcher does not mean Host
Runtime deploys the matched application.

Swap panels are intentionally absent from the current Host Runtime dashboard.
The dashboard focuses on CPU, memory, filesystem, disk, network, load, and
process pressure.

[Back to top](#navigation)

## 5. Shared Object Storage

The MinIO deployment is single-node and persistent. It is a shared platform
primitive, not an observability backend and not an HA object-storage design.

Application projects own the meaning of their objects and their scoped
credentials. Host Runtime owns the shared S3 service, its persistence and
network boundary, and the concrete RR artifact-store provisioning workflow.

The root Host Runtime Kustomization also includes a scheduled offsite object
copy implemented as an Argo CronWorkflow. That workflow is intentionally
limited to object copying and verification; it is not a complete disaster
recovery system.

See [04_object_storage.md](04_object_storage.md) and
[../k8s/minio/BACKUP.md](../k8s/minio/BACKUP.md).

[Back to top](#navigation)

## 6. Operational Entry Points

The repository exposes stable Task entry points for validation, status,
Flux reconciliation, MinIO lifecycle, RR artifact-store provisioning, and OCO
consumer inspection.

Use `task --list` for the current inventory. The primary non-destructive checks
are:

~~~bash
task validate
task status
task flux:status
task minio:status
task oco-status
~~~

`task purge` is destructive and requires `HOST_RUNTIME_PURGE=YES`.

[Back to top](#navigation)

## 7. Closing Statement

Host Runtime is the host/platform runtime boundary for telemetry collection,
shared object storage, and the Minikube Flux root. Application behavior and
central observability storage remain outside this repository.

[Back to top](#navigation)

---

**END OF DOCUMENT 01**
