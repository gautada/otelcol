#!/bin/sh
# Returns the version of the packaged OpenTelemetry Collector.

/usr/bin/otelcol --version 2>&1 | awk '{print $NF}'
