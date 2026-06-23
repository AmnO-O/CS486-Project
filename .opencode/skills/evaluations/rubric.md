# Evaluation Rubric

Use this rubric to evaluate database design agent outputs. Score each criterion from 0 to 5, then calculate:

```text
Weighted Score = Weight * Score
Total Score = Sum(Weighted Score)
```

## Score Scale

| Score | Meaning |
|---|---|
| 0 | Missing or seriously wrong |
| 1 | Very limited; many required parts missing |
| 2 | Present but shallow or contains many errors |
| 3 | Basic acceptable result |
| 4 | Good result with minor issues |
| 5 | Strong, complete, consistent, and well justified |

## Main Rubric

| Criterion | Weight | What To Check | Evidence |
|---|---:|---|---|
| Completeness of required outputs | 10% | Required files exist and required sections are present. | File list, section checklist |
| Requirement coverage | 20% | Requirements from the source file are fully reflected in analysis/design. Must explicitly document the time conflict constraint (no overlapping approved bookings) and status constraints (under_maintenance, temporarily_closed, retired cannot be booked) as top-priority business rules. | Coverage matrix, rule list |
| Database design correctness | 20% | Entities, relationships, cardinalities, tables, keys, and constraints are reasonable. The design must explicitly address the hardest booking rule: preventing conflicting bookings with overlapping time periods. **Crucially, for SQL Server, complex cross-table constraints (e.g., overlapping periods, unavailable room status checks, conditionally required fields) must specify database-level enforcement mechanisms (such as INSTEAD OF/AFTER Triggers or Filtered Indexes) rather than relying solely on application-layer logic.** | ERD, logical design, constraints |
| Traceability | 15% | Requirement -> business rule -> entity -> relationship -> table -> constraint/query can be followed. | Traceability matrices |
| Assumptions and open questions | 10% | Missing information is recorded explicitly; rules are not silently invented. | Assumption and question tables |
| Cross-file consistency | 10% | Names, statuses, entities, tables, and attributes remain consistent across artifacts. Status values must remain consistent with the statuses defined in the project requirements. | Naming review, entity-to-table matrix |
| SQL Server compatibility | 10% | SQL uses Microsoft SQL Server-compatible syntax and feasible constraints. | DDL checklist, SQL review evidence, and strict zero-error compile log from sqlcmd (using the latest logs/eval/task05/*-ddl-compile.log). |
| Query usefulness | 5% | Queries serve real requirements such as booking history, no-show, maintenance, and utilization. | Query purpose and requirement mapping |

## File-Level Checks

| File | Checks |
|---|---|
| `01-business-req-analysis-G<Group>.md` | Stakeholders, processes, explicitly identified business-critical constraints (especially time-overlap prevention and maintenance/status blocking), candidate entities, relationships, assumptions, open questions. Must include a clear Traceability Matrix mapping Requirements to Business Rules. |
| `02-erd-design-G<Group>.md` | Entity and Relationship descriptions/summaries. Mermaid `erDiagram` with correct Crow's Foot cardinality and participation constraints. **Conceptual Purity Check:** ERD must NOT include physical data types (e.g., VARCHAR), audit columns (created_at), or explicit Foreign Key attributes inside entities (FKs must be represented by relationship lines). Must document logical business constraints outside the ERD (e.g., role-based restrictions, unavailable space blocking). |
| `03-logical-design.md` | Tables, columns, PKs, FKs **(including explicit ON DELETE/ON UPDATE referential actions)**, datatypes, constraints **(including detailed logic for Triggers to handle cross-table business rules like BR1, BR2, BR8, BR9)**, **Index Strategy (Clustered, Non-clustered, Unique, Filtered)**, normalization, naming convention. |
| `04-design-validation.md` | Requirement coverage, rule coverage, anomaly checks, gap/risk log, fix recommendations.<br><br>**Additional requirements:**<br>- **Indexing & Partitioning:** Must include an evaluation of Indexing & Partitioning strategies (e.g., suggesting partitioning for >10M rows).<br>- **Registry Lock Status:** Must explicitly assess the sync state of schema/entity registries and provide a **Schema Freeze Recommendation**.<br>- **Conceptual vs Logical Delta:** Must correctly justify the intentional discrepancies between Conceptual ERD attributes (which omit audit/physical fields) and Logical Schema attributes (which include them). |
| `05-db-definition.sql` | SQL Server DDL, table creation order, PK/FK/CHECK/UNIQUE constraints, rule comments.<br><br>**Strict T-SQL Requirements:**<br>- Must start exactly with `SET QUOTED_IDENTIFIER ON` and `GO`.<br>- Every `CREATE TRIGGER` statement must be preceded by `GO` to ensure it is the first statement in its batch.<br>- Must strictly follow the constraint naming convention (`PK_`, `FK_`, `UQ_`, `CK_`).<br>- Must include mechanisms to prevent infinite trigger recursion (e.g., `IF NOT UPDATE(...)` for auto-stamp triggers). **Compilation Evidence:** Must be accompanied by the latest compile log (e.g., latest `logs/eval/task05/<timestamp>-05-ddl-compile.log`) proving the final script executes entirely without syntax, dependency, or batch errors via `sqlcmd` |
| `06-sample-data.sql` | Valid insert order, FK-safe data, realistic status scenarios, and intentional failing `INSERT` cases marked with comments such as `-- Expected error: ...` to prove constraints work. These negative cases should include invalid bookings for rooms that are `Under Maintenance` or `Retired`, and conflicting bookings with overlapping time periods. The task must also include a `logs/execution/task06/<timestamp>-output.txt` execution log from `sqlcmd`. File-level evaluation must check: valid seed sections have no unexpected SQL Server errors; the script is idempotent or rerunnable against pre-existing Task 06 sample data; every expected-error case has a corresponding captured error message; and captured expected errors prove the intended BR/constraint rather than unrelated `NULL`, FK, duplicate-key, or setup-cascade failures. |
| `07-query-design.sql` | Query purpose, requirement/report mapping, correct table/column usage. |

## Pipeline-Level Checks

| Check | Evidence |
|---|---|
| Entity in ERD becomes a table or justified logical structure. | ERD -> logical design matrix |
| Relationship in ERD becomes an FK or associative table. | Relationship -> FK matrix |
| Logical tables appear in DDL. | Logical design -> DDL comparison |
| Sample data matches DDL constraints. | Insert order and constraint review |
| Sample data executes cleanly where it should. | `logs/execution/task06/<timestamp>-output.txt` shows valid seed sections completed without unexpected SQL Server errors; if rerun evidence exists, the second run also avoids duplicate-key and NULL-cascade failures. |
| Sample data proves critical constraints through expected failures. | `06-sample-data.sql` includes commented negative `INSERT` cases with `-- Expected error: ...`, especially for unavailable room statuses and overlapping booking periods; `logs/execution/task06/<timestamp>-output.txt` shows a matching captured error for each expected-error case, and the captured message reflects the intended rule rather than a setup/cascade error. |
| Queries use existing tables and columns. | Query review |
| Business rules are preserved across the pipeline. | Requirement -> SQL/query traceability |
| Advanced logical constraints translate to DDL | Trigger logic and specialized indexes (e.g., filtered indexes) designed in `03-logical-design.md` are accurately implemented as valid T-SQL syntax in `05-db-definition.sql`. |
| **Iterative Validation** | Trajectory logs (`logs/trajectory/*`) show the agent proactively re-evaluating and updating the validation report (e.g., updating constraint coverage from Partial to Enforced) when earlier tasks/schemas are corrected. |