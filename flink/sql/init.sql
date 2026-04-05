-- Kafka source for bronze: ingest each Kafka value as a raw JSON append event.
-- We intentionally avoid Debezium changelog semantics here so one Kafka message
-- maps to exactly one appended Iceberg row in bronze.
CREATE TABLE IF NOT EXISTS orders_cdc_raw_src (
  raw_json STRING,
  kafka_event_ts_ms TIMESTAMP_LTZ(3) METADATA FROM 'timestamp'
) WITH (
  'connector' = 'kafka',
  'topic' = 'cdc_lab_pg.public.orders',
  'properties.bootstrap.servers' = 'kafka:9092',
  'properties.group.id' = 'flink-orders-bronze',
  'scan.startup.mode' = 'earliest-offset',
  'value.format' = 'raw',
  'value.raw.charset' = 'UTF-8'
);

-- Iceberg Hadoop catalog on local filesystem
CREATE CATALOG local_iceberg WITH (
  'type' = 'iceberg',
  'catalog-type' = 'hadoop',
  'warehouse' = 'file:///data/iceberg'
);

CREATE DATABASE IF NOT EXISTS local_iceberg.bronze;

-- Bronze is append-only by contract.
CREATE TABLE IF NOT EXISTS local_iceberg.bronze.orders_bronze (
  kafka_event_ts_ms TIMESTAMP_LTZ(3),
  op STRING,
  order_id BIGINT,
  customer_id BIGINT,
  status STRING,
  amount STRING,
  source_ts_ms BIGINT,
  raw_json STRING
) WITH (
  'format-version' = '2'
);

INSERT INTO local_iceberg.bronze.orders_bronze
SELECT
  kafka_event_ts_ms AS kafka_event_ts_ms,
  COALESCE(JSON_VALUE(raw_json, '$.payload.op'), JSON_VALUE(raw_json, '$.op')) AS op,
  CAST(
    CASE
      WHEN COALESCE(JSON_VALUE(raw_json, '$.payload.op'), JSON_VALUE(raw_json, '$.op')) = 'd'
        THEN COALESCE(JSON_VALUE(raw_json, '$.payload.before.order_id'), JSON_VALUE(raw_json, '$.before.order_id'))
      ELSE COALESCE(JSON_VALUE(raw_json, '$.payload.after.order_id'), JSON_VALUE(raw_json, '$.after.order_id'))
    END AS BIGINT
  ) AS order_id,
  CAST(
    CASE
      WHEN COALESCE(JSON_VALUE(raw_json, '$.payload.op'), JSON_VALUE(raw_json, '$.op')) = 'd'
        THEN COALESCE(JSON_VALUE(raw_json, '$.payload.before.customer_id'), JSON_VALUE(raw_json, '$.before.customer_id'))
      ELSE COALESCE(JSON_VALUE(raw_json, '$.payload.after.customer_id'), JSON_VALUE(raw_json, '$.after.customer_id'))
    END AS BIGINT
  ) AS customer_id,
  CASE
    WHEN COALESCE(JSON_VALUE(raw_json, '$.payload.op'), JSON_VALUE(raw_json, '$.op')) = 'd'
      THEN COALESCE(JSON_VALUE(raw_json, '$.payload.before.status'), JSON_VALUE(raw_json, '$.before.status'))
    ELSE COALESCE(JSON_VALUE(raw_json, '$.payload.after.status'), JSON_VALUE(raw_json, '$.after.status'))
  END AS status,
  CASE
    WHEN COALESCE(JSON_VALUE(raw_json, '$.payload.op'), JSON_VALUE(raw_json, '$.op')) = 'd'
      THEN COALESCE(JSON_VALUE(raw_json, '$.payload.before.amount'), JSON_VALUE(raw_json, '$.before.amount'))
    ELSE COALESCE(JSON_VALUE(raw_json, '$.payload.after.amount'), JSON_VALUE(raw_json, '$.after.amount'))
  END AS amount,
  CAST(
    COALESCE(JSON_VALUE(raw_json, '$.payload.source.ts_ms'), JSON_VALUE(raw_json, '$.source.ts_ms')) AS BIGINT
  ) AS source_ts_ms,
  raw_json
FROM default_catalog.default_database.orders_cdc_raw_src
WHERE raw_json IS NOT NULL;
