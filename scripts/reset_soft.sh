#!/usr/bin/env bash
set -euo pipefail

docker compose down --remove-orphans

echo "Soft reset complete: containers stopped/removed; persisted state kept."
