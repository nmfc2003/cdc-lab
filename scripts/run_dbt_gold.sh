#!/usr/bin/env bash
set -euo pipefail

docker compose build dbt >/dev/null

docker compose run --rm dbt bash -lc '
  cd /dbt && \
  dbt build --profiles-dir /dbt --select gold
'
