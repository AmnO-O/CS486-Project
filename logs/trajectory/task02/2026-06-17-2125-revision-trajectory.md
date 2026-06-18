---
task: "02"
task_name: "erd-design"
group: G05
run_at: "2026-06-17-2125"
status: completed
revision_of: "2026-06-13-1733-trajectory.md"
---

## 1. Plan
1. Read .opencode/skills/db-design-pipeline/02-erd/SKILL.md to check conceptual-ERD alignment.
2. Compare Task 02 output with Task 03 and schema-registry to ensure no content loss.
3. Edit SKILL.md Rule F: replace physical types (VARCHAR, TIMESTAMP, BOOLEAN) with conceptual types (string, datetime, boolean); add rules to omit audit columns and FK markers in entity blocks.
4. Edit outputs/02-erd-design-G05.md Section 2 Mermaid ERD: downgrade types to conceptual, remove audit columns (created_at, updated_at, is_deleted), remove FK markers from attribute blocks.
5. Write trajectory.

## 2. Steps (actual execution)
| # | action | target (file or check) | why |
|---|--------|------------------------|-----|
| 1 | read   | .opencode/skills/db-design-pipeline/02-erd/SKILL.md | Identify Rule F issues |
| 2 | read   | outputs/02-erd-design-G05.md | Full content for edit |
| 3 | read   | outputs/03-logical-design-G05.md | Verify content coverage |
| 4 | read   | docs/schema-registry.md | Verify content coverage |
| 5 | read   | docs/entity-registry.md | Verify content coverage |
| 6 | read   | docs/design-decisions.md | Verify content coverage |
| 7 | reason | (no file) | Verify no gap: all Task 02 logical constraints, decisions, relationships covered in Task 03 |
| 8 | edit   | .opencode/skills/db-design-pipeline/02-erd/SKILL.md | Fix Rule F types (VARCHAR→string, TIMESTAMP→datetime, BOOLEAN→boolean); add audit/FK omission rules; fix example FK |
| 9 | edit   | outputs/02-erd-design-G05.md | Conceptual cleanup: types → lowercase conceptual, remove audit columns, remove FK markers |
| 10 | write  | logs/trajectory/task02/2026-06-17-2125-revision-trajectory.md | Trajectory |

## 3. Files touched (summary)
- **Read:** .opencode/skills/db-design-pipeline/02-erd/SKILL.md, outputs/02-erd-design-G05.md, outputs/03-logical-design-G05.md, docs/schema-registry.md, docs/entity-registry.md, docs/design-decisions.md
- **Written:** .opencode/skills/db-design-pipeline/02-erd/SKILL.md, outputs/02-erd-design-G05.md

## 4. Outcome
- **Task completed:** yes
- **Assumptions made:** All physical details already captured in Task 03 + schema-registry — safe to remove from conceptual ERD.
- **Open questions raised:** none
- **Conflicts with docs/design-decisions.md:** none
- **Deviations from plan:** none
- **Self-detected errors and fixes:** none
