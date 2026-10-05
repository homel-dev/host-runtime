# syntax=docker/dockerfile:1.7
FROM debian:bookworm-slim

ARG TARGETARCH
ARG KUBECTL_VERSION=v1.31.4
ARG HELM_VERSION=v3.18.4
ARG FLUX_VERSION=v2.9.5
ARG YQ_VERSION=v4.54.1
ARG MC_VERSION=RELEASE.2026-09-06T02-44-40Z

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      bash \
      bash-completion \
      bzip2 \
      ca-certificates \
      conntrack \
      coreutils \
      curl \
      diffutils \
      dnsutils \
      ethtool \
      file \
      findutils \
      gawk \
      gh \
      git \
      grep \
      gzip \
      iperf3 \
      iproute2 \
      iptables \
      iputils-ping \
      jq \
      less \
      lsof \
      make \
      mtr-tiny \
      nano \
      net-tools \
      netcat-openbsd \
      nftables \
      nmap \
      openssh-client \
      openssl \
      patch \
      postgresql-client \
      procps \
      psmisc \
      python3 \
      python3-venv \
      redis-tools \
      rsync \
      sed \
      socat \
      sqlite3 \
      strace \
      tar \
      tcpdump \
      tmux \
      traceroute \
      tree \
      unzip \
      util-linux \
      vim-tiny \
      wget \
      whois \
      xz-utils \
      zip \
 && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    case "${TARGETARCH:-amd64}" in \
      amd64) \
        arch=amd64; \
        flux_sha256=b853df82adfd7736f580692f9f734473d571606307139f8fd20c2a80dd1ff473; \
        yq_sha256=8e34fc298390875de416e6a4afcb8cabeceb25d9aa8506c1a2f9353cf702ea5f; \
        mc_sha256=5a07c01f2e90ea3f2995d69bd69ea1a77af1d431a376e509eaa800074f789a37 \
        ;; \
      arm64) \
        arch=arm64; \
        flux_sha256=f3e159af616ec0b9bd0a405c2185cf09d06b74652c1de3c7f377e8166826651a; \
        yq_sha256=189088da0c6429ec5178dfaab1a114805f6cab0b61b165ab236efedf1d57a71b; \
        mc_sha256=3283b779571988a31f747f3c4f8414fa1fa20eff263ec12fd5d47278ad5e5d7b \
        ;; \
      *) \
        echo "unsupported TARGETARCH=${TARGETARCH}" >&2; \
        exit 1 \
        ;; \
    esac; \
    curl -fsSLo /tmp/kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${arch}/kubectl"; \
    curl -fsSLo /tmp/kubectl.sha256 "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${arch}/kubectl.sha256"; \
    echo "$(cat /tmp/kubectl.sha256)  /tmp/kubectl" | sha256sum -c -; \
    install -m 0755 /tmp/kubectl /usr/local/bin/kubectl; \
    curl -fsSLo /tmp/helm.tgz "https://get.helm.sh/helm-${HELM_VERSION}-linux-${arch}.tar.gz"; \
    curl -fsSLo /tmp/helm.sha256 "https://get.helm.sh/helm-${HELM_VERSION}-linux-${arch}.tar.gz.sha256sum"; \
    echo "$(awk '{print $1}' /tmp/helm.sha256)  /tmp/helm.tgz" | sha256sum -c -; \
    tar -xzf /tmp/helm.tgz -C /tmp; \
    install -m 0755 "/tmp/linux-${arch}/helm" /usr/local/bin/helm; \
    flux_version="${FLUX_VERSION#v}"; \
    curl -fsSLo /tmp/flux.tgz "https://github.com/fluxcd/flux2/releases/download/v${flux_version}/flux_${flux_version}_linux_${arch}.tar.gz"; \
    echo "${flux_sha256}  /tmp/flux.tgz" | sha256sum -c -; \
    tar -xzf /tmp/flux.tgz -C /tmp flux; \
    install -m 0755 /tmp/flux /usr/local/bin/flux; \
    curl -fsSLo /tmp/yq "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_${arch}"; \
    echo "${yq_sha256}  /tmp/yq" | sha256sum -c -; \
    install -m 0755 /tmp/yq /usr/local/bin/yq; \
    curl -fsSLo /tmp/mc "https://dl.min.io/aistor/mc/release/linux-${arch}/archive/mc.${MC_VERSION}"; \
    echo "${mc_sha256}  /tmp/mc" | sha256sum -c -; \
    install -m 0755 /tmp/mc /usr/local/bin/mc; \
    rm -rf /tmp/kubectl /tmp/kubectl.sha256 /tmp/helm.tgz /tmp/helm.sha256 "/tmp/linux-${arch}" /tmp/flux.tgz /tmp/flux /tmp/yq /tmp/mc; \
    kubectl version --client; \
    helm version --short; \
    flux version --client; \
    yq --version; \
    mc --version

RUN useradd --uid 1000 --create-home --shell /bin/bash kex \
 && mkdir -p /work \
 && chown -R kex:kex /work

USER 1000:1000
WORKDIR /work
CMD ["sleep", "infinity"]
