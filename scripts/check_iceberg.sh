#!/usr/bin/env bash
set -euo pipefail

TABLE_PATH="/data/iceberg/orders_bronze"

echo "Listing Iceberg table files under ${TABLE_PATH}..."
docker compose exec -T flink-jobmanager sh -lc "if [ -d '${TABLE_PATH}' ]; then find '${TABLE_PATH}' -maxdepth 3 -type f | sort; else echo 'Table path not found yet: ${TABLE_PATH}'; fi"

TMP_SQL="$(mktemp)"
cat > "${TMP_SQL}" <<'SQL'
CREATE CATALOG IF NOT EXISTS local_iceberg WITH (
  'type' = 'iceberg',
  'catalog-type' = 'hadoop',
  'warehouse' = 'file:///data/iceberg'
);
USE CATALOG local_iceberg;
SELECT * FROM orders_bronze LIMIT 10;
SQL

echo
echo "Sample rows from Iceberg table..."
docker compose cp "${TMP_SQL}" flink-jobmanager:/tmp/check_orders_bronze.sql >/dev/null
docker compose exec -T flink-jobmanager /opt/flink/bin/sql-client.sh -f /tmp/check_orders_bronze.sql

rm -f "${TMP_SQL}"
