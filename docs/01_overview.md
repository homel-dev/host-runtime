# Host Runtime Observability Overview

## Purpose

`host-runtime` is a standalone observability producer for host-level vitals. It is intentionally separate from `llm-runtime`, Memory Steward, RR, and OCO.

The project owns:

- node-level collectors
- process/application collectors
- local Prometheus storage
- Grafana datasource/dashboard definitions consumed by OCO
- namespace-local RBAC granting OCO read access to those definitions

OCO owns only presentation. Removing OCO removes the shared viewer, not the collected host telemetry.

## Namespace

```text
host-runtime
```

## Components

```text
host-runtime
  prometheus
  node-exporter
  process-exporter
  oco-consumer configmaps/rbac
```

## No swap

Swap metrics are deliberately not included in the dashboard or Prometheus intent. The target host profile is expected to be judged by CPU, RAM, disk, network, and process/app pressure.

## Process/application visibility

`process-exporter` groups host processes by known app families first, then falls back to executable/command grouping. This gives visibility into vLLM, Kubernetes components, container runtime, shells, SSH, Python, and other process groups without needing application instrumentation.
