#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOPIC_NAME="cdc_lab_pg.public.orders"
MARKER_CUSTOMER_ID="${MARKER_CUSTOMER_ID:-$((910000000 + ($(date +%s%N) % 100000000)))}"
MARKER_STATUS="${MARKER_STATUS:-BRONZE_TEST_${MARKER_CUSTOMER_ID}}"
MARKER_AMOUNT="${MARKER_AMOUNT:-99.99}"
KAFKA_WAIT_SECONDS="${KAFKA_WAIT_SECONDS:-45}"
ICEBERG_WAIT_SECONDS="${ICEBERG_WAIT_SECONDS:-90}"

cd "${ROOT_DIR}"

echo "[1/8] Bringing up core stack..."
./scripts/up.sh

echo "[2/8] Ensuring bronze Flink pipeline is running..."
./scripts/run_flink_sql.sh --replace

echo "[3/8] Reading Iceberg row baseline (if available)..."
before_rows=0
if ./scripts/check_iceberg_rows.sh >/tmp/check_rows_before.log 2>&1; then
  before_rows="$(sed -n 's/.*row count=\([0-9][0-9]*\).*/\1/p' /tmp/check_rows_before.log | tail -n1)"
  before_rows="${before_rows:-0}"
else
  echo "Baseline rows unavailable yet (acceptable on first run)."
fi


echo "[4/8] Inserting test Postgres row..."
./scripts/insert_test_order.sh "${MARKER_CUSTOMER_ID}" "${MARKER_STATUS}" "${MARKER_AMOUNT}"

echo "[5/8] Verifying Kafka received marker event..."
deadline=$(( $(date +%s) + KAFKA_WAIT_SECONDS ))
found_kafka_marker="false"
while [[ "$(date +%s)" -le "${deadline}" ]]; do
  if docker compose exec -T kafka /opt/bitnami/kafka/bin/kafka-console-consumer.sh \
    --bootstrap-server kafka:9092 \
    --topic "${TOPIC_NAME}" \
    --from-beginning \
    --timeout-ms 7000 | grep -F "\"customer_id\":${MARKER_CUSTOMER_ID}" | grep -F "\"status\":\"${MARKER_STATUS}\"" >/dev/null; then
    found_kafka_marker="true"
    break
  fi
  sleep 3
done

if [[ "${found_kafka_marker}" != "true" ]]; then
  echo "ERROR: did not find marker customer_id=${MARKER_CUSTOMER_ID} status=${MARKER_STATUS} in Kafka topic ${TOPIC_NAME}" >&2
  exit 1
fi

echo "[6/8] Verifying Flink insert job and checkpoint health..."
flink_jobs_json="$(curl -fsS http://localhost:8081/jobs/overview)"
running_insert_job_id="$(python3 - <<'PY' "${flink_jobs_json}"
import json, sys
jobs = json.loads(sys.argv[1]).get("jobs", [])
for job in jobs:
    name = (job.get("name") or "").lower()
    state = (job.get("state") or "").upper()
    if state == "RUNNING" and ("insert-into" in name or "insert into" in name):
        print(job.get("jid"))
        break
PY
)"

if [[ -z "${running_insert_job_id}" ]]; then
  echo "ERROR: no RUNNING Flink INSERT job found" >&2
  exit 1
fi

cp_json="$(curl -fsS "http://localhost:8081/jobs/${running_insert_job_id}/checkpoints")"
python3 - <<'PY' "${cp_json}"
import json, sys
p = json.loads(sys.argv[1])
completed = int((p.get("counts") or {}).get("completed", 0))
latest = ((p.get("latest") or {}).get("completed") or {})
if completed <= 0 or not latest:
    print("ERROR:no completed checkpoints for running insert job", file=sys.stderr)
    sys.exit(1)
print(f"OK: Flink checkpoints completed={completed}, latest_id={latest.get('id')}")
PY

echo "[7/8] Verifying Iceberg files committed..."
./scripts/check_iceberg_files.sh

echo "[8/8] Verifying Iceberg row count > 0 and increased after marker insert..."
deadline=$(( $(date +%s) + ICEBERG_WAIT_SECONDS ))
after_rows=0
while [[ "$(date +%s)" -le "${deadline}" ]]; do
  if after_log="$(./scripts/check_iceberg_rows.sh 2>/tmp/check_rows_after.err)"; then
    after_rows="$(sed -n 's/.*row count=\([0-9][0-9]*\).*/\1/p' <<<"${after_log}")"
    after_rows="${after_rows:-0}"
    if [[ "${after_rows}" -gt "${before_rows}" ]]; then
      break
    fi
  fi
  sleep 3
done

if [[ "${after_rows}" -le 0 ]]; then
  echo "ERROR: Iceberg row count is zero after ingestion" >&2
  exit 1
fi

if [[ "${after_rows}" -le "${before_rows}" ]]; then
  echo "ERROR: Iceberg row count did not increase within ${ICEBERG_WAIT_SECONDS}s (before=${before_rows}, after=${after_rows})" >&2
  if [[ -s /tmp/check_rows_after.err ]]; then
    echo "Last check_iceberg_rows.sh error:"
    cat /tmp/check_rows_after.err
  fi
  exit 1
fi

echo
echo "Validation succeeded."
echo "Marker customer_id=${MARKER_CUSTOMER_ID}"
echo "Iceberg rows before=${before_rows} after=${after_rows}"
