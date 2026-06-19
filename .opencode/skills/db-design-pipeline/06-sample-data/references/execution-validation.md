# Execution Run Evidence

After generating `outputs/06-sample-data-G05.sql`, run it with `sqlcmd` after Task 05 DDL has created the database. Pipe all console output to:

```text
logs/execution/task06/<YYYY-MM-DD-HHMM>-output.txt
```

Use the same timestamp style as trajectory files. Create `logs/execution/task06/` if it does not exist.

## Authentication

Choose one authentication mode and use it consistently for the Task 06 execution.

| Mode | When to use | Syntax |
|---|---|---|
| Windows Auth | Default for local/solo work. No password needed. | `-E` |
| SQL Auth | Use when connecting as `sa` on a shared team server. | `-U sa -P "$SA_PASSWORD"` |

Replace `<AUTH>` with either `-E` or `-U sa -P "$SA_PASSWORD"`.

```bash
sqlcmd -S localhost -C <AUTH> -d CS486_G05 -i outputs/06-sample-data-G05.sql > logs/execution/task06/<YYYY-MM-DD-HHMM>-output.txt 2>&1
```

If SQL Auth is selected, load `.env` first and extract `SA_PASSWORD`, following the Task 05 convention.

## SQL Script Markers

The generated SQL script should print section markers so humans and evaluators can inspect the log, for example:

```sql
PRINT 'SECTION: VALID SEED DATA';
PRINT 'EXPECTED_ERROR_CASE: BR1 overlap prevention';
```

## Generation-Side Review

After execution, do a light generation-side review:

- Confirm the output log file exists and is non-empty.
- Confirm valid seed sections did not visibly fail before expected-error sections.
- Confirm expected-error sections continue through `TRY/CATCH` instead of aborting the script.
- Fix and rerun if the log shows sample-data generation mistakes such as missing tables, wrong columns, invalid enum values, FK order mistakes, or unhandled errors in valid seed sections.

If execution is impossible because SQL Server or `sqlcmd` is unavailable, record that blocker explicitly in the trajectory and memory.

