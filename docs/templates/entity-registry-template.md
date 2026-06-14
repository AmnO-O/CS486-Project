# Entity Registry — Format Spec & Template

> This file contains **only the format specification and writing rules**.
> Actual entity data lives in `docs/entity-registry.md`.
>
> Read this file when: you are about to **write or update** `docs/entity-registry.md`.
> Skip this file when: you only need to **read** entity data for a task.

---

## Canonical entity block

Every entity MUST follow this exact structure so the registry stays uniform:

```markdown
### <EntityName>

**Status:** ⬜ draft | 🔄 refining | 🔒 locked
**Description:** <one sentence — the real-world thing this represents>
**Maps to table:** `<table_name>`
**Source:** outputs/0X §<section>

**Candidate keys:**
- `<surrogate_key>` (surrogate, PK)
- `<business_key>` (business, UNIQUE)

**Attributes:**

| Attribute | Type | Nullable | Key | Constraint / Enum | Notes |
|---|---|---|---|---|---|
| <name> | <SQL type> | NO/YES | PK/FK/UQ/— | `CHECK IN (...)` or `FK → table.col` | <note> |
```

---

## Column rules

| Column | Rule |
|---|---|
| **Type** | Final SQL Server type by end of Task 03: `INT`, `NVARCHAR(255)`, `DATETIME2`, `BIT`, … In Task 01–02, write `?` if unknown. |
| **Nullable** | `NO` or `YES` only — no blanks. |
| **Key** | One of `PK`, `FK`, `UQ`, `PK/FK` (composite), or `—`. |
| **Constraint / Enum** | Full enum list for CHECK columns: `CHECK IN ('a','b','c')`. FK pointer: `FK → table.col`. Leave `—` if none. |
| **Notes** | Defaults (`DEFAULT GETDATE()`), assumption refs (`(A1)`), open questions (`See Q2`), or anything non-obvious. Leave blank if nothing to add. |

---

## Status legend

| Icon | Meaning | When to use |
|---|---|---|
| ⬜ draft | Identified but not verified | Task 01 — first pass from business req |
| 🔄 refining | Being actively updated | Task 02 — ERD confirms/adjusts |
| 🔒 locked | Finalized, no changes without group consensus | After Task 03 logical design |

---

## Relationships registry — row format

```markdown
| # | From → To | Cardinality | Participation | Source |
|---|---|---|---|---|
| R1 | EntityA → EntityB | 1:N | EntityB total | outputs/01 §X |
```

**Cardinality options:** `1:1` · `1:N` · `M:N (via JunctionTable)`
**Participation options:** `both total` · `both partial` · `EntityX total` · `EntityX partial`

---

## Removed entities block

Use this section in `entity-registry.md` to record entities considered but rejected.
Prevents AI from re-proposing the same entity in a later session.

```markdown
### <EntityName> ~~removed~~

**Reason:** <why it was rejected>
**Replaced by:** <entity or attribute that covers this instead>
**Decision ref:** design-decisions.md #<ID>
```

---

## Writing rules

1. **Never copy this template's boilerplate into `entity-registry.md`** — the data file stays clean.
2. One entity block per `###` heading. No sub-headings inside a block.
3. Every attribute row must have all 6 columns filled — use `—` for empty, never leave blank.
4. Every entity must trace to a requirement: fill **Source** before closing the task.
5. By end of Task 03, every row must have **Type**, **Nullable**, **Key**, and **Constraint / Enum** finalized — no `?` remaining.
6. Do not add indexes, FK graphs, or 3NF proofs here — those belong in `schema-registry.md`.