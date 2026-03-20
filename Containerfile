# syntax=docker/dockerfile:1.7

# ══════════════════════════════════════════════════════════════
# Stage 1: Build
# ══════════════════════════════════════════════════════════════
FROM docker.io/library/golang:1.24-bookworm AS builder

# ╭──────────────────────────────────────────────────────────╮
# │ Build Dependencies                                       │
# ╰──────────────────────────────────────────────────────────╯
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    curl git build-essential \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Build the OpenTelemetry Collector using the builder tool
# https://github.com/open-telemetry/opentelemetry-collector-builder
RUN go install go.opentelemetry.io/collector/cmd/builder@v0.121.0 \
 && printf "dist:\n  name: otelcol-gautada\n  description: OpenTelemetry Collector Contrib for gautada\n  output_path: /build/otelcol\n  otelcol_version: 0.121.0\n\nreceivers:\n  - import: go.opentelemetry.io/collector/receiver/otlpreceiver\n  - import: github.com/open-telemetry/opentelemetry-collector-contrib/receiver/prometheusreceiver\n\nprocessors:\n  - import: go.opentelemetry.io/collector/processor/batchprocessor\n\nexporters:\n  - import: go.opentelemetry.io/collector/exporter/otlpexporter\n  - import: github.com/open-telemetry/opentelemetry-collector-contrib/exporter/prometheusexporter\n\nextensions:\n  - import: go.opentelemetry.io/collector/extension/zpagesextension\n  - import: github.com/open-telemetry/opentelemetry-collector-contrib/extension/healthcheckextension\n" > manifest.yaml \
 && builder --config manifest.yaml

# ══════════════════════════════════════════════════════════════
# Stage 2: Runtime
# ══════════════════════════════════════════════════════════════
ARG CONTAINER_VERSION=latest
FROM docker.io/gautada/debian:${CONTAINER_VERSION} AS container

# ╭──────────────────────────────────────────────────────────╮
# │ Metadata                                                 │
# ╰──────────────────────────────────────────────────────────╯
LABEL org.opencontainers.image.title="collector"
LABEL org.opencontainers.image.description="OpenTelemetry Collector for gautada"
LABEL org.opencontainers.image.url="https://github.com/gautada/collector"
LABEL org.opencontainers.image.source="https://github.com/gautada/collector"

# ╭──────────────────────────────────────────────────────────╮
# │ Application                                              │
# ╰──────────────────────────────────────────────────────────╯
WORKDIR /opt/otelcol

# Copy the built binary
COPY --from=builder /build/otelcol/otelcol-gautada /usr/bin/otelcol

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
