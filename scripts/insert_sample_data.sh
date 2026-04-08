#!/usr/bin/env bash
set -euo pipefail

docker compose exec -T postgres psql -U postgres -d appdb -v ON_ERROR_STOP=1 <<'SQL'
INSERT INTO public.customers (customer_id, full_name, email, country)
VALUES
  (1001, 'Alice Smith', 'alice@example.com', 'US'),
  (1002, 'Bob Chen', 'bob@example.com', 'CA')
ON CONFLICT (customer_id) DO UPDATE SET
  full_name = EXCLUDED.full_name,
  email = EXCLUDED.email,
  country = EXCLUDED.country,
  updated_at = NOW();

INSERT INTO public.orders (order_id, customer_id, status, amount)
VALUES
  (2001, 1001, 'CREATED', 120.50),
  (2002, 1002, 'SHIPPED', 80.00)
ON CONFLICT (order_id) DO UPDATE SET
  customer_id = EXCLUDED.customer_id,
  status = EXCLUDED.status,
  amount = EXCLUDED.amount,
  updated_at = NOW();

INSERT INTO public.payments (payment_id, order_id, customer_id, payment_method, payment_status, amount)
VALUES
  (3001, 2001, 1001, 'CARD', 'PAID', 120.50),
  (3002, 2002, 1002, 'WALLET', 'PENDING', 80.00)
ON CONFLICT (payment_id) DO UPDATE SET
  order_id = EXCLUDED.order_id,
  customer_id = EXCLUDED.customer_id,
  payment_method = EXCLUDED.payment_method,
  payment_status = EXCLUDED.payment_status,
  amount = EXCLUDED.amount,
  updated_at = NOW();

INSERT INTO public.transactions (transaction_id, payment_id, order_id, customer_id, txn_type, txn_status, amount)
VALUES
  (4001, 3001, 2001, 1001, 'CAPTURE', 'SUCCESS', 120.50),
  (4002, 3002, 2002, 1002, 'AUTH', 'PENDING', 80.00)
ON CONFLICT (transaction_id) DO UPDATE SET
  payment_id = EXCLUDED.payment_id,
  order_id = EXCLUDED.order_id,
  customer_id = EXCLUDED.customer_id,
  txn_type = EXCLUDED.txn_type,
  txn_status = EXCLUDED.txn_status,
  amount = EXCLUDED.amount,
  updated_at = NOW();
SQL

echo "Inserted/updated sample customers, orders, payments, transactions."
