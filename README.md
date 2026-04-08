# Local CDC Lakehouse Lab — Standardized Architecture

## Business Architecture

### Main route (implemented)
`Postgres -> Debezium -> Kafka -> Flink -> Iceberg Bronze -> Flink -> Iceberg Silver`

### Branch 2 (implemented now)
`Silver -> Spark/dbt -> Gold`

### Branch 1 (intentionally deferred)
`Silver -> Flink -> Redis/Kafka`

## Why Silver is the SSOT

Silver is the near-real-time **operational source of truth** in the lakehouse:
- Bronze is immutable/raw and intentionally noisy (duplicates + all CDC ops).
- Silver applies deterministic latest-state semantics by business key.
- Downstream serving and analytics should consume curated Silver state, not raw Bronze.

## Why Redis/Kafka serving branch is deferred

Redis/Kafka serving from Silver is a product-serving concern (cache/query SLA, fanout, invalidation policy).
This repo phase focuses on a robust SSOT core (Bronze + Silver) and an analytics branch (Gold).
Serving branch extension points are preserved in docs/scripts naming, but implementation is deferred intentionally.

## Layer semantics

### Bronze (append-only contract)
- one Kafka CDC message => one Bronze row
- duplicates allowed
- no upserts/deletes in Bronze
- `raw_json` preserved

### Silver (Flink latest-state contract)
- deduplicate by business PK
- latest wins by `source_ts_ms DESC`, `kafka_event_ts DESC`
- if latest event is delete (`op='d'`), row is removed from Silver
- lineage retained: `bronze_op`, `bronze_source_ts_ms`, `bronze_kafka_event_ts`

### Gold (Spark/dbt analytics contract)
- Spark is used for batch SQL execution against Iceberg locally
- dbt defines and tests business marts
- refresh cadence of every few minutes is acceptable

## Deterministic local state

- `./data/iceberg`
- `./data/flink-checkpoints`
- `./data/spark-checkpoints`
- `./output`
- `./dbt`

## Exact run order

```bash
./scripts/reset_hard.sh
./scripts/up.sh
./scripts/start_bronze.sh
./scripts/run_flink_sql.sh flink/sql/silver.sql --allow-concurrent
./scripts/insert_sample_data.sh
./scripts/validate_bronze.sh
./scripts/validate_silver.sh
./scripts/run_dbt_gold.sh
./scripts/validate_gold.sh
```

## Convenience flows

```bash
./scripts/start_silver.sh
./scripts/validate_phase2_flow.sh
```

## Reset

```bash
./scripts/reset_soft.sh
./scripts/reset_hard.sh
```
