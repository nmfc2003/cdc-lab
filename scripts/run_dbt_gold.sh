#!/usr/bin/env bash
set -euo pipefail

docker compose up -d dbt spark >/dev/null

docker compose run --rm dbt bash -lc '
  cd /dbt && \
  dbt build --profiles-dir /dbt --select gold
'
