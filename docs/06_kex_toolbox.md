# KUBERNETES EXECUTION TOOLBOX IMAGE
## Image Contents, Publication, and Ownership Boundary
### Foundational Engineering Specification (Document 06 of 06)
*Namespace: host-runtime • Owner: architecture-team*

---

## Navigation

**Previous:** [05_flux_gitops.md](05_flux_gitops.md) | **Next:** [README.md](../README.md)

- [0. Status, Scope, and Authority](#0-status-scope-and-authority)
- [1. Purpose](#1-purpose)
- [2. Image Publication](#2-image-publication)
- [3. Pinned Toolchain](#3-pinned-toolchain)
- [4. Launcher Ownership](#4-launcher-ownership)
- [5. Security Boundary](#5-security-boundary)
- [6. Closing Statement](#6-closing-statement)

---

## 0. Status, Scope, and Authority

**Status:** IMPLEMENTED
**Audience:** Operators and toolbox-image maintainers
**Change policy:** Tool versions MUST match `toolbox/Dockerfile`; publication
claims MUST match `.github/workflows/validate.yml`. Launcher behavior outside
this repository MUST NOT be described as a Host Runtime guarantee.

[Back to top](#navigation)

---

## 1. Purpose

`host-runtime` publishes the generic Kubernetes execution toolbox image used by
external operator shell tooling. It does not own the `kex` launcher, its RBAC
lifecycle, or a persistent `kex` Deployment.

The Dockerfile runs the image as UID/GID `1000:1000` with working directory
`/work`.

[Back to top](#navigation)

---

## 2. Image Publication

GitHub Actions builds and smoke-tests the toolbox on every validation run. On a
push to `main`, the workflow publishes:

~~~text
ghcr.io/homel-dev/host-runtime-kex-toolbox:main
ghcr.io/homel-dev/host-runtime-kex-toolbox:sha-<git-sha>
~~~

The smoke test executes the installed CLI tools from the built image before the
publish step.

~~~mermaid
flowchart TB
    W["GitHub Actions<br/>validate.yml"] --> B["Build toolbox image"]
    B --> S["Smoke-test installed CLI tools"]
    S -->|push to main| P["Publish GHCR tags"]
    P --> G["ghcr.io/homel-dev/<br/>host-runtime-kex-toolbox"]
    G -->|pulled by| K["External operator shell<br/>kex helper"]
    K -->|creates / invokes| E["Launcher-owned execution environment"]
    E --> C["kubectl / helm / flux / yq / mc / diagnostics"]
~~~

[Back to top](#navigation)

---

## 3. Pinned Toolchain

`toolbox/Dockerfile` currently pins:

- `kubectl` `v1.31.4`;
- Helm `v3.18.4`;
- Flux CLI `v2.9.5`;
- `yq` `v4.54.1`;
- MinIO AIStor Client (`mc`) `RELEASE.2026-09-06T02-44-40Z`.

The build verifies downloaded `kubectl` and Helm artifacts against upstream
checksums and verifies Flux, `yq`, and `mc` with architecture-specific SHA-256
values encoded in the Dockerfile.

The image also contains Git/SSH, GitHub CLI, curl/wget, DNS tools, iproute2,
ping, traceroute, mtr, netcat, socat, nmap, tcpdump, iperf3, ethtool, conntrack,
iptables/nftables, OpenSSL, jq, rsync, strace, Python 3,
PostgreSQL/Redis/SQLite clients, editors, and standard Unix diagnostics.

[Back to top](#navigation)

---

## 4. Launcher Ownership

`host-runtime` intentionally contains no `kex-run.sh`, `kex-deploy.sh`,
persistent `kex` Deployment, or `kex:*` Task targets.

The shell-provided `kex` helper is an external dependency of the operator
workflow. `scripts/flux-bootstrap.sh` and `scripts/flux-status.sh` explicitly
fail when the Bash function is unavailable.

[Back to top](#navigation)

---

## 5. Security Boundary

The Docker image itself defines a non-root runtime user. Kubernetes
ServiceAccounts, ClusterRoleBindings, Pod security context, cleanup behavior,
and image-pull credentials are launcher-owned and are not defined by this
repository.

If the GHCR package is private, the launcher must provide suitable registry
credentials. Host Runtime does not commit those credentials.

[Back to top](#navigation)

---

## 6. Closing Statement

Host Runtime owns a reproducible operator-tool image. Invocation semantics and
cluster authorization remain outside this repository and must not be inferred
from the image alone.

[Back to top](#navigation)

---

**END OF DOCUMENT 06**
