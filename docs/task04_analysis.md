# Task 04 — Design Validation Analysis

**Group:** G05
**Course:** CS486 — Introduction to Database System
**Domain:** Campus Space Management System
**Document purpose:** Analyze the design validation process (Task 04), explain each validation step, interpret the findings, and justify why the schema is ready to advance to DDL generation (Task 05).

---

## 1. Introduction

Design validation is the **gate** between logical design and physical implementation. Before writing a single `CREATE TABLE` statement, we must prove that the logical schema:

- Correctly represents the conceptual ERD
- Satisfies all business rules
- Uses appropriate keys and relationships
- Includes proper constraints
- Is normalized to at least 3NF

The validation report (`outputs/04-design-validation-G05.md`) evaluates the logical schema (`outputs/03`) against four reference artifacts: the ERD (`outputs/02`), business requirements (`outputs/01`), entity registry, and schema registry. This document walks through each validation step, explains its rationale, and interprets what the results mean for the project.

---

## 2. Validation Scope and Methodology

### 2.1 Artifacts Under Comparison

| Artifact | Role in Validation |
|---|---|
| `outputs/02-erd-design-G05.md` | Source of truth for entities, attributes, relationships, cardinalities, participation constraints |
| `outputs/01-business-req-analysis-G05.md` | Source of truth for business rules (BR1–BR14) |
| `docs/entity-registry.md` | Locked specification of all 9 entities, attributes, types, constraints |
| `docs/schema-registry.md` | Locked specification of tables, indexes, FK wiring, 3NF proof |
| `outputs/03-logical-design-G05.md` | **Target** — the schema being validated |

### 2.2 Six Evaluation Criteria

The validation applies six criteria derived from the Task 4 requirements (`req/business-requirement.md §2, Task 4`):

1. **Correctly represents the ERD** — every entity, attribute, and relationship from the ERD must appear in the logical schema with matching structure.
2. **Satisfies business rules** — every business rule must have a corresponding enforcement mechanism (CHECK, FK, UNIQUE, trigger, index).
3. **Uses appropriate keys** — every table must have a PRIMARY KEY; surrogate keys must be justified; business keys must have UNIQUE constraints.
4. **Uses appropriate relationships** — cardinalities, participation constraints, and referential integrity actions must match the ERD.
5. **Uses appropriate constraints** — NOT NULL, CHECK, UNIQUE, DEFAULT, and FK constraints must be complete and correct.
6. **Verifies Third Normal Form (3NF)** — the logical schema must be checked for 3NF compliance, ensuring that tables avoid partial dependencies, transitive dependencies, and unnecessary redundancy.

---

## 3. Step-by-Step Validation Analysis

### 3.1 ERD Fidelity (§2 of validation report)

**What was checked:**
- Every ERD entity maps to exactly one logical table (Entity Coverage — 9/9)
- Every attribute in the entity registry appears in the corresponding logical table with matching name, type, and nullability (Attribute Completeness)
- All 11 relationships (R1–R11) from the ERD are implemented via FK constraints or junction table

**Why this matters:** The ERD is the conceptual contract between the designers and the client. If even one entity or relationship is lost in translation, the database will fail to store or connect data that the client expects. A 9/9 entity match and 11/11 relationship match means **no concepts were dropped** during the ERD-to-relational translation.

**Result: ✅ Pass** — All entities, attributes, and relationships present with correct structure.

---

### 3.2 Business Rule Coverage (§3 of validation report)

**What was checked:**
A traceability matrix maps each business rule to its enforcement mechanism:

| Layer | Mechanisms Used | Coverage |
|---|---|---|
| Declarative constraints | CHECK, NOT NULL, UNIQUE, DEFAULT | BR3 (capacity), BR10 (unique IDs), BR11 (soft delete), BR12 (audit columns) |
| Indexes | Filtered unique index | BR1 (exact time collision prevention) |
| Triggers (12 total) | `AFTER INSERT, UPDATE` with `RAISERROR + ROLLBACK` | BR1 (interval overlap), BR2 (unavailable space), BR4 (maintenance check), BR6–BR9, BR15–BR19 |

**Why this matters:** The database must enforce business rules even if the application layer is bypassed. By implementing 19/19 business rules at the database level (triggers + constraints + indexes), the design ensures data integrity regardless of how the data is accessed.

**Key design philosophy:** Rules that require **cross-row or cross-table validation** (e.g., "no overlapping bookings for the same space") cannot be expressed with simple CHECK or FK constraints — they require triggers. The validation confirms that all 19 business rules have an appropriate mechanism.

**Result: ✅ Pass** — All 19 business rules are database-enforced. One minor documentation gap (BR19 missing from the numbered BR table in §7 of outputs/03, but the trigger exists) — see Finding F3.

---

### 3.3 Key Adequacy (§4 of validation report)

**What was checked:**
- Every table has a PRIMARY KEY
- Surrogate keys (INT IDENTITY) are justified
- Business keys have UNIQUE constraints
- The junction table (space_facilities) uses a natural composite PK

**Key analysis per table:**

| Table | PK | Justification |
|---|---|---|
| departments | `department_id` (surrogate) + `name` UNIQUE | Hybrid — efficient FK references + meaningful business lookup |
| users | `user_id` (surrogate) + `email` UNIQUE | Same hybrid pattern; email is the natural login identifier |
| spaces | `space_id` (surrogate) + `space_code` UNIQUE | Same pattern; space_code is human-readable (e.g., "CS-A201") |
| facilities | `facility_id` (surrogate) + `name` UNIQUE | Same pattern; prevents duplicate facility types |
| space_facilities | `(space_id, facility_id)` composite | Natural PK for a junction table; neither column alone is unique |
| bookings | `booking_id` (surrogate) | No natural business key exists |
| booking_approvals | `approval_id` (surrogate) + `booking_id` UNIQUE | Surrogate + UNIQUE on booking_id enforces 1:0..1 |
| booking_sessions | `session_id` (surrogate) + `booking_id` UNIQUE | Same pattern as approvals |
| maintenance | `maintenance_id` (surrogate) | No natural business key exists |

**Why this matters:** An incorrect PK strategy can cause performance problems (wide keys in clustered indexes), data integrity issues (non-unique rows), or join complexity (composite FKs everywhere). The hybrid surrogate + business key approach gives the best of both worlds.

**Result: ✅ Pass** — All tables have appropriate PKs. Surrogate keys used only where justified.

---

### 3.4 Relationship Translation (§5 of validation report)

**What was checked:**
- 1:N relationships → FK on the many side (NOT NULL = total participation, NULLABLE = partial)
- M:N relationship → junction table `space_facilities` with composite PK
- 1:0..1 relationships → FK + UNIQUE constraint on the child side

**Referential integrity actions verified:**

| FK | ON DELETE | Rationale |
|---|---|---|
| `space_facilities.space_id` → spaces | CASCADE | Junction is dependent child — if a space is deleted, its facility assignments are meaningless |
| `booking_approvals.booking_id` → bookings | CASCADE | Approval is dependent child — if a booking is deleted, its approval record cannot exist alone |
| `booking_sessions.booking_id` → bookings | CASCADE | Session is dependent child |
| All FKs → users | NO ACTION | Preserves historical records — deleting a user should not delete their booking/maintenance history |
| `maintenance.assigned_staff_id` → users | SET NULL | If assigned staff is deleted, the maintenance ticket survives (unassigned) |

**Why this matters:** The CASCADE vs NO ACTION vs SET NULL choice determines what happens when parent records are deleted. A wrong choice can cause either data loss (accidental cascade deletion of history) or orphan records (inability to delete legitimate parent records). The validation confirms every FK action is justified against business requirements.

**Result: ✅ Pass** — All 11 relationships translated correctly. Referential integrity actions respect business requirements.

---

### 3.5 Constraint Completeness (§6 of validation report)

**What was checked:**
An exhaustive inventory of every constraint type:

| Constraint Type | Count | Verification |
|---|---|---|
| NOT NULL | All required columns | ✅ All mandatory attributes are NOT NULL |
| CHECK | 8 total | ✅ capacity > 0, end_time > start_time, expected_participants > 0, 5 status/role enums |
| UNIQUE | 6 total | ✅ 4 business keys + 2 FK uniqueness for 1:0..1 |
| DEFAULT | Multiple | ✅ statuses, timestamps, is_deleted flags |
| FK | 12 total | ✅ All present with correct parent table and column |
| Triggers | 12 total | ✅ All documented with purpose and timing |

**Why this matters:** A missing constraint is a data integrity hole. The exhaustive inventory ensures no column is left unconstrained. Every column has at most one allowed null state, a defined domain (via CHECK), and appropriate referential integrity.

**Result: ✅ Pass** — All constraints present and correct. One optional improvement (F5: add CHECK on space_facilities.quantity).

---

### 3.6 Normalization Proof (§8 of validation report)

**3NF verification for all 9 tables:**

**1NF (Atomic columns, no repeating groups):**
- Every column holds a single atomic value
- No delimited lists or JSON/XML columns for multi-valued data
- The M:N space-facility relationship is resolved via `space_facilities` junction table instead of repeating group columns
- ✅ All 9 tables satisfy 1NF

**2NF (No partial dependencies):**
- Tables with single-column PKs are automatically in 2NF (partial dependency is impossible)
- The only composite PK table is `space_facilities(space_id, facility_id)` — its only non-key column `quantity` depends on the **full** composite key (both which space AND which facility). There is no partial dependency.
- ✅ All 9 tables satisfy 2NF

**3NF (No transitive dependencies):**
- Every non-key column depends solely on the primary key, not on another non-key column
- Foreign key columns (`department_id`, `space_id`, `requester_id`, etc.) are direct dependencies on the FK target's PK — they are **not** transitive dependencies
- Status enums use literal VARCHAR values with CHECK constraints, not integer codes from a separate table that would create a transitive dependency
- ✅ All 9 tables satisfy 3NF

**Why this matters:** Normalization to 3NF eliminates data redundancy (no duplicate storage of the same fact), prevents update anomalies (changing a fact in one place updates it everywhere), and prevents insertion anomalies (cannot create a record without its core identifier). The 3NF proof is a mathematical guarantee of sound schema design.

**Result: ✅ Pass** — All 9 tables satisfy 3NF. No partial or transitive dependencies.

---

## 4. Rationale for Each Validation Criterion

Each criterion exists to catch a specific class of design error. The sections below explain **why** each check is necessary, **what problem** it solves, and **what risk** is mitigated by passing it.

---

### 4.1 Correctly represents the ERD

**Question answered:** Does the logical schema faithfully translate the conceptual ERD?

**Why this criterion exists:** The ERD is the **conceptual contract** between the design team and the stakeholders (the School). It captures entities the business understands — "Spaces", "Bookings", "Maintenance" — and how they connect. The logical schema is a **translation** of that contract into relational terms (tables, columns, FKs). If translation errors occur, the database will not store or connect data the way the School expects.
<!-- 
**What specific errors it catches:**
- **Missing entity:** An entity from the ERD never became a table (e.g., `Facilities` exists in the ERD but not in the logical schema → equipment data has nowhere to live).
- **Orphan table:** A table exists in the schema that corresponds to no ERD entity (e.g., an extra `Incidents` table appears but was never agreed upon → scope creep or miscommunication).
- **Dropped attribute:** An attribute like `rejection_reason` is present in the ERD's `Booking_Approvals` but absent from the logical schema → the database cannot store rejection reasons even though the client explicitly requires it.
- **Wrong relationship:** The ERD says a booking can have at most one approval (1:0..1), but the schema has a simple FK without UNIQUE → a booking could have multiple approval records, breaking the business rule. -->

**Risk if this criterion were skipped:** The team would write `CREATE TABLE` statements based on an incomplete or incorrect understanding of the requirements. The database would pass syntax checks but fail to support core business workflows. Discovering this during implementation (Task 05) or testing (Task 06) would require costly schema changes.

---

### 4.2 Satisfies business rules

**Question answered:** Is every business rule enforced at the database level?

**Why this criterion exists:** Business rules define what the database **must not allow**. A correct ERD representation only ensures the database **can** store the right data — it does not guarantee it **will not** store wrong data. For example, nothing in table structure alone prevents two approved bookings from overlapping on the same space. The business rules (BR1–BR19) must be translated into enforcement mechanisms that actively reject invalid operations.

**Why database-level enforcement is required (defense-in-depth):**
- If enforcement exists only at the application layer, a bug in the application code or a direct SQL query to the database can violate business rules.
- Database-level enforcement (CHECK, FK, UNIQUE, triggers, filtered indexes) guarantees integrity **regardless of how data enters the system** — through the app, a migration script, a reporting tool, or an ad-hoc query.
- The traceability matrix (BR → mechanism) proves complete coverage: every rule has at least one enforcement object, and every enforcement object exists to serve a rule.

<!-- **What specific errors it catches:**
- **Missing rule enforcement:** A business rule documented in `outputs/01` has no corresponding CHECK, trigger, or index (e.g., "rejection must include a reason" is stated in requirements but no mechanism enforces it → rejected bookings can have NULL rejection_reason).
- **Weak enforcement level:** A rule that should be database-level is left to application code only (e.g., "only facility staff can approve" is documented but no trigger validates `approver_id`'s role → a student could be set as approver by directly inserting into `booking_approvals`).
- **Wrong enforcement mechanism:** A rule requiring cross-row logic (overlap detection) is implemented with a simple CHECK constraint (which cannot reference other rows) → the constraint never fires, overlaps go undetected. -->

**Risk if this criterion were skipped:** The database would store invalid states (double bookings, approvals by unauthorized users, missing rejection reasons). Data integrity would rely entirely on the correctness of application code, with no safety net.

---

### 4.3 Uses appropriate keys

**Question answered:** Does every table have a valid primary key strategy?

**Why this criterion exists:** A primary key is the fundamental guarantee that every row in a table is uniquely identifiable. Without a proper PK:
- Duplicate rows can be inserted, making it impossible to target a specific record.
- Foreign key references cannot be created or lose their target.
- Indexing and query performance suffer.

<!-- **What specific errors it catches:**
- **Missing PK:** A table has `NO CLUSTERED INDEX` or no PK constraint at all → duplicates allowed, no reliable row identity.
- **Wrong key type:** A business key (e.g., `email` VARCHAR(255)) is used as the clustered PK → FKs are wide (255 bytes each), join performance degrades, and email changes require cascading updates.
- **Unjustified surrogate:** A surrogate key is added to a table that already has a perfect natural PK (e.g., adding `departments.department_id` to a table where `name` is never updated and rarely used as FK → unnecessary column).
- **Missing business key UNIQUE:** A surrogate PK is used without a UNIQUE constraint on the natural business key → duplicates in the business domain are possible (two users with the same email, two spaces with the same space_code). -->

**Key design decision validated:** The hybrid approach (surrogate INT IDENTITY PK + UNIQUE on business key) is the most efficient pattern for most tables. It gives small, fast FKs (INT) while keeping the natural key available for direct lookup and data integrity.

**Risk if this criterion were skipped:** The database might accept duplicate emails (two user accounts for the same person), duplicate space codes (confusion about which room is which), or suffer from slow joins due to wide VARCHAR PKs used as FK targets.

---

### 4.4 Uses appropriate relationships

**Question answered:** Are all ERD relationships implemented with correct cardinality, FK placement, and referential integrity actions?

**Why this criterion exists:** The ERD defines **how entities connect** — who books what space, who approves which booking, which equipment is in which room. Translating these connections into FKs is the most error-prone step of logical design. A wrong FK placement, a missing UNIQUE on a 1:0..1 relationship, or an inappropriate ON DELETE action can break the data model in subtle ways.

<!-- **What specific errors it catches:**
- **Wrong cardinality implementation:**
  - A 1:N relationship has the FK on the wrong side → data is stored backwards.
  - An M:N relationship has no junction table → forced to use repeating columns (`facility_1`, `facility_2`, ...) or delimited strings, violating 1NF.
  - A 1:0..1 relationship has a simple FK without UNIQUE → multiple child rows exist when only one is allowed (e.g., two approval records for one booking).
- **Wrong participation implementation:**
  - The ERD says a User total on Bookings (every booking has a requester), but `bookings.requester_id` is nullable → bookings without a requester are allowed.
  - The ERD says Maintenance assignee is partial (may not be assigned yet), but `maintenance.assigned_staff_id` is NOT NULL → every maintenance ticket must have an assignee immediately.
- **Wrong referential integrity action:**
  - ON DELETE CASCADE on `bookings.requester_id → users` → deleting a user also deletes all their booking history (violates BR11 — historical records preservation).
  - ON DELETE NO ACTION on `booking_approvals.booking_id → bookings` → if a booking is deleted, its approval record becomes an orphan (FK violation blocks the deletion). -->

**Risk if this criterion were skipped:** The database would either (a) allow structurally invalid data (e.g., two approvals per booking), (b) lose historical data through unintended cascades, or (c) prevent legitimate operations (e.g., cannot delete a booking because its approval record blocks it with NO ACTION, even though the approval is dependent).

---

### 4.5 Uses appropriate constraints

**Question answered:** Are all data domains properly constrained?

**Why this criterion exists:** Foreign keys alone are not enough — they only guarantee that references point to existing rows. Constraints define the **allowed values, required fields, and business boundaries** for every column. Without exhaustive constraints, the database accepts any data the application sends, including values that are semantically meaningless or harmful.

<!-- **What specific errors it catches:**
- **Missing NOT NULL:** A mandatory column like `bookings.space_id` is nullable → a booking can be created for no space.
- **Missing CHECK:** `spaces.capacity` has no `CHECK (capacity > 0)` → a space can have capacity 0 or -5, which makes participant limit checking impossible.
- **Missing UNIQUE:** `users.email` has no UNIQUE constraint → two users can register with the same email, causing login ambiguity.
- **Missing DEFAULT:** `users.account_status` has no DEFAULT → new users are created with NULL status instead of 'active', breaking the application's assumption.
- **Missing FK:** `bookings.space_id` has no FK → a booking can reference a non-existent space.
- **Incorrect CHECK domain:** `bookings.purpose` CHECK includes values not in the requirements (e.g., 'party') or misses required values (e.g., 'examination'). -->

**Why exhaustive inventory matters:** Each missing constraint is a data integrity hole. A CHECK constraint weighs a few bytes and costs nothing at query time (it is evaluated once per INSERT/UPDATE). The cost of a missing constraint is potentially millions of rows of garbage data that must be cleaned up later.

**Risk if this criterion were skipped:** The database silently accepts invalid data — negative capacity, bookings without a space, users without a role, spaces with contradictory status values. Data quality degrades over time, and every query must filter out bad rows manually.

---

### 4.6 Verifies Third Normal Form (3NF)

**Question answered:** Does the schema avoid data redundancy and update anomalies?

**Why this criterion exists:** Normalization is the **mathematical foundation** of relational database design. The project requirements explicitly state "schema must be normalized to at least 3NF" (`docs/project-overview.md`). 3NF is not optional — it is a correctness standard. A schema that fails 3NF has structural flaws that cause data integrity problems over time.

<!-- **What specific errors it catches:** -->

<!-- **1NF (Atomic columns, no repeating groups):**
- **Repeating group columns:** `facility_1`, `facility_2`, `facility_3` columns on `Spaces` to store multiple facilities → violates 1NF because the space-facility relationship is M:N, and these columns are a repeating group.
- **Non-atomic values:** A single column stores multiple values as a delimited string (e.g., `facilities = "projector, AC, whiteboard"`) → violates 1NF because you cannot query individual facilities with standard SQL.

**2NF (No partial dependencies):**
Only applies to tables with composite PKs. In our schema, the only composite PK is `space_facilities(space_id, facility_id)`.
- **Partial dependency example (hypothetical):** If `space_facilities` had a column `building_name` that depends only on `space_id` (not on `facility_id`), the building would be repeated for every facility in the same space → update anomaly (changing the building requires updating multiple rows).
- **Verification result:** `space_facilities.quantity` depends on the **full** composite key (both space AND facility). No partial dependency exists.

**3NF (No transitive dependencies):**
- **Transitive dependency example (hypothetical):** If `users` had a column `department_name` that depends on `department_id` (which depends on `user_id`), then `department_name` is transitively dependent on `user_id`. If the department name changes, every user row referencing it must be updated → update anomaly.
- **Verification result:** No table stores data that depends on a non-key column. `users.department_id` is an FK (a reference to another entity's PK), not a transitive dependency. -->

**Why normalization is not optional:**
- Without 3NF, the same fact is stored in multiple places (redundancy).
- Redundancy causes **update anomalies** (updating a fact in one place but not another creates inconsistency).
- Redundancy causes **insertion anomalies** (cannot add a new facility type without first assigning it to a space).
- Redundancy causes **deletion anomalies** (deleting the last space that has a projector also deletes the projector record).

**Risk if this criterion were skipped:** The schema would pass the other five criteria (it would be structurally complete, enforce business rules, and have correct keys) but would contain hidden redundancy that corrupts data over time through update anomalies. A 3NF violation is a **slow-acting defect** — it does not cause immediate errors but produces inconsistent data as the system operates.

---

## 5. Discrepancy Log Analysis (F1–F6)

The validation found **6 minor issues, zero critical or major issues**. This is a strong result — it means the design is structurally and functionally correct, and the only problems are documentation clarity.

### F1–F2: Ambiguous participation wording in entity-registry

**Issue:** The entity-registry described R3 and R4 participation as "Booking_Approvals partial" and "Booking_Sessions partial", but the correct interpretation is: *Users'* participation is partial (not all users are approvers/check-in staff), while Booking_Approvals/Booking_Sessions participation is **total** (every record has an approver/check-in staff — `approver_id`/`checked_in_by` are NOT NULL).

**Why minor:** The ambiguity is only in the documentation wording. The actual schema implementation is correct (NOT NULL constraints on the FK columns). No structural change is needed.

**Fix:** Clarify the entity-registry note to separate the two sides of participation.

### F3: BR19 numbering gap

**Issue:** The trigger `trg_maintenance_completion_space_status` (maintenance completion restores space status, i.e., BR19) exists and is documented in the trigger details section of `outputs/03`, but is missing from the numbered Business Rule table (§7) which ends at BR18.

**Why minor:** The trigger **exists and functions correctly**. The gap is only in the numbered list — the rule is defined in the schema-registry (line 334) and implemented via trigger. This is a table-of-contents issue.

**Fix:** Add BR19 to the numbered BR table in `outputs/03` §7.

### F4: Schema registry freeze date out of sync

**Issue:** The schema registry's "Design validation passed" date (2026-06-17/18) predates the latest logical schema version (2026-07-01).

**Why minor:** Date metadata does not affect schema correctness. The schema registry content is already updated for the 9-table, 30-index design.

**Fix:** Update the freeze date after this validation report is accepted.

### F5: Missing CHECK on space_facilities.quantity

**Issue:** `space_facilities.quantity` has no CHECK constraint. If an application submits quantity = 0 or a negative number, it would be accepted.

**Why minor:** The column is nullable (quantity is optional). Adding `CHECK (quantity IS NULL OR quantity > 0)` is a defensive improvement but not a data integrity emergency — negative quantity would be an application bug, not a schema flaw.

**Fix:** Add the suggested CHECK constraint.

### F6: Misleading trigger timing wording

**Issue:** Trigger descriptions in `outputs/03` §7 use "Before insert/update" wording, but the triggers are actually `AFTER INSERT, UPDATE` triggers that use `RAISERROR + ROLLBACK` to abort.

**Why minor:** The triggers work correctly regardless of the documentation wording. The "Before" vs "AFTER" distinction is academic when the trigger always rolls back on violation.

**Fix:** Update trigger descriptions to accurately state "AFTER INSERT, UPDATE — validates and rolls back if constraint violated".

### Summary of findings

| Finding | Severity | Category | Schema Impact |
|---|---|---|---|
| F1 | Minor | Documentation | None — schema correct |
| F2 | Minor | Documentation | None — schema correct |
| F3 | Minor | Documentation | None — trigger exists and works |
| F4 | Minor | Documentation | None — date metadata only |
| F5 | Minor | Constraint improvement | Low — optional improvement |
| F6 | Minor | Documentation | None — wording only |

---

## 6. What "Schema Freeze Ready" Means

The validation verdict is: **SCHEMA FREEZE READY — with deferred minor documentation fixes.**

A "schema freeze" means the logical design is considered final and locked. After this point:
- No structural changes (new tables, columns, relationships, constraints) may be made without revisiting validation
- Only documentation fixes and the optional quantity CHECK improvement are permitted
- DDL generation (Task 05) can proceed using the locked schema

The verdict is justified because:

| Condition | Status | Evidence |
|---|---|---|
| All entities present | ✅ | 9/9 mapped, 0 orphan tables |
| All attributes match | ✅ | Attribute counts match exactly per entity |
| All relationships correct | ✅ | R1–R11 implemented with correct cardinality |
| All business rules enforced | ✅ | BR1–BR19 all database-level enforced |
| 3NF satisfied | ✅ | All 9 tables pass 1NF → 2NF → 3NF |
| Keys appropriate | ✅ | Every table has PK; surrogates justified |
| No structural errors | ✅ | 0 critical, 0 major findings |
| Only documentation gaps | ✅ | F1–F6 all minor, none block schema freeze |

---

## 7. Conclusion

The design validation process has proven that the Campus Space Management System logical schema:

1. **Correctly represents the ERD** — every entity, attribute, and relationship is faithfully translated from conceptual to relational model.
2. **Satisfies all 19 business rules** — enforced at the database level through a combination of CHECK constraints, UNIQUE constraints, FOREIGN KEY constraints, filtered indexes, and 12 database triggers. This means data integrity is guaranteed even if the application layer is bypassed or contains bugs.
3. **Uses appropriate keys** — the hybrid surrogate + business key strategy balances join efficiency with data integrity. Every table has a clear primary key. 1:0..1 relationships are enforced via UNIQUE constraints on foreign keys.
4. **Uses appropriate relationships** — cardinalities match the ERD exactly. Referential integrity actions are chosen to preserve historical records (NO ACTION on user references, CASCADE on dependent children, SET NULL on optional maintenance assignment).
5. **Uses appropriate constraints** — every column is properly constrained. No missing NOT NULL, CHECK, UNIQUE, DEFAULT, or FOREIGN KEY constraints. The only gap (quantity CHECK) is an optional improvement.

**The schema is ready for Task 05 (DDL Generation).** The six minor findings (F1–F6) are documentation-level issues that do not affect schema correctness. They can be resolved in parallel with DDL implementation.

---

*Generated for CS486 Group G05 — Campus Space Management System*
