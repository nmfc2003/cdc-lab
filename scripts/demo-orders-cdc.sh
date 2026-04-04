#!/usr/bin/env bash
set -euo pipefail

ORDER_ID="${ORDER_ID:-9001}"

docker compose exec -T postgres psql -U postgres -d appdb <<SQL
INSERT INTO public.orders (order_id, customer_id, status, amount)
VALUES (${ORDER_ID}, 101, 'CREATED', 49.99)
ON CONFLICT (order_id) DO NOTHING;

UPDATE public.orders
SET status = 'PAID', amount = 59.99, updated_at = NOW()
WHERE order_id = ${ORDER_ID};

DELETE FROM public.orders
WHERE order_id = ${ORDER_ID};
SQL

echo "Demo mutations complete for order_id=${ORDER_ID}."
echo "Consume with:"
echo "docker compose exec -T kafka /opt/bitnami/kafka/bin/kafka-console-consumer.sh --bootstrap-server kafka:9092 --topic cdc_lab_pg.public.orders --from-beginning --property print.key=true --property key.separator=' | '"
