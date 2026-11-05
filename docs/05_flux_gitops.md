# FLUX GITOPS
## Minikube Cluster Reconciliation and Bootstrap Contract
### Foundational Engineering Specification (Document 05 of 06)
*Namespace: host-runtime • Owner: architecture-team*

---

## Navigation

**[04_object_storage.md](04_object_storage.md) ← → [06_kex_toolbox.md](06_kex_toolbox.md)**

- [0. Status, Scope, and Authority](#0-status-scope-and-authority)
- [1. Scope and Cluster Root](#1-scope-and-cluster-root)
- [2. Execution Environment](#2-execution-environment)
- [3. GitHub Identity and Authentication](#3-github-identity-and-authentication)
- [4. Bootstrap](#4-bootstrap)
- [5. Current Reconciliation Graph](#5-current-reconciliation-graph)
- [6. Secrets](#6-secrets)
- [7. Operations and Recovery](#7-operations-and-recovery)
- [8. Closing Statement](#8-closing-statement)

---

## 0. Status, Scope, and Authority

**Status:** IMPLEMENTED
**Audience:** Cluster operators and repository maintainers
**Change policy:** Current-state contract. Repository/source mappings,
authentication mode, paths, `prune`, `wait`, and `dependsOn` claims MUST match
`scripts/flux-bootstrap.sh` and `clusters/minikube/`.

[Back to top](#navigation)

## 1. Scope and Cluster Root

`host-runtime` is the Flux bootstrap/control repository for the Minikube
cluster. The reconciliation root is:

~~~text
clusters/minikube/
~~~

Project Kubernetes resources remain in their owning repositories. Host Runtime
stores the Flux `GitRepository`, `Kustomization`, `HelmRepository`,
`HelmRelease`, and notification objects that connect those repositories to this
cluster.

The bootstrap-generated `GitRepository/flux-system` points to Host Runtime and
is the source for `Kustomization/host-runtime`.

[Back to top](#navigation)

## 2. Execution Environment

Flux is bootstrapped with Flux CLI `v2.9.5` through the shell-provided `kex`
helper. Host Runtime publishes the toolbox image but does not own the launcher
or its temporary Kubernetes RBAC lifecycle.

The toolbox contains pinned `kubectl`, Helm, Flux CLI, `yq`, and MinIO AIStor
Client versions. See [06_kex_toolbox.md](06_kex_toolbox.md).

[Back to top](#navigation)

## 3. GitHub Identity and Authentication

`scripts/flux-bootstrap.sh` uses the GitHub bootstrap command with
`--token-auth`. It does **not** use the SSH deploy-key bootstrap path.

For the existing organization-owned repository, use a dedicated GitHub user
with admin access to `homel-dev/host-runtime`. The current Flux GitHub bootstrap
documentation specifies these fine-grained PAT repository permissions for an
existing repository in token-auth mode:

- `Administration`: read-only;
- `Contents`: read/write;
- `Metadata`: read-only.

Export the PAT as `GITHUB_TOKEN`. `FLUX_GITHUB_TOKEN` is accepted by the wrapper
only as a compatibility alias when `GITHUB_TOKEN` is unset.

With `--token-auth`, the bootstrap PAT is used for Git over HTTPS and is stored
in the cluster as `Secret/flux-system` in namespace `flux-system`. This Secret
is also referenced by the authenticated secondary `GitRepository` objects for
`eco` and `relentless-rekrow`.

[Back to top](#navigation)

## 4. Bootstrap

Host Runtime MinIO bootstrap state remains external to Git. Materialize the
MinIO Secret, export the dedicated Flux user's PAT, then run:

~~~bash
task minio:bootstrap-secret
export GITHUB_TOKEN=...
task flux:bootstrap
~~~

The wrapper validates the active Kubernetes context before invoking:

~~~text
flux check --pre
flux bootstrap github \
  --owner=homel-dev \
  --repository=host-runtime \
  --branch=main \
  --path=clusters/minikube \
  --version=v2.9.5 \
  --personal=false \
  --token-auth \
  --reconcile
flux check
flux get all -A
~~~

`flux bootstrap github` owns the generated files under
`clusters/minikube/flux-system/`, including `gotk-components.yaml`,
`gotk-sync.yaml`, and `kustomization.yaml`.

[Back to top](#navigation)

## 5. Current Reconciliation Graph

The checked-in cluster root currently declares the following sources and
Kustomizations.

| Source | Kustomization(s) and path | Current reconciliation policy |
| --- | --- | --- |
| bootstrap `flux-system` (`host-runtime`) | `host-runtime` → `./k8s` | `prune: true`, `wait: true` |
| `eco` | `eco-rr-access` → `./k8s/rr-access`; `eco` → `./k8s` | access: `prune: true`; main: `prune: false`, depends on access |
| `llm-runtime` | `llm-runtime-namespace` → `./k8s/gitops/namespace`; `llm-runtime-observability` → `./k8s/observability`; `llm-runtime-omniroute` → `./k8s/gitops/omniroute`; `llm-runtime-mcp-controllers` → `./k8s/gitops/mcp-controllers`; `llm-runtime-mcp` → `./k8s/mcp` | mixed `prune`; all declare `wait: true`; dependencies are explicit in manifests |
| `memory-steward` | `memory-steward-infra` → `./k8s/infra`; `memory-steward-restore` → `./k8s/restore`; `memory-steward-migrate` → `./k8s/migrate`; `memory-steward` → `./k8s` | infra/main: `prune: false`; restore/migrate: `prune: true`; all `wait: true`; ordered by `dependsOn` |
| `oco` | `oco-backend` → `./k8s/backend`; `oco-console` → `./k8s` | both `prune: false`, `wait: true`; console depends on backend |
| `relentless-rekrow` | `relentless-rekrow` → `./rr-pi/k8s` | `prune: true`, `wait: true` |

`eco` and `relentless-rekrow` reference `Secret/flux-system` for Git
credentials. `llm-runtime`, `memory-steward`, and `oco` currently use HTTPS
GitHub sources without a `secretRef`.

The cluster root also installs Argo Workflows chart `2.0.12` into namespace
`argo`, with the controller configured to watch workflows in `ms` and
`host-runtime` and the Argo server disabled.

Notification objects forward selected Git source events for
`memory-steward`, `llm-runtime`, and `relentless-rekrow` to the Memory Steward
CodeGraph controller endpoint declared in the manifests.

[Back to top](#navigation)

## 6. Secrets

Current non-Git state includes:

- `host-runtime/minio-bootstrap`;
- `flux-system/flux-system`, containing the token-auth Git credential generated
  by Flux bootstrap;
- consumer credentials generated by Host Runtime MinIO provisioning;
- `host-runtime/minio-offsite-backup` when offsite object copy is enabled;
- provider credentials owned by other projects.

These values MUST NOT be committed as plaintext Kubernetes Secret manifests.
The committed `k8s/minio/backup-secret.example.yml` contains placeholders only
and exists solely to document the required keys.

[Back to top](#navigation)

## 7. Operations and Recovery

Use:

~~~text
task flux:preflight
task flux:status
task flux:reconcile
task flux:reconcile-host-runtime
~~~

The Flux CLI runs inside the Kubernetes execution toolbox. The shell Git plugin
owns creation and cleanup of the short-lived administrative execution Pod and
RBAC.

If Flux controllers or the bootstrap Git credential are lost, export a valid
`GITHUB_TOKEN` for the dedicated Flux organization user and rerun:

~~~bash
task flux:bootstrap
~~~

The wrapper reruns the official idempotent bootstrap flow and reconnects the
cluster using the repository's current token-auth configuration.

[Back to top](#navigation)

## 8. Closing Statement

Host Runtime owns the Minikube Flux control root and bootstrap wrapper. Each
application repository remains authoritative for its own manifests; this
repository only declares how those sources are reconciled into the cluster.

[Back to top](#navigation)

---

**END OF DOCUMENT 05**
