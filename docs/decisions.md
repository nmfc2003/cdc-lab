# Architecture Decisions: Local CDC Lab

This file captures key architecture decisions for the local CDC lab and provides rationale and consequences.

---

## ADR-001: Local-only deployment on Mac + Docker
### Status
Accepted

### Decision
The lab runs only on Mac laptops using Docker Desktop and Docker Compose.

### Rationale
- Fast onboarding and reproducibility for engineers.
- No cloud credentials or external dependencies required.
- Aligns with PRD constraints and learning goals.

### Consequences
- No production SLAs or resilience guarantees.
- Resource limits of developer machines directly affect reliability.

---

## ADR-002: Kafka distribution = Bitnami Kafka in KRaft mode
### Status
Accepted

### Decision
Use Bitnami Kafka image with single-node KRaft mode (combined broker/controller).

### Rationale
- Removes ZooKeeper dependency, simplifying local topology.
- Keeps service count low and startup sequence manageable.
- Meets “minimal but production-sensible” target.

### Consequences
- Not representative of multi-broker production fault tolerance.
- Listener configuration must be explicit to avoid host/container connectivity issues.

---

## ADR-003: Connect runtime = Debezium Connect single worker
### Status
Accepted

### Decision
Use Debezium Connect image as a single Kafka Connect worker.

### Rationale
- Native packaging of Debezium connector stack.
- Simplifies local setup and reduces plugin management complexity.
- Sufficient for one-source (`orders`) CDC demonstration.

### Consequences
- No distributed Connect fault tolerance.
- Any worker failure stops CDC until restart.

---

## ADR-004: Fixed connector identifiers
### Status
Accepted

### Decision
Standardize connector identity and replication linkage to:
- `database.server.name=cdc_lab_pg`
- `slot.name=cdc_lab_slot`
- `publication.name=cdc_lab_publication`

### Rationale
- Deterministic topic naming and easier troubleshooting.
- Reduces configuration drift in demos and onboarding.

### Consequences
- Multiple concurrent lab instances need identifier overrides to avoid collisions.
- Identifier changes require coordinated updates in docs and scripts.

---

## ADR-005: Topic naming strategy follows Debezium default
### Status
Accepted

### Decision
Use Debezium default topic naming pattern:
- `<database.server.name>.<schema>.<table>`
- Expected `orders` topic: `cdc_lab_pg.public.orders`

### Rationale
- Predictable mapping from source table to topic.
- Avoids custom SMT complexity for v1 lab scope.

### Consequences
- Topic names are implementation-derived and verbose.
- Any change to `database.server.name` changes all derived topic names.

---

## ADR-006: Message contract = Debezium envelope (JSON-oriented)
### Status
Accepted

### Decision
Define minimum observable contract as:
- Key contains row primary key.
- Value includes `before`, `after`, `op`.
- Operation mapping `c/u/d` required for demo assertions.

### Rationale
- Makes insert/update/delete semantics explicit and testable.
- Easier to inspect in CLI and Kafka UI for learning scenarios.

### Consequences
- Contract is tied to Debezium envelope semantics.
- Downstream consumers in real systems may require schema governance not included here.

---

## ADR-007: Include Kafka UI as first-class local observability surface
### Status
Accepted

### Decision
Include `kafka-ui` service in compose topology.

### Rationale
- Improves demo experience and troubleshooting speed.
- Lowers barrier for users less familiar with Kafka CLI tools.

### Consequences
- Additional container and port exposure in local environment.
- UI convenience does not replace API/CLI health checks.

---

## ADR-008: Deterministic startup sequence with readiness gates
### Status
Accepted

### Decision
Enforce service bring-up order and health gates:
1. Kafka
2. PostgreSQL
3. Kafka Connect
4. Connector registration
5. Consumer verification

### Rationale
- Prevents race conditions during local startup.
- Reduces flaky first-run behavior and improves demo reliability.

### Consequences
- Startup automation must include wait/retry logic.
- Manual startup out of order can cause temporary failures.

---

## ADR-009: Failure handling is restart-and-verify, not self-healing orchestration
### Status
Accepted

### Decision
Use simple local recovery patterns (restart service, re-check connector, replay demo steps) rather than automated remediation.

### Rationale
- Appropriate for local educational lab scope.
- Keeps architecture understandable and lightweight.

### Consequences
- Requires operator attention during failures.
- Not suitable as-is for production incident response expectations.

---

## ADR-010: Keep architecture minimal while preserving production-sensible boundaries
### Status
Accepted

### Decision
Adopt single instances for each required service (`postgres`, `kafka`, `kafka-connect`, `kafka-ui`) while preserving clear contracts and health definitions.

### Rationale
- Balances simplicity with realistic CDC flow components.
- Encourages correct conceptual model without overbuilding infra.

### Consequences
- Omits resiliency patterns by design.
- Future production evolution requires additional ADRs and topology changes.
