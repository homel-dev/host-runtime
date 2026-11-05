# METRICS
## Host and Process Metric Collection Contract
### Foundational Engineering Specification (Document 03 of 06)
*Namespace: host-runtime • Owner: architecture-team*

---

## Navigation

**[02_oco_wiring.md](02_oco_wiring.md) ← → [04_object_storage.md](04_object_storage.md)**

- [0. Status, Scope, and Authority](#0-status-scope-and-authority)
- [1. Collection and Storage](#1-collection-and-storage)
- [2. Node Exporter](#2-node-exporter)
- [3. Process Exporter](#3-process-exporter)
- [4. MinIO Metrics State](#4-minio-metrics-state)
- [5. Verification](#5-verification)
- [6. Closing Statement](#6-closing-statement)

---

## 0. Status, Scope, and Authority

**Status:** IMPLEMENTED
**Audience:** Operators, observability maintainers, and dashboard contributors
**Change policy:** Dashboard metric inventory MUST match the PromQL expressions
in `k8s/oco-consumer/configmap-dashboard.yml`; scrape targets MUST match
`k8s/observability/alloy/alloy.yml`.

[Back to top](#navigation)

## 1. Collection and Storage

Namespace-local Alloy scrapes Node Exporter, Process Exporter, and Alloy itself,
then remote-writes metrics to:

~~~text
http://alloy.observability-backend.svc.cluster.local:12347/api/v1/metrics/write
~~~

VictoriaMetrics in `observability-backend` is the standard metrics backend.
Host Runtime has no local Prometheus and no metrics PVC.

~~~mermaid
flowchart LR
    NE["Node Exporter<br/>:9100"] -->|15 s scrape| A["Host Runtime Alloy"]
    PE["Process Exporter<br/>:9256"] -->|15 s scrape| A
    AS["Alloy self metrics<br/>:12345"] -->|15 s scrape| A
    A -->|Prometheus remote write<br/>:12347| OA["OCO Alloy"]
    OA --> VM["VictoriaMetrics"]
    G["OCO Grafana<br/>Host Runtime dashboard"] -->|queries| VM
~~~

The Node Exporter and Process Exporter scrape targets carry:

~~~text
project="host-runtime"
namespace="host-runtime"
service="..."
subsystem="host-runtime"
job="..."
~~~

[Back to top](#navigation)

## 2. Node Exporter

The current dashboard references these Node Exporter series:

- `node_cpu_seconds_total`;
- `node_memory_MemAvailable_bytes`;
- `node_memory_MemTotal_bytes`;
- `node_memory_Buffers_bytes`;
- `node_memory_Cached_bytes`;
- `node_memory_Slab_bytes`;
- `node_filesystem_size_bytes`;
- `node_filesystem_avail_bytes`;
- `node_disk_read_bytes_total`;
- `node_disk_written_bytes_total`;
- `node_disk_reads_completed_total`;
- `node_disk_writes_completed_total`;
- `node_network_receive_bytes_total`;
- `node_network_transmit_bytes_total`;
- `node_network_receive_errs_total`;
- `node_network_transmit_errs_total`;
- `node_network_receive_drop_total`;
- `node_network_transmit_drop_total`;
- `node_load1`, `node_load5`, and `node_load15`.

The dashboard does not currently use `node_time_seconds` or
`node_boot_time_seconds`.

[Back to top](#navigation)

## 3. Process Exporter

The current dashboard references:

- `namedprocess_namegroup_num_procs`;
- `namedprocess_namegroup_cpu_seconds_total`;
- `namedprocess_namegroup_memory_bytes`;
- `namedprocess_namegroup_thread_count`;
- `namedprocess_namegroup_open_filedesc`.

Configured process-group matchers are telemetry categories only. They do not
imply that Host Runtime deploys the matched applications.

No swap panels are included in the current dashboard.

[Back to top](#navigation)

## 4. MinIO Metrics State

The MinIO StatefulSet sets:

~~~text
MINIO_PROMETHEUS_AUTH_TYPE=public
~~~

but the current Host Runtime Alloy configuration contains no MinIO scrape
target. The Host Runtime dashboard also contains no MinIO metric queries.
Therefore MinIO metrics are **not currently collected by Host Runtime**.

The internal MinIO service remains ClusterIP-only. Enabling MinIO metric
collection later would require an explicit Alloy scrape configuration and a
corresponding documentation/dashboard update.

[Back to top](#navigation)

## 5. Verification

The repository provides direct metric inspection through temporary curl pods:

~~~bash
task node-metrics
task process-metrics
~~~

Use `task logs-alloy` to inspect scrape/remote-write failures from the local
collector.

[Back to top](#navigation)

## 6. Closing Statement

The metric contract is intentionally small: Host Runtime collects host/process
metrics and forwards them to OCO. The checked-in dashboard is the authority for
which exported series are part of the current user-facing view.

[Back to top](#navigation)

---

**END OF DOCUMENT 03**
