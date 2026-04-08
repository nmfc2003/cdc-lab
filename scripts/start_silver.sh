#!/usr/bin/env bash
set -euo pipefail

./scripts/up.sh
./scripts/start_bronze.sh
./scripts/run_flink_sql.sh flink/sql/silver.sql --allow-concurrent

echo "Silver Flink SQL job submitted (running concurrently with Bronze job)."
