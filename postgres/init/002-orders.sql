CREATE TABLE IF NOT EXISTS public.customers (
  customer_id BIGINT PRIMARY KEY,
  full_name TEXT NOT NULL,
  email TEXT NOT NULL,
  country TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.orders (
  order_id BIGINT PRIMARY KEY,
  customer_id BIGINT NOT NULL REFERENCES public.customers(customer_id),
  status TEXT NOT NULL,
  amount NUMERIC(12,2) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.payments (
  payment_id BIGINT PRIMARY KEY,
  order_id BIGINT NOT NULL REFERENCES public.orders(order_id),
  customer_id BIGINT NOT NULL REFERENCES public.customers(customer_id),
  payment_method TEXT NOT NULL,
  payment_status TEXT NOT NULL,
  amount NUMERIC(12,2) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.transactions (
  transaction_id BIGINT PRIMARY KEY,
  payment_id BIGINT NOT NULL REFERENCES public.payments(payment_id),
  order_id BIGINT NOT NULL REFERENCES public.orders(order_id),
  customer_id BIGINT NOT NULL REFERENCES public.customers(customer_id),
  txn_type TEXT NOT NULL,
  txn_status TEXT NOT NULL,
  amount NUMERIC(12,2) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.customers REPLICA IDENTITY FULL;
ALTER TABLE public.orders REPLICA IDENTITY FULL;
ALTER TABLE public.payments REPLICA IDENTITY FULL;
ALTER TABLE public.transactions REPLICA IDENTITY FULL;

GRANT USAGE ON SCHEMA public TO debezium;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO debezium;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO debezium;

DROP PUBLICATION IF EXISTS cdc_lab_publication;
CREATE PUBLICATION cdc_lab_publication
FOR TABLE public.customers, public.orders, public.payments, public.transactions;
