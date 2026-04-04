#!/usr/bin/env bash
set -euo pipefail

CONNECT_URL="${CONNECT_URL:-http://localhost:8083}"
CONNECTOR_NAME="${CONNECTOR_NAME:-orders-cdc}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-180}"

start_ts="$(date +%s)"

check_timeout() {
  local now
  now="$(date +%s)"
  if (( now - start_ts > TIMEOUT_SECONDS )); then
    echo "ERROR: timed out waiting for CDC lab health checks" >&2
    exit 1
  fi
}

echo "Waiting for Kafka Connect API at ${CONNECT_URL}..."
until curl -fsS "${CONNECT_URL}/connectors" >/dev/null; do
  check_timeout
  sleep 2
done

echo "Waiting for connector ${CONNECTOR_NAME} and tasks to reach RUNNING..."
while true; do
  check_timeout

  tmp_resp="$(mktemp)"
  http_code="$(curl -sS -o "${tmp_resp}" -w '%{http_code}' "${CONNECT_URL}/connectors/${CONNECTOR_NAME}/status" || true)"

  if [[ "${http_code}" == "200" ]]; then
    if python3 - "${tmp_resp}" <<'PY'
import json, sys
with open(sys.argv[1], 'r', encoding='utf-8') as f:
    s=json.load(f)
tasks=s.get('tasks', [])
ok=(s.get('connector', {}).get('state')=='RUNNING' and len(tasks)>0 and all(t.get('state')=='RUNNING' for t in tasks))
raise SystemExit(0 if ok else 1)
PY
    then
      rm -f "${tmp_resp}"
      break
    fi
  elif [[ "${http_code}" != "404" ]]; then
    echo "Connector status endpoint returned HTTP ${http_code}; waiting..."
  fi

  rm -f "${tmp_resp}"
  sleep 2
done

echo "Health checks passed."
