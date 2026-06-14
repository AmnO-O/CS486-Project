# Agent Metrics Rubric (Six Metrics)

Scores the agent's PROCESS (trajectory), complementing the artifact rubric in
`rubric.md`. Each metric is scored 0-5 using the same scale as `rubric.md`
(0 = missing/seriously wrong ... 5 = strong, complete, well justified).

Two groups:
- **Full-trace** (read the whole trajectory): PlanQuality, PlanAdherence,
  StepEfficiency, TaskCompletion.
- **Component-level** (inspect Files touched vs expected): ToolCorrectness,
  ArgumentCorrectness.

## Metric definitions and scoring anchors

### 1. PlanQuality (full-trace)
Is the plan in section 1 logical, complete, and efficient for the task?
- 5: Steps are ordered, cover all required inputs/outputs, no missing or wasteful steps.
- 4: Steps are mostly ordered and complete, with only small gaps that do not affect the final output.
- 3: Plan is workable but vague or misses a minor step.
- 2: Plan is incomplete, inefficient, or misses an important dependency, but still points toward the task.
- 1: Plan is incoherent, skips required inputs, or contradicts the pipeline order.
- Evidence: trajectory section 1 vs the task's expected inputs/outputs.

### 2. PlanAdherence (full-trace)
Did the actual steps (section 2) follow the plan (section 1)?
- 5: Execution matches the plan; any deviation is noted and justified in section 4. If a verification step fails (for example, a SQL run fails), the agent records it under `Self-detected errors and fixes`, explains the deviation, and successfully revises the code before completing the task.
- 4: Execution mostly follows the plan, with small justified adjustments that do not affect completeness.
- 3: Minor unexplained deviation.
- 2: Several deviations are unexplained or only partially aligned with the original plan.
- 1: Execution ignores the plan or does something else entirely.
- Evidence: section 1 vs section 2; check `deviations from plan` in section 4.

### 3. StepEfficiency (full-trace)
Were there redundant, repeated, or wasteful steps?
- 5: No redundant reads/writes; shortest reasonable path.
- 4: Mostly efficient, with one small avoidable step that does not slow the task materially.
- 3: One or two avoidable steps (e.g. a re-read that caching would avoid).
- 2: Multiple avoidable reads/writes or inefficient retries, but progress is still made.
- 1: Many redundant steps; same file read repeatedly; looping.
- Evidence: section 2 step count and repeats; compare to minimal expected path.

### 4. TaskCompletion (full-trace)
Did the agent actually complete the task's defined success criteria?
- 5: Output exists, status completed, success criteria met, assumptions/questions recorded. If the trajectory shows a self-detected error (for example, a failed SQL execution), the agent records the issue under `Self-detected errors and fixes` and successfully fixes the code before final completion.
- 4: Output exists and most success criteria are met, with only minor omissions or polish issues.
- 3: Output exists but a success criterion is partially unmet.
- 2: Output exists but multiple success criteria are incomplete or weakly satisfied.
- 1: Output missing or status failed.
- Evidence: section 4 + existence/quality of `outputs/0X-*`; cross-check artifact rubric.

### 5. ToolCorrectness (component-level)
Did the agent read/write the RIGHT files (per `expected-files.md`)?
- 5: All expected reads + writes present; nothing forbidden touched.
- 4: All required writes are present, with one minor expected read missing or one clearly harmless extra read.
- 3: Missing one expected input OR an extra harmless file.
- 2: Missing multiple expected inputs or touched extra files that create review noise but do not alter forbidden content.
- 1: Read/wrote mostly wrong files, but did not violate a hard forbidden-write rule.
- 0: Wrote a read-only/forbidden file (hard fail), e.g. edited a registry in task 05.
- Evidence: section 3 vs `expected-files.md` row for this task.

### 6. ArgumentCorrectness (component-level)
Were the targets/arguments of each action correct (right filename, right group
suffix, right direction read vs write)?
- 5: Correct `-G05` naming, correct paths, correct read/write direction.
- 4: Mostly correct targets/arguments, with one minor issue that does not affect file resolution or output validity.
- 3: Minor naming slip (e.g. wrong case) that still resolves.
- 2: Several argument mistakes require interpretation or cleanup, but the intended files are still identifiable.
- 1: Wrong filenames, wrong group suffix, or write where a read was expected.
- Evidence: section 2 `target` column vs naming convention in `project-overview.md`.

## Scoring output format

Produce a table:

| Metric | Score (0-5) | Evidence | Note |
|---|---|---|---|
| PlanQuality | | | |
| PlanAdherence | | | |
| StepEfficiency | | | |
| TaskCompletion | | | |
| ToolCorrectness | | | |
| ArgumentCorrectness | | | |

Process score = average of the six. Report alongside (not blended into) the
artifact score from `rubric.md`, so process and product stay separable.

## Notes
- A 0 on ToolCorrectness (forbidden write) should be called out as a blocking
  issue even if other metrics are high — it means the agent violated a hard rule.
- TaskCompletion can be high while StepEfficiency is low; that is expected and is
  exactly why both are scored.
