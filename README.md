# Local CDC Lakehouse Lab — Phase 2

Postgres -> Debezium -> Kafka -> Flink -> Iceberg Bronze -> Spark Structured Streaming -> Iceberg Silver -> dbt -> Gold marts.

## Architecture (text diagram)

```text
Postgres (customers/orders/payments/transactions)
  -> Debezium Postgres connector
  -> Kafka topics (cdc_lab_pg.public.*)
  -> Flink SQL (raw JSON extraction, append-only)
  -> Iceberg bronze.*_bronze
  -> Spark Structured Streaming (dedup/latest-state merge)
  -> Iceberg silver.*_silver
  -> dbt-spark models/tests
  -> Iceberg gold.*_gold
```

## Semantics

### Bronze
- Append-only by design.
- One Kafka message => one Bronze row.
- No upsert semantics.
- Duplicates preserved.
- `raw_json` preserved for debugging/replay.

### Silver
- Latest-state tables keyed by source PK.
- Dedup ordering: `source_ts_ms DESC`, tie-break `kafka_event_ts DESC`.
- CDC deletes (`op='d'`) are explicitly removed from Silver.
- Lineage retained: `bronze_op`, `bronze_source_ts_ms`, `bronze_kafka_event_ts`.

### Gold (dbt)
- Business marts built from Silver:
  - `customer_order_summary_gold`
  - `order_payment_status_gold`
  - `daily_revenue_gold`
- dbt tests include key not-null/uniqueness checks for gold + silver PK assertions.

## Deterministic local state

- `./data/iceberg`
- `./data/flink-checkpoints`
- `./data/spark-checkpoints`
- `./output`
- `./dbt`

## Commands

### Startup
```bash
./scripts/reset_hard.sh
./scripts/up.sh
```

### Start Bronze ingestion (Flink)
```bash
./scripts/start_bronze.sh
```

### Start Silver streaming (Spark Structured Streaming)
```bash
./scripts/start_silver.sh
```

### Insert sample source data
```bash
./scripts/insert_sample_data.sh
```

### Build Gold marts (dbt)
```bash
./scripts/run_dbt_gold.sh
```

### Validate layers
```bash
./scripts/validate_bronze.sh
./scripts/validate_silver.sh
./scripts/validate_gold.sh
```

### Full Phase 2 validation flow
```bash
./scripts/validate_phase2_flow.sh
```

### Reset
```bash
./scripts/reset_soft.sh
./scripts/reset_hard.sh
```
