#!/usr/bin/env bash
set -euo pipefail

QUERY="${1:?Usage: ./scripts/spark_sql.sh \"SELECT ...\"}"

docker compose build dbt >/dev/null
docker compose run --rm dbt bash -lc "
  /usr/local/bin/spark-sql \
    --packages org.apache.iceberg:iceberg-spark-runtime-3.5_2.12:1.5.2 \
    --conf spark.sql.extensions=org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions \
    --conf spark.sql.catalog.local_iceberg=org.apache.iceberg.spark.SparkCatalog \
    --conf spark.sql.catalog.local_iceberg.type=hadoop \
    --conf spark.sql.catalog.local_iceberg.warehouse=file:///data/iceberg \
    -e \"${QUERY}\"
"
