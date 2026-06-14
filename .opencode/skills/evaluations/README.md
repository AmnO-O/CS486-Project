# Evaluation System README

This folder defines the evaluation framework for the CS486 G05 database design
agent. It evaluates both the final database design artifacts and the process the
agent used to create them.

- Agent evaluation should measure both reasoning and action, not only the final
  answer. Source: [DeepEval - AI Agent Evaluation](https://deepeval.com/guides/guides-ai-agent-evaluation).
- Multi-step agents need trajectory-based evaluation to detect silent failures,
  such as reading the wrong source file while still producing plausible output.
  Source: [Google Cloud - A methodical approach to agent evaluation](https://cloud.google.com/blog/topics/developers-practitioners/a-methodical-approach-to-agent-evaluation).
- Evaluation should combine end-to-end artifact quality with component-level
  checks for tool choice, file access, arguments, and side effects. Sources:
  [Braintrust - What is agent evaluation?](https://www.braintrust.dev/articles/agent-evaluation)
  and [Openlayer - Agent evaluation complete guide](https://www.openlayer.com/blog/post/agent-evaluation-complete-guide-testing-ai-agents).
- Every task should have measurable success criteria and expected inputs/outputs.
- Evaluation should become a quality gate before a task is marked complete.
  Source: [Google Cloud - A methodical approach to agent evaluation](https://cloud.google.com/blog/topics/developers-practitioners/a-methodical-approach-to-agent-evaluation).

## Evaluation Layers

The evaluation system has two separate scores:

| Layer | Purpose | Main file |
|---|---|---|
| Artifact quality | Scores the generated database design output. | `rubric.md` |
| Agent process quality | Scores the trajectory: plan, steps, files touched, and outcome. | `agent-metrics-rubric.md` |

These scores must stay separate. A task can produce a useful artifact while still
using an inefficient or unsafe process, and the evaluator should make that visible.
This follows the recommendation to evaluate both end-to-end success and
step-level behavior. Source: [Braintrust - What is agent evaluation?](https://www.braintrust.dev/articles/agent-evaluation).

## Trajectory Recording

`trajectory-recording.md` defines the hard rule: after generating or revising any
`outputs/0X-*` artifact, the agent must write a trajectory before reporting the
task as complete.

Trajectory files are saved as:

```text
logs/trajectory/task0X/<YYYY-MM-DD-HHMM>-trajectory.md
```

The detailed format lives in:

```text
templates/trajectory-template.md
```

Each trajectory records:

- the original plan,
- the actual execution steps,
- the files read and written,
- the outcome,
- deviations from plan,
- self-detected errors and fixes, if any.

The trajectory is the input for the six process metrics. Evaluation commands may
read trajectories, but generation tasks must not read old `logs/` files.
Trajectory-based evaluation is important because failures can happen in the
execution path even when the final output looks plausible. Sources:
[Google Cloud - A methodical approach to agent evaluation](https://cloud.google.com/blog/topics/developers-practitioners/a-methodical-approach-to-agent-evaluation)
and [Openlayer - Agent evaluation complete guide](https://www.openlayer.com/blog/post/agent-evaluation-complete-guide-testing-ai-agents).

## Evaluation Files

| File | Role |
|---|---|
| `rubric.md` | Artifact rubric. Scores outputs from 0 to 5 across completeness, requirement coverage, database correctness, traceability, assumptions, consistency, SQL Server compatibility, and query usefulness. |
| `agent-metrics-rubric.md` | Process rubric. Scores PlanQuality, PlanAdherence, StepEfficiency, TaskCompletion, ToolCorrectness, and ArgumentCorrectness from the trajectory. |
| `expected-files.md` | Expected reads/writes per task. Used to score ToolCorrectness and ArgumentCorrectness. It also marks forbidden writes and read-only files. |
| `trajectory-recording.md` | Rule for when a trajectory is required and where it must be saved. |
| `templates/trajectory-template.md` | Copyable template for trajectory logs. Defines the exact sections consumed by the evaluator. |

The six process metrics are based on common agent-evaluation dimensions:
PlanQuality, PlanAdherence, TaskCompletion, StepEfficiency, ToolCorrectness, and
ArgumentCorrectness. Sources:
[DeepEval - AI Agent Evaluation](https://deepeval.com/guides/guides-ai-agent-evaluation)
and [Daily Dose of DS - Six Key Metrics for AI Agent Evaluation](https://blog.dailydoseofds.com/p/six-key-metrics-for-ai-agent-evaluation).

## Commands

### `evaluate-task`

Use this command during normal task-by-task work.

```text
evaluate-task --task 0X
```

It evaluates one task in isolation by reading:

- the task artifact in `outputs/`,
- the newest trajectory in `logs/trajectory/task0X/`,
- the matching row in `expected-files.md`,
- `rubric.md`,
- `agent-metrics-rubric.md`.

It writes a non-overwriting log:

```text
logs/eval/task0X/<YYYY-MM-DD-HHMM>-eval.md
```

The output includes an artifact score, a process score, evidence, and the top
improvement actions.
This command maps to component-level evaluation: inspect one task's output,
trajectory, expected files, and side effects before moving forward. Source:
[Openlayer - Agent evaluation complete guide](https://www.openlayer.com/blog/post/agent-evaluation-complete-guide-testing-ai-agents).

### `evaluate-pipeline`

Use this command at milestones or before submission.

```text
evaluate-pipeline
evaluate-pipeline --through 04
```

It evaluates the pipeline as a whole by reading the latest trajectory from each
task folder and, when available, existing per-task eval logs. Its focus is
cross-task consistency:

- entity in ERD -> table in logical design -> DDL,
- relationship in ERD -> FK or junction table -> DDL,
- business rules preserved from Task 01 through SQL/query outputs,
- naming consistency,
- valid file handoffs across tasks.

It writes:

```text
logs/eval/pipeline/<YYYY-MM-DD-HHMM>-pipeline-eval.md
```

This command maps to end-to-end and cross-trajectory evaluation: it checks
whether the whole multi-step workflow preserves rules and consistency. Source:
[Braintrust - What is agent evaluation?](https://www.braintrust.dev/articles/agent-evaluation).

## Recommended Workflow

1. Generate one task output.
2. Write the trajectory immediately.
3. Run `evaluate-task --task 0X`.
4. Review artifact score, process score, and top improvements.
5. Revise the skill/template/output if needed.
6. Repeat until the task passes the quality gate.
7. Run `evaluate-pipeline` at major milestones and before final submission.

This workflow follows article-based guidance: define measurable success, inspect
the full trajectory, validate side effects, and use evaluation logs to prevent
regressions. Sources:
[Google Cloud - A methodical approach to agent evaluation](https://cloud.google.com/blog/topics/developers-practitioners/a-methodical-approach-to-agent-evaluation),
[Openlayer - Agent evaluation complete guide](https://www.openlayer.com/blog/post/agent-evaluation-complete-guide-testing-ai-agents),
and [Braintrust - What is agent evaluation?](https://www.braintrust.dev/articles/agent-evaluation).

## References

- [DeepEval - AI Agent Evaluation](https://deepeval.com/guides/guides-ai-agent-evaluation)
- [Google Cloud - A methodical approach to agent evaluation](https://cloud.google.com/blog/topics/developers-practitioners/a-methodical-approach-to-agent-evaluation)
- [Google Cloud - View and interpret evaluation results](https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/view-evaluation)
- [Openlayer - Agent evaluation complete guide](https://www.openlayer.com/blog/post/agent-evaluation-complete-guide-testing-ai-agents)
- [Braintrust - What is agent evaluation?](https://www.braintrust.dev/articles/agent-evaluation)
- [Daily Dose of DS - Six Key Metrics for AI Agent Evaluation](https://blog.dailydoseofds.com/p/six-key-metrics-for-ai-agent-evaluation)
