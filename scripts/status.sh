#!/usr/bin/env bash
set -euo pipefail

CONNECT_URL="${CONNECT_URL:-http://localhost:8083}"
FLINK_REST_URL="${FLINK_REST_URL:-http://localhost:8081}"
TOPICS=(
  cdc_lab_pg.public.customers
  cdc_lab_pg.public.orders
  cdc_lab_pg.public.payments
  cdc_lab_pg.public.transactions
)

echo "=== Docker services ==="
docker compose ps

echo

echo "=== Kafka topics ==="
for t in "${TOPICS[@]}"; do
  docker compose exec -T kafka /opt/bitnami/kafka/bin/kafka-topics.sh --bootstrap-server kafka:9092 --list | grep -Fx "$t" >/dev/null \
    && echo "[OK] topic exists: $t" || echo "[FAIL] missing topic: $t"
done

echo
echo "=== Connector status ==="
curl -fsS "${CONNECT_URL}/connectors/orders-cdc/status" | python3 -m json.tool

echo
echo "=== Flink jobs overview ==="
curl -fsS "${FLINK_REST_URL}/jobs/overview" | python3 -m json.tool
