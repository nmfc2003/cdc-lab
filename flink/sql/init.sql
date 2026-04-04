-- Kafka CDC source (Debezium JSON envelope)
CREATE TABLE IF NOT EXISTS orders_cdc_src (
  `before` ROW<
    id BIGINT,
    customer_id BIGINT,
    status STRING,
    amount STRING
  >,
  `after` ROW<
    id BIGINT,
    customer_id BIGINT,
    status STRING,
    amount STRING
  >,
  op STRING,
  source ROW<
    ts_ms BIGINT
  >
) WITH (
  'connector' = 'kafka',
  'topic' = 'cdc_lab_pg.public.orders',
  'properties.bootstrap.servers' = 'kafka:9092',
  'properties.group.id' = 'flink-orders-bronze',
  'scan.startup.mode' = 'earliest-offset',
  'value.format' = 'debezium-json',
  'value.debezium-json.schema-include' = 'false'
);

-- Iceberg Hadoop catalog on local filesystem
CREATE CATALOG IF NOT EXISTS local_iceberg WITH (
  'type' = 'iceberg',
  'catalog-type' = 'hadoop',
  'warehouse' = 'file:///data/iceberg'
);

USE CATALOG local_iceberg;

-- Bronze sink table
CREATE TABLE IF NOT EXISTS orders_bronze (
  order_id BIGINT,
  customer_id BIGINT,
  status STRING,
  amount STRING,
  op STRING,
  source_ts_ms BIGINT
) WITH (
  'format-version' = '2',
  'location' = 'file:///data/iceberg/orders_bronze'
);

-- Map CDC events to bronze records (after for c/u/r, before for d)
INSERT INTO orders_bronze
SELECT
  CASE WHEN op = 'd' THEN `before`.id ELSE `after`.id END AS order_id,
  CASE WHEN op = 'd' THEN `before`.customer_id ELSE `after`.customer_id END AS customer_id,
  CASE WHEN op = 'd' THEN `before`.status ELSE `after`.status END AS status,
  CASE WHEN op = 'd' THEN `before`.amount ELSE `after`.amount END AS amount,
  op,
  source.ts_ms AS source_ts_ms
FROM orders_cdc_src
WHERE (op IN ('c', 'u', 'r') AND `after` IS NOT NULL)
   OR (op = 'd' AND `before` IS NOT NULL);
