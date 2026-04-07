#!/usr/bin/env bash
set -euo pipefail

for t in customers_silver orders_silver payments_silver transactions_silver; do
  echo "Validating silver table: $t"
  ./scripts/spark_sql.sh "SELECT '$t' AS table_name, COUNT(*) AS cnt FROM local_iceberg.silver.$t;"
done
