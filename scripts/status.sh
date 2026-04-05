#!/usr/bin/env bash
set -euo pipefail

CONNECT_URL="${CONNECT_URL:-http://localhost:8083}"
FLINK_REST_URL="${FLINK_REST_URL:-http://localhost:8081}"
TOPIC_NAME="${TOPIC_NAME:-cdc_lab_pg.public.orders}"

failures=0

ok() { echo "[OK] $*"; }
warn() { echo "[WARN] $*"; }
fail() { echo "[FAIL] $*"; failures=$((failures + 1)); }

section() {
  echo
  echo "=== $* ==="
}

section "Postgres"
if docker compose exec -T postgres pg_isready -U postgres -d appdb >/dev/null 2>&1; then
  ok "Postgres reachable (appdb)."
else
  fail "Postgres not reachable via docker compose exec -T postgres pg_isready -U postgres -d appdb"
fi

section "Kafka"
if docker compose exec -T kafka /opt/bitnami/kafka/bin/kafka-topics.sh --bootstrap-server kafka:9092 --list >/dev/null 2>&1; then
  ok "Kafka broker reachable (kafka:9092)."
else
  fail "Kafka broker not reachable at kafka:9092"
fi

if docker compose exec -T kafka /opt/bitnami/kafka/bin/kafka-topics.sh --bootstrap-server kafka:9092 --list 2>/dev/null | tr -d '\r' | grep -Fxq "${TOPIC_NAME}"; then
  ok "Topic exists: ${TOPIC_NAME}"
else
  fail "Topic missing: ${TOPIC_NAME}"
fi

section "Kafka Connect"
if curl -fsS "${CONNECT_URL}/connectors" >/dev/null 2>&1; then
  ok "Kafka Connect API reachable at ${CONNECT_URL}"
else
  fail "Kafka Connect API not reachable at ${CONNECT_URL}"
fi

connector_json=""
if connector_json="$(curl -fsS "${CONNECT_URL}/connectors/orders-cdc/status" 2>/dev/null)"; then
  python3 - <<'PY' "${connector_json}"
import json, sys
s = json.loads(sys.argv[1])
connector = s.get("connector", {})
tasks = s.get("tasks", [])
print(f"connector.state={connector.get('state','UNKNOWN')}")
if not tasks:
    print("tasks=none")
for t in tasks:
    print(f"task[{t.get('id')}].state={t.get('state','UNKNOWN')}")
PY
  state="$(python3 - <<'PY' "${connector_json}"
import json, sys
s = json.loads(sys.argv[1])
connector_ok = s.get("connector", {}).get("state") == "RUNNING"
tasks = s.get("tasks", [])
tasks_ok = bool(tasks) and all(t.get("state") == "RUNNING" for t in tasks)
print("ok" if connector_ok and tasks_ok else "bad")
PY
)"
  if [[ "${state}" == "ok" ]]; then
    ok "orders-cdc connector and tasks are RUNNING"
  else
    fail "orders-cdc connector/tasks not fully RUNNING"
  fi
else
  fail "Unable to fetch connector status for orders-cdc"
fi

section "Flink"
if flink_jobs="$(curl -fsS "${FLINK_REST_URL}/jobs/overview" 2>/dev/null)"; then
  ok "Flink REST reachable at ${FLINK_REST_URL}"
  python3 - <<'PY' "${flink_jobs}"
import json, sys, datetime
jobs = json.loads(sys.argv[1]).get("jobs", [])
if not jobs:
    print("jobs=none")
else:
    print(f"{'JOB_ID':<35} {'STATE':<12} NAME")
    for j in jobs:
      print(f"{j.get('jid','-'):<35} {j.get('state','-'):<12} {j.get('name','-')}")
PY

  mapfile -t running_ids < <(python3 - <<'PY' "${flink_jobs}"
import json, sys
for j in json.loads(sys.argv[1]).get("jobs", []):
    if (j.get("state") or "").upper() == "RUNNING":
        print(j.get("jid"))
PY
)

  if [[ "${#running_ids[@]}" -eq 0 ]]; then
    warn "No RUNNING Flink jobs; checkpoint summary unavailable."
  else
    for jid in "${running_ids[@]}"; do
      echo "checkpoint_summary job=${jid}"
      cp_json=""
      if cp_json="$(curl -fsS "${FLINK_REST_URL}/jobs/${jid}/checkpoints" 2>/dev/null)"; then
        python3 - <<'PY' "${cp_json}"
import json, sys, datetime
p = json.loads(sys.argv[1])
latest = p.get("latest", {}).get("completed")
counts = p.get("counts", {})
if not latest:
    print(f"  completed=0 failed={counts.get('failed',0)} in_progress={counts.get('in_progress',0)}")
else:
    ts = latest.get("trigger_timestamp", 0)
    iso = "-"
    if isinstance(ts, int) and ts > 0:
        iso = datetime.datetime.utcfromtimestamp(ts/1000).isoformat() + "Z"
    print(f"  latest_completed_id={latest.get('id')}")
    print(f"  status={latest.get('status')}")
    print(f"  trigger_time_utc={iso}")
    print(f"  end_to_end_ms={latest.get('end_to_end_duration')}")
    print(f"  completed={counts.get('completed',0)} failed={counts.get('failed',0)} in_progress={counts.get('in_progress',0)}")
PY
      else
        warn "Unable to fetch checkpoints for job ${jid}"
      fi
    done
  fi
else
  fail "Flink REST not reachable at ${FLINK_REST_URL}"
fi

section "Iceberg warehouse"
if [[ -d data/iceberg ]]; then
  total_files="$(find data/iceberg -type f | wc -l | tr -d ' ')"
  metadata_files="$(find data/iceberg -type f \( -name '*.metadata.json' -o -path '*/metadata/*' \) | wc -l | tr -d ' ')"
  data_files="$(find data/iceberg -type f \( -name '*.parquet' -o -name '*.avro' -o -name '*.orc' \) | wc -l | tr -d ' ')"
  ok "Iceberg files total=${total_files} metadata_like=${metadata_files} data_like=${data_files}"
else
  warn "data/iceberg not found"
fi

if (( failures > 0 )); then
  echo
  echo "Status check completed with ${failures} failure(s)."
  exit 1
fi

echo
ok "Status check completed with no failures."
