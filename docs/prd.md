# Product Requirements Document (PRD)

## Product Title
Local CDC Lab: PostgreSQL → Debezium → Kafka (Docker Compose)

## Product Manager Intent
Create a **local-only** demonstration system that shows how Change Data Capture (CDC) events flow from PostgreSQL (via logical replication) through Debezium in Kafka Connect and land in Kafka topics.

This PRD defines scope and expectations for a hands-on lab environment intended for learning, validation, and internal demos on a Mac with Docker.

---

## Problem Statement
Teams often understand CDC conceptually but lack a reproducible, local environment to see end-to-end behavior for insert, update, and delete operations in real time.

We need a small, self-contained lab that:
- Is easy to run on a developer laptop.
- Makes CDC behavior observable.
- Demonstrates a realistic pattern using PostgreSQL + Debezium + Kafka.

---

## Goals
1. Provide a local Docker Compose environment that runs on Mac.
2. Enable PostgreSQL logical replication and Debezium capture.
3. Publish row-level change events from an `orders` table into Kafka.
4. Demonstrate CDC event behavior for:
   - Insert
   - Update
   - Delete
5. Make the demo deterministic and repeatable for onboarding and knowledge sharing.

---

## In Scope
- Local machine execution only (Mac + Docker Desktop).
- One PostgreSQL instance configured for logical replication.
- One Kafka broker suitable for local development.
- **Bitnami Kafka** image/distribution as the default local broker choice.
- One Kafka Connect worker with Debezium PostgreSQL connector enabled.
- **Debezium Connect** image/distribution as the default connector runtime choice.
- One demo schema/table centered on `orders`.
- CDC event generation and verification for insert/update/delete lifecycle.
- Documentation-first delivery (this PRD) before infrastructure creation.

---

## Out of Scope / Non-Goals
- Production hardening (HA, clustering, scaling, security hardening).
- Cloud deployment (AWS/GCP/Azure/Kubernetes).
- Multi-node Kafka, multi-broker resilience testing.
- Schema registry compatibility workflows.
- Data lake sinks, downstream stream processors, or microservices integration.
- Monitoring stack (Prometheus/Grafana) beyond minimal demo observability.
- CI/CD pipelines for environment provisioning.

---

## Users / Stakeholders
- Primary: Engineers learning CDC and event streaming.
- Secondary: Architects/technical leads evaluating CDC patterns.
- Tertiary: Enablement/training teams running live demos.

---

## Functional Requirements

### FR1: Local-Only Environment
- The system must run entirely on a Mac laptop using Docker Compose.
- No dependency on remote managed services.

### FR2: PostgreSQL Logical Replication
- PostgreSQL must be configured to support logical replication required by Debezium.
- Database setup must include an `orders` table suitable for row mutation demos.

### FR3: Kafka Broker Availability
- Kafka broker must be reachable by Kafka Connect and local CLI tooling.
- Broker must accept topics and messages required for CDC flow.
- Kafka distribution is fixed to **Bitnami Kafka** for this lab.

### FR4: Kafka Connect + Debezium
- Kafka Connect must load and run a Debezium PostgreSQL source connector.
- Connector must capture change events from the `orders` table.
- Connector runtime is fixed to **Debezium Connect** image/distribution for this lab.
- Required connector identifiers must be explicitly configured and documented as:
  - `database.server.name=cdc_lab_pg`
  - `slot.name=cdc_lab_slot`
  - `publication.name=cdc_lab_publication`

### FR5: CDC Event Coverage
- Insert, update, and delete operations on `orders` must each produce corresponding CDC events in Kafka.
- Events must include sufficient payload structure to distinguish operation type.
- Topic naming convention is fixed to Debezium default pattern using the required server name:
  - `<database.server.name>.<schema>.<table>`
  - For the demo `orders` table in `public` schema, expected topic is:
    - `cdc_lab_pg.public.orders`
- Message contract must include, at minimum:
  - Key with the primary key for the `orders` row.
  - Value payload containing Debezium envelope fields `before`, `after`, and operation code `op`.
  - `op` values interpreted as:
    - `c` for create (insert)
    - `u` for update
    - `d` for delete

### FR6: Demo-Readiness
- The lab must include clear steps for standing up services, creating test records, modifying records, deleting records, and viewing emitted messages.
- Topic consumer instructions must explicitly include consuming from:
  - `cdc_lab_pg.public.orders`
- Topic consumer instructions must include beginning-of-topic read mode for deterministic demo replay.

---

## Success Criteria
1. A developer can start the environment on Mac using Docker Compose and reach healthy service states.
2. The Debezium connector transitions to RUNNING state without manual code changes.
3. Inserting a row into `orders` produces a corresponding CDC event in `cdc_lab_pg.public.orders`.
4. Updating the same row produces a CDC update event with `op=u` and changed `after` content.
5. Deleting the same row produces a CDC delete event with `op=d` and expected Debezium delete semantics.
6. A first-time user can complete the demo from instructions in under 20 minutes.

System health is defined as all of the following being true simultaneously:
- PostgreSQL container/process reports healthy and accepts SQL connections.
- Bitnami Kafka broker container/process reports healthy and accepts client connections.
- Debezium Connect REST API is reachable and returns healthy worker status.
- Debezium PostgreSQL connector status is `RUNNING` with zero failed tasks.

---

## Acceptance Tests

### AT1: Environment Startup
- **Given** Docker Desktop is running on Mac,
- **When** the user starts the lab stack via documented compose command,
- **Then** PostgreSQL, Bitnami Kafka, and Debezium Connect are all healthy/reachable per the defined system health criteria.

### AT2: Connector Health
- **Given** services are running,
- **When** the user queries Kafka Connect connector status,
- **Then** the Debezium PostgreSQL connector is in `RUNNING` state with no failed tasks,
- **And** connector identifiers match:
  - `database.server.name=cdc_lab_pg`
  - `slot.name=cdc_lab_slot`
  - `publication.name=cdc_lab_publication`

### AT3: Insert CDC Event
- **Given** connector is running and topic `cdc_lab_pg.public.orders` is being consumed from the beginning,
- **When** user inserts a new row into `orders`,
- **Then** one insert CDC event appears for that row with `op=c`.

### AT4: Update CDC Event
- **Given** an existing `orders` row,
- **When** user updates one or more columns,
- **Then** one update CDC event appears with updated `after` field values and `op=u`.

### AT5: Delete CDC Event
- **Given** an existing `orders` row,
- **When** user deletes that row,
- **Then** one delete CDC event appears representing row removal with `op=d`.

### AT6: End-to-End Reproducibility
- **Given** a clean local machine state,
- **When** a new user follows the documented demo steps,
- **Then** they can reproduce insert/update/delete CDC outputs in `cdc_lab_pg.public.orders` without undocumented steps.

---

## Demo Steps (Planned User Journey)
1. **Prerequisites Check**
   - Confirm Mac + Docker Desktop available.
2. **Start Stack**
   - Launch local services via Docker Compose.
3. **Verify Service Health**
   - Confirm PostgreSQL reachable and healthy.
   - Confirm Bitnami Kafka broker reachable and healthy.
   - Confirm Debezium Connect API reachable and connector task healthy.
4. **Register/Verify Debezium Connector**
   - Ensure PostgreSQL source connector is active and RUNNING.
   - Verify connector identifiers:
     - `database.server.name=cdc_lab_pg`
     - `slot.name=cdc_lab_slot`
     - `publication.name=cdc_lab_publication`
5. **Open Kafka Topic Consumer**
   - Start a consumer against topic `cdc_lab_pg.public.orders`.
   - Start consumption from the beginning of the topic.
   - Include message key output so primary key linkage is visible.
6. **Run Data Changes in PostgreSQL**
   - Perform insert on `orders`.
   - Perform update on same row.
   - Perform delete on same row.
7. **Observe CDC Events**
   - Verify three event types appear and align with operations performed.
   - Verify message contract fields `before`, `after`, and `op`.
8. **Reset / Repeat**
   - Demonstrate repeatability by running a second lifecycle scenario.

---

## Assumptions
- Users are comfortable with basic Docker and terminal commands.
- Docker Desktop resources are sufficient to run Bitnami Kafka + Debezium Connect + PostgreSQL.
- A single broker/worker is acceptable for local demonstration goals.

---

## Risks & Mitigations
- **Risk:** Local environment resource constraints causing unstable startup.
  - **Mitigation:** Keep scope minimal (single broker, single connect worker).
- **Risk:** Connector configuration drift or plugin mismatch.
  - **Mitigation:** Use documented, tested image tags and allow local override when upstream tags are retired.
- **Risk:** User confusion around topic names/event format.
  - **Mitigation:** Enforce fixed topic naming and minimum message contract (`before`, `after`, `op`) in docs and acceptance criteria.

---

## Milestones (Documentation-First)
1. PRD approved.
2. Technical design for local compose topology drafted.
3. Implementation of compose stack and connector config.
4. Demo script and quickstart finalized.
5. Validation against acceptance tests.

---

## Open Questions
1. Should tombstone message behavior for deletes be included in first demo or deferred?
2. Do we standardize on JSON payload consumption only for v1?

---

## Explicitly Deferred (Per Request)
- No code artifacts.
- No Docker Compose or infrastructure files.
- No connector JSON payload/config implementation yet.
