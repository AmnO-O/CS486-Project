# Trajectory Recording Rule

Makes the agent record a trajectory after every task. Mandatory; it is the
prerequisite for scoring the six agent metrics.

> File structure, save path, timestamp format, field-to-metric mapping, and
> authoring rules all live in `templates/trajectory-template.md`. This file
> states only the *rule* and the few constraints the template does not cover.

## Hard rule

> After generating or revising any `outputs/0X-*` artifact, the agent MUST write
> a trajectory file before reporting the task as done. A task is not "complete"
> until its trajectory exists.

## Procedure (end of every task)

1. Create the trajectory file following `templates/trajectory-template.md`
   (path, timestamp, and section structure are defined there). If this run
   revises an earlier output, set `revision_of` to the prior trajectory filename.
2. In the Post-Task Handshake summary, add one line:
   `Trajectory: logs/trajectory/task0X/<timestamp>-trajectory.md`

## Constraints not in the template

- **Never load `logs/` while *generating* a task.** Trajectories are read only
  during *evaluation*. 

## Integration points

- Referenced by `.opencode/skills/db-design-pipeline/SKILL.md` 
- Consumed by `/evaluate-task` and `/evaluate-pipeline` commands.
