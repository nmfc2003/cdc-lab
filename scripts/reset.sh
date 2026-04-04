#!/usr/bin/env bash
set -euo pipefail

docker compose down -v --remove-orphans

echo "Local CDC lab has been hard-reset (containers + volumes removed)."
