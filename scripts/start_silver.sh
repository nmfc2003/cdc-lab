#!/usr/bin/env bash
set -euo pipefail

./scripts/up.sh
./scripts/run_flink_sql.sh --replace

docker compose up -d spark

docker compose exec -d spark /opt/bitnami/spark/bin/spark-submit \
  --packages org.apache.iceberg:iceberg-spark-runtime-3.5_2.12:1.5.2 \
  --conf spark.sql.extensions=org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions \
  --conf spark.sql.catalog.local_iceberg=org.apache.iceberg.spark.SparkCatalog \
  --conf spark.sql.catalog.local_iceberg.type=hadoop \
  --conf spark.sql.catalog.local_iceberg.warehouse=file:///data/iceberg \
  /opt/spark/jobs/silver_streaming.py

echo "Silver streaming job submitted in cdc-spark container."
