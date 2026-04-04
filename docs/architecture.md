# Architecture: Local CDC Lab (Postgres → Debezium → Kafka)

## Purpose
This document defines the target system design for a **local-only** CDC lab on **Mac + Docker** based on the product requirements in `docs/prd.md`.

The design emphasizes:
- Minimal local footprint.
- Deterministic startup and demo behavior.
- Production-sensible patterns (clear boundaries, explicit contracts, controlled failure handling) without production complexity.

---

## Scope and Design Constraints
- Runs only on a local Mac using Docker Desktop.
- Uses Docker Compose as the orchestration boundary.
- Single-node Kafka in KRaft mode (no ZooKeeper).
- Single Kafka Connect worker with Debezium PostgreSQL connector.
- Single PostgreSQL instance configured for logical replication.
- Includes Kafka UI for observability and demo usability.
- No cloud dependencies, no HA, no scaling/elasticity in v1.

---

## High-Level System Context

### Data Flow
1. Application or SQL client mutates rows in `public.orders` within PostgreSQL.
2. PostgreSQL logical replication stream is read by Debezium PostgreSQL connector running in Kafka Connect.
3. Connector publishes CDC events to Kafka topic `cdc_lab_pg.public.orders`.
4. Kafka UI and CLI consumers read events for verification and demo.

### Logical Components
- **Source database:** PostgreSQL (logical replication enabled).
- **Streaming backbone:** Kafka broker (KRaft mode).
- **CDC ingestion:** Kafka Connect + Debezium PostgreSQL source connector.
- **Observation layer:** Kafka UI and local command-line consumers.

---

## Proposed Repository Structure

```text
.
├─ docs/
│  ├─ prd.md
│  ├─ architecture.md
│  └─ decisions.md
├─ compose/
│  ├─ docker-compose.yml
│  ├─ env/
│  │  └─ local.env
│  └─ init/
│     ├─ postgres/
│     │  ├─ 001-schema.sql
│     │  └─ 002-seed.sql
│     └─ connect/
│        └─ connector-orders.json
├─ scripts/
│  ├─ up.sh
│  ├─ wait-for-health.sh
│  ├─ register-connector.sh
│  └─ demo-orders-cdc.sh
└─ README.md
```

### Structure Rationale
- `docs/` separates product, architecture, and decision records.
- `compose/` isolates runtime artifacts and environment parameters.
- `init/` stores deterministic bootstrap assets for schema and connector registration.
- `scripts/` keeps repetitive operator/demo commands reproducible.

---

## Implemented Repository Structure

```text
.
├─ docker-compose.yml
├─ docs/
│  ├─ prd.md
│  ├─ architecture.md
│  └─ decisions.md
├─ connect/
│  ├─ connect.env
│  └─ debezium-orders-connector.json
├─ postgres/init/
│  ├─ 001-users.sql
│  └─ 002-orders.sql
└─ scripts/
   ├─ up.sh
   ├─ wait-for-health.sh
   ├─ demo-orders-cdc.sh
   └─ reset.sh
```

This repository currently keeps runtime artifacts at the repository root (instead of a `compose/` folder) to keep local commands concise for first-time users.

---

## Docker Services Design

## 1) `postgres`
### Role
System of record and CDC source.

### Required Characteristics
- PostgreSQL image version pinned.
- Logical replication enabled (`wal_level=logical`).
- Replication settings explicitly include:
  - `max_replication_slots` >= 1 (supports `cdc_lab_slot`).
  - `max_wal_senders` >= 1 (supports logical stream sender).
- Debezium-compatible publication and slot strategy:
  - Publication name fixed as `cdc_lab_publication`.
  - Replication slot name fixed as `cdc_lab_slot`.
- Durable local volume for data persistence between restarts.
- Init SQL creates `public.orders` table and replication permissions as needed.

### Data Contracts
- Source table: `public.orders`.
- Primary key required for stable CDC keying.

---

## 2) `kafka` (KRaft mode)
### Role
Event broker for CDC topics.

### Required Characteristics
- Single-node KRaft deployment (controller + broker combined for local simplicity).
- Bitnami Kafka distribution (aligned with PRD).
- Internal and external listeners configured for:
  - Inter-container communication.
  - Local host access from Mac terminal.
- Listener model is explicitly split as:
  - **Internal listener** (container network): `PLAINTEXT://kafka:9092` used by `kafka-connect` and `kafka-ui`.
  - **External listener** (host access): `PLAINTEXT_HOST://localhost:19092` used by local Mac CLI tools.
- `advertised.listeners` must advertise both endpoints so each client class resolves the correct address.
- `listener.security.protocol.map` must include mappings for both listener names and `inter.broker.listener.name` must point to the internal listener.
- Persistent volume for broker state/logs.

### Topic Baseline
- CDC topic of interest: `cdc_lab_pg.public.orders`.
- Internal Kafka Connect topics provisioned with compaction and deterministic names.

---

## 3) `kafka-connect` (Debezium)
### Role
Runs Debezium PostgreSQL source connector and streams changes into Kafka.

### Required Characteristics
- Debezium Connect image pinned.
- Single worker mode.
- Connect internal topics explicitly configured (config/offset/status).
- Internal topic names must be explicit and stable:
  - `connect-configs`
  - `connect-offsets`
  - `connect-status`
- Internal topic requirements:
  - Must exist on Kafka before or at worker startup.
  - Must use `cleanup.policy=compact` for config and status topics.
  - Offsets topic should use high partition count relative to local scale (minimal acceptable default documented for v1 implementation).
  - Replication factor is `1` for local single-broker operation.
- REST API exposed for connector lifecycle operations.

### Connector Configuration Strategy (Orders CDC)
- Connector class: Debezium PostgreSQL source connector.
- Required identifiers (fixed):
  - `database.server.name=cdc_lab_pg`
  - `slot.name=cdc_lab_slot`
  - `publication.name=cdc_lab_publication`
- Capture scope limited to `public.orders` in v1 for deterministic demos.
- Serialization kept JSON-focused for readability in local demos.
- Delete semantics surfaced with Debezium `op` contract (`c/u/d`), with tombstone handling policy documented in `docs/decisions.md`.

---

## 4) `kafka-ui`
### Role
Human-friendly inspection of cluster health, topics, and messages.

### Required Characteristics
- Connected to local Kafka broker via container network.
- Used for demo visibility and rapid troubleshooting.
- Not a source of truth for operational health; supplements API/CLI checks.

---

## Service Networking

## Compose Network Model
- Single user-defined bridge network (e.g., `cdc_net`) for all services.
- Service-to-service communication uses container DNS names:
  - `postgres`
  - `kafka`
  - `kafka-connect`
  - `kafka-ui`

## Port Exposure Strategy
- Expose only necessary ports to host Mac:
  - PostgreSQL client port.
  - Kafka external listener port.
  - Kafka Connect REST port.
  - Kafka UI web port.
- Keep internal-only ports unexposed to reduce local conflict surface.

## Connectivity Expectations
- `kafka-connect` must resolve and reach both `postgres` and `kafka` over the bridge network.
- Host terminal tools must reach Kafka external listener and Connect REST endpoint.

---

## Topic Naming and Message Contract

## Topic Naming
- Debezium topic naming convention:
  - `<database.server.name>.<schema>.<table>`
- With fixed server name and `public.orders`, expected topic is:
  - `cdc_lab_pg.public.orders`

## Message Contract (Minimum)
- **Key**: primary key of `orders` row.
- **Value envelope** includes:
  - `before`
  - `after`
  - `op`
- **Operation mapping**:
  - `c` = insert
  - `u` = update
  - `d` = delete

## Consumer Behavior for Demo
- Consume from beginning of topic to ensure deterministic replay.
- Display keys and values to correlate row identity with mutation lifecycle.

---

## Startup Sequence (Deterministic)
1. Start `kafka` in KRaft mode; wait for broker readiness.
2. Start `postgres`; wait for SQL readiness and completion of schema initialization.
3. Start `kafka-connect`; verify worker REST health.
4. Register Debezium PostgreSQL connector with fixed identifiers.
   - Registration timing: only after Connect worker health is green and Postgres replication prerequisites are confirmed.
   - Registration method: Kafka Connect REST `POST /connectors` for first create; `PUT /connectors/{name}/config` for idempotent updates.
   - Connector should not be registered during broker/bootstrap race windows.
5. Start `kafka-ui` (can start earlier, but considered ready for demo after broker reachable).
6. Run smoke checks:
   - Connector status RUNNING with zero failed tasks.
   - CDC topic visible after first source mutation.

### Readiness Gates
- No downstream step proceeds until upstream health checks pass.
- Demo script should fail fast with explicit error if any gate fails.
- Connector registration gate requires all true:
  - Kafka broker reachable on internal listener (`kafka:9092`).
  - PostgreSQL accepts connections and replication settings are active.
  - Connect worker REST health endpoint responds successfully.

---

## System Health Definition
System is considered healthy only when all are true:
- PostgreSQL is accepting SQL connections.
- Kafka broker is accepting produce/consume operations.
- Kafka Connect worker REST endpoint responds successfully.
- Orders CDC connector is RUNNING with zero failed tasks.
- Topic consumption from `cdc_lab_pg.public.orders` returns expected event envelope for test mutation.

---

## Failure Modes and Recovery

## System Reset Strategy (Deterministic Demo Re-run)
- Provide two reset modes:
  1. **Soft reset**: keep containers/volumes, truncate or recreate demo rows in `orders`, and re-run insert/update/delete sequence.
  2. **Hard reset**: stop stack and remove containers + volumes to guarantee clean broker state, clean connector offsets, and fresh replication artifacts.
- Hard reset is the authoritative approach for deterministic first-run demos and troubleshooting unknown state drift.
- After hard reset, startup sequence must be re-executed in order, including connector re-registration via REST API.


## 1) PostgreSQL unavailable
### Symptoms
- Connector task transitions to FAILED or repeatedly retries.
- No new CDC events emitted.

### Recovery
- Restore PostgreSQL container health.
- Verify replication slot/publication exist and match connector identifiers.
- Restart failed connector task if needed.

---

## 2) Kafka broker unavailable or mis-advertised listeners
### Symptoms
- Connect worker cannot write offsets/config/status topics.
- Consumers cannot read topic; UI disconnected.

### Recovery
- Correct listener and advertised listener settings.
- Ensure internal/external listener mapping aligns with container and host clients.
- Restart broker, then Connect worker.

---

## 3) Connector misconfiguration
### Symptoms
- Connector remains FAILED/UNASSIGNED.
- Events absent despite source mutations.

### Recovery
- Validate required fields:
  - `database.server.name=cdc_lab_pg`
  - `slot.name=cdc_lab_slot`
  - `publication.name=cdc_lab_publication`
- Validate table include list targets `public.orders`.
- Re-register connector with corrected config.

---

## 4) Topic not observed by consumer
### Symptoms
- SQL mutations succeed but no visible messages.

### Recovery
- Confirm consumer targets `cdc_lab_pg.public.orders`.
- Confirm consume-from-beginning mode for previously emitted events.
- Validate connector task is RUNNING and offset progression occurs.

---

## 5) Local resource pressure (CPU/RAM)
### Symptoms
- Slow startup, intermittent timeouts, container restarts.

### Recovery
- Increase Docker Desktop resources.
- Reduce background workloads.
- Re-run deterministic startup sequence after stabilization.

---

## Non-Goals in Architecture
- Multi-broker Kafka cluster.
- Multi-worker Connect cluster.
- Cross-host networking.
- Production-grade security controls (mTLS, secret managers, ACL hardening).

---

## Traceability to PRD
This design implements and refines PRD constraints for:
- Fixed local runtime choices (Bitnami Kafka + Debezium Connect).
- Fixed topic naming and message contract.
- Fixed connector identifiers.
- Explicit health criteria and demo observability path.
