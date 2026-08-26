# Base image for Hall dispatch containers.
#
# Provides the infrastructure layer common to all agent environments:
# Node.js 20 (for MCP server tooling), gh CLI, git, jq, yq, unzip,
# and runner user at UID 1001.
#
# Target repos extend FROM this image and add repo-specific runtimes
# (Elixir, PostgreSQL, etc.) in their own docker/Dockerfile.
#
# Designed to run as UID 1001 (runner). The dispatch workflow must pass
# --user 1001 in the container options so GHA does not override the
# effective user to root. CC 2.1+ refuses --dangerously-skip-permissions
# as root; running as non-root is the fix.

FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# ── External package repos (Node.js 20, GitHub CLI) ───────────────────────────
RUN apt-get update \
    && apt-get install -y --no-install-recommends gnupg curl ca-certificates \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
       | gpg --dearmor -o /etc/apt/trusted.gpg.d/githubcli.gpg \
    && echo "deb [arch=$(dpkg --print-architecture)] https://cli.github.com/packages stable main" \
       > /etc/apt/sources.list.d/github-cli.list \
    && rm -rf /var/lib/apt/lists/*

# ── System packages ────────────────────────────────────────────────────────────
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       nodejs \
       gh \
       git \
       jq \
       unzip \
    && rm -rf /var/lib/apt/lists/*

# yq is not in Ubuntu repos; install the Go binary directly
RUN curl -fsSL https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 \
       -o /usr/local/bin/yq \
    && chmod +x /usr/local/bin/yq

# ── Runner user ────────────────────────────────────────────────────────────────
# UID 1001 matches the github-hosted runner's UID so workspace bind-mounts
# are accessible and CC (which refuses to run as root since 2.1.186) works.
RUN useradd -m -u 1001 -s /bin/bash runner

# ── npm global prefix ──────────────────────────────────────────────────────────
# apt-installed Node.js owns /usr/lib/node_modules as root; runner (UID 1001)
# cannot install there. Point NPM_CONFIG_PREFIX at a world-writable location
# so npm install -g works without sudo — same pattern as MIX_HOME for Elixir.
ENV NPM_CONFIG_PREFIX=/usr/local/share/npm-global
ENV PATH="/usr/local/share/npm-global/bin:${PATH}"
RUN mkdir -p /usr/local/share/npm-global/bin \
    && chmod 777 /usr/local/share/npm-global

# GHA sets HOME=/github/home; use --system so safe.directory is honoured
# regardless of what HOME the runner injects at container start.
RUN git config --system --add safe.directory '*'

# ── Entrypoint ─────────────────────────────────────────────────────────────────
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["tail", "-f", "/dev/null"]
