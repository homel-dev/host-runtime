# SHARED OBJECT STORAGE
## MinIO Runtime, Consumer Isolation, and Offsite Copy Contract
### Foundational Engineering Specification (Document 04 of 06)
*Namespace: host-runtime • Owner: architecture-team*

---

## Navigation

**Previous:** [03_metrics.md](03_metrics.md) | **Next:** [05_flux_gitops.md](05_flux_gitops.md)

- [0. Status, Scope, and Authority](#0-status-scope-and-authority)
- [1. Purpose and Placement](#1-purpose-and-placement)
- [2. Distribution and License](#2-distribution-and-license)
- [3. Local Configuration and Bootstrap Secret](#3-local-configuration-and-bootstrap-secret)
- [4. Storage and Lifecycle](#4-storage-and-lifecycle)
- [5. Consumer Isolation](#5-consumer-isolation)
- [6. RR Run-Artifact Integration](#6-rr-run-artifact-integration)
- [7. Offsite Object Copy](#7-offsite-object-copy)
- [8. Observability](#8-observability)
- [9. Operations](#9-operations)
- [10. Closing Statement](#10-closing-statement)

---

## 0. Status, Scope, and Authority

**Status:** IMPLEMENTED
**Audience:** Platform operators and storage consumers
**Change policy:** Keep service endpoints, persistence, consumer network access,
provisioning tasks, and backup behavior synchronized with `k8s/minio/`,
`k8s/minio-consumers/`, `Taskfile.yml`, and `k8s/minio/BACKUP.md`.

[Back to top](#navigation)

---

## 1. Purpose and Placement

`host-runtime` owns a single-node MinIO AIStor object store as a shared platform
storage primitive. It is consumer-neutral: application projects own object
meaning and scoped credentials rather than deploying separate object stores.

The S3 and Console services are cluster-local:

~~~text
S3:      minio.host-runtime.svc.cluster.local:9000
Console: minio-console.host-runtime.svc.cluster.local:9001
~~~

Use `task minio:console` for local administrative UI access instead of exposing
the Console with a NodePort or LoadBalancer.

[Back to top](#navigation)

---

## 2. Distribution and License

The StatefulSet uses MinIO AIStor in a single-node topology and mounts a license
from the external `minio-bootstrap` Secret. The repository intentionally uses a
direct StatefulSet rather than the AIStor Kubernetes Operator.

The license file and root credentials MUST remain outside Git.

Official MinIO documentation:

- https://docs.min.io/aistor/operations/licenses/
- https://docs.min.io/aistor/installation/kubernetes/install/deploy-aistor-on-kubernetes/

[Back to top](#navigation)

---

## 3. Local Configuration and Bootstrap Secret

Operator-facing configuration lives in local `minio.env`, which is ignored by
Git. The committed `minio.env.example` contains lab placeholders:

~~~text
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=minioadmin-change-me
MINIO_LICENSE_FILE=./minio.license
~~~

The normal local first-run path is:

~~~bash
task minio:start
~~~

If `minio.env` does not exist, `task minio:init` materializes it from the
example. `task minio:bootstrap-secret` creates or updates
`host-runtime/minio-bootstrap` with:

~~~text
root-user
root-password
minio.license
~~~

Applications MUST NOT use these root credentials.

[Back to top](#navigation)

---

## 4. Storage and Lifecycle

The MinIO StatefulSet requests one `ReadWriteOnce` PVC of `50Gi` from the
cluster default StorageClass.

`task delete` deletes labeled Deployments, DaemonSets, StatefulSets, Services,
ConfigMaps, Roles, and RoleBindings. It does not delete the namespace,
StatefulSet-generated PVC, `minio-bootstrap` Secret, CronWorkflow,
ServiceAccounts, or NetworkPolicies. `task minio:stop` deletes only the MinIO
sub-Kustomization and also preserves its PVC and bootstrap Secret.

`task purge` is destructive. It requires `HOST_RUNTIME_PURGE=YES` and deletes
the entire `host-runtime` namespace, including MinIO object data and bootstrap
credentials.

This is a single-node lab/platform topology, not an HA storage design.

[Back to top](#navigation)

---

## 5. Consumer Isolation

Applications MUST use dedicated scoped identities rather than MinIO root
credentials.

`k8s/minio-consumers/networkpolicy.yml` currently permits:

| Source | Pod scope | Ports |
| --- | --- | --- |
| `host-runtime` | any pod | `9000`, `9001` |
| `rr` | `app.kubernetes.io/name=rr-pi-runner` | `9000` |
| `observability-console` | `app.kubernetes.io/name=grafana` | `9000` |
| `ms` | any pod | `9000` |
| `eco` | any pod | `9000` |

~~~mermaid
flowchart TB
    subgraph C["Allowed MinIO consumers"]
        direction TB
        HR["host-runtime pods"]
        RR["rr / rr-pi-runner"]
        G["observability-console / Grafana"]
        MS["ms namespace"]
        ECO["eco namespace"]
    end

    HR -->|9000 / 9001| M["MinIO AIStor"]
    RR -->|9000<br/>rr-artifacts writer| M
    G -->|9000<br/>rr-artifacts read-only| M
    MS -->|9000<br/>network allowed| M
    ECO -->|9000<br/>network allowed| M
    M --> B["Argo minio-offsite-backup"]
    B -->|rclone copy + check| S3["External S3 bucket"]
~~~

No Flux `source-controller` ingress rule exists. Host Runtime defines no MinIO
bucket, mirror, or consumer rule for Flux source artifacts.

Bucket names, IAM policies, and credentials remain consumer contracts unless a
specific provisioning workflow is implemented in this repository.

[Back to top](#navigation)

---

## 6. RR Run-Artifact Integration

`task minio:rr-artifacts` is the implemented consumer-specific provisioning
workflow. It:

1. creates or reuses scoped RR writer and OCO reader credentials;
2. creates the `rr-artifacts` bucket;
3. applies bucket-scoped MinIO policies;
4. disables anonymous bucket access;
5. writes the RR writer configuration to `rr/rr-artifact-store`;
6. writes the OCO read-only configuration to
   `observability-console/oco-artifact-store`;
7. deletes the temporary provisioning Secret and Job when complete.

RR owns artifact semantics and publication. OCO owns presentation. Host Runtime
owns only the storage/provisioning boundary.

[Back to top](#navigation)

---

## 7. Offsite Object Copy

The root `k8s/kustomization.yml` includes
`k8s/minio/backup-cronworkflow.yml`. The CronWorkflow runs at `03:15 UTC` and
copies all objects visible to its source identity into an existing external S3
bucket under:

~~~text
s3://<backup-bucket>/minio/<UTC-timestamp>/...
~~~

It then runs `rclone check --one-way --size-only` and writes
`_BACKUP_COMPLETE` last.

The workflow requires the external `host-runtime/minio-offsite-backup` Secret.
The committed `k8s/minio/backup-secret.example.yml` is an example only and MUST
NOT be applied with placeholder values.

The Minikube Flux root installs Argo Workflows and configures its controller to
watch `host-runtime`. The local `k8s/minio` sub-Kustomization intentionally does
not include the backup CronWorkflow; `task minio:start` therefore starts MinIO
without installing the offsite backup object.

This copy is not an atomic MinIO snapshot and does not preserve MinIO IAM,
bucket configuration, or version history. See
[../k8s/minio/BACKUP.md](../k8s/minio/BACKUP.md) for the operator contract.

[Back to top](#navigation)

---

## 8. Observability

The StatefulSet configures `MINIO_PROMETHEUS_AUTH_TYPE=public`, but the current
Host Runtime Alloy configuration does not scrape MinIO. No Host Runtime
dashboard query currently consumes MinIO metrics.

The S3 and Console Services remain ClusterIP-only. Any future MinIO scrape MUST
be added explicitly to `k8s/observability/alloy/alloy.yml` and documented in
`03_metrics.md`.

[Back to top](#navigation)

---

## 9. Operations

Available MinIO tasks are:

~~~bash
task minio:init
task minio:start
task minio:stop
task minio:restart
task minio:status
task minio:logs
task minio:console
task minio:api
task minio:rr-artifacts
task minio:rr-artifacts-status
~~~

`minio:console` and `minio:api` use `kubectl port-forward`; they do not create
persistent host-facing services.

[Back to top](#navigation)

---

## 10. Closing Statement

Host Runtime owns a persistent shared S3 service and narrowly defined platform
operations around it. Consumer semantics, external S3 provisioning, and full
disaster recovery remain outside this repository.

[Back to top](#navigation)

---

**END OF DOCUMENT 04**
