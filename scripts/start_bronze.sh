#!/usr/bin/env bash
set -euo pipefail

./scripts/up.sh
./scripts/run_flink_sql.sh flink/sql/init.sql --replace
