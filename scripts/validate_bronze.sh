#!/usr/bin/env bash
set -euo pipefail

for t in customers_bronze orders_bronze payments_bronze transactions_bronze; do
  echo "Validating bronze table: $t"
  ./scripts/spark_sql.sh "SELECT '$t' AS table_name, COUNT(*) AS cnt FROM local_iceberg.bronze.$t;"
done
