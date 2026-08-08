SET QUOTED_IDENTIFIER ON
GO
SET XACT_ABORT ON;
GO

-- ============================================================
-- CS486 G05 — Campus Space Management System
-- Task 10: Phase 2 Schema Migration — ROLLBACK script
-- Target: SQL Server 2019+ (T-SQL)
--
-- Reverses every additive change made by
-- outputs/10-schema-migration-G05.sql, so a bad migration can be undone
-- during testing:
--   1. drops the new/replaced Phase 2 triggers,
--   2. restores the three Phase 1 trigger definitions
--      (trg_bookings_check_maintenance, trg_booking_approvals_check_space,
--      trg_maintenance_completion_space_status) from the Phase 1 baseline,
--   3. drops the three new tables (incl. space_type_allowed_purpose),
--   4. drops maintenance.impact_level (column + DF/CK),
--   5. restores spaces.usage_policy NVARCHAR(MAX) NULL (Phase 1 free-text
--      column dropped by the migration — re-added empty; its values were
--      never read by any enforcement logic, see migration header D9).
--      v2.6: the migration adds NO spaces.max_hours column, so there is no
--      drop step for it here (Task 09 v2.6 removed the duration cap),
--   6. removes the reserved system approver seed row (-1) and any instant
--      approvals referencing it (plus the School Administration department
--      only if it was created by the migration and is still unreferenced).
--
-- NOTE: spaces.current_status values recomputed by the migration are kept —
-- under the restored Phase 1 rules every active maintenance blocks again, so
-- the recomputed hints remain consistent with Phase 1 semantics.
-- ============================================================

-- ============================================================
-- Preflight: only run when the Phase 2 schema is present
-- ============================================================
IF OBJECT_ID(N'dbo.maintenance_impact_history', N'U') IS NULL
   AND OBJECT_ID(N'dbo.booking_advisory_acknowledgement', N'U') IS NULL
   AND OBJECT_ID(N'dbo.space_type_allowed_purpose', N'U') IS NULL
   AND COL_LENGTH(N'dbo.maintenance', N'impact_level') IS NULL
   AND COL_LENGTH(N'dbo.spaces', N'usage_policy') IS NOT NULL
BEGIN
    PRINT 'Rollback not needed: no Phase 2 migration objects found.';
END
GO

BEGIN TRANSACTION;
GO

-- ============================================================
-- 1. Drop Phase 2 triggers (new + replaced versions)
-- ============================================================
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

IF OBJECT_ID(N'dbo.trg_space_type_allowed_purpose_updated_at', N'TR') IS NOT NULL
    DROP TRIGGER dbo.trg_space_type_allowed_purpose_updated_at;
GO

IF OBJECT_ID(N'dbo.trg_bookings_check_maintenance', N'TR') IS NOT NULL
    DROP TRIGGER dbo.trg_bookings_check_maintenance;
GO

IF OBJECT_ID(N'dbo.trg_booking_approvals_check_space', N'TR') IS NOT NULL
    DROP TRIGGER dbo.trg_booking_approvals_check_space;
GO

IF OBJECT_ID(N'dbo.trg_maintenance_completion_space_status', N'TR') IS NOT NULL
    DROP TRIGGER dbo.trg_maintenance_completion_space_status;
GO

-- ============================================================
-- 2. Drop the three new tables (child-first: ack references maintenance)
-- ============================================================
IF OBJECT_ID(N'dbo.booking_advisory_acknowledgement', N'U') IS NOT NULL
    DROP TABLE dbo.booking_advisory_acknowledgement;
GO

IF OBJECT_ID(N'dbo.maintenance_impact_history', N'U') IS NOT NULL
    DROP TABLE dbo.maintenance_impact_history;
GO

IF OBJECT_ID(N'dbo.space_type_allowed_purpose', N'U') IS NOT NULL
    DROP TABLE dbo.space_type_allowed_purpose;
GO

-- ============================================================
-- 3. Drop maintenance.impact_level (constraints first, then column)
-- ============================================================
IF OBJECT_ID(N'dbo.CK_maintenance_impact_level', N'C') IS NOT NULL
    ALTER TABLE dbo.maintenance DROP CONSTRAINT CK_maintenance_impact_level;
GO

IF OBJECT_ID(N'dbo.DF_maintenance_impact_level', N'D') IS NOT NULL
    ALTER TABLE dbo.maintenance DROP CONSTRAINT DF_maintenance_impact_level;
GO

IF COL_LENGTH(N'dbo.maintenance', N'impact_level') IS NOT NULL
    ALTER TABLE dbo.maintenance DROP COLUMN impact_level;
GO

-- ============================================================
-- 4. Restore the Phase 1 spaces.usage_policy free-text column
--    (the migration's only spaces column change; Task 09 v2.6 adds NO
--    max_hours column, so there is nothing else to drop on spaces)
-- ============================================================
IF COL_LENGTH(N'dbo.spaces', N'usage_policy') IS NULL
    ALTER TABLE dbo.spaces ADD usage_policy NVARCHAR(MAX) NULL;
GO

-- ============================================================
-- 5. Remove reserved seed rows
--    a) instant approvals made against the system approver,
--    b) the system approver user -1,
--    c) the School Administration department IF the migration created it
--       (no other users reference it).
-- ============================================================
DELETE FROM dbo.booking_approvals WHERE approver_id = -1;
GO

DELETE FROM dbo.users WHERE user_id = -1;
GO

DELETE FROM dbo.departments
WHERE name = N'School Administration'
  AND NOT EXISTS (SELECT 1 FROM dbo.users WHERE department_id = dbo.departments.department_id);
GO

-- ============================================================
-- 6. Restore the Phase 1 trigger definitions (outputs/05 baseline)
-- ============================================================

-- BR4 Phase 1: any overlapping unresolved maintenance blocks booking
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
            AND m.start_time < i.requested_end_time
            AND (m.completion_time IS NULL OR m.completion_time > i.requested_start_time)
    )
    BEGIN
        RAISERROR('Overlapping unresolved maintenance exists for this space.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END
GO

-- BR2 Phase 1: unavailable spaces cannot be approved
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
          AND s.current_status NOT IN ('available','in_use')
    )
    BEGIN
        RAISERROR('Cannot approve booking: space is not available.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END
GO

-- BR19 Phase 1: maintenance completion restores space status
-- (with the concurrent-ticket NOT EXISTS guard)
CREATE TRIGGER trg_maintenance_completion_space_status
ON maintenance
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN deleted d ON i.maintenance_id = d.maintenance_id
        WHERE i.status = 'resolved'
          AND d.status != 'resolved'
    )
    BEGIN
        UPDATE s
        SET current_status = 'available'
        FROM spaces s
        INNER JOIN inserted i ON s.space_id = i.space_id
        WHERE NOT EXISTS (
            SELECT 1
            FROM maintenance m
            WHERE m.space_id = i.space_id
              AND m.status IN ('open','in_progress')
              AND m.is_deleted = 0
        );
    END
END
GO

COMMIT TRANSACTION;
GO

PRINT 'ROLLBACK-OK: Phase 2 migration reversed (Phase 1 schema restored).';
GO

-- ============================================================
-- 7. Validation: Phase 1 objects are back
-- ============================================================
SELECT 'R7.1 new tables gone' AS action,
       CASE WHEN OBJECT_ID(N'dbo.space_type_allowed_purpose', N'U') IS NULL
             AND OBJECT_ID(N'dbo.maintenance_impact_history', N'U') IS NULL
             AND OBJECT_ID(N'dbo.booking_advisory_acknowledgement', N'U') IS NULL
            THEN 'PASS' ELSE 'FAIL' END AS result,
       'all Phase 2 tables dropped' AS detail;
GO

SELECT 'R7.2 impact_level gone' AS check_name,
       CASE WHEN COL_LENGTH(N'dbo.maintenance', N'impact_level') IS NULL THEN 'PASS' ELSE 'FAIL' END AS result,
       'maintenance.impact_level + DF/CK dropped' AS detail;
GO

SELECT 'R7.3 spaces restored' AS check_name,
       CASE WHEN COL_LENGTH(N'dbo.spaces', N'usage_policy') IS NOT NULL
             AND COL_LENGTH(N'dbo.spaces', N'max_hours') IS NULL
            THEN 'PASS' ELSE 'FAIL' END AS result,
       'usage_policy column restored; no max_hours column present (v2.6)' AS detail;
GO

SELECT 'R7.4 Phase 1 triggers restored' AS check_name,
       CASE WHEN
            OBJECT_ID(N'dbo.trg_bookings_check_maintenance', N'TR') IS NOT NULL
        AND OBJECT_ID(N'dbo.trg_booking_approvals_check_space', N'TR') IS NOT NULL
        AND OBJECT_ID(N'dbo.trg_maintenance_completion_space_status', N'TR') IS NOT NULL
        AND OBJECT_ID(N'dbo.trg_maintenance_recompute_space_status', N'TR') IS NULL
        AND OBJECT_ID(N'dbo.trg_booking_advisory_ack_validate', N'TR') IS NULL
        AND OBJECT_ID(N'dbo.trg_space_type_allowed_purpose_updated_at', N'TR') IS NULL
            THEN 'PASS' ELSE 'FAIL' END AS result,
       '3 Phase 1 triggers recreated, Phase 2 triggers dropped' AS detail;
GO

SELECT 'R7.5 system approver gone' AS check_name,
       CASE WHEN NOT EXISTS (SELECT 1 FROM dbo.users WHERE user_id = -1) THEN 'PASS' ELSE 'FAIL' END AS result,
       'user_id = -1 removed' AS detail;
GO

SELECT 'R7.6 no instant approvals remain' AS check_name,
       CASE WHEN NOT EXISTS (SELECT 1 FROM dbo.booking_approvals WHERE approver_id = -1) THEN 'PASS' ELSE 'FAIL' END AS result,
       'booking_approvals rows referencing -1 removed' AS detail;
GO

PRINT 'ROLLBACK-VALIDATION-DONE';
GO