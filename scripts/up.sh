#!/usr/bin/env bash
set -euo pipefail

# Bring up core services first.
docker compose up -d postgres kafka kafka-init kafka-connect kafka-ui

# Force recreate so connector registration runs every startup (idempotent via PUT).
docker compose up -d --force-recreate connector-init

# Validate end-state health.
"$(dirname "$0")/wait-for-health.sh"

echo "Stack is ready."
