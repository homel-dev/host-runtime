# Kubernetes execution toolbox

## Purpose

The Kubernetes execution toolbox is the operator container for cluster-facing
CLI and diagnostic work. It is owned by `host-runtime`; RR agent/runtime images
do not carry Flux for host-cluster administration.

CI builds and publishes:

`ghcr.io/homel-dev/host-runtime-kex-toolbox`

The image contains pinned control-plane tools:

- `kubectl` v1.31.4;
- Helm v3.18.4;
- Flux CLI v2.9.5;
- `yq` v4.54.1.

It also contains Git/SSH, GitHub CLI, curl/wget, DNS tools, iproute2, ping,
traceroute, mtr, netcat, socat, nmap, tcpdump, iperf3, ethtool, conntrack,
iptables/nftables, OpenSSL, jq, rsync, strace, Python 3, PostgreSQL/Redis/SQLite
clients, editors, and standard Unix diagnostics.

## Persistent interactive toolbox

The existing shell `kex` helper uses namespace `kex`, deployment `kex-toolbox`,
and container `toolbox`. Reconcile that deployment to this image with:

`task kex:deploy`

For the shell helper itself, set:

`export KEX_IMAGE=ghcr.io/homel-dev/host-runtime-kex-toolbox:main`

The persistent toolbox intentionally has `automountServiceAccountToken: false`.
It is suitable for HTTP, DNS, Git, network, and other diagnostics but does not
carry standing cluster-admin credentials.

## Ephemeral administrative execution

`scripts/kex-run.sh` is for commands that must mutate the cluster. It creates a
short-lived ServiceAccount and ClusterRoleBinding, a one-shot toolbox Pod, and a
temporary environment Secret. The execution pod receives an in-cluster
kubeconfig backed by its projected ServiceAccount token. All temporary resources
are deleted on exit.

Examples:

```text
./scripts/kex-run.sh kubectl get nodes -o wide
./scripts/kex-run.sh helm version
./scripts/kex-run.sh flux check --pre
```

An interactive administrative shell is available with:

`./scripts/kex-run.sh`

If `GITHUB_TOKEN` is set, the runner exposes it only through the temporary
Secret, which is removed with the execution pod.

## Image pull authentication

The bootstrap toolbox image should be public because it is itself a bootstrap
dependency. If the registry package is private, create an image pull Secret in
the `kex` namespace and set:

`KEX_IMAGE_PULL_SECRET=<secret-name>`

Both the persistent deployment and ephemeral runner honor that setting.
