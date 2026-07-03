# Validation And Completion

## Coverage Inventory

Before writing or revising `outputs/06-sample-data-G05.sql`, build a coverage inventory from:

- `SKILL.md`
- `references/data-requirements.md`
- `references/script-rules.md`
- `references/validation-and-completion.md`

Atomize each required "must", "include", "attempt", "verify", "respect", "run", "rerun", "record", and "do not" item into one checklist item. Give each item a stable local ID, such as `DATA-Users-01`, `DATA-BR1-01`, `RULE-Idempotence-02`, or `VAL-Exec-03`.

Each item must have exactly one primary proof owner:

- `seed_section`
- `expected_error_case`
- `verification_query`
- `execution_log`
- `trajectory_entry`
- `declared_blocker` for unavailable external execution, such as missing SQL Server

Do not move from planning to SQL generation until every item has a planned owner. Do not mark an item covered by "general review" or "the script runs".

## SQL Markers And Static Audit

For every expected-error case:

- Print `EXPECTED_ERROR_CASE: <case id> - <purpose>`.
- Add `-- Expected error: <intended rule or constraint>` next to the failing action.
- Use `BEGIN TRY / BEGIN CATCH`, print `ERROR_MESSAGE()`, and roll back or clean up temporary fixtures.
- Include the DDL-derived target object or exact trigger message in a nearby SQL comment, marker, or PASS/FAIL message.

For every verification query:

- Print `VERIFY: <check id> - <purpose>`.
- Return counts, distributions, or exact rows that prove the item.
- Exclude expected-error fixtures from reports unless intentionally documented as valid sample data.

Before running `sqlcmd`, audit that:

- A DDL-derived proof matrix exists in the plan or trajectory notes, and every DDL enforcement object selected from tables, constraints, indexes, FKs, triggers, and lifecycle transitions has a proof owner or declared blocker.
- The proof matrix was derived from DDL text, not manually copied from BR labels only. It includes rows for every table, FK, CHECK enum value, CHECK rule, NOT NULL required field, UNIQUE key, filtered unique index, unique child FK, trigger `RAISERROR`/`THROW` branch, trigger side effect, trigger guard branch, lifecycle transition, and selected audit trigger.
- All table and column names exist in Task 05 DDL.
- Every locked table from Task 05 DDL is seeded or intentionally covered as reference data.
- Insert order is FK-safe and valid rows satisfy CHECK constraints and triggers.
- Required enum sets, roles, statuses, purposes, space types, maintenance statuses, soft-delete evidence, audit evidence, and reporting examples are covered.
- Lifecycle-relative dates are derived from a single execution-time anchor, or are explicitly labeled as fixed historical examples. Future/current/past/upcoming claims must remain true against `GETDATE()`/`SYSDATETIME()` at execution time.
- `booking_approvals.booking_id` and `booking_sessions.booking_id` remain one-to-zero-or-one in valid seed data.
- Expected-error cases have markers, comments, `TRY/CATCH`, captured error messages, and fixture cleanup.
- The number of `-- Expected error:` comments equals the number of `EXPECTED_ERROR_CASE` markers, unless a case intentionally has multiple failing statements and each failing statement has its own comment.
- Every DDL `RAISERROR`/`THROW` message appears in either an expected-error target or a declared blocker, and the final execution log includes a matching PASS/FAIL result for that target.
- Every `UNIQUE` FK child table has a valid child-row proof and a duplicate-child expected-error proof.
- Every trigger side effect has a before/after verification. Every trigger guard that prevents a side effect has a verification that the protected state did not change.
- Every required enum/status value claimed as covered appears in a final verification result set or has a declared blocker. Compare the execution log, not only SQL comments or trajectory prose.
- Critical lookup IDs cannot be NULL before child inserts or expected-error statements.
- No two valid active bookings overlap for the same space.
- Verification queries prove workflow/reporting evidence, not just raw row counts. For trigger or lifecycle coverage, verification must show the operation-created state, not only pre-seeded final-state rows.
- Reporting verification predicates match their labels. "Upcoming" reports must exclude deleted rows and non-actionable terminal/negative statuses; history, no-show, and maintenance reports must use explicit status/date predicates rather than relying only on broad time filters.
- Cleanup statements use the documented ownership predicate. Reject any permanent-table `DELETE` without a restrictive `WHERE`, joined delete, or `WHERE EXISTS` tied to Task 06-owned natural keys.
- Update-driven audit evidence includes at least one parent table and at least one lifecycle child table when those tables exist in the DDL. The execution log must return an actual lifecycle child row or PASS marker; an empty result set is uncovered.
- The trajectory plan explicitly names the coverage audit step.

Revise before execution if any audit item is uncovered.

Static audit must fail immediately for any of these general patterns:

- Unconditional permanent-table cleanup, such as `DELETE FROM [dbo].[some_table];`.
- Expected-error cases that print `PASS` for a caught error without proving the caught error belongs to the intended rule category.
- Trigger-enforced business rules represented only by seeded final-state data.
- Lifecycle status coverage where a terminal status appears in final counts but no workflow operation created it.
- Lifecycle-relative rows that use stale fixed dates so "future", "current", or "upcoming" labels are false at execution time.
- Report verification queries whose labels are narrower than their predicates, such as "upcoming bookings" that admit cancelled, rejected, completed, checked-in, no-show, or soft-deleted rows.
- A child table with a unique FK that has valid seed rows but no duplicate-child expected-error proof.
- A role-gated trigger in the DDL without both valid-role and invalid-role evidence.
- A DDL trigger error branch whose message or target is absent from expected-error markers and final execution PASS/FAIL output.
- A trigger side-effect guard whose protected state is not verified before and after the guarded operation.
- A required enum/status value listed by DDL or claimed by the SQL header but absent from final verification output.
- An update-driven audit proof that omits a lifecycle child table row/PASS result from the final log.
- A trajectory that claims `coverage_uncovered_count: 0` while the final execution log omits any mandatory DDL-derived proof.
- A trajectory that omits final coverage counts or reports a nonzero uncovered count.

## Execution Evidence

Run the script with `sqlcmd` after Task 05 DDL creates the database. Use a temporary output file first:

```text
logs/execution/task06/temp-execution-output.txt
```

If the run fails, fix the SQL and rerun into the same temp file. Only after a fully successful run, rename the temp file to:

```text
logs/execution/task06/<YYYY-MM-DD-HHMM>-output.txt
```

Use the same timestamp style as trajectory files. Create `logs/execution/task06/` if needed.

Choose one authentication mode and use it consistently:

| Mode | When | Syntax |
|---|---|---|
| Windows Auth | Default local work | `-E` |
| SQL Auth | Shared server as `sa`; load `.env` first if needed | `-U sa -P "$SA_PASSWORD"` |

Command shape:

```bash
sqlcmd -S localhost -C <AUTH> -d CS486_G05 -i outputs/06-sample-data-G05.sql > logs/execution/task06/temp-execution-output.txt 2>&1
```

After execution, confirm the log:

- exists and is non-empty;
- includes seed, expected-error, and verification markers;
- includes every expected-error and verification marker from the coverage inventory;
- shows expected failures caught with PASS-style messages;
- has no `FAIL:` markers or unhandled valid-seed errors;
- proves `booking_approvals` and `booking_sessions` workflows;
- proves every DDL-derived trigger error branch, trigger side effect, trigger guard, unique child FK, and required enum/status value that the coverage inventory marks as covered;
- keeps final reporting based on valid sample data, not leaked fixtures.

Rerun after any fix to cleanup, idempotence, lookup capture, FK order, expected-error setup, or coverage evidence. Validate idempotence by running Task 06 a second time against the same database or against a database already containing prior Task 06 rows; the rerun must have no unexpected valid-seed errors, and expected-error cases must still capture the intended rule-specific failures.

Keep only the final successful log from the current run cycle. Delete temporary or separate failed logs created during the current cycle, but do not delete previous historical `.txt` logs. If SQL Server or `sqlcmd` is unavailable, record the blocker in trajectory and ask before updating memory.

## Trajectory

Write `logs/trajectory/task06/<YYYY-MM-DD-HHMM>-trajectory.md` after final SQL/log review, following `.opencode/skills/evaluations/trajectory-recording.md`.

The trajectory must include:

- planned steps for SQL generation, `sqlcmd`, log review, possible fixes/reruns, idempotence, and coverage audit;
- every input file and Task 06 reference read, listed explicitly rather than as "all required inputs";
- one `verify` step for the final successful `sqlcmd` run and log path, or an explicit execution blocker;
- one `verify` step for reviewing that final log;
- one `verify` step for final coverage audit with total, covered, uncovered counts, and evidence types;
- under Written, only the single final successful execution log plus the trajectory itself;
- the frontmatter and section structure from `.opencode/skills/evaluations/templates/trajectory-template.md`, including `revision_of` and the required Task 06 coverage fields;
- self-detected errors and fixes, including valid-seed errors, idempotence/rerun failures, coverage gaps, exact fixes, and final proving log;
- `coverage_uncovered_count`, which must be `0` for completion;
- "No open questions raised" or "No ambiguities found" when applicable.

If a later revision changes `outputs/06-sample-data-G05.sql`, write a new trajectory with `revision_of` set to the prior trajectory. Do not leave critical fixes only in the SQL diff or execution log.

## Completion Rule

Task 06 is not complete until the SQL is generated, final coverage has no uncovered items, execution evidence is recorded, and the user has been asked whether to approve memory updates under the AGENTS post-task handshake.
