# Local CDC Lab (PostgreSQL → Debezium → Kafka → Flink → Iceberg)

A deterministic local lab for learning CDC end to end:

1. PostgreSQL emits row changes (logical replication)
2. Debezium in Kafka Connect captures changes into Kafka
3. Flink SQL reads Kafka values as raw JSON append events
4. Flink SQL flattens Debezium envelopes into append-only bronze rows in Iceberg

## Stack
- PostgreSQL 16 (logical replication enabled)
- Bitnami Legacy Kafka `4.0.0-debian-12-r10` (single-node KRaft, configurable via `KAFKA_IMAGE`)
- Debezium Connect 2.7.3.Final
- Flink 1.18.1
- Iceberg Flink runtime 1.5.2 (Hadoop catalog on local FS)
- Kafka UI 0.7.2

## Bronze ingestion contract (important)

The bronze table is intentionally **append-only** and does **not** use CDC changelog semantics at the Flink source layer.

Why:
- Debezium emits CDC envelopes intended for downstream stateful upsert/delete consumers.
- Iceberg bronze in this lab is a raw historical event log, so every Kafka message should append one row.
- Treating Debezium as a changelog source can produce zero-data-file commits when updates/deletes are interpreted as retractions instead of append events.

How this lab implements bronze:
- Kafka source uses `value.format = raw` to ingest each message as `raw_json` text.
- SQL manually parses envelope fields (`op`, `before`, `after`, `source.ts_ms`) via `JSON_VALUE`.
- Insert target has no primary key and no merge/upsert/delete behavior.
- Update/delete Debezium events are still appended as bronze rows (using `before` values for `d`).


## State contract (explicit)

| Subsystem | Persisted state | Where it lives | Kept by `reset_soft.sh` | Cleared by `reset_hard.sh` |
|---|---|---|---|---|
| PostgreSQL | tables, WAL, replication metadata | compose volume `postgres_data` | Yes | Yes |
| Kafka | topics, messages, consumer groups, Connect internal topics | compose volume `kafka_data` | Yes | Yes |
| Flink | checkpoint state | `./data/flink-checkpoints` bind mount | Yes | Yes |
| Iceberg | warehouse metadata + data files | `./data/iceberg` bind mount | Yes | Yes |
| Local output | JSONL/debug output | `./output` | Yes | Yes |

Interpretation:
- **soft reset** = stop/remove containers only; keep all persisted state.
- **hard reset** = remove containers + compose volumes + local bind-mounted state directories.

---

## Deterministic flows

### Fresh-start flow (clean lab)
```bash
./scripts/reset_hard.sh
./scripts/up.sh
./scripts/run_flink_sql.sh
./scripts/status.sh
```

### Resume flow (continue existing state)
```bash
./scripts/up.sh
./scripts/run_flink_sql.sh --replace
./scripts/status.sh
python3 scripts/tail-orders.py --mode resume
```

### Replay flow (re-read CDC topic for learning)
Replay uses ephemeral consumer group IDs and `--from-beginning` behavior.
```bash
python3 scripts/orders-to-jsonl.py --mode replay
# or
python3 scripts/tail-orders.py --mode replay
```

---

## Quickstart

### Optional image pin override
If you want to pin a specific Kafka image tag locally, export `KAFKA_IMAGE` before startup:
```bash
export KAFKA_IMAGE=bitnamilegacy/kafka:<tag>
./scripts/up.sh
```

### Start CDC core stack
```bash
./scripts/up.sh
```

### Verify connector status quickly
```bash
curl -fsS http://localhost:8083/connectors/orders-cdc/status | jq
```

### Start Flink + submit SQL pipeline
```bash
./scripts/run_flink_sql.sh
```

If you need to replace a previous running INSERT job:
```bash
./scripts/run_flink_sql.sh --replace
```

### Full-stack doctor/status
```bash
./scripts/status.sh
```
This reports:
- PostgreSQL reachability
- Kafka broker reachability
- `cdc_lab_pg.public.orders` topic existence
- Kafka Connect + connector/task status
- Flink job list
- Latest checkpoint summary for running jobs
- Iceberg warehouse file counts

---

## Reset commands

### Soft reset (preserve all persisted state)
```bash
./scripts/reset_soft.sh
```

### Hard reset (fully deterministic clean slate)
```bash
./scripts/reset_hard.sh
```
Hard reset removes:
- containers
- compose volumes
- `./data/iceberg`
- `./data/flink-checkpoints`
- `./output`

> Backward-compat: `./scripts/reset.sh` now delegates to `reset_hard.sh`.

---

## Kafka consumer semantics (learning-safe)

### Resume mode
Uses a stable consumer group and continues from committed offsets.
```bash
python3 scripts/orders-to-jsonl.py --mode resume
python3 scripts/tail-orders.py --mode resume
```

### Replay mode
Uses an ephemeral consumer group and reads from beginning.
```bash
python3 scripts/orders-to-jsonl.py --mode replay
python3 scripts/tail-orders.py --mode replay
```

---

## Flink SQL lifecycle

### Submit pipeline
```bash
./scripts/run_flink_sql.sh
```
- Verifies CDC stack health first.
- Starts Flink services.
- Refuses to submit if a RUNNING INSERT job already exists.

### Replace existing INSERT pipeline safely
```bash
./scripts/run_flink_sql.sh --replace
```
- Cancels RUNNING INSERT jobs first.
- Re-submits SQL file.

### Inspect Flink jobs
```bash
./scripts/flink_jobs.sh list
```

### Cancel a specific job
```bash
./scripts/flink_jobs.sh cancel <job_id>
```

### Cancel running INSERT job(s)
```bash
./scripts/flink_jobs.sh cancel --insert-running
```

---


### Verify bronze append behavior end-to-end
1. Insert one fresh PostgreSQL row.
   ```bash
   docker compose exec -T postgres psql -U app -d appdb -c "\
   INSERT INTO public.orders (customer_id, status, amount) VALUES (900001, 'NEW', 42.50);"
   ```
2. Verify Kafka received the event.
   ```bash
   docker compose exec -T kafka /opt/bitnami/kafka/bin/kafka-console-consumer.sh \
     --bootstrap-server kafka:9092 \
     --topic cdc_lab_pg.public.orders \
     --from-beginning \
     --timeout-ms 10000 | tail -n 5
   ```
3. Verify Flink checkpoints are completing.
   ```bash
   ./scripts/status.sh
   ```
4. Verify Iceberg data/parquet files exist.
   ```bash
   ./scripts/check_iceberg.sh
   find data/iceberg -type f | rg '\\.parquet$|metadata\\.json$'
   ```
5. Verify bronze row count increases.
   ```bash
   docker compose exec -T flink-jobmanager /opt/flink/bin/sql-client.sh -f /opt/flink/sql/init.sql
   # then in SQL client:
   # SELECT COUNT(*) FROM local_iceberg.bronze.orders_bronze;
   ```

## Manual checks

### Consume CDC topic from beginning (CLI)
```bash
docker compose exec -T kafka /opt/bitnami/kafka/bin/kafka-console-consumer.sh \
  --bootstrap-server kafka:9092 \
  --topic cdc_lab_pg.public.orders \
  --from-beginning \
  --property print.key=true \
  --property key.separator=' | '
```

### Trigger insert/update/delete demo
```bash
./scripts/demo-orders-cdc.sh
```

### Verify Iceberg data
```bash
./scripts/check_iceberg.sh
```

---

## Checkpointing and Iceberg commits
Iceberg streaming commits are checkpoint-driven.

This lab enables periodic checkpoints every 10 seconds and stores state in:
- `file:///data/flink-checkpoints` inside Flink containers
- mapped to `./data/flink-checkpoints` on host

If checkpoints are not completing, committed Iceberg output may lag behind consumed Kafka records.

---

## Endpoints
- Kafka host listener: `localhost:19092`
- Kafka Connect API: `http://localhost:8083`
- Kafka UI: `http://localhost:8080`
- Flink UI: `http://localhost:8081`

---

## Flink dependency pins
- Base image: `flink:1.18.1-scala_2.12-java11`
- Iceberg runtime: `org.apache.iceberg:iceberg-flink-runtime-1.18:1.5.2`
- Kafka SQL connector: `org.apache.flink:flink-sql-connector-kafka:3.1.0-1.18`
- Hadoop support: `org.apache.hadoop:hadoop-client-api:3.3.6`, `org.apache.hadoop:hadoop-client-runtime:3.3.6`, `commons-logging:commons-logging:1.2`

These are pinned in `flink/Dockerfile` for deterministic local builds.
