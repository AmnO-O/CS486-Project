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
| Requirement coverage | 20% | Requirements from the source file are reflected in analysis/design. | Coverage matrix, rule list |
| Database design correctness | 20% | Entities, relationships, cardinalities, tables, keys, and constraints are reasonable. | ERD, logical design, constraints |
| Traceability | 15% | Requirement -> business rule -> entity -> relationship -> table -> constraint/query can be followed. | Traceability matrices |
| Assumptions and open questions | 10% | Missing information is recorded explicitly; rules are not silently invented. | Assumption and question tables |
| Cross-file consistency | 10% | Names, statuses, entities, tables, and attributes remain consistent across artifacts. | Naming review, entity-to-table matrix |
| SQL Server compatibility | 10% | SQL uses Microsoft SQL Server-compatible syntax and feasible constraints. | DDL checklist, SQL review/run evidence |
| Query usefulness | 5% | Queries serve real requirements such as booking history, no-show, maintenance, and utilization. | Query purpose and requirement mapping |

## File-Level Checks

| File | Checks |
|---|---|
| `01-business-requirement-analysis.md` | Stakeholders, processes, business rules, candidate entities, relationships, assumptions, open questions, traceability. |
| `02-conceptual-design-erd.md` | Entity catalog, relationship catalog, Mermaid `erDiagram`, Crow's Foot cardinality, traceability. |
| `03-logical-design.md` | Tables, columns, PKs, FKs, datatypes, constraints, normalization, naming convention. |
| `04-design-validation.md` | Requirement coverage, rule coverage, anomaly checks, gap/risk log, fix recommendations. |
| `05-db-definition.sql` | SQL Server DDL, table order, PK/FK/CHECK/UNIQUE constraints, rule comments. |
| `06-sample-data.sql` | Valid insert order, FK-safe data, realistic status scenarios. |
| `07-query-design.sql` | Query purpose, requirement/report mapping, correct table/column usage. |

## Pipeline-Level Checks

| Check | Evidence |
|---|---|
| Entity in ERD becomes a table or justified logical structure. | ERD -> logical design matrix |
| Relationship in ERD becomes an FK or associative table. | Relationship -> FK matrix |
| Logical tables appear in DDL. | Logical design -> DDL comparison |
| Sample data matches DDL constraints. | Insert order and constraint review |
| Queries use existing tables and columns. | Query review |
| Business rules are preserved across the pipeline. | Requirement -> SQL/query traceability |


