# OCO WIRING
## Shared Observability Integration Contract
### Foundational Engineering Specification (Document 02 of 06)
*Namespace: host-runtime • Owner: architecture-team*

---

## Navigation

**[01_overview.md](01_overview.md) ← → [03_metrics.md](03_metrics.md)**

- [0. Status, Scope, and Authority](#0-status-scope-and-authority)
- [1. Telemetry Path](#1-telemetry-path)
- [2. Namespace Contract](#2-namespace-contract)
- [3. Dashboard Contract](#3-dashboard-contract)
- [4. Central Log De-duplication](#4-central-log-de-duplication)
- [5. Failure Boundary](#5-failure-boundary)
- [6. Closing Statement](#6-closing-statement)

---

## 0. Status, Scope, and Authority

**Status:** IMPLEMENTED
**Audience:** Operators and observability maintainers
**Change policy:** Keep endpoints, labels, RBAC names, and dashboard datasource
UID synchronized with Host Runtime manifests and the OCO backend contract.

`k8s/observability/alloy/alloy.yml`, `k8s/namespace.yml`, and
`k8s/oco-consumer/` are authoritative for the Host Runtime side of this
integration.

[Back to top](#navigation)

## 1. Telemetry Path

`host-runtime` runs namespace-local Grafana Alloy because it performs local
exporter scraping, pod-log collection, OTLP reception, enrichment, and
forwarding.

Central OCO ingress endpoints are:

~~~text
metrics remote write: http://alloy.observability-backend.svc.cluster.local:12347/api/v1/metrics/write
logs Loki push:       http://alloy.observability-backend.svc.cluster.local:12348/loki/api/v1/push
OTLP gRPC:            alloy.observability-backend.svc.cluster.local:4317
~~~

Central Alloy routes these signals to VictoriaMetrics, VictoriaLogs, and Tempo
in `observability-backend`.

[Back to top](#navigation)

## 2. Namespace Contract

`k8s/namespace.yml` applies the following labels:

~~~text
observability.homel.dev/telemetry-consumer=true
observability.homel.dev/project=host-runtime
observability.homel.dev/local-alloy=true
~~~

The labels identify Host Runtime as an OCO telemetry consumer and declare that
pod logs are collected by a namespace-local Alloy instance.

The local Alloy OTLP Service accepts namespace-local traffic on ports `4317`
and `4318`. Its NetworkPolicy permits ingress from pods in `host-runtime` only.

[Back to top](#navigation)

## 3. Dashboard Contract

`host-runtime` publishes one dashboard ConfigMap labeled:

~~~text
grafana_dashboard=1
~~~

The namespace grants the
`observability-console/observability-console` ServiceAccount `get`, `list`, and
`watch` access to ConfigMaps through:

~~~text
Role/observability-console-reader
RoleBinding/observability-console-reader
~~~

The dashboard references the shared datasource UID:

~~~text
victoriametrics
~~~

Host Runtime does not publish a Grafana datasource and Grafana must not depend
on a Host Runtime Prometheus service.

[Back to top](#navigation)

## 4. Central Log De-duplication

Because Host Runtime tails its own pod logs, central OCO Alloy must not tail the
same namespace. The current OCO backend configuration excludes `host-runtime`
from central Kubernetes pod-log discovery.

This is a cross-repository invariant: Host Runtime declares
`observability.homel.dev/local-alloy=true`, while OCO owns the actual central
collector exclusion.

[Back to top](#navigation)

## 5. Failure Boundary

If central OCO ingress is unavailable, Host Runtime does not fall back to a
namespace-local metrics, logs, or traces backend. The local Alloy configuration
continues to target the OCO endpoints and reports forwarding failures in Alloy
logs.

Use:

~~~bash
task logs-alloy
task oco-status
~~~

for Host Runtime-side inspection. Backend health remains an OCO operational
responsibility.

[Back to top](#navigation)

## 6. Closing Statement

Host Runtime owns collection and forwarding; OCO owns telemetry persistence and
presentation. The dashboard/RBAC contract is the only Grafana-facing resource
owned here.

[Back to top](#navigation)

---

**END OF DOCUMENT 02**
