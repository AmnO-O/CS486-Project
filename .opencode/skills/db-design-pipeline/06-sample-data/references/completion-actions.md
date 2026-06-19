# Completion Actions

After generating and validating the script:

1. Save `outputs/06-sample-data-G05.sql`.
2. Run `sqlcmd` and save output to `logs/execution/task06/<YYYY-MM-DD-HHMM>-output.txt`.
3. Review the execution output for obvious generation errors and fix the SQL if valid seed sections fail.
4. Write a trajectory file under `logs/trajectory/task06/`.
5. Update `memory/Progress.md`.
6. Update `memory/ActiveContext.md` only when Task 06 is truly complete.

## Trajectory Requirements

In the Task 06 trajectory file:

- In Section 2, include a `verify` step for the `sqlcmd` run.
- In Section 2, include another `verify` step for reviewing the execution output for generation errors.
- In Section 3, list the execution log under **Written**.
- In Section 4 `Self-detected errors and fixes`, summarize:
  - valid seed errors observed during the run
  - fixes made
  - execution blocker, if SQL Server or `sqlcmd` was unavailable

