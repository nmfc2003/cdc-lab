#!/usr/bin/env bash
set -euo pipefail

# Bring up core services first.
docker compose up -d postgres kafka kafka-init kafka-connect kafka-ui

# Force recreate so connector registration runs every startup (idempotent via PUT).
docker compose up -d --force-recreate connector-init

# Wait for connector-init to finish and fail fast if it did not complete successfully.
container_id="$(docker compose ps -q connector-init)"
if [[ -z "${container_id}" ]]; then
  echo "ERROR: connector-init container was not created" >&2
  exit 1
fi

while true; do
  state="$(docker inspect -f '{{.State.Status}}' "${container_id}")"
  if [[ "${state}" == "exited" ]]; then
    break
  fi
  sleep 1
done

exit_code="$(docker inspect -f '{{.State.ExitCode}}' "${container_id}")"
if [[ "${exit_code}" != "0" ]]; then
  echo "ERROR: connector-init exited with code ${exit_code}" >&2
  docker compose logs --no-color connector-init >&2 || true
  exit 1
fi

# Validate end-state health.
"$(dirname "$0")/wait-for-health.sh"

echo "Stack is ready."
