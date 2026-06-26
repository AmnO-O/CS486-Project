---
name: 04-design-validation
description: Use when user asks to validate a logical schema against an ERD, or references outputs/03-logical-design and outputs/02-erd-design files
---

# Task 04 — Design Validation of Relational Schema against ERD and Business Requirements

## Purpose
Produce a comprehensive design validation report for Task 04, generating `outputs/04-design-validation-G05.md`, which evaluates the relational schema in `outputs/03-logical-design-G05.md` against the ERD in `outputs/02-erd-design-G05.md` and the business requirements in `outputs/01-business-req-analysis-G05.md`.

---

## Inputs
- `outputs/01-business-req-analysis-G05.md` (required for business rules)
- `outputs/02-erd-design-G05.md` (required for ERD reference)
- `outputs/03-logical-design-G05.md` (required for logical schema reference)
- `docs/entity-registry.md` (required for entity and attribute reference)
- `docs/schema-registry.md` (required for logical design details)
- --group (optional, default: G05)

---

## Outputs
- `outputs/04-design-validation-G{{group}}.md` (validation report)

---

## Evaluation Criteria

The report must explicitly evaluate whether the relational schema:

1. **Correctly represents the ERD** — every entity, attribute, and relationship in the ERD has a faithful counterpart in the logical schema with no omissions or structural mismatches.
2. **Satisfies business rules** — all business rules, invariants, and domain constraints identified in the requirements are enforced in the schema via constraints, checks, triggers, or equivalent mechanisms.
3. **Uses appropriate keys** — each table has a well-chosen primary key (surrogate or natural); foreign keys are declared wherever a referencing relationship exists; candidate keys are captured with UNIQUE constraints where applicable.
4. **Uses appropriate relationships** — every ERD relationship (1:1, 1:N, M:N) is correctly translated: 1:N via FK on the many-side, M:N via junction table with composite PK, 1:1 via FK with UNIQUE constraint. Cardinality and participation (total vs. partial) constraints must match.
5. **Uses appropriate constraints** — NOT NULL, UNIQUE, CHECK, DEFAULT, and referential-integrity (ON DELETE / ON UPDATE) actions are applied wherever the ERD or business rules demand them.

---

## Behavior / Steps

1. Read `outputs/01-business-req-analysis-G05.md`, `outputs/02-erd-design-G05.md`, `outputs/03-logical-design-G05.md`, and `docs/entity-registry.md`.
2. **ERD fidelity** — for each entity in the ERD, verify it exists as a table in the logical schema with all attributes present, correct data types, and correct nullability. Flag any entity, attribute, or derived relationship that is missing or mis-typed.
3. **Business rule coverage** — enumerate every business rule from the requirements document and trace it to the schema construct that enforces it (CHECK, UNIQUE, FK, trigger, etc.). Mark each rule as *Enforced*, *Partial*, or *Missing*.
4. **Key adequacy** — confirm that every table has a clearly defined PRIMARY KEY. Verify that natural candidate keys are expressed as UNIQUE constraints. Verify that surrogate keys are used only where a suitable natural key does not exist.
5. **Relationship translation** — for each ERD relationship, verify the correct translation pattern (FK, junction table, or FK+UNIQUE for 1:1). Check cardinality multiplicity (1:1 / 1:N / M:N) and participation (mandatory/optional ↔ NOT NULL / nullable FK). Verify ON DELETE / ON UPDATE actions match the business rules.
6. **Constraint completeness** — scan every table for missing NOT NULL, missing CHECK bounds (e.g., positive quantities, valid status enums), missing UNIQUE constraints, and unspecified referential-integrity actions. Document each gap.
7. **Naming consistency** — check that table names, column names, FK names, and index names follow a single consistent convention (snake_case, singular/plural, etc.).
8. **Normalization** — evaluate compliance with 3NF; identify any partial or transitive dependencies and recommend decomposition if present.
9. **Discrepancy log** — compile a prioritised list of all findings: *Critical* (schema cannot correctly store or enforce required data), *Major* (constraint or relationship missing), *Minor* (naming, style, or optional improvement).
10. **Recommendations** — for every discrepancy, provide a concrete corrective action (e.g., add column, add constraint, rename table, add junction table).

---

## Guidelines

- **Role**: Act as a database design validation engineer, ensuring that the logical schema accurately reflects the ERD and business requirements.
- **Input sources only**: `outputs/01-business-req-analysis-G05.md`, `outputs/02-erd-design-G05.md`, `outputs/03-logical-design-G05.md`, and `docs/entity-registry.md`.
- **Output intent**: Produce a detailed, reviewer-ready validation report structured around the five evaluation criteria above. Each section should contain a summary verdict (*Pass / Partial / Fail*), a per-item checklist, and actionable recommendations.

---

## Validation / Self-Check Checklist

Before finalizing the report, verify every item below. Each must be checked (`[x]`) or explicitly documented as not applicable:

- [ ] **Entity coverage** — every entity in the ERD (`outputs/02`) maps to exactly one table in the logical schema (`outputs/03`); no table exists without a corresponding ERD entity.
- [ ] **Attribute completeness** — for each entity, every conceptual attribute in the ERD/entity-registry appears as a column in its mapped table; attribute names, types, and nullability match.
- [ ] **Business rule coverage** — every business rule from `outputs/01` is traced to a schema mechanism (CHECK, UNIQUE, FK, trigger, etc.) and labelled *Enforced*, *Partial*, or *Missing*.
- [ ] **Relationship translation** — each relationship (R1–R9) in the entity-registry is translated with correct cardinality (1:N / M:N / 1:1), correct participation (NOT NULL ↔ total, nullable ↔ partial), and correct referential-integrity actions.
- [ ] **Key adequacy** — every table has a PRIMARY KEY; natural/business candidate keys are declared as UNIQUE; surrogate keys are used only where no suitable natural key exists.
- [ ] **Normalization (3NF)** — no partial or transitive dependencies remain; every non-key column depends on nothing but the whole primary key.
- [ ] **Discrepancy log quality** — each entry is classified as *Critical* / *Major* / *Minor* with a concrete, actionable recommendation; no entry is vague or unactionable.
- [ ] **Discrepancy log completeness** — every finding discovered during the checks above is recorded; nothing is silently ignored or assumed "obvious."
- [ ] **Cross-file synchronisation** — `docs/schema-registry.md` is in sync with `outputs/03`; any delta found is either resolved or logged in the discrepancy log.
- [ ] **Lock status documented** — Section 12 (registry lock status) is present, listing both `entity-registry.md` and `schema-registry.md` with their current status and any actions taken.
- [ ] **Verdict summary** — a clear recommendation (SCHEMA FREEZE READY / FREEZE WITH DEFERRED ITEMS / REVISION REQUIRED) is stated at the end.

---

## Idempotency

- Running with the **same set of input files** (unchanged `outputs/01`, `outputs/02`, `outputs/03`, `docs/entity-registry.md`, `docs/schema-registry.md`) **must produce the same verdict and the same discrepancy log**.
- Discrepancy entries must not contain **timestamps, random sort orders, or volatile identifiers** that would change between runs.
- If a discrepancy is resolved between runs, the log must reflect the new state (e.g., entry moved to "Resolved") — but for identical inputs, output must be deterministic.