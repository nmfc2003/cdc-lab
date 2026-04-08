#!/usr/bin/env bash
set -euo pipefail

for t in customers_silver orders_silver payments_silver transactions_silver; do
  echo "Validating silver table: $t"
  ./scripts/spark_sql.sh "SELECT '$t' AS table_name, COUNT(*) AS cnt FROM local_iceberg.silver.$t;"
done

./scripts/spark_sql.sh "SELECT 'customers_pk_duplicates' AS check_name, COUNT(*) AS cnt FROM (SELECT customer_id FROM local_iceberg.silver.customers_silver GROUP BY customer_id HAVING COUNT(*) > 1) x;"
./scripts/spark_sql.sh "SELECT 'orders_pk_duplicates' AS check_name, COUNT(*) AS cnt FROM (SELECT order_id FROM local_iceberg.silver.orders_silver GROUP BY order_id HAVING COUNT(*) > 1) x;"
./scripts/spark_sql.sh "SELECT 'payments_pk_duplicates' AS check_name, COUNT(*) AS cnt FROM (SELECT payment_id FROM local_iceberg.silver.payments_silver GROUP BY payment_id HAVING COUNT(*) > 1) x;"
./scripts/spark_sql.sh "SELECT 'transactions_pk_duplicates' AS check_name, COUNT(*) AS cnt FROM (SELECT transaction_id FROM local_iceberg.silver.transactions_silver GROUP BY transaction_id HAVING COUNT(*) > 1) x;"
./scripts/spark_sql.sh "SELECT 'customers_delete_ops_present' AS check_name, COUNT(*) AS cnt FROM local_iceberg.silver.customers_silver WHERE bronze_op = 'd';"
./scripts/spark_sql.sh "SELECT 'orders_delete_ops_present' AS check_name, COUNT(*) AS cnt FROM local_iceberg.silver.orders_silver WHERE bronze_op = 'd';"
./scripts/spark_sql.sh "SELECT 'payments_delete_ops_present' AS check_name, COUNT(*) AS cnt FROM local_iceberg.silver.payments_silver WHERE bronze_op = 'd';"
./scripts/spark_sql.sh "SELECT 'transactions_delete_ops_present' AS check_name, COUNT(*) AS cnt FROM local_iceberg.silver.transactions_silver WHERE bronze_op = 'd';"
