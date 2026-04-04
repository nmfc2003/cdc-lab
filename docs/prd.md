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
- One Kafka Connect worker with Debezium PostgreSQL connector enabled.
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

### FR4: Kafka Connect + Debezium
- Kafka Connect must load and run a Debezium PostgreSQL source connector.
- Connector must capture change events from the `orders` table.

### FR5: CDC Event Coverage
- Insert, update, and delete operations on `orders` must each produce corresponding CDC events in Kafka.
- Events must include sufficient payload structure to distinguish operation type.

### FR6: Demo-Readiness
- The lab must include clear steps for standing up services, creating test records, modifying records, deleting records, and viewing emitted messages.

---

## Success Criteria
1. A developer can start the environment on Mac using Docker Compose and reach healthy service states.
2. The Debezium connector transitions to RUNNING state without manual code changes.
3. Inserting a row into `orders` produces a corresponding CDC event in the expected Kafka topic.
4. Updating the same row produces a CDC update event.
5. Deleting the same row produces a CDC delete event.
6. A first-time user can complete the demo from instructions in under 20 minutes.

---

## Acceptance Tests

### AT1: Environment Startup
- **Given** Docker Desktop is running on Mac,
- **When** the user starts the lab stack via documented compose command,
- **Then** PostgreSQL, Kafka broker, and Kafka Connect are all healthy/reachable.

### AT2: Connector Health
- **Given** services are running,
- **When** the user queries Kafka Connect connector status,
- **Then** the Debezium PostgreSQL connector is in `RUNNING` state.

### AT3: Insert CDC Event
- **Given** connector is running and topic is being consumed,
- **When** user inserts a new row into `orders`,
- **Then** one insert CDC event appears for that row in Kafka.

### AT4: Update CDC Event
- **Given** an existing `orders` row,
- **When** user updates one or more columns,
- **Then** one update CDC event appears with updated field values.

### AT5: Delete CDC Event
- **Given** an existing `orders` row,
- **When** user deletes that row,
- **Then** one delete CDC event appears representing row removal.

### AT6: End-to-End Reproducibility
- **Given** a clean local machine state,
- **When** a new user follows the documented demo steps,
- **Then** they can reproduce insert/update/delete CDC outputs without undocumented steps.

---

## Demo Steps (Planned User Journey)
1. **Prerequisites Check**
   - Confirm Mac + Docker Desktop available.
2. **Start Stack**
   - Launch local services via Docker Compose.
3. **Verify Service Health**
   - Confirm PostgreSQL reachable.
   - Confirm Kafka broker reachable.
   - Confirm Kafka Connect API reachable.
4. **Register/Verify Debezium Connector**
   - Ensure PostgreSQL source connector is active and RUNNING.
5. **Open Kafka Topic Consumer**
   - Start a consumer against the expected CDC topic for `orders`.
6. **Run Data Changes in PostgreSQL**
   - Perform insert on `orders`.
   - Perform update on same row.
   - Perform delete on same row.
7. **Observe CDC Events**
   - Verify three event types appear and align with operations performed.
8. **Reset / Repeat**
   - Demonstrate repeatability by running a second lifecycle scenario.

---

## Assumptions
- Users are comfortable with basic Docker and terminal commands.
- Docker Desktop resources are sufficient to run Kafka + Connect + PostgreSQL.
- A single broker/worker is acceptable for local demonstration goals.

---

## Risks & Mitigations
- **Risk:** Local environment resource constraints causing unstable startup.
  - **Mitigation:** Keep scope minimal (single broker, single connect worker).
- **Risk:** Connector configuration drift or plugin mismatch.
  - **Mitigation:** Pin image versions and document expected versions.
- **Risk:** User confusion around topic names/event format.
  - **Mitigation:** Provide explicit expected topic naming and sample event interpretation guidance in future implementation docs.

---

## Milestones (Documentation-First)
1. PRD approved.
2. Technical design for local compose topology drafted.
3. Implementation of compose stack and connector config.
4. Demo script and quickstart finalized.
5. Validation against acceptance tests.

---

## Open Questions
1. Preferred Kafka distribution/image for local lab consistency?
2. Should tombstone message behavior for deletes be included in first demo or deferred?
3. Do we standardize on JSON payload consumption only for v1?

---

## Explicitly Deferred (Per Request)
- No code artifacts.
- No Docker Compose or infrastructure files.
- No connector JSON payload/config implementation yet.

### CDC Topic Contract

- Topic name pattern: `cdc.public.orders`
- Message format: Debezium envelope (before/after/op)
- Operation types:
    - c → insert
    - u → update
    - d → delete
