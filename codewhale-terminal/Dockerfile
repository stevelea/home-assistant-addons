# Codewhale Terminal — Home Assistant add-on
#
# Codewhale's coding agent (Rust TUI/CLI) in a browser terminal (ttyd + tmux).
#
# Base image: Ubuntu 24.04 for both arches. Codewhale's prebuilt Linux
# binaries are fetched straight from GitHub Releases at build time — the x64
# asset is a static musl build, the arm64 asset is a glibc build that needs
# glibc >= 2.39 (Ubuntu 24.04 ships 2.39). No Node/npm is involved: the npm
# package is only a download wrapper around these same binaries.
#
# Runtime packages are baked into the image so startup never depends on the
# network. This add-on runs on a plain
# Ubuntu base (no s6-overlay, no bashio) — startup is plain bash that reads
# /data/options.json with jq.

ARG BUILD_FROM
FROM ${BUILD_FROM}

# Codewhale release to fetch at build time. Kept in sync with the upstream
# release; bump this when a new Codewhale version is wanted.
ARG CODEWHALE_VERSION=0.9.3

# Version of this add-on (also in config.yaml) — shown by the welcome banner.
ARG ADDON_VERSION=0.1.0

ENV DEBIAN_FRONTEND=noninteractive

# All runtime packages are baked into the image so startup never depends on
# the network (ttyd/tmux/jq were previously installed on every boot in the
# Claude add-on; we keep the same philosophy here)
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        git \
        jq \
        nano \
        python3 \
        python3-pip \
        python3-yaml \
        tmux \
        tree \
        ttyd \
        vim \
        wget \
    && rm -rf /var/lib/apt/lists/*

# uv from PyPI, pinned: ha-mcp >= 4.x requires Python 3.13, which Ubuntu 24.04
# does not ship — uv provisions a managed CPython build on first use
RUN pip3 install --no-cache-dir --break-system-packages uv==0.11.28

# Keep caches out of persistent storage so they never land in HA backups
# (/data is included in backups; uv's managed Pythons live under /data on
# purpose, but its download cache does not need to)
ENV UV_CACHE_DIR=/tmp/uv-cache

# The Codewhale facade locates the TUI binary through this env var. run.sh
# repoints it at a persistent copy in /data when a runtime-updated one exists.
ENV CODEWHALE_TUI_BIN=/usr/local/bin/codewhale-tui

# Codewhale keeps all state (config.toml, mcp.json, sessions) under its home
# dir; /data persists across restarts and add-on updates
ENV CODEWHALE_HOME=/data/.codewhale

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Bundled Codewhale binaries, pinned at image build time. When
# codewhale_auto_update is enabled, run.sh keeps a persistent copy in /data
# that takes precedence and stays current.
RUN arch="$(dpkg --print-architecture)"; \
    case "$arch" in \
        amd64) cw_arch="x64" ;; \
        arm64) cw_arch="arm64" ;; \
        *) echo "Unsupported architecture: $arch" >&2; exit 1 ;; \
    esac; \
    base="https://github.com/Hmbown/CodeWhale/releases/download/v${CODEWHALE_VERSION}"; \
    curl -fsSL --connect-timeout 20 -o /usr/local/bin/codewhale "${base}/codewhale-linux-${cw_arch}" \
    && curl -fsSL --connect-timeout 20 -o /usr/local/bin/codewhale-tui "${base}/codewhale-tui-linux-${cw_arch}" \
    && chmod 755 /usr/local/bin/codewhale /usr/local/bin/codewhale-tui

COPY run.sh /run.sh
COPY scripts/ /opt/scripts/
RUN chmod 755 /run.sh /opt/scripts/*.sh \
    && echo "${ADDON_VERSION}" > /opt/scripts/addon-version

# The terminal (and Codewhale, when auto-launched) starts in /config — your
# Home Assistant configuration directory
WORKDIR /config
CMD ["/run.sh"]
