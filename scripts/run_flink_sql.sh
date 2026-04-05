#!/usr/bin/env bash
set -euo pipefail

SQL_FILE="flink/sql/init.sql"
REPLACE_RUNNING="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --replace)
      REPLACE_RUNNING="true"
      shift
      ;;
    *)
      SQL_FILE="$1"
      shift
      ;;
  esac
done

if [[ ! -f "${SQL_FILE}" ]]; then
  echo "ERROR: SQL file not found: ${SQL_FILE}" >&2
  exit 1
fi

echo "Ensuring CDC stack is healthy before Flink SQL submission..."
"$(dirname "$0")/wait-for-health.sh"

echo "Starting Flink services..."
docker compose up -d --build flink-jobmanager flink-taskmanager

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

if [[ "${REPLACE_RUNNING}" == "true" ]]; then
  echo "Cancelling RUNNING Flink INSERT jobs before submission (--replace enabled)..."
  "$(dirname "$0")/flink_jobs.sh" cancel --insert-running
else
  running_insert_jobs="$("$(dirname "$0")/flink_jobs.sh" list | grep -E 'RUNNING[[:space:]]+insert-into|RUNNING[[:space:]]+InsertInto' | wc -l | tr -d ' ' || true)"
  if [[ "${running_insert_jobs}" != "0" ]]; then
    echo "ERROR: Detected existing RUNNING INSERT job(s)." >&2
    echo "Use --replace to cancel existing INSERT job(s) before re-submitting." >&2
    exit 1
  fi
fi

sql_in_container="/opt/flink/sql/$(basename "${SQL_FILE}")"

echo "Submitting SQL from ${SQL_FILE}..."
tmp_out="$(mktemp)"
trap 'rm -f "${tmp_out}"' EXIT

docker compose exec -T flink-jobmanager /opt/flink/bin/sql-client.sh -f "${sql_in_container}" 2>&1 | tee "${tmp_out}"

# Portable, defensive SQL-client error detection.
if grep -Eqi '\[ERROR\]|Could not execute SQL statement|ClassNotFoundException|TableException|ValidationException|SqlParserException|ProgramInvocationException|Exception in thread' "${tmp_out}"; then
  echo "ERROR: Flink SQL execution reported errors. See output above." >&2
  exit 1
fi

echo "Flink SQL submitted. Current Flink jobs:"
"$(dirname "$0")/flink_jobs.sh" list
