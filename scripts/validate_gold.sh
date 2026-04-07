#!/usr/bin/env bash
set -euo pipefail

./scripts/run_dbt_gold.sh
for t in customer_order_summary_gold order_payment_status_gold daily_revenue_gold; do
  ./scripts/spark_sql.sh "SELECT '$t' AS model_name, COUNT(*) AS cnt FROM local_iceberg.gold.$t;"
done
