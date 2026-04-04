#!/usr/bin/env bash
set -euo pipefail

docker compose exec -T postgres psql -v ON_ERROR_STOP=1 -U postgres -d appdb <<'SQL'
INSERT INTO public.orders (customer_id, status, amount)
VALUES (101, 'CREATED', 49.99)
RETURNING order_id \gset

UPDATE public.orders
SET status = 'PAID', amount = 59.99, updated_at = NOW()
WHERE order_id = :order_id;

DELETE FROM public.orders
WHERE order_id = :order_id;

\echo Demo mutations complete for order_id=:order_id.
SQL

echo "Consume with:"
echo "docker compose exec -T kafka /opt/bitnami/kafka/bin/kafka-console-consumer.sh --bootstrap-server kafka:9092 --topic cdc_lab_pg.public.orders --from-beginning --property print.key=true --property key.separator=' | '"
