#!/usr/bin/env bash
set -euo pipefail

./scripts/up.sh
./scripts/start_bronze.sh
./scripts/run_flink_sql.sh flink/sql/silver.sql --allow-concurrent
./scripts/insert_sample_data.sh

echo "Waiting 45s for Bronze and Silver propagation..."
sleep 45

./scripts/validate_bronze.sh
./scripts/validate_silver.sh
./scripts/run_dbt_gold.sh
./scripts/validate_gold.sh

./scripts/spark_sql.sh "SELECT customer_id, total_orders, total_paid_amount FROM local_iceberg.gold.customer_order_summary_gold ORDER BY customer_id;"
./scripts/spark_sql.sh "SELECT revenue_date, gross_revenue FROM local_iceberg.gold.daily_revenue_gold ORDER BY revenue_date;"

echo "Phase 2 validation flow completed."
