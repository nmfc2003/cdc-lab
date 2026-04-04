# Autonomous Multi-Agent Workflow

## Roles

### Product Manager
- Defines PRD, scope, success criteria
- Clarifies ambiguities
- Validates final solution meets intent

### Architect
- Defines system design and constraints
- Resolves infra decisions
- Ensures correctness before implementation

### Data Engineer
- Implements code
- Writes docker-compose, scripts, configs
- Ensures system runs end-to-end

---

## Execution Rules

- Agents MUST collaborate internally before writing code
- Architect MUST validate PM requirements
- Data Engineer MUST validate architecture before coding
- No code should be written until:
    - PRD is complete
    - Architecture is complete
    - All contradictions are resolved

---

## Autonomous Loop

Before producing final output, run:

1. PM reviews requirements
2. Architect critiques design
3. Data Engineer checks feasibility
4. Resolve conflicts internally
5. Only then produce final implementation

---

## Constraints

- Prefer correctness over speed
- Avoid iterative fixes after code generation
- Produce a working system in one pass
- Assume no human intervention until final result