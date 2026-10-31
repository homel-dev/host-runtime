# MinIO offsite backup — Argo CronWorkflow

**Status:** PARTIAL. The CronWorkflow copies the current contents of shared MinIO to an existing external S3 bucket. It does not provision AWS resources, export Memory Steward PVC artifacts, or implement disaster recovery.

The `minio-offsite-backup` CronWorkflow runs at 03:15 UTC in `host-runtime` using the `minio-offsite-backup` ServiceAccount. The shared Argo controller must watch `host-runtime` as well as `ms`.

Create the `minio-offsite-backup` Secret from the keys documented in `backup-secret.example.yml`. Never apply the placeholder values. The source identity requires list/read access to MinIO; the destination identity requires write access to the external S3 bucket. The bucket and its lifecycle must be provisioned separately.

Each execution copies all visible MinIO objects to `s3://<backup-bucket>/minio/<UTC-timestamp>/<source-bucket>/<key>`, verifies object sizes, and writes `_BACKUP_COMPLETE` last. This is a live object copy, **not** an atomic MinIO snapshot. It does not preserve MinIO bucket configuration, IAM, policies, or object version history. Do not treat the completion marker as proof of application-consistent database recovery.

Inspect executions using `kubectl -n host-runtime get cronworkflows.argoproj.io minio-offsite-backup` and `kubectl -n host-runtime get workflows.argoproj.io`. No restore automation is included in this change.
