#!/usr/bin/env bash
set -euo pipefail

SQL_FILE="${1:-flink/sql/init.sql}"

if [[ ! -f "${SQL_FILE}" ]]; then
  echo "ERROR: SQL file not found: ${SQL_FILE}" >&2
  exit 1
fi

echo "Starting Flink services..."
docker compose up -d flink-jobmanager flink-taskmanager

echo "Waiting for Flink JobManager REST API..."
for _ in {1..90}; do
  if curl -fsS http://localhost:8081/overview >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

if ! curl -fsS http://localhost:8081/overview >/dev/null 2>&1; then
  echo "ERROR: Flink JobManager is not reachable on http://localhost:8081" >&2
  exit 1
fi

sql_in_container="/opt/flink/sql/$(basename "${SQL_FILE}")"

echo "Submitting SQL from ${SQL_FILE}..."
tmp_out="$(mktemp)"
trap 'rm -f "${tmp_out}"' EXIT

docker compose exec -T flink-jobmanager /opt/flink/bin/sql-client.sh -f "${sql_in_container}" | tee "${tmp_out}"

if rg -q "\\[ERROR\\]" "${tmp_out}"; then
  echo "ERROR: Flink SQL execution reported errors. See output above." >&2
  exit 1
fi

echo "Flink SQL submitted."
