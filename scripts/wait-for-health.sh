#!/usr/bin/env bash
set -euo pipefail

CONNECT_URL="${CONNECT_URL:-http://localhost:8083}"
CONNECTOR_NAME="${CONNECTOR_NAME:-orders-cdc}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-180}"

start_ts="$(date +%s)"

echo "Waiting for Kafka Connect API at ${CONNECT_URL}..."
until curl -fsS "${CONNECT_URL}/connectors" >/dev/null; do
  now="$(date +%s)"
  if (( now - start_ts > TIMEOUT_SECONDS )); then
    echo "ERROR: timed out waiting for Kafka Connect API" >&2
    exit 1
  fi
  sleep 2
done

echo "Waiting for connector ${CONNECTOR_NAME} and tasks to reach RUNNING..."
until curl -fsS "${CONNECT_URL}/connectors/${CONNECTOR_NAME}/status" | python3 -c 'import json,sys; s=json.load(sys.stdin); tasks=s.get("tasks",[]); ok=(s.get("connector",{}).get("state")=="RUNNING" and len(tasks)>0 and all(t.get("state")=="RUNNING" for t in tasks)); raise SystemExit(0 if ok else 1)'; do
  now="$(date +%s)"
  if (( now - start_ts > TIMEOUT_SECONDS )); then
    echo "ERROR: timed out waiting for connector ${CONNECTOR_NAME} to become RUNNING" >&2
    exit 1
  fi
  sleep 2
done

echo "Health checks passed."
