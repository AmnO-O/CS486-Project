/*
  CS486 G05 - Task 14 bulk loader
  SQL Server 2019+

  Run in an isolated scratch/database after:
    1. outputs/05-db-definition-G05.sql
    2. outputs/10-schema-migration-G05.sql

  Pass CSV_ROOT as a sqlcmd variable pointing at the generated CSV directory.
  The path must be visible to the SQL Server service account. Do not run against
  the Task 06 baseline without the coexistence key-range policy documented in
  README.md.

  Mode B decision:
    * BULK INSERT for the large historical mass.
    * The generator emits delimiter-safe CSV values (no embedded commas, tabs,
      CR/LF, or double quotes), so this script uses legacy FIELDTERMINATOR
      parsing. This avoids SQL Server BULK provider failures observed on SQL1
      with FORMAT='CSV' while remaining SQL Server 2019-compatible.
    * KEEPIDENTITY preserves the generator's explicit IDs.
    * CHECK_CONSTRAINTS validates CHECK/FK constraints during import.
    * FIRE_TRIGGERS is deliberately omitted: the generator owns legal status,
      capacity, maintenance-overlap, acknowledgement correspondence, and the
      single-threaded confirmed schedule. This is required for practical 120k+
      loading; the verifier independently proves the invariants.
    * Every table uses BATCHSIZE. A failed batch rolls back without deleting
      previously committed batches. The database must be scratch or isolated by
      the T14 ID/natural-key namespace; reruns are not append-safe.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET ARITHABORT ON;
SET NUMERIC_ROUNDABORT OFF;
GO

-- Required sqlcmd variable. Invoke as:
--   PowerShell:
--   sqlcmd -S <server> -d <scratch_db> -E -C -I -v CSV_ROOT = "D:\path\to\_generated" -i load.sql
-- Do not define :setvar CSV_ROOT here; that would override the -v value.
GO

IF ('$(CSV_ROOT)' = '' OR '$(CSV_ROOT)' = 'REPLACE_WITH_ABSOLUTE_PATH')
    THROW 51400, 'Pass -v CSV_ROOT="<absolute path>" to sqlcmd before running load.sql.', 1;
GO

IF OBJECT_ID(N'dbo.departments', N'U') IS NULL
   OR OBJECT_ID(N'dbo.users', N'U') IS NULL
   OR OBJECT_ID(N'dbo.spaces', N'U') IS NULL
   OR OBJECT_ID(N'dbo.facilities', N'U') IS NULL
   OR OBJECT_ID(N'dbo.space_facilities', N'U') IS NULL
   OR OBJECT_ID(N'dbo.maintenance', N'U') IS NULL
   OR OBJECT_ID(N'dbo.bookings', N'U') IS NULL
   OR OBJECT_ID(N'dbo.booking_approvals', N'U') IS NULL
   OR OBJECT_ID(N'dbo.booking_sessions', N'U') IS NULL
   OR OBJECT_ID(N'dbo.maintenance_impact_history', N'U') IS NULL
   OR OBJECT_ID(N'dbo.booking_advisory_acknowledgement', N'U') IS NULL
BEGIN
    THROW 51401, 'Task 14 requires the Phase 2 migrated schema (Tasks 05 + 10).', 1;
END
GO

/* Parent tables. Paths below are concatenated in BULK INSERT literals by the
   operator after replacing the root. This explicit section preserves FK order. */
-- Example invocation shape, repeated for every table:
-- BULK INSERT dbo.departments FROM 'C:\path\departments.csv'
-- WITH (FIRSTROW=2, FIELDTERMINATOR=',', ROWTERMINATOR='0x0a', KEEPIDENTITY,
--       CHECK_CONSTRAINTS, BATCHSIZE=20000, TABLOCK);

-- Use SQLCMD variable substitution when invoking this script:
-- sqlcmd -v CSV_ROOT = "D:\data\task14\_generated" -i load.sql
:ON ERROR EXIT

BULK INSERT dbo.departments
FROM '$(CSV_ROOT)\departments.csv'
WITH (FIRSTROW=2, FIELDTERMINATOR=',', ROWTERMINATOR='0x0a', KEEPIDENTITY, CHECK_CONSTRAINTS, BATCHSIZE=20000, TABLOCK);
GO
BULK INSERT dbo.users
FROM '$(CSV_ROOT)\users.csv'
WITH (FIRSTROW=2, FIELDTERMINATOR=',', ROWTERMINATOR='0x0a', KEEPIDENTITY, CHECK_CONSTRAINTS, BATCHSIZE=20000, TABLOCK);
GO
BULK INSERT dbo.spaces
FROM '$(CSV_ROOT)\spaces.csv'
WITH (FIRSTROW=2, FIELDTERMINATOR=',', ROWTERMINATOR='0x0a', KEEPIDENTITY, CHECK_CONSTRAINTS, BATCHSIZE=20000, TABLOCK);
GO
BULK INSERT dbo.facilities
FROM '$(CSV_ROOT)\facilities.csv'
WITH (FIRSTROW=2, FIELDTERMINATOR=',', ROWTERMINATOR='0x0a', KEEPIDENTITY, CHECK_CONSTRAINTS, BATCHSIZE=20000, TABLOCK);
GO
BULK INSERT dbo.space_facilities
FROM '$(CSV_ROOT)\space_facilities.csv'
WITH (FIRSTROW=2, FIELDTERMINATOR=',', ROWTERMINATOR='0x0a', KEEPIDENTITY, CHECK_CONSTRAINTS, BATCHSIZE=20000, TABLOCK);
GO
BULK INSERT dbo.maintenance
FROM '$(CSV_ROOT)\maintenance.csv'
WITH (FIRSTROW=2, FIELDTERMINATOR=',', ROWTERMINATOR='0x0a', KEEPIDENTITY, CHECK_CONSTRAINTS, BATCHSIZE=20000, TABLOCK);
GO

/* Acknowledgements precede approvals. The approval trigger then sees all acks
   for every confirmed booking/advisory pair. */
BULK INSERT dbo.bookings
FROM '$(CSV_ROOT)\bookings.csv'
WITH (FIRSTROW=2, FIELDTERMINATOR=',', ROWTERMINATOR='0x0a', KEEPIDENTITY, CHECK_CONSTRAINTS, BATCHSIZE=20000, TABLOCK);
GO
BULK INSERT dbo.booking_advisory_acknowledgement
FROM '$(CSV_ROOT)\booking_advisory_acknowledgement.csv'
WITH (FIRSTROW=2, FIELDTERMINATOR=',', ROWTERMINATOR='0x0a', KEEPIDENTITY, CHECK_CONSTRAINTS, BATCHSIZE=20000, TABLOCK);
GO

/* Approvals are loaded with FIRE_TRIGGERS omitted. Their decision/status
   correspondence is already represented in bookings.csv and verified below. */
BULK INSERT dbo.booking_approvals
FROM '$(CSV_ROOT)\booking_approvals.csv'
WITH (FIRSTROW=2, FIELDTERMINATOR=',', ROWTERMINATOR='0x0a', KEEPIDENTITY, CHECK_CONSTRAINTS, BATCHSIZE=20000, TABLOCK);
GO
BULK INSERT dbo.booking_sessions
FROM '$(CSV_ROOT)\booking_sessions.csv'
WITH (FIRSTROW=2, FIELDTERMINATOR=',', ROWTERMINATOR='0x0a', KEEPIDENTITY, CHECK_CONSTRAINTS, BATCHSIZE=20000, TABLOCK);
GO

/* Mode-A behavior proof / history slice.
   The generator intentionally does not emit history CSV rows because
   trg_maintenance_impact_history is AFTER UPDATE only. This executable slice
   selects one active advisory ticket, escalates it, then downgrades it back to
   advisory so V3 does not treat it as a current blocker. */
DECLARE @maintenance_id INT;

SELECT TOP (1) @maintenance_id = m.maintenance_id
FROM dbo.maintenance AS m
INNER JOIN dbo.bookings AS b
    ON b.space_id = m.space_id
   AND b.is_deleted = 0
   AND b.status IN ('approved','checked_in','completed')
   AND m.start_time < b.requested_end_time
   AND (m.completion_time IS NULL OR m.completion_time > b.requested_start_time)
WHERE m.is_deleted = 0
  AND m.status IN ('open','in_progress')
  AND m.impact_level = 'advisory'
GROUP BY m.maintenance_id
ORDER BY COUNT_BIG(*) DESC, m.maintenance_id;

IF @maintenance_id IS NULL
BEGIN
    SELECT TOP (1) @maintenance_id = maintenance_id
    FROM dbo.maintenance
    WHERE is_deleted = 0
      AND status IN ('open','in_progress')
      AND impact_level = 'advisory'
    ORDER BY maintenance_id;
END;

DECLARE @actor_id INT = (
    SELECT TOP (1) user_id
    FROM dbo.users
    WHERE role = 'facility_manager'
      AND account_status = 'active'
      AND user_id <> -1
    ORDER BY user_id
);

IF @maintenance_id IS NULL OR @actor_id IS NULL
BEGIN
    PRINT 'TASK14-MODEA-SKIP: no active advisory maintenance or facility manager was available.';
END
ELSE
BEGIN
    EXEC sys.sp_set_session_context @key=N'current_user_id', @value=@actor_id;
    UPDATE dbo.maintenance SET impact_level = 'out-of-service'
    WHERE maintenance_id = @maintenance_id;
    UPDATE dbo.maintenance SET impact_level = 'advisory'
    WHERE maintenance_id = @maintenance_id;
    EXEC sys.sp_set_session_context @key=N'current_user_id', @value=NULL;

    DECLARE @history_rows INT;
    SELECT @history_rows = COUNT(*)
    FROM dbo.maintenance_impact_history
    WHERE maintenance_id = @maintenance_id;

    PRINT CONCAT(
        'TASK14-MODEA-HISTORY: maintenance_id=',
        CONVERT(VARCHAR(20), @maintenance_id),
        ', history_rows=',
        CONVERT(VARCHAR(20), @history_rows)
    );
END
GO

PRINT 'TASK14-BULK-LOAD-COMPLETE: run verify.sql next.';
