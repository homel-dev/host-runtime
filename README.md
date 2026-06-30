# host-runtime

Host Runtime provides project-owned host vitals telemetry for the Homel lab host / Minikube node.

It owns collection and storage for host-level metrics. The shared OCO repository owns presentation only.

## Scope

Included:

- Prometheus in namespace `host-runtime`
- Node Exporter for host CPU, memory, filesystem, disk, network, load, uptime
- Process Exporter for process/application group visibility
- OCO datasource ConfigMap
- OCO dashboard ConfigMap
- OCO read RBAC contract

Excluded:

- swap dashboards/alerts
- GPU/DCGM metrics; those remain owned by `llm-runtime` observability
- hidden local tunnel/proxy helpers
- host-published service exposure

## Deploy

```bash
task host-runtime:deploy
```

## Status

```bash
task host-runtime:status
task host-runtime:targets
task host-runtime:up
```

## OCO wiring

The project publishes the OCO consumer contract in its own namespace:

```bash
kubectl apply -k k8s/oco-consumer
```

OCO must also watch the `host-runtime` namespace. Apply the patch in `oco-patches/observability-console-watch-host-runtime.patch` to the OCO repository, then redeploy/restart OCO.

## Datasource

Grafana datasource UID:

```text
host-runtime-prometheus
```

Dashboard UID:

```text
host-runtime-main-vitals
```
