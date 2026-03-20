# syntax=docker/dockerfile:1.7

# ══════════════════════════════════════════════════════════════
# Stage 1: Build
# ══════════════════════════════════════════════════════════════
FROM docker.io/library/golang:1.25-trixie AS builder

RUN apt-get update && apt-get install --yes --no-install-recommends \
    git ca-certificates make gcc pkg-config \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/

RUN git clone --depth 1 \
    --branch "v0.148.0" "https://github.com/open-telemetry/opentelemetry-collector-contrib.git" \
    otelcol

# Optional: verify tag signature or commit hash here.

WORKDIR /opt/otelcol
RUN make otelcontribcol

# # ══════════════════════════════════════════════════════════════
# # Stage 2: Runtime
# # ══════════════════════════════════════════════════════════════
ARG CONTAINER_VERSION=latest
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
