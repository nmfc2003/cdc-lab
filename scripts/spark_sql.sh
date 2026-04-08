#!/usr/bin/env bash
set -euo pipefail

QUERY="${1:?Usage: ./scripts/spark_sql.sh \"SELECT ...\"}"

docker compose up -d spark >/dev/null

docker compose exec -T spark /opt/bitnami/spark/bin/spark-sql \
  --packages org.apache.iceberg:iceberg-spark-runtime-3.5_2.12:1.5.2 \
  --conf spark.sql.extensions=org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions \
  --conf spark.sql.catalog.local_iceberg=org.apache.iceberg.spark.SparkCatalog \
  --conf spark.sql.catalog.local_iceberg.type=hadoop \
  --conf spark.sql.catalog.local_iceberg.warehouse=file:///data/iceberg \
  -e "$QUERY"
