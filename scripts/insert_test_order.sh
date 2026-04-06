#!/usr/bin/env bash
set -euo pipefail

customer_id="${1:-$((900000000 + $(date +%s)))}"
status="${2:-BRONZE_TEST}"
amount="${3:-42.50}"

sql="INSERT INTO public.orders (customer_id, status, amount) VALUES (${customer_id}, '${status}', ${amount}) RETURNING order_id, customer_id, status, amount, created_at;"

echo "Inserting test row into Postgres orders..."
docker compose exec -T postgres psql -U postgres -d appdb -v ON_ERROR_STOP=1 -At -c "${sql}"

echo "Inserted marker customer_id=${customer_id} status=${status} amount=${amount}"
