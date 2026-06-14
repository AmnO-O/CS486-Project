# Trajectory Template

A trajectory is the recorded "flight path" of one task run: the plan the agent intended, the steps it actually executed, the files it read/wrote, and the outcome. It is the **input data** for the six agent metrics. Without it, those metrics cannot be scored objectively.

## When to write it

Write **one trajectory file per task run**, immediately after generating or revising a `outputs/0X-*` artifact. 

## Where to save it

```text
logs/trajectory/task0X/<YYYY-MM-DD-HHMM>-trajectory.md
```

- One folder per task (`task01` ... `task07`).
- **Never overwrite.** Every run is a new timestamped file so improvement over time stays provable.
- "Latest wins": evaluators read the newest file in each `task0X/` folder.
- Timestamp uses 24h local time, e.g. `2026-06-12-1644-trajectory.md`.

## Field-to-metric mapping

| Section | Feeds metric |
|---|---|
| `plan` | PlanQuality |
| `steps` | PlanAdherence, StepEfficiency |
| `files_touched` | ToolCorrectness, ArgumentCorrectness |
| `outcome` | PlanAdherence, TaskCompletion |

---

## Template (copy everything below into the new file)

```markdown
---
task: "0X"                      # 01..07
task_name: "<short task name>"  # e.g. logical-design
group: G05
run_at: "YYYY-MM-DD-HHMM"
status: completed               # completed | partial | failed
revision_of: ""                 # filename of prior trajectory if this is a re-run, else ""
---

## 1. Plan
> The ordered steps the agent decided BEFORE acting. Keep it high-level. Replace the placeholders below with your real plan for THIS task.
1. ...
2. ...
3. ...

## 2. Steps (actual execution)
> One row per concrete action, in execution order. `action` is read | write | reason | verify.
>
> NOTE: the rows below are an EXAMPLE for Task 03 (logical-design) only. They are here to show the format, NOT fixed content. Delete them and fill in the real files of the task you are actually running. 

<!-- EXAMPLE (Task 03) — replace every row with your task's real actions -->
| # | action | target (file or check) | why |
|---|--------|------------------------|-----|
| 1 | read   | outputs/02-erd-design-G05.md | upstream input |
| 2 | reason | (no file)                    | derive PK/FK |
| 3 | write  | docs/schema-registry.md      | populate relations |
| 4 | write  | outputs/03-logical-design-G05.md | deliverable |
<!-- END EXAMPLE -->

## 3. Files touched (summary)
> Deduplicated lists. These are compared to the task's expected files.
>
> NOTE: the lists below are an EXAMPLE for Task 03 (logical-design) only.
> Replace them with the real files YOUR task read and wrote (they must match the rows in section 2). See `.opencode/skills/evaluations/expected-files.md` for the files each task is expected to touch.

<!-- EXAMPLE (Task 03) — replace with your task's real files -->
- **Read:** outputs/02-erd-design-G05.md, docs/entity-registry.md
- **Written:** docs/schema-registry.md, outputs/03-logical-design-G05.md
<!-- END EXAMPLE -->

## 4. Outcome
- **Task completed:** yes | no
- **Assumptions made:** A1: ...; A2: ...   (or "none")
- **Open questions raised:** Q1: ...        (or "none")
- **Conflicts with docs/design-decisions.md:** none | <describe + how resolved>
- **Deviations from plan:** none | <which step changed and why>
- **Self-detected errors and fixes:** none | <error found, evidence/check that failed, and how it was fixed>

---

## Authoring rules

- Be honest, not aspirational: section 2 records what actually happened, not the ideal path. A redundant re-read belongs in the log — that is exactly what StepEfficiency is meant to catch.
- If a verification step fails, record it in section 2 as a `verify` action and summarize the failure/fix under `Self-detected errors and fixes` in section 4.
- Keep it terse. The trajectory is read by the evaluator on every run, so bloat costs tokens. Aim for under one screen.
- Do not paste artifact content into the trajectory; reference files by path.
- `reason` rows have no file; use them only when a real decision was made.
