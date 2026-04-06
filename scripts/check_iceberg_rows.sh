#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TABLE_PATH="${ROOT_DIR}/data/iceberg/bronze/orders_bronze"
METADATA_DIR="${TABLE_PATH}/metadata"

if [[ ! -d "${METADATA_DIR}" ]]; then
  echo "ERROR: metadata dir missing: ${METADATA_DIR}" >&2
  exit 1
fi

count_from_metadata() {
  python3 - "$1" <<'PY'
import json
import pathlib
import sys

metadata_dir = pathlib.Path(sys.argv[1])
version_hint = metadata_dir / "version-hint.text"
meta_file = None

if version_hint.exists():
    raw = version_hint.read_text(encoding="utf-8").strip()
    if raw.isdigit():
        candidate = metadata_dir / f"v{raw}.metadata.json"
        if candidate.exists():
            meta_file = candidate

if meta_file is None:
    files = list(metadata_dir.glob("v*.metadata.json"))
    if not files:
        print("ERROR:no metadata json files", file=sys.stderr)
        sys.exit(2)
    def version_num(path: pathlib.Path) -> int:
        stem = path.name
        # v123.metadata.json -> 123
        value = stem.split(".")[0].lstrip("v")
        return int(value) if value.isdigit() else -1
    files.sort(key=version_num)
    meta_file = files[-1]

payload = json.loads(meta_file.read_text(encoding="utf-8"))
current_snapshot_id = payload.get("current-snapshot-id")
if current_snapshot_id is None:
    print(0)
    sys.exit(0)

snapshots = payload.get("snapshots", [])
snapshot = next((s for s in snapshots if s.get("snapshot-id") == current_snapshot_id), None)
if not snapshot:
    print("ERROR:current snapshot not found", file=sys.stderr)
    sys.exit(3)

summary = snapshot.get("summary", {})
for key in ("total-records", "added-records"):
    value = summary.get(key)
    if value is not None:
        print(int(value))
        sys.exit(0)

print("ERROR:no record count in snapshot summary", file=sys.stderr)
sys.exit(4)
PY
}

rows="$(count_from_metadata "${METADATA_DIR}")"

if [[ "${rows}" -le 0 ]]; then
  echo "ERROR: Iceberg snapshot reports non-positive row count (${rows})" >&2
  exit 1
fi

echo "OK: Iceberg snapshot row count=${rows}"
