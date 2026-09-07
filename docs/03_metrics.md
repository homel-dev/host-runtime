# Metrics

## Node Exporter

Primary dashboards use:

- `node_cpu_seconds_total`
- `node_memory_MemAvailable_bytes`
- `node_memory_MemTotal_bytes`
- `node_filesystem_size_bytes`
- `node_filesystem_avail_bytes`
- `node_disk_read_bytes_total`
- `node_disk_written_bytes_total`
- `node_disk_reads_completed_total`
- `node_disk_writes_completed_total`
- `node_network_receive_bytes_total`
- `node_network_transmit_bytes_total`
- `node_network_receive_errs_total`
- `node_network_transmit_errs_total`
- `node_load1`, `node_load5`, `node_load15`
- `node_time_seconds`
- `node_boot_time_seconds`

## Process Exporter

Primary dashboards use:

- `namedprocess_namegroup_num_procs`
- `namedprocess_namegroup_cpu_seconds_total`
- `namedprocess_namegroup_memory_bytes`
- `namedprocess_namegroup_thread_count`
- `namedprocess_namegroup_open_filedesc`

Configured process-group matchers are telemetry categories only. They do not imply that Host Runtime deploys the matched applications.

No swap panels are included.

## MinIO

Host Runtime Prometheus scrapes MinIO metrics v3 at:

```text
http://minio.host-runtime.svc.cluster.local:9000/minio/metrics/v3
```

The MinIO service is ClusterIP-only. Metrics authentication is configured as `public` for this internal service so Prometheus does not require root credentials or an administrative bearer token.

If the S3 endpoint is exposed outside the cluster or stricter network isolation is introduced, switch metrics scraping to a dedicated least-privilege MinIO Prometheus credential/token.
