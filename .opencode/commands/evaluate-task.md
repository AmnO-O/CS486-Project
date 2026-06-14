---
description: Evaluate a single task run (artifact + trajectory) against the rubrics and write an eval log
---

Command: evaluate-task

Purpose:
Score ONE task in isolation to keep token and time cost low. Reads only that
task's output, its latest trajectory, and the one relevant expected-files row.
Use this for normal task-by-task work.

Usage:
```
evaluate-task --task 0X
# example
evaluate-task --task 03
```

Inputs to read (and nothing else):
- `outputs/0X-<task-name>-G05.*` (the artifact)
- newest file in `logs/trajectory/task0X/` (the trajectory; "latest wins")
- the matching row in `.opencode/skills/evaluations/expected-files.md`
- `.opencode/skills/evaluations/rubric.md` (artifact criteria + that task's File-Level Checks)
- `.opencode/skills/evaluations/agent-metrics-rubric.md` (the six metrics)

Do NOT read: other `outputs/` files, `node_modules/`, `.git/`, or unrelated tasks.

Steps:
1. Resolve `0X` to the task name and locate the artifact and the latest trajectory.
   - If no trajectory exists, stop and report: "No trajectory for task 0X — run the
     task with trajectory recording enabled before evaluating."
2. Artifact score: apply the relevant rows of `rubric.md` (weighted criteria) plus
   the File-Level Checks for this task. Produce per-criterion scores 0-5.
3. Process score: apply `agent-metrics-rubric.md` to the trajectory. Produce the
   six-metric table with evidence.
4. Write the eval log (do not overwrite):
   `logs/eval/task0X/<YYYY-MM-DD-HHMM>-eval.md`
5. Summary line back to the user: artifact score, process score (avg of six), and
   the top 1-3 improvement actions.

Output log structure:
```markdown
---
task: "0X"
group: G05
evaluated_at: "YYYY-MM-DD-HHMM"
trajectory: "logs/trajectory/task0X/<file>"
artifact: "outputs/0X-...-G05.*"
---

## Artifact score (from rubric.md)
| Criterion | Weight | Score (0-5) | Weighted | Evidence |
| ... |
**Artifact total:** <weighted sum>

## Process score (from agent-metrics-rubric.md)
| Metric | Score (0-5) | Evidence | Note |
| ... |
**Process average:** <avg of six>


## Top improvements
1. ...
2. ...
```

Notes:
- Keep artifact score and process score SEPARATE; do not blend them.
- A ToolCorrectness of 0 (forbidden write) is a blocking issue — surface it first.
- This command never modifies `outputs/`; it only writes under `logs/eval/`.