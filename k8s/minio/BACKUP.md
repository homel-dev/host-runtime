# MinIO Offsite Backup — Argo CronWorkflow

## Status and authority

**Status:** PARTIAL

`k8s/minio/backup-cronworkflow.yml` is authoritative for the implemented
schedule, image, credentials, copy path, and verification behavior.

The CronWorkflow copies the current contents visible to its MinIO source
identity to an existing external S3 bucket. It does not provision AWS
resources, export application database/PVC state, preserve MinIO IAM or bucket
configuration, or implement restore automation.

## Runtime contract

`CronWorkflow/minio-offsite-backup` runs at `03:15 UTC` in namespace
`host-runtime` with `concurrencyPolicy: Forbid`. The Minikube Flux root installs
the shared Argo Workflows controller and configures it to watch
`host-runtime` and `ms`.

The workflow uses `rclone/rclone:1.71.2` and copies source objects under:

~~~text
s3://<backup-bucket>/minio/<UTC-timestamp>/...
~~~

After copying, it runs a one-way size check and writes `_BACKUP_COMPLETE` last.
The completion marker means the configured object-copy/check sequence
completed; it is not proof of application-consistent recovery.

## Credentials

Create `Secret/minio-offsite-backup` in `host-runtime` using the key names from
`backup-secret.example.yml`:

~~~text
source-access-key
source-secret-key
aws-region
aws-access-key
aws-secret-key
backup-bucket
~~~

The committed Secret file is an example only. Never apply its placeholder
values.

The source identity requires sufficient list/read access to every MinIO object
that must be copied. The destination identity requires write access to the
selected external S3 bucket. The bucket, lifecycle, retention, and AWS identity
must be provisioned separately.

## Consistency and restore limits

This is a live object copy, not an atomic MinIO snapshot. It does not preserve:

- MinIO users or policies;
- bucket configuration;
- object version history not visible through the configured source view;
- external application state such as PostgreSQL volumes;
- a tested automated restore procedure.

A complete disaster-recovery design must validate application-specific restore
requirements separately.

## Operations

Inspect the schedule and executions with:

~~~bash
kubectl -n host-runtime get cronworkflows.argoproj.io minio-offsite-backup
kubectl -n host-runtime get workflows.argoproj.io
~~~

Restore automation is not implemented in this repository.
