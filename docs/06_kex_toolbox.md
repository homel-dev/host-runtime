# Kubernetes execution toolbox image

## Purpose

`host-runtime` publishes the generic Kubernetes execution toolbox image used by
operator shell tooling. It does not own the `kex` launcher, its RBAC lifecycle,
or any persistent `kex` Deployment.

CI builds and publishes:

`ghcr.io/homel-dev/host-runtime-kex-toolbox`

The shell `kex` helper is owned by the Oh My Bash Git plugin. Each invocation
creates its own short-lived ServiceAccount, `cluster-admin` ClusterRoleBinding,
and execution Pod, then removes them on exit.

## Image contents

The image contains pinned control-plane and object-storage tools:

- `kubectl` v1.31.4;
- Helm v3.18.4;
- Flux CLI v2.9.5;
- `yq` v4.54.1;
- MinIO AIStor Client (`mc`) `RELEASE.2026-09-06T02-44-40Z`.

The `mc` binary is downloaded from the official AIStor client release archive
and verified with architecture-specific SHA-256 values during the image build.

The image also contains Git/SSH, GitHub CLI, curl/wget, DNS tools, iproute2,
ping, traceroute, mtr, netcat, socat, nmap, tcpdump, iperf3, ethtool, conntrack,
iptables/nftables, OpenSSL, jq, rsync, strace, Python 3, PostgreSQL/Redis/SQLite
clients, editors, and standard Unix diagnostics.

## Launcher ownership

`host-runtime` intentionally contains no `kex-run.sh`, `kex-deploy.sh`, persistent
`kex` Deployment, or `kex:*` Task targets. The shell plugin supplies execution
semantics and Kubernetes RBAC.

The image is expected to run as UID/GID 1000 with Linux privilege escalation
disabled. Kubernetes administrative authority comes only from the temporary
ServiceAccount created by the shell launcher.

If the GHCR package is private, the shell launcher can be pointed at an
appropriate image pull Secret through its own configuration.
