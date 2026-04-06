# Local CDC Lab (PostgreSQL → Debezium → Kafka → Flink → Iceberg)

A deterministic local lab for learning CDC end to end:

1. PostgreSQL emits row changes (logical replication).
2. Debezium in Kafka Connect captures changes into Kafka.
3. Flink reads Kafka values as raw JSON append events.
4. Flink writes append-only bronze rows to Iceberg on local filesystem.

## Stack
- PostgreSQL 16 (logical replication enabled)
- Bitnami Legacy Kafka `4.0.0-debian-12-r10` (single-node KRaft, configurable via `KAFKA_IMAGE`)
- Debezium Connect 2.7.3.Final
- Flink 1.18.1
- Iceberg Flink runtime 1.5.2 (Hadoop catalog on local FS)
- Kafka UI 0.7.2

## Bronze ingestion design (append-only raw events)

Bronze ingestion intentionally does **not** use Debezium changelog semantics in Flink.

Why:
- Bronze here is a raw event log for learning and replay.
- For local reliability, each Kafka message should map to one appended Iceberg row.
- Changelog semantics can introduce retraction/upsert behavior that is unnecessary for bronze and confusing in local labs.

How:
- Kafka source uses `value.format = raw` so every record is read as `raw_json`.
- Flink SQL extracts envelope fields with `JSON_VALUE`.
- Iceberg bronze table has no PK and no merge/delete behavior.
- `c/u/d/r` events are all appended; delete events map using `before` payload values.

## Bronze schema

`local_iceberg.bronze.orders_bronze`
- `kafka_event_ts TIMESTAMP_LTZ(3)`
- `op STRING`
- `order_id BIGINT`
- `customer_id BIGINT`
- `status STRING`
- `amount DECIMAL(12,2)`
- `source_ts_ms BIGINT`
- `raw_json STRING`

## Exact startup sequence

From a clean checkout:

```bash
./scripts/reset_hard.sh
./scripts/up.sh
./scripts/run_flink_sql.sh --replace
./scripts/status.sh
```

## Exact validation sequence (non-interactive)

End-to-end validation does not depend on interactive Flink SQL client sessions.

```bash
./scripts/validate_bronze.sh
```

`validate_bronze.sh` runs all checks and fails loudly if any step fails:
- starts/validates stack health
- ensures Flink bronze INSERT job is running
- inserts one unique Postgres test row
- verifies Kafka topic contains that marker event
- verifies Flink INSERT job is running
- verifies at least one completed checkpoint exists
- verifies Iceberg metadata + parquet files exist
- verifies Iceberg snapshot row count is `> 0`
- verifies Iceberg row count increased after marker insert

## Individual validation commands

```bash
./scripts/insert_test_order.sh
./scripts/check_iceberg_files.sh
./scripts/check_iceberg_rows.sh
./scripts/check_iceberg.sh
./scripts/status.sh
```

## Exact reset sequence

Soft reset (preserve volumes and local state):
```bash
./scripts/reset_soft.sh
```

Hard reset (fully clean state):
```bash
./scripts/reset_hard.sh
```

Hard reset removes:
- containers
- compose volumes
- `./data/iceberg`
- `./data/flink-checkpoints`
- `./output`

## State contract

| Subsystem | Persisted state | Where it lives | Kept by `reset_soft.sh` | Cleared by `reset_hard.sh` |
|---|---|---|---|---|
| PostgreSQL | tables, WAL, replication metadata | compose volume `postgres_data` | Yes | Yes |
| Kafka | topics, messages, consumer groups, Connect internal topics | compose volume `kafka_data` | Yes | Yes |
| Flink | checkpoint state | `./data/flink-checkpoints` bind mount | Yes | Yes |
| Iceberg | warehouse metadata + data files | `./data/iceberg` bind mount | Yes | Yes |
| Local output | JSONL/debug output | `./output` | Yes | Yes |

## Flink lifecycle

Submit bronze pipeline:
```bash
./scripts/run_flink_sql.sh
```

Replace previous bronze INSERT job safely:
```bash
./scripts/run_flink_sql.sh --replace
```

Inspect jobs:
```bash
./scripts/flink_jobs.sh list
```
