#!/usr/bin/env bash
set -euo pipefail

docker compose down --remove-orphans

echo "Soft reset complete: containers removed, volumes and local state preserved."
