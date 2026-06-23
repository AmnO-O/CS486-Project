# Completion Actions

After generating and validating the script:

1. Save `outputs/06-sample-data-G05.sql`.
2. Run `sqlcmd` and save output to `logs/execution/task06/<YYYY-MM-DD-HHMM>-output.txt`.
3. Review the execution output for obvious generation errors and fix the SQL if valid seed sections fail.
4. Rerun `sqlcmd` after any fix to cleanup, idempotence, lookup capture, FK order, or expected-error setup.
5. Write a trajectory file under `logs/trajectory/task06/`.

## Trajectory Requirements

In the Task 06 trajectory file:

- In Section 1, include planned steps for generating the SQL, running `sqlcmd`, reviewing the execution log, fixing generation errors if found, and rerunning for idempotence when relevant. **Crucially, you must explicitly enumerate every single input file you plan to read. Do not use generic phrases like "Read all required inputs".**
- In Section 2, include a single `verify` step for the final successful `sqlcmd` run with its log path.
- In Section 2, include another `verify` step for reviewing that final execution output to ensure there are no generation errors.
- In Section 3, list **ONLY** the single, final successful execution log under Written. **CRITICAL:** You are strictly forbidden from listing any intermediate failed log files here. If temporary log files were created, confirm they are deleted and exclude them from this section.
- In Section 4 `Self-detected errors and fixes`, summarize the complete debugging history to maintain evaluation transparency without needing physical error files:
  - Narrate all valid seed errors observed during intermediate runs.
  - Narrate idempotence or rerun failures, if any.
  - Explain the exact fixes applied (cleanup, `IF NOT EXISTS`, lookup-capture, or expected-error setup fixes) to reach the final successful state.
  - State the final execution log proving the revised script ran successfully, when available.
  - State the execution blocker, if SQL Server or `sqlcmd` was unavailable.
- If there are no open questions during the task, explicitly state "No open questions raised" or "No ambiguities found" in the trajectory.

If a later manual or follow-up revision changes `outputs/06-sample-data-G05.sql`, write a new trajectory with `revision_of` set to the previous trajectory. Do not leave critical fixes, such as adding a cleanup section or guarded inserts, only in the SQL diff or execution log.
