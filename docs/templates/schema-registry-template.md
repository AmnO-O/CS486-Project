# Schema Registry — Format Spec & Template

> Format spec only. Actual data lives in `docs/schema-registry.md`.
> Read this when **writing/updating** the registry (Task 03, 04). Skip when only reading (05–07).
> 3NF proof, normalization narrative, and business-rule coverage belong in `outputs/04-design-validation-G05.md`, not here.

---

## Canonical table block

```markdown
### <table_name>

**Status:** ⬜ draft | 🔄 refining | 🔒 locked
**Maps from entity:** `<EntityName>` (see entity-registry.md)
**Primary key:** `<column>` (surrogate) | `<col1>, <col2>` (composite)

**Columns:**

| Column | Type | Nullable | Key | Constraint / Default | Notes |
|---|---|---|---|---|---|
| <name> | <SQL Server type> | NO/YES | PK/FK/UQ/— | `CHECK (...)` / `DEFAULT GETDATE()` / `FK → table.col` | <note> |

**Foreign keys:** *(only if any — omit section if none)*
| Column | References | On Delete | On Update |
|---|---|---|---|
| <fk_column> | `<table>.<column>` | CASCADE / NO ACTION / SET NULL | CASCADE / NO ACTION |
```

For **junction tables** (M:N resolution), replace `Maps from entity` with `Resolves relationship: <A> ↔ <B> (R<N>)` and use a composite PK of both FK columns. No other structural difference.

---

## Column rules

| Column | Rule |
|---|---|
| **Type** | Final SQL Server type, no `?` allowed: `INT`, `NVARCHAR(n)`, `DATETIME2`, `BIT`, `DECIMAL(p,s)`, `UNIQUEIDENTIFIER`, … |
| **Nullable** | `NO` or `YES` only. |
| **Key** | `PK`, `FK`, `UQ`, `PK/FK`, or `—`. |
| **Constraint / Default** | `CHECK (...)`, `DEFAULT <expr>`, or `FK → table.col`. `—` if none. |
| **Notes** | Assumption refs, open questions, **application-level constraints not expressible in SQL** (e.g. "approver_id must be facility_staff/facility_manager — enforced in app, see DD-0X"), or `—`. |

---

## Status legend

| Icon | Meaning |
|---|---|
| ⬜ draft | First-pass transcription from logical design (Task 03 start) |
| 🔄 refining | Actively adjusting FK wiring / constraints (Task 03 mid) |
| 🔒 locked | **LOCK GATE passed** — Task 04 confirmed it satisfies its business rules. No changes without consensus. |

**LOCK GATE:** Task 05 (DDL) only transcribes 🔒 tables. If any table isn't 🔒, stop and flag instead of generating DDL.

---

## Required summary block (top of file)

```markdown
## Table inventory

| # | Table | Type | Status | Maps from |
|---|---|---|---|---|
| 1 | <table_name> | entity / junction | 🔒 | EntityName or R<N> |

## CREATE TABLE dependency order
*(parents before children — Task 05 reads this directly)*
1. <table>
2. <table>
```

---

## Removed / merged tables *(add only when it happens)*

```markdown
### <table_name> ~~removed~~
**Reason:** <why> · **Replaced by:** <table> · **Decision ref:** design-decisions.md #<ID>
```

---

## Writing rules

1. Never copy this template's boilerplate into `schema-registry.md` — keep the data file clean.
2. One table per `###` heading, no `?` remaining once status is 🔒.
3. FK is documented only on the **child** table, never duplicated on the parent.
4. Update `CREATE TABLE dependency order` every time a table is added.
5. No indexes unless a known query pattern requires one — don't speculate.
6. Any FK or constraint that the business rules require but SQL cannot express (role checks, cross-row overlap rules, conditional requiredness) **must** get a Notes entry pointing to the enforcing layer — either `application-level, see design-decisions.md DD-0X` or a forward note that DD-0X needs to be created. A table cannot be set to 🔒 with an unexplained gap like this.