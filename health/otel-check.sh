#!/bin/sh
# Check if the OpenTelemetry Collector is responding to health check requests.
# Returns 0 if healthy, non-zero otherwise.

# For now, we'll check if the metrics port is accessible.
curl -fsSL http://localhost:8889/metrics > /dev/null
