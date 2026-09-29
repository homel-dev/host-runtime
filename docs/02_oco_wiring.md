# OCO Wiring

## Telemetry path

`host-runtime` runs namespace-local Grafana Alloy because it performs useful local work: exporter scraping, pod-log collection, OTLP reception, enrichment, and forwarding.

The namespace is labeled:

```text
observability.homel.dev/telemetry-consumer=true
observability.homel.dev/project=host-runtime
observability.homel.dev/local-alloy=true
```

Central OCO ingress endpoints are:

```text
metrics remote write: http://alloy.observability-backend.svc.cluster.local:12347/api/v1/metrics/write
logs Loki push:       http://alloy.observability-backend.svc.cluster.local:12348/loki/api/v1/push
OTLP gRPC:            alloy.observability-backend.svc.cluster.local:4317
```

Central Alloy then routes telemetry to VictoriaMetrics, VictoriaLogs, and Tempo in `observability-backend`.

## Dashboard contract

`host-runtime` publishes one labeled ConfigMap:

```text
grafana_dashboard=1
```

and grants the OCO ServiceAccount namespaced read access through:

```text
Role/observability-console-reader
RoleBinding/observability-console-reader
```

The dashboard references the shared datasource UID:

```text
victoriametrics
```

Host Runtime does not publish a datasource and Grafana must not query a Host Runtime Prometheus endpoint.

## Central log de-duplication

Once Host Runtime uses local Alloy for pod logs, central OCO Alloy must exclude namespace `host-runtime` from its own Kubernetes pod-log tailing. Otherwise the same pod logs are shipped twice.
