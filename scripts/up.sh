#!/usr/bin/env bash
set -euo pipefail

docker compose up -d postgres kafka kafka-init kafka-connect kafka-ui

echo "Waiting for Kafka Connect API..."
until curl -fsS http://localhost:8083/connectors >/dev/null; do
  sleep 2
done

# Force recreate so connector registration runs every startup (idempotent via PUT).
docker compose up -d --force-recreate connector-init

# Wait for connector and task state to both be RUNNING.
echo "Waiting for connector + task to reach RUNNING..."
until curl -fsS http://localhost:8083/connectors/orders-cdc/status | python -c 'import json,sys; s=json.load(sys.stdin); ok=(s.get("connector",{}).get("state")=="RUNNING" and all(t.get("state")=="RUNNING" for t in s.get("tasks",[]))); raise SystemExit(0 if ok else 1)'; do
  sleep 2
done

echo "Stack is ready."
