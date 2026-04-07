CREATE CATALOG local_iceberg WITH (
  'type' = 'iceberg',
  'catalog-type' = 'hadoop',
  'warehouse' = 'file:///data/iceberg'
);

CREATE DATABASE IF NOT EXISTS local_iceberg.bronze;

CREATE TABLE IF NOT EXISTS customers_cdc_raw_src (
  raw_json STRING,
  kafka_event_ts TIMESTAMP_LTZ(3) METADATA FROM 'timestamp'
) WITH (
  'connector' = 'kafka',
  'topic' = 'cdc_lab_pg.public.customers',
  'properties.bootstrap.servers' = 'kafka:9092',
  'properties.group.id' = 'flink-customers-bronze',
  'scan.startup.mode' = 'earliest-offset',
  'value.format' = 'raw',
  'value.raw.charset' = 'UTF-8'
);

CREATE TABLE IF NOT EXISTS orders_cdc_raw_src (
  raw_json STRING,
  kafka_event_ts TIMESTAMP_LTZ(3) METADATA FROM 'timestamp'
) WITH (
  'connector' = 'kafka',
  'topic' = 'cdc_lab_pg.public.orders',
  'properties.bootstrap.servers' = 'kafka:9092',
  'properties.group.id' = 'flink-orders-bronze',
  'scan.startup.mode' = 'earliest-offset',
  'value.format' = 'raw',
  'value.raw.charset' = 'UTF-8'
);

CREATE TABLE IF NOT EXISTS payments_cdc_raw_src (
  raw_json STRING,
  kafka_event_ts TIMESTAMP_LTZ(3) METADATA FROM 'timestamp'
) WITH (
  'connector' = 'kafka',
  'topic' = 'cdc_lab_pg.public.payments',
  'properties.bootstrap.servers' = 'kafka:9092',
  'properties.group.id' = 'flink-payments-bronze',
  'scan.startup.mode' = 'earliest-offset',
  'value.format' = 'raw',
  'value.raw.charset' = 'UTF-8'
);

CREATE TABLE IF NOT EXISTS transactions_cdc_raw_src (
  raw_json STRING,
  kafka_event_ts TIMESTAMP_LTZ(3) METADATA FROM 'timestamp'
) WITH (
  'connector' = 'kafka',
  'topic' = 'cdc_lab_pg.public.transactions',
  'properties.bootstrap.servers' = 'kafka:9092',
  'properties.group.id' = 'flink-transactions-bronze',
  'scan.startup.mode' = 'earliest-offset',
  'value.format' = 'raw',
  'value.raw.charset' = 'UTF-8'
);

CREATE TABLE IF NOT EXISTS local_iceberg.bronze.customers_bronze (
  kafka_event_ts TIMESTAMP_LTZ(3),
  op STRING,
  customer_id BIGINT,
  full_name STRING,
  email STRING,
  country STRING,
  created_at TIMESTAMP_LTZ(3),
  updated_at TIMESTAMP_LTZ(3),
  source_ts_ms BIGINT,
  raw_json STRING
) WITH ('format-version' = '2');

CREATE TABLE IF NOT EXISTS local_iceberg.bronze.orders_bronze (
  kafka_event_ts TIMESTAMP_LTZ(3),
  op STRING,
  order_id BIGINT,
  customer_id BIGINT,
  status STRING,
  amount DECIMAL(12,2),
  created_at TIMESTAMP_LTZ(3),
  updated_at TIMESTAMP_LTZ(3),
  source_ts_ms BIGINT,
  raw_json STRING
) WITH ('format-version' = '2');

CREATE TABLE IF NOT EXISTS local_iceberg.bronze.payments_bronze (
  kafka_event_ts TIMESTAMP_LTZ(3),
  op STRING,
  payment_id BIGINT,
  order_id BIGINT,
  customer_id BIGINT,
  payment_method STRING,
  payment_status STRING,
  amount DECIMAL(12,2),
  created_at TIMESTAMP_LTZ(3),
  updated_at TIMESTAMP_LTZ(3),
  source_ts_ms BIGINT,
  raw_json STRING
) WITH ('format-version' = '2');

CREATE TABLE IF NOT EXISTS local_iceberg.bronze.transactions_bronze (
  kafka_event_ts TIMESTAMP_LTZ(3),
  op STRING,
  transaction_id BIGINT,
  payment_id BIGINT,
  order_id BIGINT,
  customer_id BIGINT,
  txn_type STRING,
  txn_status STRING,
  amount DECIMAL(12,2),
  created_at TIMESTAMP_LTZ(3),
  updated_at TIMESTAMP_LTZ(3),
  source_ts_ms BIGINT,
  raw_json STRING
) WITH ('format-version' = '2');

BEGIN STATEMENT SET;
INSERT INTO local_iceberg.bronze.customers_bronze
SELECT kafka_event_ts,
  COALESCE(JSON_VALUE(raw_json, '$.payload.op'), JSON_VALUE(raw_json, '$.op')) AS op,
  CAST(CASE WHEN COALESCE(JSON_VALUE(raw_json, '$.payload.op'), JSON_VALUE(raw_json, '$.op'))='d' THEN COALESCE(JSON_VALUE(raw_json, '$.payload.before.customer_id'), JSON_VALUE(raw_json, '$.before.customer_id')) ELSE COALESCE(JSON_VALUE(raw_json, '$.payload.after.customer_id'), JSON_VALUE(raw_json, '$.after.customer_id')) END AS BIGINT),
  CASE WHEN COALESCE(JSON_VALUE(raw_json, '$.payload.op'), JSON_VALUE(raw_json, '$.op'))='d' THEN COALESCE(JSON_VALUE(raw_json, '$.payload.before.full_name'), JSON_VALUE(raw_json, '$.before.full_name')) ELSE COALESCE(JSON_VALUE(raw_json, '$.payload.after.full_name'), JSON_VALUE(raw_json, '$.after.full_name')) END,
  CASE WHEN COALESCE(JSON_VALUE(raw_json, '$.payload.op'), JSON_VALUE(raw_json, '$.op'))='d' THEN COALESCE(JSON_VALUE(raw_json, '$.payload.before.email'), JSON_VALUE(raw_json, '$.before.email')) ELSE COALESCE(JSON_VALUE(raw_json, '$.payload.after.email'), JSON_VALUE(raw_json, '$.after.email')) END,
  CASE WHEN COALESCE(JSON_VALUE(raw_json, '$.payload.op'), JSON_VALUE(raw_json, '$.op'))='d' THEN COALESCE(JSON_VALUE(raw_json, '$.payload.before.country'), JSON_VALUE(raw_json, '$.before.country')) ELSE COALESCE(JSON_VALUE(raw_json, '$.payload.after.country'), JSON_VALUE(raw_json, '$.after.country')) END,
  CAST(CASE WHEN COALESCE(JSON_VALUE(raw_json, '$.payload.op'), JSON_VALUE(raw_json, '$.op'))='d' THEN COALESCE(JSON_VALUE(raw_json, '$.payload.before.created_at'), JSON_VALUE(raw_json, '$.before.created_at')) ELSE COALESCE(JSON_VALUE(raw_json, '$.payload.after.created_at'), JSON_VALUE(raw_json, '$.after.created_at')) END AS TIMESTAMP_LTZ(3)),
  CAST(CASE WHEN COALESCE(JSON_VALUE(raw_json, '$.payload.op'), JSON_VALUE(raw_json, '$.op'))='d' THEN COALESCE(JSON_VALUE(raw_json, '$.payload.before.updated_at'), JSON_VALUE(raw_json, '$.before.updated_at')) ELSE COALESCE(JSON_VALUE(raw_json, '$.payload.after.updated_at'), JSON_VALUE(raw_json, '$.after.updated_at')) END AS TIMESTAMP_LTZ(3)),
  CAST(COALESCE(JSON_VALUE(raw_json, '$.payload.source.ts_ms'), JSON_VALUE(raw_json, '$.source.ts_ms')) AS BIGINT),
  raw_json
FROM customers_cdc_raw_src WHERE raw_json IS NOT NULL;

INSERT INTO local_iceberg.bronze.orders_bronze
SELECT kafka_event_ts,
  COALESCE(JSON_VALUE(raw_json, '$.payload.op'), JSON_VALUE(raw_json, '$.op')) AS op,
  CAST(CASE WHEN COALESCE(JSON_VALUE(raw_json, '$.payload.op'), JSON_VALUE(raw_json, '$.op'))='d' THEN COALESCE(JSON_VALUE(raw_json, '$.payload.before.order_id'), JSON_VALUE(raw_json, '$.before.order_id')) ELSE COALESCE(JSON_VALUE(raw_json, '$.payload.after.order_id'), JSON_VALUE(raw_json, '$.after.order_id')) END AS BIGINT),
  CAST(CASE WHEN COALESCE(JSON_VALUE(raw_json, '$.payload.op'), JSON_VALUE(raw_json, '$.op'))='d' THEN COALESCE(JSON_VALUE(raw_json, '$.payload.before.customer_id'), JSON_VALUE(raw_json, '$.before.customer_id')) ELSE COALESCE(JSON_VALUE(raw_json, '$.payload.after.customer_id'), JSON_VALUE(raw_json, '$.after.customer_id')) END AS BIGINT),
  CASE WHEN COALESCE(JSON_VALUE(raw_json, '$.payload.op'), JSON_VALUE(raw_json, '$.op'))='d' THEN COALESCE(JSON_VALUE(raw_json, '$.payload.before.status'), JSON_VALUE(raw_json, '$.before.status')) ELSE COALESCE(JSON_VALUE(raw_json, '$.payload.after.status'), JSON_VALUE(raw_json, '$.after.status')) END,
  CAST(CASE WHEN COALESCE(JSON_VALUE(raw_json, '$.payload.op'), JSON_VALUE(raw_json, '$.op'))='d' THEN COALESCE(JSON_VALUE(raw_json, '$.payload.before.amount'), JSON_VALUE(raw_json, '$.before.amount')) ELSE COALESCE(JSON_VALUE(raw_json, '$.payload.after.amount'), JSON_VALUE(raw_json, '$.after.amount')) END AS DECIMAL(12,2)),
  CAST(CASE WHEN COALESCE(JSON_VALUE(raw_json, '$.payload.op'), JSON_VALUE(raw_json, '$.op'))='d' THEN COALESCE(JSON_VALUE(raw_json, '$.payload.before.created_at'), JSON_VALUE(raw_json, '$.before.created_at')) ELSE COALESCE(JSON_VALUE(raw_json, '$.payload.after.created_at'), JSON_VALUE(raw_json, '$.after.created_at')) END AS TIMESTAMP_LTZ(3)),
  CAST(CASE WHEN COALESCE(JSON_VALUE(raw_json, '$.payload.op'), JSON_VALUE(raw_json, '$.op'))='d' THEN COALESCE(JSON_VALUE(raw_json, '$.payload.before.updated_at'), JSON_VALUE(raw_json, '$.before.updated_at')) ELSE COALESCE(JSON_VALUE(raw_json, '$.payload.after.updated_at'), JSON_VALUE(raw_json, '$.after.updated_at')) END AS TIMESTAMP_LTZ(3)),
  CAST(COALESCE(JSON_VALUE(raw_json, '$.payload.source.ts_ms'), JSON_VALUE(raw_json, '$.source.ts_ms')) AS BIGINT),
  raw_json
FROM orders_cdc_raw_src WHERE raw_json IS NOT NULL;

INSERT INTO local_iceberg.bronze.payments_bronze
SELECT kafka_event_ts,
  COALESCE(JSON_VALUE(raw_json, '$.payload.op'), JSON_VALUE(raw_json, '$.op')) AS op,
  CAST(CASE WHEN COALESCE(JSON_VALUE(raw_json, '$.payload.op'), JSON_VALUE(raw_json, '$.op'))='d' THEN COALESCE(JSON_VALUE(raw_json, '$.payload.before.payment_id'), JSON_VALUE(raw_json, '$.before.payment_id')) ELSE COALESCE(JSON_VALUE(raw_json, '$.payload.after.payment_id'), JSON_VALUE(raw_json, '$.after.payment_id')) END AS BIGINT),
  CAST(CASE WHEN COALESCE(JSON_VALUE(raw_json, '$.payload.op'), JSON_VALUE(raw_json, '$.op'))='d' THEN COALESCE(JSON_VALUE(raw_json, '$.payload.before.order_id'), JSON_VALUE(raw_json, '$.before.order_id')) ELSE COALESCE(JSON_VALUE(raw_json, '$.payload.after.order_id'), JSON_VALUE(raw_json, '$.after.order_id')) END AS BIGINT),
  CAST(CASE WHEN COALESCE(JSON_VALUE(raw_json, '$.payload.op'), JSON_VALUE(raw_json, '$.op'))='d' THEN COALESCE(JSON_VALUE(raw_json, '$.payload.before.customer_id'), JSON_VALUE(raw_json, '$.before.customer_id')) ELSE COALESCE(JSON_VALUE(raw_json, '$.payload.after.customer_id'), JSON_VALUE(raw_json, '$.after.customer_id')) END AS BIGINT),
  CASE WHEN COALESCE(JSON_VALUE(raw_json, '$.payload.op'), JSON_VALUE(raw_json, '$.op'))='d' THEN COALESCE(JSON_VALUE(raw_json, '$.payload.before.payment_method'), JSON_VALUE(raw_json, '$.before.payment_method')) ELSE COALESCE(JSON_VALUE(raw_json, '$.payload.after.payment_method'), JSON_VALUE(raw_json, '$.after.payment_method')) END,
  CASE WHEN COALESCE(JSON_VALUE(raw_json, '$.payload.op'), JSON_VALUE(raw_json, '$.op'))='d' THEN COALESCE(JSON_VALUE(raw_json, '$.payload.before.payment_status'), JSON_VALUE(raw_json, '$.before.payment_status')) ELSE COALESCE(JSON_VALUE(raw_json, '$.payload.after.payment_status'), JSON_VALUE(raw_json, '$.after.payment_status')) END,
  CAST(CASE WHEN COALESCE(JSON_VALUE(raw_json, '$.payload.op'), JSON_VALUE(raw_json, '$.op'))='d' THEN COALESCE(JSON_VALUE(raw_json, '$.payload.before.amount'), JSON_VALUE(raw_json, '$.before.amount')) ELSE COALESCE(JSON_VALUE(raw_json, '$.payload.after.amount'), JSON_VALUE(raw_json, '$.after.amount')) END AS DECIMAL(12,2)),
  CAST(CASE WHEN COALESCE(JSON_VALUE(raw_json, '$.payload.op'), JSON_VALUE(raw_json, '$.op'))='d' THEN COALESCE(JSON_VALUE(raw_json, '$.payload.before.created_at'), JSON_VALUE(raw_json, '$.before.created_at')) ELSE COALESCE(JSON_VALUE(raw_json, '$.payload.after.created_at'), JSON_VALUE(raw_json, '$.after.created_at')) END AS TIMESTAMP_LTZ(3)),
  CAST(CASE WHEN COALESCE(JSON_VALUE(raw_json, '$.payload.op'), JSON_VALUE(raw_json, '$.op'))='d' THEN COALESCE(JSON_VALUE(raw_json, '$.payload.before.updated_at'), JSON_VALUE(raw_json, '$.before.updated_at')) ELSE COALESCE(JSON_VALUE(raw_json, '$.payload.after.updated_at'), JSON_VALUE(raw_json, '$.after.updated_at')) END AS TIMESTAMP_LTZ(3)),
  CAST(COALESCE(JSON_VALUE(raw_json, '$.payload.source.ts_ms'), JSON_VALUE(raw_json, '$.source.ts_ms')) AS BIGINT),
  raw_json
FROM payments_cdc_raw_src WHERE raw_json IS NOT NULL;

INSERT INTO local_iceberg.bronze.transactions_bronze
SELECT kafka_event_ts,
  COALESCE(JSON_VALUE(raw_json, '$.payload.op'), JSON_VALUE(raw_json, '$.op')) AS op,
  CAST(CASE WHEN COALESCE(JSON_VALUE(raw_json, '$.payload.op'), JSON_VALUE(raw_json, '$.op'))='d' THEN COALESCE(JSON_VALUE(raw_json, '$.payload.before.transaction_id'), JSON_VALUE(raw_json, '$.before.transaction_id')) ELSE COALESCE(JSON_VALUE(raw_json, '$.payload.after.transaction_id'), JSON_VALUE(raw_json, '$.after.transaction_id')) END AS BIGINT),
  CAST(CASE WHEN COALESCE(JSON_VALUE(raw_json, '$.payload.op'), JSON_VALUE(raw_json, '$.op'))='d' THEN COALESCE(JSON_VALUE(raw_json, '$.payload.before.payment_id'), JSON_VALUE(raw_json, '$.before.payment_id')) ELSE COALESCE(JSON_VALUE(raw_json, '$.payload.after.payment_id'), JSON_VALUE(raw_json, '$.after.payment_id')) END AS BIGINT),
  CAST(CASE WHEN COALESCE(JSON_VALUE(raw_json, '$.payload.op'), JSON_VALUE(raw_json, '$.op'))='d' THEN COALESCE(JSON_VALUE(raw_json, '$.payload.before.order_id'), JSON_VALUE(raw_json, '$.before.order_id')) ELSE COALESCE(JSON_VALUE(raw_json, '$.payload.after.order_id'), JSON_VALUE(raw_json, '$.after.order_id')) END AS BIGINT),
  CAST(CASE WHEN COALESCE(JSON_VALUE(raw_json, '$.payload.op'), JSON_VALUE(raw_json, '$.op'))='d' THEN COALESCE(JSON_VALUE(raw_json, '$.payload.before.customer_id'), JSON_VALUE(raw_json, '$.before.customer_id')) ELSE COALESCE(JSON_VALUE(raw_json, '$.payload.after.customer_id'), JSON_VALUE(raw_json, '$.after.customer_id')) END AS BIGINT),
  CASE WHEN COALESCE(JSON_VALUE(raw_json, '$.payload.op'), JSON_VALUE(raw_json, '$.op'))='d' THEN COALESCE(JSON_VALUE(raw_json, '$.payload.before.txn_type'), JSON_VALUE(raw_json, '$.before.txn_type')) ELSE COALESCE(JSON_VALUE(raw_json, '$.payload.after.txn_type'), JSON_VALUE(raw_json, '$.after.txn_type')) END,
  CASE WHEN COALESCE(JSON_VALUE(raw_json, '$.payload.op'), JSON_VALUE(raw_json, '$.op'))='d' THEN COALESCE(JSON_VALUE(raw_json, '$.payload.before.txn_status'), JSON_VALUE(raw_json, '$.before.txn_status')) ELSE COALESCE(JSON_VALUE(raw_json, '$.payload.after.txn_status'), JSON_VALUE(raw_json, '$.after.txn_status')) END,
  CAST(CASE WHEN COALESCE(JSON_VALUE(raw_json, '$.payload.op'), JSON_VALUE(raw_json, '$.op'))='d' THEN COALESCE(JSON_VALUE(raw_json, '$.payload.before.amount'), JSON_VALUE(raw_json, '$.before.amount')) ELSE COALESCE(JSON_VALUE(raw_json, '$.payload.after.amount'), JSON_VALUE(raw_json, '$.after.amount')) END AS DECIMAL(12,2)),
  CAST(CASE WHEN COALESCE(JSON_VALUE(raw_json, '$.payload.op'), JSON_VALUE(raw_json, '$.op'))='d' THEN COALESCE(JSON_VALUE(raw_json, '$.payload.before.created_at'), JSON_VALUE(raw_json, '$.before.created_at')) ELSE COALESCE(JSON_VALUE(raw_json, '$.payload.after.created_at'), JSON_VALUE(raw_json, '$.after.created_at')) END AS TIMESTAMP_LTZ(3)),
  CAST(CASE WHEN COALESCE(JSON_VALUE(raw_json, '$.payload.op'), JSON_VALUE(raw_json, '$.op'))='d' THEN COALESCE(JSON_VALUE(raw_json, '$.payload.before.updated_at'), JSON_VALUE(raw_json, '$.before.updated_at')) ELSE COALESCE(JSON_VALUE(raw_json, '$.payload.after.updated_at'), JSON_VALUE(raw_json, '$.after.updated_at')) END AS TIMESTAMP_LTZ(3)),
  CAST(COALESCE(JSON_VALUE(raw_json, '$.payload.source.ts_ms'), JSON_VALUE(raw_json, '$.source.ts_ms')) AS BIGINT),
  raw_json
FROM transactions_cdc_raw_src WHERE raw_json IS NOT NULL;
END;
