#!/usr/bin/env bash
set -euo pipefail

docker compose down -v --remove-orphans

rm -rf data/iceberg data/flink-checkpoints output

mkdir -p data/iceberg data/flink-checkpoints output

echo "Hard reset complete: containers, compose volumes, and local state directories removed/recreated."
