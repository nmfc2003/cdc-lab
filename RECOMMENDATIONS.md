# Recommendations: Stabilize the Local CDC + Flink + Iceberg Learning Lab

This document provides exact, minimal changes to produce a **clean, restartable, deterministic** local learning setup.

## 1) Exact changes to make

### A. Make reset semantics truly deterministic
1. Extend reset behavior into two explicit modes:
   - `reset-soft`: keep Postgres/Kafka volumes, clear running containers only.
   - `reset-hard`: remove containers/volumes **and** delete bind-mounted state folders:
     - `./data/iceberg`
     - `./data/flink-checkpoints`
     - optional local output files (e.g., `output/orders_cdc.jsonl`)
2. Update README to define both modes and when to use each.

### B. Normalize replay behavior for Kafka consumers
1. For learning replay commands, avoid fixed consumer group IDs by default.
2. Provide one of these deterministic patterns:
   - use console consumer with `--from-beginning` and no persistent group, or
   - generate timestamped/ephemeral group IDs per run.
3. Keep a separate “resume mode” consumer script for tailing live events.

### C. Make Flink SQL lifecycle explicit and debuggable
1. Add a dedicated script for SQL session submission with clear behavior:
   - checks CDC stack readiness first,
   - submits DDL/DML,
   - prints resulting Flink job IDs.
2. Add a script to list/cancel Flink jobs safely before re-submission.
3. Document that SQL objects in the default SQL client context are session-scoped metadata unless externalized in a persistent metastore.

### D. Tighten checkpoint/commit visibility
1. Add a script (or section in existing check script) that verifies:
   - at least one successful checkpoint for the running sink job,
   - Iceberg metadata/data files advancing after checkpoints.
2. In README/runbook, explicitly state:
   - “Iceberg streaming commit is checkpoint-driven; uncheckpointed records may not be committed.”

### E. Define end-to-end state contract
1. Add a short table in README mapping each subsystem to its persisted state:
   - Postgres WAL + tables (named volume)
   - Kafka topics + consumer groups + Connect internal topics (named volume)
   - Flink checkpoints (bind mount)
   - Iceberg warehouse (bind mount)
2. For each run mode (fresh, resume, replay), state exactly which state is preserved and which is cleared.

### F. Harden readiness checks
1. Expand `wait-for-health.sh` into layered checks:
   - Postgres query readiness
   - Kafka broker reachability + topic existence
   - Kafka Connect worker + connector task status
   - (optional) Flink REST readiness and active jobs
2. Fail fast with clear troubleshooting hints.

### G. Debezium config clarity improvements
1. Make snapshot behavior explicit (e.g., `snapshot.mode=initial` or `when_needed`) and document implications.
2. Keep fixed IDs (`topic.prefix`, slot, publication) as-is for deterministic naming.

---

## 2) What to delete

1. Delete ambiguous “hard reset” wording that does not include bind-mounted state removal.
2. Delete or demote any replay instructions that rely on persistent consumer groups without warning.
3. Delete duplicated/conflicting run instructions if they produce multiple lifecycle paths with different state outcomes.

---

## 3) What to simplify

1. Simplify operations into a small command surface:
   - `up`
   - `status`
   - `run-pipeline`
   - `replay`
   - `reset-soft`
   - `reset-hard`
2. Simplify docs around one canonical happy path and one canonical full reset path.
3. Simplify observability by providing one summary status script instead of scattered manual checks.

---

## 4) What to keep

1. Keep current service choices (Postgres + Debezium Connect + single-node KRaft Kafka + Flink + Iceberg).
2. Keep connector/topic naming contract:
   - `cdc_lab_pg.public.orders`
   - slot/publication IDs.
3. Keep checkpoint configuration concept (exactly-once mode + externalized checkpoint retention) but make operational validation explicit.
4. Keep lightweight local filesystem warehouse/checkpoint approach for learning.

---

## 5) Proposed clean baseline architecture (local-only)

### Baseline goals
- Local only.
- Deterministic startup.
- Deterministic teardown.
- Reproducible replay.

### Baseline topology
- **Postgres** (logical replication enabled; seeded schema/publication)
- **Kafka (single-node KRaft)**
- **Kafka Connect + Debezium**
- **Flink JobManager + TaskManager**
- **Iceberg Hadoop catalog on local filesystem**
- **Kafka UI** (optional but enabled for learning)

### Deterministic startup sequence
1. `up` starts Postgres + Kafka + Kafka topic bootstrap.
2. Register/verify Debezium connector only after broker + DB + Connect are healthy.
3. `run-pipeline` starts Flink and submits SQL pipeline only after connector RUNNING and source topic exists.
4. Emit a starter mutation and validate:
   - Kafka event observed,
   - Flink job running,
   - checkpoint succeeded,
   - Iceberg row visible.

### Deterministic teardown sequence
- `reset-soft`: stop/remove containers only; preserve all persisted state.
- `reset-hard`: stop/remove containers + named volumes + bind-mounted warehouse/checkpoints + derived local outputs.

### Reproducible replay model
- Replay command uses fresh/ephemeral Kafka consumer group and `from-beginning` semantics.
- For Flink replay learning, either:
  - reset consumer group/checkpoint state explicitly, or
  - run in a dedicated replay mode that starts from earliest with cleared checkpoints.
- Documentation must clearly separate “resume existing stream processing” from “replay from scratch.”

---

## 6) Follow-up patch plan (do not implement yet)

1. **Script refactor**
   - Add `scripts/status.sh` for one-shot health summary.
   - Split reset script into soft/hard modes.
   - Add `scripts/flink_jobs.sh` for list/cancel helpers.

2. **Replay tooling**
   - Update Python consumer scripts to support `--mode replay|resume`.
   - Default replay mode to ephemeral group IDs.

3. **Flink lifecycle safety**
   - Update SQL submission script to detect existing sink job and require explicit replace/cancel flag.
   - Print job ID and checkpoint progress URL hints.

4. **Docs alignment**
   - Update README + runbook with explicit state contract and operational modes.
   - Add a short troubleshooting matrix for common hidden-state failures.

5. **Optional quality gates**
   - Add a lightweight smoke script that runs: up → mutate → verify Kafka → verify checkpoint → verify Iceberg row.

