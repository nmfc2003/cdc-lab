#!/usr/bin/env bash
set -euo pipefail

FLINK_REST_URL="${FLINK_REST_URL:-http://localhost:8081}"
CMD="${1:-list}"
ARG="${2:-}"

jobs_json() {
  curl -fsS "${FLINK_REST_URL}/jobs/overview"
}

list_jobs() {
  local payload
  if ! payload="$(jobs_json 2>/dev/null)"; then
    echo "Flink REST not reachable at ${FLINK_REST_URL}" >&2
    exit 1
  fi

  python3 - <<'PY' "${payload}"
import json, sys, datetime

p = json.loads(sys.argv[1])
jobs = p.get("jobs", [])
if not jobs:
    print("No Flink jobs found.")
    raise SystemExit(0)

print(f"{'JOB_ID':<35} {'STATE':<12} {'NAME':<60} STARTED_UTC")
for j in jobs:
    ts = j.get("start-time", -1)
    started = "-"
    if isinstance(ts, int) and ts > 0:
      started = datetime.datetime.utcfromtimestamp(ts/1000).isoformat() + "Z"
    print(f"{j.get('jid','-'):<35} {j.get('state','-'):<12} {j.get('name','-')[:60]:<60} {started}")
PY
}

cancel_job() {
  local job_id="$1"
  curl -fsS -X PATCH "${FLINK_REST_URL}/jobs/${job_id}" >/dev/null
  echo "Cancelled Flink job: ${job_id}"
}

cancel_insert_running() {
  local payload
  if ! payload="$(jobs_json 2>/dev/null)"; then
    echo "Flink REST not reachable at ${FLINK_REST_URL}" >&2
    exit 1
  fi

  ids=()
  while IFS= read -r line; do
    [[ -n "${line}" ]] && ids+=("${line}")
  done < <(python3 - <<'PY' "${payload}"
import json, sys
jobs = json.loads(sys.argv[1]).get("jobs", [])
for j in jobs:
    name = (j.get("name") or "").lower()
    state = (j.get("state") or "").upper()
    if state == "RUNNING" and ("insert-into" in name or "insert into" in name):
        print(j.get("jid"))
PY
)

  if [[ "${#ids[@]}" -eq 0 ]]; then
    echo "No RUNNING Flink INSERT jobs found to cancel."
    return 0
  fi

  for id in "${ids[@]}"; do
    cancel_job "${id}"
  done
}

case "${CMD}" in
  list)
    list_jobs
    ;;
  cancel)
    if [[ -z "${ARG}" ]]; then
      echo "Usage: $0 cancel <job_id|--insert-running>" >&2
      exit 1
    fi
    if [[ "${ARG}" == "--insert-running" ]]; then
      cancel_insert_running
    else
      cancel_job "${ARG}"
    fi
    ;;
  *)
    echo "Usage: $0 [list|cancel <job_id|--insert-running>]" >&2
    exit 1
    ;;
esac
