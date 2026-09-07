# Host Runtime Overview

## Purpose

`host-runtime` provides host-level telemetry and shared platform storage for a single-host Kubernetes/lab environment.

It is intentionally separate from application runtimes such as `llm-runtime`, Memory Steward, RR, and from OCO/Grafana presentation.

The project owns:

- node-level collectors;
- process/application collectors;
- persistent Prometheus storage;
- shared MinIO object storage;
- Grafana datasource/dashboard definitions consumed by OCO;
- namespace-local RBAC granting OCO read access to those definitions.

OCO owns presentation only. Removing OCO removes the shared viewer, not Host Runtime metrics or object storage.

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
  minio
  oco-consumer configmaps/rbac
```

MinIO is a platform storage primitive, not an observability backend. Application projects own their bucket layout and credentials while sharing the same S3 service.

## Host metrics

Swap metrics are deliberately not included in the dashboard or Prometheus intent. The target host profile is judged by CPU, RAM, disk, network, and process/application pressure.

## Process/application visibility

`process-exporter` groups host processes by known app families first, then falls back to executable/command grouping. This gives visibility into vLLM, Kubernetes components, container runtime, shells, SSH, Python, databases, MinIO, and other process groups without requiring application instrumentation.

Process-exporter group names are observation rules only. A matcher for a process such as `postgres`, `redis-server`, or `minio` does not mean Host Runtime deploys that service unless a corresponding Kubernetes workload exists in this repository.

## Shared storage

The MinIO deployment is single-node and persistent. It is intended for shared artifacts/resources in this lab/runtime environment, not as a highly available object-storage cluster.

See [04_object_storage.md](04_object_storage.md).
