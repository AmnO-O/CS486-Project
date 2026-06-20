# Completion Actions

After generating and validating the script:

1. Save `outputs/06-sample-data-G05.sql`.
2. Run `sqlcmd` and save output to `logs/execution/task06/<YYYY-MM-DD-HHMM>-output.txt`.
3. Review the execution output for obvious generation errors and fix the SQL if valid seed sections fail.
4. Rerun `sqlcmd` after any fix to cleanup, idempotence, lookup capture, FK order, or expected-error setup.
5. Write a trajectory file under `logs/trajectory/task06/`.

## Trajectory Requirements

In the Task 06 trajectory file:

- In Section 1, include planned steps for generating the SQL, running `sqlcmd`, reviewing the execution log, fixing generation errors if found, and rerunning for idempotence when relevant.
- In Section 2, include a `verify` step for the `sqlcmd` run.
- In Section 2, include another `verify` step for reviewing the execution output for generation errors.
- In Section 2, include each rerun as a separate `verify` step with its log path.
- In Section 3, list every execution log under **Written**.
- In Section 4 `Self-detected errors and fixes`, summarize:
  - valid seed errors observed during the run
  - idempotence or rerun failures, if any
  - cleanup, `IF NOT EXISTS`, lookup-capture, or expected-error setup fixes
  - fixes made
  - final execution log proving the revised script ran successfully, when available
  - execution blocker, if SQL Server or `sqlcmd` was unavailable

If a later manual or follow-up revision changes `outputs/06-sample-data-G05.sql`, write a new trajectory with `revision_of` set to the previous trajectory. Do not leave critical fixes, such as adding a cleanup section or guarded inserts, only in the SQL diff or execution log.
