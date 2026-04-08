#!/usr/bin/env bash
set -euo pipefail

QUERY="${1:?Usage: ./scripts/spark_sql.sh \"SELECT ...\"}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ICEBERG_DIR="${REPO_ROOT}/data/iceberg"
OUTPUT_DIR="${REPO_ROOT}/output"
IVY_CACHE_DIR="${REPO_ROOT}/.cache/ivy2"
SPARK_LOCAL_DIR="${REPO_ROOT}/.cache/spark-local"

mkdir -p "${ICEBERG_DIR}" "${OUTPUT_DIR}" "${IVY_CACHE_DIR}" "${SPARK_LOCAL_DIR}"

docker run --rm -i \
  -v "${ICEBERG_DIR}:/data/iceberg" \
  -v "${OUTPUT_DIR}:/output" \
  -v "${IVY_CACHE_DIR}:/tmp/.ivy2" \
  -v "${SPARK_LOCAL_DIR}:/tmp/spark-local" \
  apache/spark:3.5.1-python3 \
  /opt/spark/bin/spark-sql \
    --packages org.apache.iceberg:iceberg-spark-runtime-3.5_2.12:1.5.2 \
    --conf spark.jars.ivy=/tmp/.ivy2 \
    --conf spark.local.dir=/tmp/spark-local \
    --conf spark.sql.extensions=org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions \
    --conf spark.sql.catalog.local_iceberg=org.apache.iceberg.spark.SparkCatalog \
    --conf spark.sql.catalog.local_iceberg.type=hadoop \
    --conf spark.sql.catalog.local_iceberg.warehouse=file:///data/iceberg \
    -e "${QUERY}"