SET QUOTED_IDENTIFIER ON
GO
SET XACT_ABORT ON;
GO

-- ============================================================
-- CS486 G05 — Campus Space Management System
-- Task 10: Phase 2 Schema Migration (delta on the Phase 1 baseline)
-- Target: SQL Server 2019+ (T-SQL)
--
-- Baseline : outputs/05-db-definition-G05.sql (Phase 1, Task 05, SCHEMA FREEZE)
--            + outputs/06-sample-data-G05.sql (existing data context)
-- Target   : docs/schema-registry.md + outputs/09-updated-erd-and-logical-design-G05.md
--            + docs/design-decisions.md (Task 09 decisions)
--
-- DATA-PRESERVATION PROMISE
--   - No Phase 1 table is dropped or rebuilt; no booking/maintenance row is
--     deleted or modified in meaning.
--   - All existing maintenance rows are backfilled to impact_level
--     'out-of-service' (registry default, A09-1) so legacy rows keep their
--     Phase 1 blocking behavior.
--   - All changes are additive: 1 new column, 2 new tables, 4 new indexes,
--     7 triggers (5 new + 2 replaced), 1 reserved seed row (system approver
--     -1), plus a one-time recompute of spaces.current_status under the new
--     trigger-maintained semantics (Task 09, Area 1, U5).
--
-- PRE-MIGRATION AUDIT (baseline vs registry), performed before generation:
--   departments/users/spaces/facilities/space_facilities/bookings/
--   booking_approvals/booking_sessions/maintenance — columns, nullability,
--   PK/FK/UQ/CK/DF, indexes and triggers all match docs/schema-registry.md.
--   The only registry entries absent from the baseline are the Phase 2
--   targets implemented below (maintenance.impact_level, the two new tables
--   and their indexes, and the reserved users row user_id = -1).
--   No mismatch found -> migration is generated on a verified baseline.
--
-- DESIGN DECISION MAPPING (docs/design-decisions.md, Task 09)
--   1. Advisory-ack uniqueness shape: ONE composite UNIQUE constraint
--      UQ_booking_advisory_ack_booking_maintenance over (booking_id,
--      maintenance_id) — neither column is unique alone.
--   2. Instant-approval approver identity: reserved system user
--      user_id = -1 (System Booking Service, role facility_manager), seeded
--      via SET IDENTITY_INSERT. NO approval_source/origin column is added
--      (Task 09 rejected it for 3NF).
--   3. spaces.current_status stays trigger-maintained: replaced
--      trg_maintenance_completion_space_status with
--      trg_maintenance_recompute_space_status (INSERT/UPDATE, priority rule);
--      spaces schema itself is unchanged.
--
-- TRIGGER BEHAVIOR MAPPING (Task 09 "trigger behavior — Task 10")
--   - trg_bookings_check_maintenance   (replaced): blocks only overlapping
--     active out-of-service maintenance; advisory overlaps are allowed.
--   - trg_booking_approvals_check_space (replaced): approval prerequisites —
--     manual retired/temporarily_closed overrides block, out-of-service
--     overlap blocks, and every overlapping active advisory must have an
--     acknowledgement row (NR2 completeness gate at the point where a booking
--     becomes confirmed, incl. the instant path).
--   - trg_booking_advisory_ack_validate (new): correspondence — each ack must
--     reference an active advisory maintenance whose period overlaps the
--     booking's requested period.
--   - trg_maintenance_impact_history   (new): records level changes
--     (escalation/downgrade) of still-active maintenance (NR3). changed_by is
--     read from SESSION_CONTEXT(N'current_user_id') set via
--     sys.sp_set_session_context; when no context is set, the change is
--     attributed to the reserved system user -1.
--   - trg_maintenance_recompute_space_status (new, replaces BR19 trigger):
--     recomputes spaces.current_status per the priority rule on maintenance
--     INSERT/UPDATE, guarded to status-relevant column changes (status,
--     impact_level, start_time, completion_time, is_deleted — see 7e).
--
-- HANDOFF NOTE (application layer — Tasks 11/12 concurrency design):
--   changed_by flows through SESSION_CONTEXT, which is session-scoped, NOT
--   transaction-scoped. With connection pooling, a reused connection may
--   still hold a stale 'current_user_id' from a previous request. The
--   application layer MUST set sys.sp_set_session_context N'current_user_id'
--   before each unit of work and clear it (set NULL) when the unit of work
--   ends. The migration itself always degrades safely to the reserved user -1.
-- ============================================================

-- ============================================================
-- 0. PREFLIGHT CHECKS
--    - all 9 Phase 1 tables must exist (baseline, not an empty DB)
--    - Task 10 must not be run against a partially-migrated database
-- ============================================================
IF OBJECT_ID(N'dbo.departments', N'U') IS NULL
   OR OBJECT_ID(N'dbo.users', N'U') IS NULL
   OR OBJECT_ID(N'dbo.spaces', N'U') IS NULL
   OR OBJECT_ID(N'dbo.facilities', N'U') IS NULL
   OR OBJECT_ID(N'dbo.space_facilities', N'U') IS NULL
   OR OBJECT_ID(N'dbo.bookings', N'U') IS NULL
   OR OBJECT_ID(N'dbo.booking_approvals', N'U') IS NULL
   OR OBJECT_ID(N'dbo.booking_sessions', N'U') IS NULL
   OR OBJECT_ID(N'dbo.maintenance', N'U') IS NULL
BEGIN
    THROW 51010, 'Task 10 migration aborted: not all Phase 1 baseline tables exist. Run outputs/05-db-definition-G05.sql first.', 1;
END
GO

IF OBJECT_ID(N'dbo.maintenance_impact_history', N'U') IS NOT NULL
   OR OBJECT_ID(N'dbo.booking_advisory_acknowledgement', N'U') IS NOT NULL
BEGIN
    PRINT 'WARNING: Phase 2 tables already exist — running in idempotent re-run mode (additive steps skipped, triggers refreshed).';
END
GO

IF (SELECT COUNT(*) FROM dbo.departments) = 0
BEGIN
    PRINT 'WARNING: departments table is empty (bare DDL baseline). The migration will create the School Administration department needed by the reserved system approver row.';
END
GO

-- ============================================================
-- Migration body — one explicit transaction spanning the GO batches
-- (DDL is transactional in SQL Server; XACT_ABORT rolls back on any error)
-- ============================================================
BEGIN TRANSACTION;
GO

-- ============================================================
-- 1. Drop existing triggers that will be replaced (Task 09 behavior change)
--    or re-created (idempotent re-run). Keep the other Phase 1 triggers
--    untouched (BR1/BR3/BR6-9/BR15-18, role and updated_at triggers).
-- ============================================================
IF OBJECT_ID(N'dbo.trg_bookings_check_maintenance', N'TR') IS NOT NULL
    DROP TRIGGER dbo.trg_bookings_check_maintenance;
GO

IF OBJECT_ID(N'dbo.trg_booking_approvals_check_space', N'TR') IS NOT NULL
    DROP TRIGGER dbo.trg_booking_approvals_check_space;
GO

IF OBJECT_ID(N'dbo.trg_maintenance_completion_space_status', N'TR') IS NOT NULL
    DROP TRIGGER dbo.trg_maintenance_completion_space_status;
GO

IF OBJECT_ID(N'dbo.trg_booking_advisory_ack_validate', N'TR') IS NOT NULL
    DROP TRIGGER dbo.trg_booking_advisory_ack_validate;
GO

IF OBJECT_ID(N'dbo.trg_maintenance_impact_history', N'TR') IS NOT NULL
    DROP TRIGGER dbo.trg_maintenance_impact_history;
GO

IF OBJECT_ID(N'dbo.trg_maintenance_recompute_space_status', N'TR') IS NOT NULL
    DROP TRIGGER dbo.trg_maintenance_recompute_space_status;
GO

IF OBJECT_ID(N'dbo.trg_maintenance_impact_history_updated_at', N'TR') IS NOT NULL
    DROP TRIGGER dbo.trg_maintenance_impact_history_updated_at;
GO

IF OBJECT_ID(N'dbo.trg_booking_advisory_acknowledgement_updated_at', N'TR') IS NOT NULL
    DROP TRIGGER dbo.trg_booking_advisory_acknowledgement_updated_at;
GO

-- ============================================================
-- 2. Existing-table alteration: maintenance.impact_level
--    NOT NULL DEFAULT 'out-of-service' preserves Phase 1 blocking semantics
--    for legacy rows (A09-1). Idempotent: skipped if already present.
-- ============================================================
IF COL_LENGTH(N'dbo.maintenance', N'impact_level') IS NULL
BEGIN
    -- One statement: the CHECK references the new column, so it must be
    -- defined inline (a second ALTER in the same batch would not compile).
    ALTER TABLE dbo.maintenance
        ADD impact_level VARCHAR(50) NOT NULL
            CONSTRAINT DF_maintenance_impact_level DEFAULT 'out-of-service'
            CONSTRAINT CK_maintenance_impact_level
                CHECK (impact_level IN ('advisory','out-of-service'));
END
GO

-- ============================================================
-- 3. New table: maintenance_impact_history (NR3 — level-change audit)
-- ============================================================
IF OBJECT_ID(N'dbo.maintenance_impact_history', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.maintenance_impact_history (
        history_id       INT NOT NULL IDENTITY(1,1),
        maintenance_id   INT NOT NULL,
        changed_by       INT NOT NULL,
        prior_level      VARCHAR(50) NOT NULL,
        new_level        VARCHAR(50) NOT NULL,
        changed_at       DATETIME2 NOT NULL CONSTRAINT DF_maintenance_impact_history_changed_at DEFAULT GETDATE(),
        reason           NVARCHAR(MAX) NULL,
        created_at       DATETIME2 NOT NULL CONSTRAINT DF_maintenance_impact_history_created_at DEFAULT GETDATE(),
        updated_at       DATETIME2 NOT NULL CONSTRAINT DF_maintenance_impact_history_updated_at DEFAULT GETDATE(),
        CONSTRAINT PK_maintenance_impact_history PRIMARY KEY (history_id),
        CONSTRAINT CK_maintenance_impact_history_prior_level CHECK (prior_level IN ('advisory','out-of-service')),
        CONSTRAINT CK_maintenance_impact_history_new_level CHECK (new_level IN ('advisory','out-of-service')),
        CONSTRAINT CK_maintenance_impact_history_levels_differ CHECK (prior_level <> new_level),
        CONSTRAINT FK_maintenance_impact_history_maintenance_id
            FOREIGN KEY (maintenance_id) REFERENCES dbo.maintenance(maintenance_id)
            ON DELETE CASCADE ON UPDATE NO ACTION,
        CONSTRAINT FK_maintenance_impact_history_changed_by
            FOREIGN KEY (changed_by) REFERENCES dbo.users(user_id)
            ON DELETE NO ACTION ON UPDATE NO ACTION
    );
END
GO

-- ============================================================
-- 4. New table: booking_advisory_acknowledgement (NR2)
--    Composite UNIQUE (booking_id, maintenance_id) = one acknowledgement
--    per (booking, advisory) — decision point 1.
-- ============================================================
IF OBJECT_ID(N'dbo.booking_advisory_acknowledgement', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.booking_advisory_acknowledgement (
        ack_id           INT NOT NULL IDENTITY(1,1),
        booking_id       INT NOT NULL,
        maintenance_id   INT NOT NULL,
        acknowledged_at  DATETIME2 NOT NULL CONSTRAINT DF_booking_advisory_ack_acknowledged_at DEFAULT GETDATE(),
        acknowledged_by  INT NOT NULL,
        created_at       DATETIME2 NOT NULL CONSTRAINT DF_booking_advisory_ack_created_at DEFAULT GETDATE(),
        updated_at       DATETIME2 NOT NULL CONSTRAINT DF_booking_advisory_ack_updated_at DEFAULT GETDATE(),
        CONSTRAINT PK_booking_advisory_acknowledgement PRIMARY KEY (ack_id),
        CONSTRAINT UQ_booking_advisory_ack_booking_maintenance UNIQUE (booking_id, maintenance_id),
        CONSTRAINT FK_booking_advisory_ack_booking_id
            FOREIGN KEY (booking_id) REFERENCES dbo.bookings(booking_id)
            ON DELETE CASCADE ON UPDATE NO ACTION,
        CONSTRAINT FK_booking_advisory_ack_maintenance_id
            FOREIGN KEY (maintenance_id) REFERENCES dbo.maintenance(maintenance_id)
            ON DELETE CASCADE ON UPDATE NO ACTION,
        CONSTRAINT FK_booking_advisory_ack_acknowledged_by
            FOREIGN KEY (acknowledged_by) REFERENCES dbo.users(user_id)
            ON DELETE NO ACTION ON UPDATE NO ACTION
    );
END
GO

-- ============================================================
-- 5. New indexes (registry §Indexes — Phase 2 additions only)
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'idx_maintenance_impact_history_maintenance' AND object_id = OBJECT_ID(N'dbo.maintenance_impact_history'))
    CREATE INDEX idx_maintenance_impact_history_maintenance ON dbo.maintenance_impact_history (maintenance_id);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'idx_maintenance_impact_history_changed_by' AND object_id = OBJECT_ID(N'dbo.maintenance_impact_history'))
    CREATE INDEX idx_maintenance_impact_history_changed_by ON dbo.maintenance_impact_history (changed_by);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'idx_booking_advisory_ack_maintenance' AND object_id = OBJECT_ID(N'dbo.booking_advisory_acknowledgement'))
    CREATE INDEX idx_booking_advisory_ack_maintenance ON dbo.booking_advisory_acknowledgement (maintenance_id);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'idx_booking_advisory_ack_acknowledged_by' AND object_id = OBJECT_ID(N'dbo.booking_advisory_acknowledgement'))
    CREATE INDEX idx_booking_advisory_ack_acknowledged_by ON dbo.booking_advisory_acknowledgement (acknowledged_by);
GO

-- ============================================================
-- 6. Guarded seed rows
--    a) Reserved system approver user_id = -1 (NR5, decision point 2).
--       FK department: School Administration if present, else the lowest
--       department_id; if the baseline has no departments at all, create
--       School Administration (Task 06 uses the same guarded canonical row).
--    b) One-time current_status refresh under the new recompute semantics
--       (Task 09 A.3). Manual retired/temporarily_closed overrides are kept.
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM dbo.users WHERE user_id = -1)
BEGIN
    DECLARE @dept_id INT = (SELECT department_id FROM dbo.departments WHERE name = N'School Administration');
    IF @dept_id IS NULL
        SET @dept_id = (SELECT MIN(department_id) FROM dbo.departments);
    IF @dept_id IS NULL
    BEGIN
        INSERT INTO dbo.departments (name) VALUES (N'School Administration');
        SET @dept_id = SCOPE_IDENTITY();
    END

    SET IDENTITY_INSERT dbo.users ON;
    INSERT INTO dbo.users (user_id, email, full_name, phone_number, role, department_id, account_status, created_at, updated_at)
    VALUES (-1, N'system@campus.edu', N'System Booking Service', NULL, 'facility_manager', @dept_id, 'active', GETDATE(), GETDATE());
    SET IDENTITY_INSERT dbo.users OFF;
END
GO

-- One-time refresh of spaces.current_status (priority rule, Task 09 A.3).
-- Idempotent by nature: recomputing an already-computed value is a no-op.
DECLARE @now_mig DATETIME2 = SYSDATETIME();
UPDATE s
SET current_status =
    CASE
        WHEN s.current_status = 'retired' THEN 'retired'
        WHEN s.current_status = 'temporarily_closed' THEN 'temporarily_closed'
        WHEN EXISTS (
            SELECT 1 FROM dbo.maintenance m
            WHERE m.space_id = s.space_id
              AND m.is_deleted = 0
              AND m.status IN ('open','in_progress')
              AND m.impact_level = 'out-of-service'
              AND m.start_time <= @now_mig
              AND (m.completion_time IS NULL OR m.completion_time > @now_mig)
        ) THEN 'under_maintenance'
        WHEN EXISTS (
            SELECT 1 FROM dbo.booking_sessions bs
            INNER JOIN dbo.bookings b ON b.booking_id = bs.booking_id
            WHERE b.space_id = s.space_id
              AND b.is_deleted = 0
              AND bs.actual_end_time IS NULL
        ) THEN 'in_use'
        ELSE 'available'
    END
FROM dbo.spaces s;
GO

-- ============================================================
-- 7. Trigger creations / replacements (each in its own batch)
-- ============================================================

-- ------------------------------------------------------------
-- 7a. trg_bookings_check_maintenance (REPLACED, BR4 Phase 2)
--     Blocks only overlapping active out-of-service maintenance.
--     Advisory overlaps are allowed (acknowledgement is the NR2 gate).
-- ------------------------------------------------------------
CREATE TRIGGER trg_bookings_check_maintenance
ON bookings
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN maintenance m
            ON m.space_id = i.space_id
            AND m.is_deleted = 0
            AND m.status IN ('open','in_progress')
            AND m.impact_level = 'out-of-service'
            AND m.start_time < i.requested_end_time
            AND (m.completion_time IS NULL OR m.completion_time > i.requested_start_time)
    )
    BEGIN
        RAISERROR('Overlapping out-of-service maintenance exists for this space.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END
GO

-- ------------------------------------------------------------
-- 7b. trg_booking_approvals_check_space (REPLACED, BR2/BR4 Phase 2 + NR2 gate)
--     Approval prerequisites, checked when decision = 'approved':
--       1. manual space overrides still block (retired / temporarily_closed)
--       2. overlapping active out-of-service maintenance blocks
--       3. every overlapping active advisory must have an acknowledgement
--          row (NR2 completeness at the point a booking becomes confirmed,
--          covering both the staff and the instant approval path)
-- ------------------------------------------------------------
CREATE TRIGGER trg_booking_approvals_check_space
ON booking_approvals
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN bookings b ON b.booking_id = i.booking_id
        INNER JOIN spaces s ON s.space_id = b.space_id
        WHERE i.decision = 'approved'
          AND s.current_status IN ('temporarily_closed','retired')
    )
    BEGIN
        RAISERROR('Cannot approve booking: space is manually closed or retired.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN bookings b ON b.booking_id = i.booking_id
        INNER JOIN maintenance m
            ON m.space_id = b.space_id
            AND m.is_deleted = 0
            AND m.status IN ('open','in_progress')
            AND m.impact_level = 'out-of-service'
            AND m.start_time < b.requested_end_time
            AND (m.completion_time IS NULL OR m.completion_time > b.requested_start_time)
        WHERE i.decision = 'approved'
    )
    BEGIN
        RAISERROR('Cannot approve booking: overlapping out-of-service maintenance.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN bookings b ON b.booking_id = i.booking_id
        WHERE i.decision = 'approved'
          AND EXISTS (
              SELECT 1
              FROM maintenance m
              WHERE m.space_id = b.space_id
                AND m.is_deleted = 0
                AND m.status IN ('open','in_progress')
                AND m.impact_level = 'advisory'
                AND m.start_time < b.requested_end_time
                AND (m.completion_time IS NULL OR m.completion_time > b.requested_start_time)
                AND NOT EXISTS (
                    SELECT 1
                    FROM booking_advisory_acknowledgement a
                    WHERE a.booking_id = b.booking_id
                      AND a.maintenance_id = m.maintenance_id
                )
          )
    )
    BEGIN
        RAISERROR('Cannot approve booking: advisory acknowledgements are missing.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END
GO

-- ------------------------------------------------------------
-- 7c. trg_booking_advisory_ack_validate (NEW, NR2 correspondence)
--     Every acknowledgement must reference an active advisory maintenance
--     whose period overlaps the booking's requested period. Fires on the
--     acknowledgement table so manual (application) ack inserts are checked
--     too; the bookings-side completeness gate lives in 7b.
-- ------------------------------------------------------------
CREATE TRIGGER trg_booking_advisory_ack_validate
ON booking_advisory_acknowledgement
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN bookings b ON b.booking_id = i.booking_id
        INNER JOIN maintenance m ON m.maintenance_id = i.maintenance_id
        WHERE b.is_deleted = 1
           OR m.is_deleted = 1
           OR m.status NOT IN ('open','in_progress')
           OR m.impact_level <> 'advisory'
           OR m.start_time >= b.requested_end_time
           OR (m.completion_time IS NOT NULL AND m.completion_time <= b.requested_start_time)
    )
    BEGIN
        RAISERROR('Acknowledgement must reference an active advisory maintenance overlapping the booking period.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END
GO

-- ------------------------------------------------------------
-- 7d. trg_maintenance_impact_history (NEW, NR3)
--     Records every impact-level change of a still-active maintenance row.
--     changed_by is read from SESSION_CONTEXT(N'current_user_id'); when no
--     user context is set (or the value is not a valid int), the change is
--     attributed to the reserved system user -1 so the NOT NULL FK is always
--     satisfiable. NOTE: SESSION_CONTEXT is session-scoped, not
--     transaction-scoped — see the HANDOFF NOTE in the header (app layer).
-- ------------------------------------------------------------
CREATE TRIGGER trg_maintenance_impact_history
ON maintenance
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF UPDATE(impact_level)
    BEGIN
        DECLARE @changed_by INT = TRY_CAST(SESSION_CONTEXT(N'current_user_id') AS INT);
        IF @changed_by IS NULL
            SET @changed_by = -1;

        INSERT INTO maintenance_impact_history (maintenance_id, changed_by, prior_level, new_level, changed_at, reason)
        SELECT i.maintenance_id, @changed_by, d.impact_level, i.impact_level, GETDATE(), NULL
        FROM inserted i
        INNER JOIN deleted d ON i.maintenance_id = d.maintenance_id
        WHERE d.impact_level <> i.impact_level
          AND i.status IN ('open','in_progress');
    END
END
GO

-- ------------------------------------------------------------
-- 7e. trg_maintenance_recompute_space_status (NEW, replaces BR19 trigger;
--     Task 09 A.3 priority rule, decision point 3)
--     Recomputed on maintenance INSERT/UPDATE for the affected spaces:
--       1 retired (manual, permanent)          — never auto-overridden
--       2 temporarily_closed (manual)          — never auto-overridden
--       3 under_maintenance iff an active out-of-service period covers now
--       4 in_use iff a live booking_sessions row exists (checked in)
--       5 available (fallback)
--     Advisory maintenance never sets under_maintenance. Correctness never
--     depends on this hint — booking/approval checks read maintenance
--     directly (7a/7b).
--     Guard: recompute only when a status-relevant column changed. UPDATE()
--     returns TRUE on INSERT (every column counts as updated), so the INSERT
--     path is unaffected — the guard only skips no-op UPDATEs (e.g. editing
--     problem_description/result_note alone). is_deleted is included because
--     soft-deleting an open ticket must also recompute.
-- ------------------------------------------------------------
CREATE TRIGGER trg_maintenance_recompute_space_status
ON maintenance
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF UPDATE(status) OR UPDATE(impact_level) OR UPDATE(start_time)
       OR UPDATE(completion_time) OR UPDATE(is_deleted)
    BEGIN
        DECLARE @now_rec DATETIME2 = SYSDATETIME();
        UPDATE s
        SET current_status =
            CASE
                WHEN s.current_status = 'retired' THEN 'retired'
                WHEN s.current_status = 'temporarily_closed' THEN 'temporarily_closed'
                WHEN EXISTS (
                    SELECT 1 FROM maintenance m
                    WHERE m.space_id = s.space_id
                      AND m.is_deleted = 0
                      AND m.status IN ('open','in_progress')
                      AND m.impact_level = 'out-of-service'
                      AND m.start_time <= @now_rec
                      AND (m.completion_time IS NULL OR m.completion_time > @now_rec)
                ) THEN 'under_maintenance'
                WHEN EXISTS (
                    SELECT 1 FROM booking_sessions bs
                    INNER JOIN bookings b ON b.booking_id = bs.booking_id
                    WHERE b.space_id = s.space_id
                      AND b.is_deleted = 0
                      AND bs.actual_end_time IS NULL
                ) THEN 'in_use'
                ELSE 'available'
            END
        FROM spaces s
        INNER JOIN inserted i ON s.space_id = i.space_id;
    END
END
GO

-- ------------------------------------------------------------
-- 7f. updated_at auto-stamp triggers for the two new tables (BR12 pattern,
--     same shape as the Phase 1 updated_at triggers)
-- ------------------------------------------------------------
CREATE TRIGGER trg_maintenance_impact_history_updated_at
ON maintenance_impact_history
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(updated_at)
    BEGIN
        UPDATE h
        SET updated_at = GETDATE()
        FROM maintenance_impact_history h
        INNER JOIN inserted i ON h.history_id = i.history_id;
    END
END
GO

CREATE TRIGGER trg_booking_advisory_acknowledgement_updated_at
ON booking_advisory_acknowledgement
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(updated_at)
    BEGIN
        UPDATE a
        SET updated_at = GETDATE()
        FROM booking_advisory_acknowledgement a
        INNER JOIN inserted i ON a.ack_id = i.ack_id;
    END
END
GO

-- ============================================================
-- 8. Commit
-- ============================================================
COMMIT TRANSACTION;
GO

PRINT 'MIGRATION-OK: Phase 2 schema migration applied.';
GO

-- ============================================================
-- 9. POST-MIGRATION VALIDATION (reviewer-runnable, no hardcoded counts)
-- ============================================================

-- 9.1 Phase 2 tables exist
SELECT '9.1 tables' AS check_name,
       CASE WHEN OBJECT_ID(N'dbo.maintenance_impact_history', N'U') IS NOT NULL
             AND OBJECT_ID(N'dbo.booking_advisory_acknowledgement', N'U') IS NOT NULL
            THEN 'PASS' ELSE 'FAIL' END AS result,
       'maintenance_impact_history + booking_advisory_acknowledgement' AS detail;
GO

-- 9.2 impact_level column + default + check
SELECT '9.2 impact_level' AS check_name,
       CASE WHEN COL_LENGTH(N'dbo.maintenance', N'impact_level') IS NOT NULL
             AND EXISTS (SELECT 1 FROM sys.default_constraints WHERE parent_object_id = OBJECT_ID(N'dbo.maintenance') AND name = N'DF_maintenance_impact_level')
             AND EXISTS (SELECT 1 FROM sys.check_constraints WHERE parent_object_id = OBJECT_ID(N'dbo.maintenance') AND name = N'CK_maintenance_impact_level')
            THEN 'PASS' ELSE 'FAIL' END AS result,
       'column+DF+CK present, NOT NULL default out-of-service' AS detail;
GO

-- 9.3 legacy maintenance rows backfilled (none may be NULL)
SELECT '9.3 legacy backfill' AS check_name,
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS result,
       'maintenance rows with NULL impact_level' AS detail
FROM dbo.maintenance
WHERE impact_level IS NULL;
GO

-- 9.4 impact_level value distribution (informational)
SELECT impact_level, COUNT(*) AS maintenance_rows
FROM dbo.maintenance
GROUP BY impact_level;
GO

-- 9.5 constraints on the new tables
SELECT '9.5 constraints' AS check_name,
       CASE WHEN
            EXISTS (SELECT 1 FROM sys.objects WHERE name = N'PK_maintenance_impact_history' AND type = 'PK')
        AND EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_maintenance_impact_history_maintenance_id' AND type = 'F')
        AND EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_maintenance_impact_history_changed_by' AND type = 'F')
        AND EXISTS (SELECT 1 FROM sys.objects WHERE name = N'PK_booking_advisory_acknowledgement' AND type = 'PK')
        AND EXISTS (SELECT 1 FROM sys.objects WHERE name = N'UQ_booking_advisory_ack_booking_maintenance' AND type = 'UQ')
        AND EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_booking_advisory_ack_booking_id' AND type = 'F')
        AND EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_booking_advisory_ack_maintenance_id' AND type = 'F')
        AND EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_booking_advisory_ack_acknowledged_by' AND type = 'F')
            THEN 'PASS' ELSE 'FAIL' END AS result,
       'PK/FK/UQ/CHECK of the two new tables' AS detail;
GO

-- 9.6 new indexes exist
SELECT '9.6 indexes' AS check_name,
       CASE WHEN
            EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'idx_maintenance_impact_history_maintenance')
        AND EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'idx_maintenance_impact_history_changed_by')
        AND EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'idx_booking_advisory_ack_maintenance')
        AND EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'idx_booking_advisory_ack_acknowledged_by')
        AND EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UQ_booking_advisory_ack_booking_maintenance')
            THEN 'PASS' ELSE 'FAIL' END AS result,
       '4 nonclustered + composite UQ index' AS detail;
GO

-- 9.7 triggers present (replaced + new)
SELECT '9.7 triggers' AS check_name,
       CASE WHEN
            OBJECT_ID(N'dbo.trg_bookings_check_maintenance', N'TR') IS NOT NULL
        AND OBJECT_ID(N'dbo.trg_booking_approvals_check_space', N'TR') IS NOT NULL
        AND OBJECT_ID(N'dbo.trg_booking_advisory_ack_validate', N'TR') IS NOT NULL
        AND OBJECT_ID(N'dbo.trg_maintenance_impact_history', N'TR') IS NOT NULL
        AND OBJECT_ID(N'dbo.trg_maintenance_recompute_space_status', N'TR') IS NOT NULL
        AND OBJECT_ID(N'dbo.trg_maintenance_impact_history_updated_at', N'TR') IS NOT NULL
        AND OBJECT_ID(N'dbo.trg_booking_advisory_acknowledgement_updated_at', N'TR') IS NOT NULL
        AND OBJECT_ID(N'dbo.trg_maintenance_completion_space_status', N'TR') IS NULL
            THEN 'PASS' ELSE 'FAIL' END AS result,
       'replaced BR4/BR2/BR19 triggers + 5 new triggers' AS detail;
GO

-- 9.8 reserved system approver exists (NR5, decision point 2)
SELECT '9.8 system approver' AS check_name,
       CASE WHEN EXISTS (
                SELECT 1 FROM dbo.users
                WHERE user_id = -1
                  AND email = N'system@campus.edu'
                  AND role = 'facility_manager'
                  AND account_status = 'active'
            ) THEN 'PASS' ELSE 'FAIL' END AS result,
       'user_id = -1 System Booking Service' AS detail;
GO

-- 9.9 current_status consistency spot-check:
--     spaces with an active out-of-service period covering now that are not
--     flagged under_maintenance (manual overrides excluded).
SELECT '9.9 status recompute' AS check_name,
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'WARN' END AS result,
       'spaces with active OOS covering now but not under_maintenance' AS detail
FROM dbo.spaces s
WHERE s.current_status NOT IN ('retired','temporarily_closed')
  AND EXISTS (
      SELECT 1 FROM dbo.maintenance m
      WHERE m.space_id = s.space_id
        AND m.is_deleted = 0
        AND m.status IN ('open','in_progress')
        AND m.impact_level = 'out-of-service'
        AND m.start_time <= SYSDATETIME()
        AND (m.completion_time IS NULL OR m.completion_time > SYSDATETIME())
  )
  AND s.current_status <> 'under_maintenance';
GO

-- 9.10 Semantics smoke checks (advisory/out-of-service + ack + history).
--      Self-contained: every sub-test runs inside its own transaction that is
--      always rolled back (nothing persists, no destructive cleanup, no Task
--      06 row counts assumed). Expected-error sub-tests follow the Task 06
--      pattern — Phase 1-style triggers ROLLBACK the whole transaction, so
--      each expected error is isolated. Skips gracefully if the baseline
--      carries no spaces/users.
IF NOT EXISTS (SELECT 1 FROM dbo.spaces) OR NOT EXISTS (SELECT 1 FROM dbo.users WHERE account_status = 'active' AND user_id <> -1)
BEGIN
    PRINT 'SKIP: 9.10 semantics smoke checks — no baseline spaces/users to test against.';
END
ELSE
BEGIN
    DECLARE @smoke_space INT = (SELECT TOP 1 space_id FROM dbo.spaces WHERE capacity >= 20 ORDER BY space_id);
    DECLARE @smoke_user  INT = (SELECT TOP 1 user_id FROM dbo.users WHERE account_status = 'active' AND user_id <> -1 ORDER BY user_id);
    DECLARE @win_start DATETIME2 = DATEADD(day, 400, SYSDATETIME());
    DECLARE @win_end   DATETIME2 = DATEADD(hour, 2, @win_start);
    DECLARE @m_id INT, @bk_id INT, @st VARCHAR(50);

    -- S1: out-of-service maintenance overlapping the window blocks booking (BR4 Phase 2)
    BEGIN TRY
        BEGIN TRANSACTION;
        INSERT INTO dbo.maintenance (space_id, reporter_id, problem_description, start_time, status, impact_level)
        VALUES (@smoke_space, @smoke_user, N'MIG-SMOKE: out-of-service ticket', DATEADD(day, -1, SYSDATETIME()), 'open', 'out-of-service');
        BEGIN TRY
            INSERT INTO dbo.bookings (space_id, requester_id, requested_start_time, requested_end_time, purpose, expected_participants)
            VALUES (@smoke_space, @smoke_user, @win_start, @win_end, 'meeting', 10);
            PRINT 'FAIL: 9.10-S1 out-of-service did not block the booking.';
        END TRY
        BEGIN CATCH
            IF ERROR_MESSAGE() LIKE '%Overlapping out-of-service maintenance exists%'
                PRINT 'PASS: 9.10-S1 out-of-service blocks overlapping booking.';
            ELSE
                PRINT 'FAIL: 9.10-S1 unexpected error: ' + ERROR_MESSAGE();
            IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        END CATCH;
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        PRINT 'FAIL: 9.10-S1 aborted: ' + ERROR_MESSAGE();
    END CATCH;

    -- S2..S10 happy path (one transaction, no expected errors):
    --   S2 advisory allows booking (NR1)  S3 ack accepted (NR2)
    --   S5 ack against a different advisory accepted (composite UQ shape)
    --   S7 instant approval accepted when acks are complete (NR5)
    --   S8 escalation recorded in maintenance_impact_history (NR3)
    --   S9 current_status recomputed to under_maintenance (U5)
    --   S10a guard skips description-only update  S10b is_deleted recompute
    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.maintenance (space_id, reporter_id, problem_description, start_time, status, impact_level)
        VALUES (@smoke_space, @smoke_user, N'MIG-SMOKE: advisory ticket 1', DATEADD(day, -1, SYSDATETIME()), 'open', 'advisory');
        SET @m_id = SCOPE_IDENTITY();

        INSERT INTO dbo.bookings (space_id, requester_id, requested_start_time, requested_end_time, purpose, expected_participants)
        VALUES (@smoke_space, @smoke_user, @win_start, @win_end, 'meeting', 10);
        SET @bk_id = SCOPE_IDENTITY();
        PRINT 'PASS: 9.10-S2 advisory maintenance allows the booking.';

        INSERT INTO dbo.booking_advisory_acknowledgement (booking_id, maintenance_id, acknowledged_by)
        VALUES (@bk_id, @m_id, @smoke_user);
        PRINT 'PASS: 9.10-S3 ack for overlapping advisory accepted.';

        INSERT INTO dbo.maintenance (space_id, reporter_id, problem_description, start_time, status, impact_level)
        VALUES (@smoke_space, @smoke_user, N'MIG-SMOKE: advisory ticket 2', DATEADD(day, -1, SYSDATETIME()), 'open', 'advisory');
        SET @m_id = SCOPE_IDENTITY();

        INSERT INTO dbo.booking_advisory_acknowledgement (booking_id, maintenance_id, acknowledged_by)
        VALUES (@bk_id, @m_id, @smoke_user);
        PRINT 'PASS: 9.10-S5 ack against a different maintenance accepted.';

        INSERT INTO dbo.booking_approvals (booking_id, approver_id, decision_time, decision, decision_note)
        VALUES (@bk_id, -1, SYSDATETIME(), 'approved', N'MIG-SMOKE instant approval');
        PRINT 'PASS: 9.10-S7 instant approval accepted when acks are complete.';

        EXEC sys.sp_set_session_context N'current_user_id', @smoke_user;
        UPDATE dbo.maintenance SET impact_level = 'out-of-service' WHERE maintenance_id = @m_id;
        EXEC sys.sp_set_session_context N'current_user_id', NULL;
        IF EXISTS (SELECT 1 FROM dbo.maintenance_impact_history
                   WHERE maintenance_id = @m_id AND prior_level = 'advisory' AND new_level = 'out-of-service' AND changed_by = @smoke_user)
            PRINT 'PASS: 9.10-S8 escalation recorded in maintenance_impact_history.';
        ELSE
            PRINT 'FAIL: 9.10-S8 escalation history row missing.';

        SELECT @st = current_status FROM dbo.spaces WHERE space_id = @smoke_space;
        IF @st = 'under_maintenance'
            PRINT 'PASS: 9.10-S9 current_status recomputed to under_maintenance.';
        ELSE
            PRINT 'FAIL: 9.10-S9 current_status not recomputed (got ' + ISNULL(@st, 'NULL') + ').';

        UPDATE dbo.maintenance SET problem_description = N'MIG-SMOKE: description-only edit' WHERE maintenance_id = @m_id;
        SELECT @st = current_status FROM dbo.spaces WHERE space_id = @smoke_space;
        IF @st = 'under_maintenance'
            PRINT 'PASS: 9.10-S10a description-only update skipped by guard (status unchanged).';
        ELSE
            PRINT 'FAIL: 9.10-S10a status changed on description-only update (got ' + ISNULL(@st, 'NULL') + ').';

        UPDATE dbo.maintenance SET is_deleted = 1 WHERE maintenance_id = @m_id;
        SELECT @st = current_status FROM dbo.spaces WHERE space_id = @smoke_space;
        IF @st = 'available'
            PRINT 'PASS: 9.10-S10b soft-delete recomputed space to available (is_deleted in guard).';
        ELSE
            PRINT 'FAIL: 9.10-S10b soft-delete did not recompute (got ' + ISNULL(@st, 'NULL') + ').';

        ROLLBACK TRANSACTION;
        PRINT 'SMOKE-DONE: 9.10 happy-path checks rolled back (no data persisted).';
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        PRINT 'FAIL: 9.10 happy-path sub-tests aborted: ' + ERROR_MESSAGE();
    END CATCH;

    -- S4: composite UNIQUE — a second ack for the same (booking, advisory) pair must be rejected
    BEGIN TRY
        BEGIN TRANSACTION;
        INSERT INTO dbo.maintenance (space_id, reporter_id, problem_description, start_time, status, impact_level)
        VALUES (@smoke_space, @smoke_user, N'MIG-SMOKE: advisory ticket 1', DATEADD(day, -1, SYSDATETIME()), 'open', 'advisory');
        SET @m_id = SCOPE_IDENTITY();
        INSERT INTO dbo.bookings (space_id, requester_id, requested_start_time, requested_end_time, purpose, expected_participants)
        VALUES (@smoke_space, @smoke_user, @win_start, @win_end, 'meeting', 10);
        SET @bk_id = SCOPE_IDENTITY();
        INSERT INTO dbo.booking_advisory_acknowledgement (booking_id, maintenance_id, acknowledged_by)
        VALUES (@bk_id, @m_id, @smoke_user);
        BEGIN TRY
            INSERT INTO dbo.booking_advisory_acknowledgement (booking_id, maintenance_id, acknowledged_by)
            VALUES (@bk_id, @m_id, @smoke_user);
            PRINT 'FAIL: 9.10-S4 duplicate ack pair was accepted.';
        END TRY
        BEGIN CATCH
            IF ERROR_MESSAGE() LIKE '%UQ_booking_advisory_ack_booking_maintenance%'
                PRINT 'PASS: 9.10-S4 composite UQ rejects a duplicate (booking, advisory) pair.';
            ELSE
                PRINT 'FAIL: 9.10-S4 unexpected error: ' + ERROR_MESSAGE();
            IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        END CATCH;
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        PRINT 'FAIL: 9.10-S4 aborted: ' + ERROR_MESSAGE();
    END CATCH;

    -- S6: approval gate — a booking without advisory acknowledgements cannot be approved
    BEGIN TRY
        BEGIN TRANSACTION;
        INSERT INTO dbo.maintenance (space_id, reporter_id, problem_description, start_time, status, impact_level)
        VALUES (@smoke_space, @smoke_user, N'MIG-SMOKE: advisory ticket 1', DATEADD(day, -1, SYSDATETIME()), 'open', 'advisory');
        INSERT INTO dbo.bookings (space_id, requester_id, requested_start_time, requested_end_time, purpose, expected_participants)
        VALUES (@smoke_space, @smoke_user, DATEADD(day, 401, SYSDATETIME()), DATEADD(hour, 2, DATEADD(day, 401, SYSDATETIME())), 'meeting', 10);
        SET @bk_id = SCOPE_IDENTITY();
        BEGIN TRY
            INSERT INTO dbo.booking_approvals (booking_id, approver_id, decision_time, decision, decision_note)
            VALUES (@bk_id, -1, SYSDATETIME(), 'approved', N'MIG-SMOKE');
            PRINT 'FAIL: 9.10-S6 approval without acks was accepted.';
        END TRY
        BEGIN CATCH
            IF ERROR_MESSAGE() LIKE '%advisory acknowledgements are missing%'
                PRINT 'PASS: 9.10-S6 approval gate rejects missing advisory acknowledgements.';
            ELSE
                PRINT 'FAIL: 9.10-S6 unexpected error: ' + ERROR_MESSAGE();
            IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        END CATCH;
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        PRINT 'FAIL: 9.10-S6 aborted: ' + ERROR_MESSAGE();
    END CATCH;
END
GO

PRINT 'MIGRATION-VALIDATION-DONE';
GO
