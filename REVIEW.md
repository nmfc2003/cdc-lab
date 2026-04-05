# End-to-End Platform Review: Local CDC + Flink + Iceberg Lab

This review consolidates internal perspectives from **Product Manager, Architect, Data Engineer, and Reviewer** into one strict assessment.

## Internal collaboration summary

### Product Manager perspective (requirements and learning goals)
- The repository succeeds at presenting a compact local CDC learning stack.
- However, current behavior is not consistently deterministic across repeats because reset/startup semantics and consumer/job state semantics are mixed.
- Documentation promises deterministic behavior but operational scripts only partially enforce it.

### Architect perspective (system correctness and consistency)
- The CDC pipeline boundary contracts are mostly explicit (topic names, publication/slot names, checkpoint path).
- The Flink SQL model relies on session-defined objects and script-side submission assumptions that are not made explicit.
- Replay semantics across Kafka offsets, connector offsets, Flink state, and Iceberg files are not modeled as one coherent state machine.

### Data Engineer perspective (runtime feasibility and operator ergonomics)
- Compose topology is runnable and mostly health-gated for the CDC core.
- Flink lifecycle and replay controls are under-specified in scripts.
- Existing scripts are useful but can hide stale state (consumer groups, local filesystem artifacts, lingering checkpoints/warehouse files).

### Reviewer consolidation
- Primary risk theme: **hidden state** across subsystems (Kafka Connect offsets, Kafka consumer groups, Flink checkpoints, Iceberg warehouse files, persisted Postgres/Kafka volumes).
- Secondary risk theme: **session-scoped SQL assumptions** not called out clearly enough for repeatable learning runs.

---

## Critical issues

1. **`reset.sh` does not reset bind-mounted Flink/Iceberg state, so “hard reset” is incomplete.**
   - `docker compose down -v` removes named volumes but does not remove `./data/iceberg` or `./data/flink-checkpoints` bind-mount contents.
   - This leaves previous Iceberg snapshots/checkpoints and can make replay behavior non-deterministic after “reset”.

2. **Replay semantics are non-deterministic due to fixed Kafka consumer groups in scripts.**
   - `orders-to-jsonl.py` and `tail-orders.py` use stable group IDs, so repeated runs resume from committed offsets instead of replaying from topic start unless operators manually reset offsets.
   - This directly conflicts with local learning expectations around repeatable event playback.

3. **Flink SQL source and catalog objects are effectively session artifacts with no explicit persistent metastore.**
   - `CREATE TABLE orders_cdc_src` and `CREATE CATALOG local_iceberg` are created through SQL client files per run.
   - Jobs may run after submission, but object definitions are not persistently discoverable across new SQL sessions unless re-created.
   - This can confuse operators who expect metadata persistence.

4. **State model for end-to-end recovery is undefined across Connect offsets, Kafka offsets, Flink checkpoints, and Iceberg tables.**
   - Components are individually configured, but no single documented recovery contract exists describing what happens on restart vs teardown vs reset.
   - This creates high chance of accidental partial resets and hard-to-explain output.

5. **Checkpoint-commit dependency is enabled but not operationally validated/observable in scripts.**
   - Iceberg sink commit semantics depend on successful checkpoints.
   - There is no script guard that verifies checkpoint completion before claiming data durability.

---

## Medium issues

1. **Startup health checks are CDC-centric only, not full-stack.**
   - `wait-for-health.sh` validates Kafka Connect and connector RUNNING, but not Postgres mutation readiness checks, Kafka topic assertion, Flink readiness, or active checkpoint progression.

2. **Flink startup script does not gate on CDC stack readiness.**
   - `run_flink_sql.sh` starts Flink and submits SQL but does not assert that source topic is receiving records or that connector is RUNNING.

3. **`scan.startup.mode = earliest-offset` does not guarantee replay when committed offsets already exist for the fixed group id.**
   - The behavior can look inconsistent to learners unless group/offset lifecycle is controlled.

4. **Debezium snapshot behavior is implicit.**
   - `snapshot.mode` is not explicit, so initial/bootstrap behavior depends on Debezium defaults and existing offset state.

5. **Observability is fragmented.**
   - Kafka UI exists and scripts exist, but there is no single “doctor/status” command that summarizes connector state, topic activity, Flink jobs, and checkpoint health.

---

## Low-priority issues

1. **Architecture docs contain proposed vs implemented structures that diverge from current repo layout.**
   - This is not incorrect, but increases cognitive load during onboarding.

2. **Some scripts use service names via `docker compose exec`, others use hard-coded container names via `docker exec`.**
   - Mixed patterns make scripts less portable and harder to extend.

3. **No explicit retention/cleanup guidance for local disk growth in `data/iceberg` and checkpoint directories.**

4. **No explicit guardrails around rerunning SQL submission (duplicate running jobs possibility).**

---

## Design smells

1. **Determinism is declared as a goal but not encoded as first-class operational modes.**
   - Missing explicit run modes such as `fresh-start`, `resume`, `replay`.

2. **Lifecycle responsibilities are spread across multiple scripts without a central orchestrator.**
   - Startup, connector registration, SQL submission, and checks are separate and can be run in inconsistent order.

3. **Session-bound Flink SQL object creation is not documented as such.**
   - New users may interpret catalog/table existence incorrectly.

4. **Reset semantics are asymmetric.**
   - Named volumes reset, bind mounts persist, consumer groups persist in Kafka volume until reset, etc.

---

## Operational risks

1. **Accidental data loss / accidental stale-state reuse.**
   - Operators may think they reset everything while checkpoints/warehouse persist.

2. **Replay confusion and false debugging trails.**
   - Same script command may produce different record windows across runs due to offset state.

3. **Checkpoint/commit misunderstanding.**
   - Users may expect immediate Iceberg row visibility equivalent to Kafka consumption timing.

4. **Hard-to-diagnose “it worked yesterday” scenarios.**
   - Hidden persisted state across subsystems amplifies local support burden.

---

## Verdict

The repository is close to a strong local learning lab, but currently falls short of deterministic/restartable behavior because state and session semantics are not unified. The fastest path to stability is to simplify around explicit lifecycle modes and make state reset/replay behavior unambiguous.
