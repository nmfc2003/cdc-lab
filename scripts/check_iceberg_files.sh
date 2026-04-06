#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TABLE_PATH="${ROOT_DIR}/data/iceberg/bronze/orders_bronze"

if [[ ! -d "${TABLE_PATH}" ]]; then
  echo "ERROR: Iceberg table path missing: ${TABLE_PATH}" >&2
  exit 1
fi

metadata_count="$(find "${TABLE_PATH}" -type f -name '*.metadata.json' | wc -l | tr -d ' ')"
data_count="$(find "${TABLE_PATH}" -type f -name '*.parquet' | wc -l | tr -d ' ')"

if [[ "${metadata_count}" == "0" ]]; then
  echo "ERROR: no Iceberg metadata json files found under ${TABLE_PATH}" >&2
  exit 1
fi

if [[ "${data_count}" == "0" ]]; then
  echo "ERROR: no Iceberg parquet data files found under ${TABLE_PATH}" >&2
  exit 1
fi

echo "OK: Iceberg files present metadata=${metadata_count} parquet=${data_count}"
