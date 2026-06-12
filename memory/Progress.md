# Progress — CS486 DB Design Pipeline

## Pipeline status

| Task | Deliverable | Output file | Status | Depends on |
|---|---|---|---|---|
| Task 1 | Business analysis | `outputs/01-business-req-analysis-G05.md` | ✅ Approved | — |
| Task 2 | ERD design | `outputs/02-erd-design-G05.md` | ⬜ Not started | Task 1 |
| Task 3 | Logical design | `outputs/03-logical-design-G05.md` | ⬜ Not started | Task 2 |
| Task 4 | Design validation | `outputs/04-design-validation-G05.md` | ⬜ Not started | Task 3 |
| Task 5 | SQL DDL | `outputs/05-ddl-G05.sql` | ⬜ Not started | Task 4 ✅ freeze |
| Task 6 | Sample data | `outputs/06-sample-data-G05.sql` | ⬜ Not started | Task 5 |
| Task 7 | Query design | `outputs/07-query-design-G05.sql` | ⬜ Not started | Task 5 |
| — | Logs agent improvement | `docs/changelog/` | ⬜ ongoing | — |
| — | Git repository | — | ⬜ Not started | — |
| — | Report PDF | `outputs/report-G05.pdf` | ⬜ Not started | All tasks |
| — | SCHEMA FREEZE | — | ⬜ Not started | Task 4 — all 4 must approve |

## Status legend

- ⬜ Not started
- 🔄 In progress
- ✅ Approved — safe to use as upstream input
- ⚠️ Needs revision — do not use as upstream input

---

## Critical gate: SCHEMA FREEZE

**Task 5, 6, 7 cannot start until SCHEMA FREEZE is reached.**

SCHEMA FREEZE requires all 4 group members to approve Task 4 (Design validation).
Once frozen, the schema in `outputs/04-design-validation-G05.md` becomes
the locked upstream input for DDL, sample data, and queries.

Do NOT generate DDL or sample data before this gate.

---

## Decisions log

_(Record key decisions here so future sessions don't re-debate them)_

| Date | Decision | Reason |
|---|---|---|
| 2026-06-12 | Task 01 output filename: `01-business-req-analysis-G05.md` | Matches required naming in `req/business-requirement.md` §3.2 |
| 2026-06-12 | 7 entities defined: Users, Departments, Spaces, Facilities, Space_Facilities, Bookings, Maintenance | Directly derived from requirement sections |
| 2026-06-12 | Assumption: Users have unique emails | Natural business key |
| 2026-06-12 | Assumption: Soft deletes for bookings/maintenance | Historical records requirement |

---

## Known open questions

_(Unresolved items — must answer before moving to next task)_

1. Rejection reason — separate column or part of decision note?
2. Usage policy — free text or coded rules?
3. Building/floor — reference tables or varchar fields?
4. No-show detection — automatic or manual?

---

## How to update this file

After completing each task:
1. Change status to ✅ Approved or ⚠️ Needs revision
2. Add key decisions to the decisions log
3. Update `memory/activeContext.md` for the next task