# syntax=docker/dockerfile:1.7
ARG CONTAINER_VERSION=latest

# ══════════════════════════════════════════════════════════════
# Stage 1: Build
# ══════════════════════════════════════════════════════════════
FROM docker.io/library/golang:1.25-trixie AS builder

COPY scripts/latest-tag.sh /usr/bin/latest-repo-release

RUN apt-get update && apt-get install --yes --no-install-recommends \
    git ca-certificates make gcc pkg-config \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/

RUN git clone --depth 1 \
    --branch "v$(/usr/bin/latest-repo-release)" "https://github.com/open-telemetry/opentelemetry-collector-contrib.git" \
    otelcol

# Optional: verify tag signature or commit hash here.

WORKDIR /opt/otelcol
ENTRYPOINT ["tail", "-f", "/dev/null"]
RUN sed -i 's/-dev//g' cmd/otelcontribcol/builder-config.yaml \
 && make otelcontribcol


# ══════════════════════════════════════════════════════════════
# Stage 2: Runtime
# ══════════════════════════════════════════════════════════════
FROM docker.io/gautada/debian:${CONTAINER_VERSION} AS container

# ╭──────────────────────────────────────────────────────────╮
# │ Metadata                                                 │
# ╰──────────────────────────────────────────────────────────╯
LABEL org.opencontainers.image.title="collector"
LABEL org.opencontainers.image.description="OpenTelemetry (Contrib)Collector"
LABEL org.opencontainers.image.url="https://github.com/gautada/collector"
LABEL org.opencontainers.image.source="https://github.com/gautada/collector"

# Copy the built binary
COPY --from=builder /opt/otelcol/bin/otelcontribcol_linux_* /usr/bin/otelcol
COPY --from=builder /usr/bin/latest-repo-release /usr/bin/latest-repo-release

# ╭──────────────────────────────────────────────────────────╮
# │ User                                                     │
# ╰──────────────────────────────────────────────────────────╯
ARG USER=watcher
RUN /usr/sbin/usermod -l $USER debian \
 && /usr/sbin/usermod -d /home/$USER -m $USER \
 && /usr/sbin/groupmod -n $USER debian \
 && /bin/passwd -d $USER \
 && rm -rf /home/debian 

# ╭──────────────────────────────────────────────────────────╮
# │ Configuration                                            │
# ╰──────────────────────────────────────────────────────────╯
COPY config.yaml /etc/otelcol/config.yaml

# ╭──────────────────────────────────────────────────────────╮
# │ Service                                                  │
# ╰──────────────────────────────────────────────────────────╯
RUN mkdir -p /etc/services.d/otelcol
COPY services/otelcol/run /etc/services.d/otelcol/run
RUN chmod +x /etc/services.d/otelcol/run \
 && mkdir -p /etc/container/health.d

# ╭──────────────────────────────────────────────────────────╮
# │ Container Scripts                                        │
# ╰──────────────────────────────────────────────────────────╯
COPY scripts/container-version.sh /usr/bin/container-version
COPY health/otel-check.sh /etc/container/health.d/otel-running
RUN chmod +x \
    /usr/bin/container-version \
    /etc/container/health.d/otel-running

EXPOSE 4317/tcp 4318/tcp 8889/tcp
WORKDIR /opt/otelcol
