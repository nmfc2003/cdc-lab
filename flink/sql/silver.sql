CREATE CATALOG local_iceberg WITH (
  'type' = 'iceberg',
  'catalog-type' = 'hadoop',
  'warehouse' = 'file:///data/iceberg'
);

CREATE DATABASE IF NOT EXISTS local_iceberg.silver;
SET 'table.dynamic-table-options.enabled' = 'true';

CREATE TABLE IF NOT EXISTS local_iceberg.silver.customers_silver (
  customer_id BIGINT,
  full_name STRING,
  email STRING,
  country STRING,
  created_at TIMESTAMP_LTZ(3),
  updated_at TIMESTAMP_LTZ(3),
  bronze_op STRING,
  bronze_source_ts_ms BIGINT,
  bronze_kafka_event_ts TIMESTAMP_LTZ(3),
  PRIMARY KEY (customer_id) NOT ENFORCED
) WITH (
  'format-version' = '2',
  'write.upsert.enabled' = 'true'
);

CREATE TABLE IF NOT EXISTS local_iceberg.silver.orders_silver (
  order_id BIGINT,
  customer_id BIGINT,
  status STRING,
  amount DECIMAL(12,2),
  created_at TIMESTAMP_LTZ(3),
  updated_at TIMESTAMP_LTZ(3),
  bronze_op STRING,
  bronze_source_ts_ms BIGINT,
  bronze_kafka_event_ts TIMESTAMP_LTZ(3),
  PRIMARY KEY (order_id) NOT ENFORCED
) WITH (
  'format-version' = '2',
  'write.upsert.enabled' = 'true'
);

CREATE TABLE IF NOT EXISTS local_iceberg.silver.payments_silver (
  payment_id BIGINT,
  order_id BIGINT,
  customer_id BIGINT,
  payment_method STRING,
  payment_status STRING,
  amount DECIMAL(12,2),
  created_at TIMESTAMP_LTZ(3),
  updated_at TIMESTAMP_LTZ(3),
  bronze_op STRING,
  bronze_source_ts_ms BIGINT,
  bronze_kafka_event_ts TIMESTAMP_LTZ(3),
  PRIMARY KEY (payment_id) NOT ENFORCED
) WITH (
  'format-version' = '2',
  'write.upsert.enabled' = 'true'
);

CREATE TABLE IF NOT EXISTS local_iceberg.silver.transactions_silver (
  transaction_id BIGINT,
  payment_id BIGINT,
  order_id BIGINT,
  customer_id BIGINT,
  txn_type STRING,
  txn_status STRING,
  amount DECIMAL(12,2),
  created_at TIMESTAMP_LTZ(3),
  updated_at TIMESTAMP_LTZ(3),
  bronze_op STRING,
  bronze_source_ts_ms BIGINT,
  bronze_kafka_event_ts TIMESTAMP_LTZ(3),
  PRIMARY KEY (transaction_id) NOT ENFORCED
) WITH (
  'format-version' = '2',
  'write.upsert.enabled' = 'true'
);

BEGIN STATEMENT SET;
INSERT INTO local_iceberg.silver.customers_silver
SELECT customer_id, full_name, email, country, created_at, updated_at,
       op AS bronze_op, source_ts_ms AS bronze_source_ts_ms, kafka_event_ts AS bronze_kafka_event_ts
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY source_ts_ms DESC, kafka_event_ts DESC) AS rn
  FROM local_iceberg.bronze.customers_bronze /*+ OPTIONS('streaming'='true', 'monitor-interval'='5 s') */
  WHERE customer_id IS NOT NULL
)
WHERE rn = 1 AND op <> 'd';

INSERT INTO local_iceberg.silver.orders_silver
SELECT order_id, customer_id, status, amount, created_at, updated_at,
       op AS bronze_op, source_ts_ms AS bronze_source_ts_ms, kafka_event_ts AS bronze_kafka_event_ts
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY source_ts_ms DESC, kafka_event_ts DESC) AS rn
  FROM local_iceberg.bronze.orders_bronze /*+ OPTIONS('streaming'='true', 'monitor-interval'='5 s') */
  WHERE order_id IS NOT NULL
)
WHERE rn = 1 AND op <> 'd';

INSERT INTO local_iceberg.silver.payments_silver
SELECT payment_id, order_id, customer_id, payment_method, payment_status, amount, created_at, updated_at,
       op AS bronze_op, source_ts_ms AS bronze_source_ts_ms, kafka_event_ts AS bronze_kafka_event_ts
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY payment_id ORDER BY source_ts_ms DESC, kafka_event_ts DESC) AS rn
  FROM local_iceberg.bronze.payments_bronze /*+ OPTIONS('streaming'='true', 'monitor-interval'='5 s') */
  WHERE payment_id IS NOT NULL
)
WHERE rn = 1 AND op <> 'd';

INSERT INTO local_iceberg.silver.transactions_silver
SELECT transaction_id, payment_id, order_id, customer_id, txn_type, txn_status, amount, created_at, updated_at,
       op AS bronze_op, source_ts_ms AS bronze_source_ts_ms, kafka_event_ts AS bronze_kafka_event_ts
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY transaction_id ORDER BY source_ts_ms DESC, kafka_event_ts DESC) AS rn
  FROM local_iceberg.bronze.transactions_bronze /*+ OPTIONS('streaming'='true', 'monitor-interval'='5 s') */
  WHERE transaction_id IS NOT NULL
)
WHERE rn = 1 AND op <> 'd';
END;
