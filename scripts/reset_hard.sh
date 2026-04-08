#!/usr/bin/env bash
set -euo pipefail

docker compose down -v --remove-orphans

rm -rf data/iceberg data/flink-checkpoints data/spark-checkpoints output

mkdir -p data/iceberg data/flink-checkpoints data/spark-checkpoints output dbt

echo "Hard reset complete: containers, compose volumes, and local state directories removed/recreated."
