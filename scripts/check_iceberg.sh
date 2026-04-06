#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

"$(dirname "$0")/check_iceberg_files.sh"
"$(dirname "$0")/check_iceberg_rows.sh"

TABLE_PATH="${ROOT_DIR}/data/iceberg/bronze/orders_bronze"
echo "Recent Iceberg files under ${TABLE_PATH}:"
find "${TABLE_PATH}" -type f | sort | tail -n 20
