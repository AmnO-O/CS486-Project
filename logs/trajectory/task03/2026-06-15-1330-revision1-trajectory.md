---
task: "03"
task_name: "logical-design (revision 1)"
group: G05
run_at: "2026-06-15-1330"
status: completed
revision_of: "2026-06-15-1230-trajectory.md"
---

## 1. Plan
1. Read current outputs/03-logical-design-G05.md and evaluation log
2. Identify low-scoring criteria: DB design correctness (4/5) and assumptions/open questions (4/5)
3. For DB correctness: add filtered unique index for BR1 exact-start overlap, replace vague "application-level" with concrete trigger definitions for all cross-table/cross-row constraints
4. For assumptions: resolve Q3 (maintenance auto-status) and Q4 (auto no-show)
5. Update schema-registry.md with new filtered index
6. Update design-decisions.md with Q3/Q4 decision entries
7. Update progress.md to mark all open questions resolved
8. Update entity-registry revision log
9. Write revision trajectory

## 2. Steps (actual execution)

| # | action | target | why |
|---|--------|--------|-----|
| 1 | read | outputs/03-logical-design-G05.md | current output to identify improvements |
| 2 | read | logs/eval/task03/2026-06-15-1230-eval.md | evaluation with scores and improvement suggestions |
| 3 | edit | outputs/03-logical-design-G05.md | added filtered unique index uq_bookings_active_overlap in §4 |
| 4 | edit | outputs/03-logical-design-G05.md | rewrote §4 index notes to explain overlap strategy |
| 5 | edit | outputs/03-logical-design-G05.md | rewrote BR table with concrete trigger names in §7 |
| 6 | edit | outputs/03-logical-design-G05.md | replaced generic cross-column section with 7 trigger definitions |
| 7 | edit | outputs/03-logical-design-G05.md | replaced generic ON DELETE with per-FK rules in §3 |
| 8 | edit | outputs/03-logical-design-G05.md | added Q3 and Q4 resolutions to ambiguities table |
| 9 | edit | outputs/03-logical-design-G05.md | added revision log at end, updated status line |
| 10 | edit | docs/schema-registry.md | added uq_bookings_active_overlap index |
| 11 | edit | docs/design-decisions.md | added Q3 and Q4 decision entries |
| 12 | edit | docs/design-decisions.md | updated revision log |
| 13 | edit | docs/entity-registry.md | updated revision log |
| 14 | edit | memory/Progress.md | replaced open questions with resolved table |
| 15 | write | logs/trajectory/task03/2026-06-15-1330-revision1-trajectory.md | this file |

## 3. Files touched (summary)

- **Read:** outputs/03-logical-design-G05.md, logs/eval/task03/2026-06-15-1230-eval.md
- **Written:** outputs/03-logical-design-G05.md, docs/schema-registry.md, docs/design-decisions.md, docs/entity-registry.md, memory/Progress.md, logs/trajectory/task03/2026-06-15-1330-revision1-trajectory.md

## 4. Outcome

- **Task completed:** yes
- **Assumptions made:** None new
- **Open questions raised:** None — all 5 ambiguities (Q1–Q5) resolved
- **Conflicts with docs/design-decisions.md:** None
- **Deviations from plan:** None
- **Self-detected errors and fixes:** None
