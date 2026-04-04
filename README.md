# Local CDC Lab (PostgreSQL → Debezium → Kafka)

A deterministic local lab that captures row-level changes from PostgreSQL and publishes CDC events to Kafka using Debezium.

## Stack
- PostgreSQL 16 (logical replication enabled)
- Bitnami Legacy Kafka `4.0.0-debian-12-r10` (single-node KRaft, configurable via `KAFKA_IMAGE`)
- Debezium Connect 2.7.3.Final
- Kafka UI 0.7.2

## Quickstart

### Optional image pin override
If you want to pin a specific Kafka image tag locally, export `KAFKA_IMAGE` before startup:
```bash
export KAFKA_IMAGE=bitnamilegacy/kafka:<tag>
./scripts/up.sh
```

1. Start the stack:
   ```bash
   ./scripts/up.sh
   ```
2. Verify connector status:
   ```bash
   curl -fsS http://localhost:8083/connectors/orders-cdc/status | jq
   ```
3. Consume CDC topic from the beginning:
   ```bash
   docker compose exec -T kafka /opt/bitnami/kafka/bin/kafka-console-consumer.sh \
     --bootstrap-server kafka:9092 \
     --topic cdc_lab_pg.public.orders \
     --from-beginning \
     --property print.key=true \
     --property key.separator=' | '
   ```
4. Trigger insert/update/delete demo:
   ```bash
   ./scripts/demo-orders-cdc.sh
   ```

## Reset
Hard reset (containers + volumes):
```bash
./scripts/reset.sh
```

## Expected Connector Identifiers
- `topic.prefix=cdc_lab_pg`
- `slot.name=cdc_lab_slot`
- `publication.name=cdc_lab_publication`

## Notes
- Kafka host listener: `localhost:19092`
- Kafka Connect API: `http://localhost:8083`
- Kafka UI: `http://localhost:8080`


> Note: Bitnami moved public Kafka images to `bitnamilegacy/kafka` (legacy/no updates).
