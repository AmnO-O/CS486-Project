SET QUOTED_IDENTIFIER ON;
GO
SET ANSI_NULLS ON;
GO
SET XACT_ABORT ON;
GO

-- ============================================================
-- CS486 G05 — Campus Space Management System
-- Task 12: Phase 2 Concurrency Implementation
-- Target: SQL Server 2019+ (T-SQL)
--
-- Upstream files
--   - outputs/10-schema-migration-G05.sql          (implemented Phase 2 schema
--                                                    + trigger contract)
--   - outputs/11-concurrency-design-G05.md         (approved Task 11 design —
--                                                    entry points, result codes,
--                                                    lock contract, workflows)
--
-- Selected strategy (Task 11 §7): per-space transaction-owned
-- sys.sp_getapplock critical section (resource 'space_booking:<space_id>')
-- shared by instant booking, staff approval, maintenance
-- escalation/downgrade, and maintenance-ticket creation starting at
-- out-of-service (Task 11 §9.4, closes K5), with authoritative post-lock
-- invariant re-checks. READ COMMITTED baseline, @LockTimeout = 5000 ms;
-- result codes 51001-51010 exactly as Task 11 §8.5 defines.
--
-- NO-SCHEMA-CHANGE PROMISE
--   This script creates stored procedures only. No tables, columns, keys,
--   indexes, triggers, or seed rows are added, dropped, or altered. The
--   Task 10 trigger set and the filtered unique index uq_bookings_active_overlap
--   are kept untouched as defense-in-depth.
--
-- RESULT-CODE CONTRACT (Task 11 §8.5 + Task 12 additions)
--   0      SUCCESS (procedure)
--   51001  BOOKING-OVERLAP      (BR1/NR6 — post-lock, authoritative)
--   51002  MAINTENANCE-OOS      (BR4 — post-lock, authoritative)
--   51003  ACK-MISSING          (NR2 — post-lock, authoritative)
--   51004  CAPACITY             (BR3 — post-lock, authoritative)
--   51005  LOCK-TIMEOUT         (sp_getapplock -1/-2 — retry)
--   51006  DEADLOCK             (sp_getapplock -3 / SQL 1205 — retry)
--   51007  NOT-ELIGIBLE         (instant path only — space type / inactive requester)
--   51008  ALREADY-DECIDED      (fast-path + post-lock re-check)
--   51009  NO-CHANGE            (escalation/downgrade — post-lock re-check, authoritative)
--   51010  SPACE-CLOSED         (BR2 manual override — distinct from 51002)
--   51011  INVALID-INPUT        (Task 12 addition: caller contract violations —
--                                NULL/unknown entity ids, invalid enums,
--                                inverted time window, BR7 missing rejection
--                                reason, BR15 approver-role pre-check)
--   51012  MAINTENANCE-NOT-ACTIVE (Task 12 addition: escalation/downgrade of a
--                                maintenance row not in 'open'/'in_progress')
--   Preflight failures use THROW 59001-59006 (script-level, not business codes).
--
-- SESSION-CONTEXT CONTRACT (Task 11 §11.3 / Task 10 handoff)
--   SESSION_CONTEXT(N'current_user_id') is set and cleared by the APPLICATION
--   per unit of work (sys.sp_set_session_context). These procedures do NOT
--   touch session context; trigger-generated audit rows
--   (trg_maintenance_impact_history.changed_by) degrade to the reserved
--   system user -1 when the app did not set it. Cleanup on the application
--   side is mandatory (connection-pooling leak risk).
--
-- NOTE on usp_maintenance_set_impact_level @reason
--   @reason is accepted for application-side logging, but the Task 10 trigger
--   trg_maintenance_impact_history persists reason = NULL (hardcoded). Writing
--   the reason into maintenance_impact_history would require a trigger change,
--   which Task 11 §11.2 explicitly forbids — preserved as-is.
-- ============================================================

-- ============================================================
-- 0. PREFLIGHT CHECKS (reviewer-runnable; THROW 59xxx on failure)
--    Fail-fast if the migrated schema / defense-in-depth objects that the
--    Task 11 design relies on are missing.
-- ============================================================
IF OBJECT_ID(N'dbo.bookings', N'U') IS NULL
   OR OBJECT_ID(N'dbo.booking_approvals', N'U') IS NULL
   OR OBJECT_ID(N'dbo.spaces', N'U') IS NULL
   OR OBJECT_ID(N'dbo.users', N'U') IS NULL
   OR OBJECT_ID(N'dbo.maintenance', N'U') IS NULL
   OR OBJECT_ID(N'dbo.booking_advisory_acknowledgement', N'U') IS NULL
   OR OBJECT_ID(N'dbo.maintenance_impact_history', N'U') IS NULL
BEGIN
    THROW 59001, 'Task 12 preflight failed: required tables are missing. Run outputs/05-db-definition-G05.sql then outputs/10-schema-migration-G05.sql first.', 1;
END
GO

IF COL_LENGTH(N'dbo.maintenance', N'impact_level') IS NULL
   OR COL_LENGTH(N'dbo.maintenance', N'status') IS NULL
   OR COL_LENGTH(N'dbo.maintenance', N'space_id') IS NULL
   OR COL_LENGTH(N'dbo.bookings', N'requested_start_time') IS NULL
   OR COL_LENGTH(N'dbo.bookings', N'requested_end_time') IS NULL
   OR COL_LENGTH(N'dbo.bookings', N'status') IS NULL
   OR COL_LENGTH(N'dbo.bookings', N'is_deleted') IS NULL
   OR COL_LENGTH(N'dbo.bookings', N'expected_participants') IS NULL
   OR COL_LENGTH(N'dbo.spaces', N'space_type') IS NULL
   OR COL_LENGTH(N'dbo.spaces', N'capacity') IS NULL
   OR COL_LENGTH(N'dbo.spaces', N'current_status') IS NULL
   OR COL_LENGTH(N'dbo.users', N'account_status') IS NULL
   OR COL_LENGTH(N'dbo.booking_approvals', N'decision') IS NULL
   OR COL_LENGTH(N'dbo.booking_approvals', N'rejection_reason') IS NULL
   OR COL_LENGTH(N'dbo.booking_approvals', N'decision_note') IS NULL
BEGIN
    THROW 59002, 'Task 12 preflight failed: required columns are missing from the migrated schema.', 1;
END
GO

IF OBJECT_ID(N'dbo.trg_bookings_prevent_overlap', N'TR') IS NULL
   OR OBJECT_ID(N'dbo.trg_bookings_check_maintenance', N'TR') IS NULL
   OR OBJECT_ID(N'dbo.trg_bookings_check_capacity', N'TR') IS NULL
   OR OBJECT_ID(N'dbo.trg_booking_approvals_check_space', N'TR') IS NULL
   OR OBJECT_ID(N'dbo.trg_booking_approvals_decision', N'TR') IS NULL
   OR OBJECT_ID(N'dbo.trg_booking_advisory_ack_validate', N'TR') IS NULL
   OR OBJECT_ID(N'dbo.trg_maintenance_impact_history', N'TR') IS NULL
   OR OBJECT_ID(N'dbo.trg_maintenance_recompute_space_status', N'TR') IS NULL
BEGIN
    THROW 59003, 'Task 12 preflight failed: defense-in-depth triggers are missing or were modified.', 1;
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'uq_bookings_active_overlap' AND object_id = OBJECT_ID(N'dbo.bookings'))
   OR NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'idx_bookings_time_range' AND object_id = OBJECT_ID(N'dbo.bookings'))
   OR NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'idx_maintenance_space_id' AND object_id = OBJECT_ID(N'dbo.maintenance'))
   OR NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UQ_booking_advisory_ack_booking_maintenance' AND object_id = OBJECT_ID(N'dbo.booking_advisory_acknowledgement'))
BEGIN
    THROW 59004, 'Task 12 preflight failed: required defense-in-depth indexes are missing.', 1;
END
GO

IF NOT EXISTS (SELECT 1 FROM dbo.users WHERE user_id = -1 AND account_status = 'active')
BEGIN
    THROW 59005, 'Task 12 preflight failed: reserved system approver user_id = -1 is missing (NR5). Run the Task 10 migration seed.', 1;
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE parent_object_id = OBJECT_ID(N'dbo.maintenance') AND name = N'CK_maintenance_impact_level')
BEGIN
    THROW 59006, 'Task 12 preflight failed: CK_maintenance_impact_level is missing.', 1;
END
GO

-- ============================================================
-- 1. ENTRY POINT: usp_booking_instant_submit (Task 11 §9.1 / §11.1)
--    Instant booking: applock -> eligibility (51007) -> BR3 (51004) ->
--    BR2 (51010) -> BR1 (51001) -> BR4 (51002) -> booking INSERT -> advisory
--    acks -> auto-approval with approver_id = -1 -> COMMIT.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.usp_booking_instant_submit
    @space_id              INT,
    @requester_id          INT,
    @requested_start_time  DATETIME2,
    @requested_end_time    DATETIME2,
    @purpose               VARCHAR(50),
    @expected_participants INT,
    @booking_id            INT = NULL OUTPUT,
    @result_code           INT = 0 OUTPUT,
    @message               NVARCHAR(500) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    -- Task 11 §8.4: XACT_ABORT ON so any runtime error aborts the whole unit
    -- of work and the transaction-owned applock is released with it.
    SET XACT_ABORT ON;

    -- ------------------------------------------------------------
    -- 1. Input validation (no locks required — caller contract)
    -- ------------------------------------------------------------
    IF @space_id IS NULL OR @requester_id IS NULL
       OR @requested_start_time IS NULL OR @requested_end_time IS NULL
       OR @purpose IS NULL OR @expected_participants IS NULL
       OR @requested_end_time <= @requested_start_time
       OR @expected_participants <= 0
       OR @purpose NOT IN ('lecture','examination','seminar','workshop','meeting','student_activity','administrative_event')
    BEGIN
        SET @result_code = 51011;
        SET @message = N'INVALID-INPUT: malformed booking parameters (time window, purpose or participants).';
        RETURN 51011;
    END

    DECLARE @lock_rc        INT;
    DECLARE @lock_resource  NVARCHAR(255);
    DECLARE @new_booking_id INT;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- --------------------------------------------------------
        -- 2. Acquire the per-space critical section FIRST (Task 11 §8.1/§8.2)
        --    Resource 'space_booking:<space_id>' shared by instant, staff,
        --    and escalation paths; held until COMMIT/ROLLBACK. The resource
        --    expression is built into a variable first because the
        --    `EXEC @rc = proc` form does not accept expressions as arguments.
        -- --------------------------------------------------------
        SET @lock_resource = N'space_booking:' + CONVERT(NVARCHAR(16), @space_id);
        EXEC @lock_rc = sys.sp_getapplock
            @Resource = @lock_resource,
            @LockMode = 'Exclusive',
            @LockOwner = 'Transaction',
            @LockTimeout = 5000;

        IF @lock_rc IN (-1, -2)   -- -1 timeout, -2 cancelled -> 51005 LOCK-TIMEOUT (retryable)
        BEGIN
            SET @result_code = 51005;
            SET @message = N'LOCK-TIMEOUT: could not acquire the space critical section within 5 s. Retry the request.';
            ROLLBACK TRANSACTION;
            RETURN 51005;
        END
        IF @lock_rc = -3          -- -3 deadlock victim -> 51006 DEADLOCK (retryable; never merged into 51005)
        BEGIN
            SET @result_code = 51006;
            SET @message = N'DEADLOCK: this session was chosen as the deadlock victim on the space critical section. Retry the request.';
            ROLLBACK TRANSACTION;
            RETURN 51006;
        END
        IF @lock_rc < 0           -- any other negative return (e.g. -999) -> unexpected, rethrow via CATCH
        BEGIN
            THROW 59006, 'sp_getapplock returned an unexpected negative result code.', 1;
        END

        -- --------------------------------------------------------
        -- 3. Post-lock authoritative checks (Task 11 §9.1 steps 3-7)
        -- --------------------------------------------------------
        -- 3.1 Eligibility (U1): space type + requester account status (51007)
        DECLARE @space_type VARCHAR(50), @space_capacity INT, @space_status VARCHAR(50);
        SELECT @space_type = space_type,
               @space_capacity = capacity,
               @space_status = current_status
        FROM dbo.spaces
        WHERE space_id = @space_id;

        IF @space_type IS NULL
        BEGIN
            SET @result_code = 51011;
            SET @message = N'INVALID-INPUT: space not found.';
            ROLLBACK TRANSACTION;
            RETURN 51011;
        END
        IF @space_type NOT IN ('classroom','computer_lab','project_lab','meeting_room')
        BEGIN
            SET @result_code = 51007;
            SET @message = N'NOT-ELIGIBLE: space type is not eligible for instant booking (NR5).';
            ROLLBACK TRANSACTION;
            RETURN 51007;
        END

        DECLARE @requester_status VARCHAR(50);
        SELECT @requester_status = account_status
        FROM dbo.users
        WHERE user_id = @requester_id;

        IF @requester_status IS NULL
        BEGIN
            SET @result_code = 51011;
            SET @message = N'INVALID-INPUT: requester not found.';
            ROLLBACK TRANSACTION;
            RETURN 51011;
        END
        IF @requester_status <> 'active'
        BEGIN
            SET @result_code = 51007;
            SET @message = N'NOT-ELIGIBLE: requester account is not active (NR5 eligibility).';
            ROLLBACK TRANSACTION;
            RETURN 51007;
        END

        -- 3.2 BR3: participants must fit capacity (51004)
        IF @expected_participants > @space_capacity
        BEGIN
            SET @result_code = 51004;
            SET @message = N'CAPACITY: expected participants exceed the space capacity (BR3).';
            ROLLBACK TRANSACTION;
            RETURN 51004;
        END

        -- 3.3 BR2 manual override (51010 — distinct from 51002, Task 11 rev 1.2)
        IF @space_status IN ('temporarily_closed','retired')
        BEGIN
            SET @result_code = 51010;
            SET @message = N'SPACE-CLOSED: the space is manually closed or retired (BR2).';
            ROLLBACK TRANSACTION;
            RETURN 51010;
        END

        -- 3.4 BR1 / NR6: no confirmed booking overlapping the window (51001)
        IF EXISTS (
            SELECT 1
            FROM dbo.bookings b
            WHERE b.space_id = @space_id
              AND b.is_deleted = 0
              AND b.status IN ('approved','checked_in','completed')
              AND b.requested_start_time < @requested_end_time
              AND b.requested_end_time > @requested_start_time
        )
        BEGIN
            SET @result_code = 51001;
            SET @message = N'BOOKING-OVERLAP: another confirmed booking overlaps this period on the space (BR1/NR6).';
            ROLLBACK TRANSACTION;
            RETURN 51001;
        END

        -- 3.5 BR4: no active out-of-service maintenance overlap (51002)
        IF EXISTS (
            SELECT 1
            FROM dbo.maintenance m
            WHERE m.space_id = @space_id
              AND m.is_deleted = 0
              AND m.status IN ('open','in_progress')
              AND m.impact_level = 'out-of-service'
              AND m.start_time < @requested_end_time
              AND (m.completion_time IS NULL OR m.completion_time > @requested_start_time)
        )
        BEGIN
            SET @result_code = 51002;
            SET @message = N'MAINTENANCE-OOS: overlapping out-of-service maintenance exists on this space (BR4).';
            ROLLBACK TRANSACTION;
            RETURN 51002;
        END

        -- --------------------------------------------------------
        -- 4. INSERT the booking (status defaults to 'pending'); triggers
        --    trg_bookings_check_maintenance + trg_bookings_prevent_overlap
        --    re-check as defense-in-depth.
        -- --------------------------------------------------------
        INSERT INTO dbo.bookings (space_id, requester_id, requested_start_time, requested_end_time, purpose, expected_participants)
        VALUES (@space_id, @requester_id, @requested_start_time, @requested_end_time, @purpose, @expected_participants);
        SET @new_booking_id = SCOPE_IDENTITY();

        -- --------------------------------------------------------
        -- 5. NR2: acknowledge every overlapping active advisory in the SAME
        --    transaction (ack rows first, so the approval gate passes first
        --    time; trg_booking_advisory_ack_validate re-checks each row).
        -- --------------------------------------------------------
        INSERT INTO dbo.booking_advisory_acknowledgement (booking_id, maintenance_id, acknowledged_by)
        SELECT @new_booking_id, m.maintenance_id, @requester_id
        FROM dbo.maintenance m
        WHERE m.space_id = @space_id
          AND m.is_deleted = 0
          AND m.status IN ('open','in_progress')
          AND m.impact_level = 'advisory'
          AND m.start_time < @requested_end_time
          AND (m.completion_time IS NULL OR m.completion_time > @requested_start_time);

        -- --------------------------------------------------------
        -- 6. Instant auto-approval with the reserved system approver -1 (NR5);
        --    trg_booking_approvals_decision sets status='approved';
        --    trg_booking_approvals_check_space re-checks BR2/BR4/NR2.
        -- --------------------------------------------------------
        INSERT INTO dbo.booking_approvals (booking_id, approver_id, decision_time, decision, decision_note)
        VALUES (@new_booking_id, -1, SYSDATETIME(), 'approved', N'Instant booking auto-approval (NR5).');

        COMMIT TRANSACTION;

        SET @booking_id = @new_booking_id;
        SET @result_code = 0;
        SET @message = N'SUCCESS: booking created and instantly approved.';
        RETURN 0;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        -- SQL 1205 raised by the engine (data-lock deadlock or applock victim
        -- surfaced as an error) maps to the Task 11 retryable 51006.
        IF ERROR_NUMBER() = 1205
        BEGIN
            SET @result_code = 51006;
            SET @message = N'DEADLOCK: transaction aborted as deadlock victim (SQL 1205). Retry the request.';
            RETURN 51006;
        END
        ELSE
        BEGIN
            -- Unexpected error: roll back (done above) and rethrow; triggers
            -- rejected a write the procedure pre-check missed (defense-in-depth).
            THROW;
        END
    END CATCH
END
GO

-- ============================================================
-- 2. ENTRY POINT: usp_booking_approve (Task 11 §9.2 / §11.1)
--    Staff workflow: fast-path booking read (51008 early exit) -> applock on
--    the booking's space -> authoritative re-read (pending, 51008) ->
--    BR1 (51001) / BR4 (51002) / BR2 (51010) / NR2 (51003) when approving ->
--    approval INSERT -> COMMIT.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.usp_booking_approve
    @booking_id       INT,
    @approver_id      INT,
    @decision         VARCHAR(50),
    @rejection_reason NVARCHAR(MAX) = NULL,
    @decision_note    NVARCHAR(MAX) = NULL,
    @result_code      INT = 0 OUTPUT,
    @message          NVARCHAR(500) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- ------------------------------------------------------------
    -- 1. Input validation (no locks required — caller contract)
    --    BR7 pre-check: a rejection must carry a reason.
    -- ------------------------------------------------------------
    IF @booking_id IS NULL OR @approver_id IS NULL OR @decision IS NULL
       OR @decision NOT IN ('approved','rejected')
       OR (@decision = 'rejected' AND @rejection_reason IS NULL)
    BEGIN
        SET @result_code = 51011;
        SET @message = N'INVALID-INPUT: decision must be approved/rejected and a rejected decision requires a rejection reason (BR7).';
        RETURN 51011;
    END

    -- BR15 pre-check: the approver must be an existing facility staff/manager
    -- (the BR15 trigger remains the authoritative last line).
    IF NOT EXISTS (
        SELECT 1 FROM dbo.users
        WHERE user_id = @approver_id
          AND role IN ('facility_staff','facility_manager')
    )
    BEGIN
        SET @result_code = 51011;
        SET @message = N'INVALID-INPUT: approver must be an active facility staff/manager (BR15 pre-check).';
        RETURN 51011;
    END

    DECLARE @lock_rc  INT;
    DECLARE @lock_resource NVARCHAR(255);
    DECLARE @space_id INT;
    DECLARE @bk_status VARCHAR(50);
    DECLARE @req_start DATETIME2, @req_end DATETIME2;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- --------------------------------------------------------
        -- 2. Fast-path read (Task 11 §9.2 step 2) — resolves space_id and
        --    exits early on already-decided bookings. EARLY EXIT ONLY:
        --    not authoritative (a concurrent decision may commit before the
        --    lock is granted).
        -- --------------------------------------------------------
        SELECT @space_id = space_id,
               @bk_status = status,
               @req_start = requested_start_time,
               @req_end = requested_end_time
        FROM dbo.bookings
        WHERE booking_id = @booking_id
          AND is_deleted = 0;

        IF @space_id IS NULL
        BEGIN
            SET @result_code = 51011;
            SET @message = N'INVALID-INPUT: booking not found.';
            ROLLBACK TRANSACTION;
            RETURN 51011;
        END

        IF EXISTS (SELECT 1 FROM dbo.booking_approvals WHERE booking_id = @booking_id)
        BEGIN
            SET @result_code = 51008;
            SET @message = N'ALREADY-DECIDED: this booking already has an approval decision.';
            ROLLBACK TRANSACTION;
            RETURN 51008;
        END

        -- --------------------------------------------------------
        -- 3. Acquire the booking's space critical section (same resource as
        --    the instant and escalation paths — the K2 killer).
        -- --------------------------------------------------------
        SET @lock_resource = N'space_booking:' + CONVERT(NVARCHAR(16), @space_id);
        EXEC @lock_rc = sys.sp_getapplock
            @Resource = @lock_resource,
            @LockMode = 'Exclusive',
            @LockOwner = 'Transaction',
            @LockTimeout = 5000;

        IF @lock_rc IN (-1, -2)
        BEGIN
            SET @result_code = 51005;
            SET @message = N'LOCK-TIMEOUT: could not acquire the space critical section within 5 s. Retry the request.';
            ROLLBACK TRANSACTION;
            RETURN 51005;
        END
        IF @lock_rc = -3
        BEGIN
            SET @result_code = 51006;
            SET @message = N'DEADLOCK: this session was chosen as the deadlock victim on the space critical section. Retry the request.';
            ROLLBACK TRANSACTION;
            RETURN 51006;
        END
        IF @lock_rc < 0
        BEGIN
            THROW 59006, 'sp_getapplock returned an unexpected negative result code.', 1;
        END

        -- --------------------------------------------------------
        -- 4. Authoritative re-read under the lock (Task 11 §9.2 step 4) —
        --    the K1/K2 killer: the winner's committed write is now visible.
        -- --------------------------------------------------------
        SELECT @space_id = space_id,
               @bk_status = status,
               @req_start = requested_start_time,
               @req_end = requested_end_time
        FROM dbo.bookings
        WHERE booking_id = @booking_id
          AND is_deleted = 0;

        IF @space_id IS NULL
        BEGIN
            SET @result_code = 51011;
            SET @message = N'INVALID-INPUT: booking not found.';
            ROLLBACK TRANSACTION;
            RETURN 51011;
        END
        IF @bk_status <> 'pending'
        BEGIN
            SET @result_code = 51008;
            SET @message = N'ALREADY-DECIDED: booking is no longer pending.';
            ROLLBACK TRANSACTION;
            RETURN 51008;
        END
        IF EXISTS (SELECT 1 FROM dbo.booking_approvals WHERE booking_id = @booking_id)
        BEGIN
            SET @result_code = 51008;
            SET @message = N'ALREADY-DECIDED: this booking already has an approval decision.';
            ROLLBACK TRANSACTION;
            RETURN 51008;
        END

        -- --------------------------------------------------------
        -- 5. Availability gates apply ONLY to confirmations; a rejection is
        --    always allowed (it confirms nothing).
        -- --------------------------------------------------------
        IF @decision = 'approved'
        BEGIN
            -- 5.1 BR1 / NR6 (51001)
            IF EXISTS (
                SELECT 1
                FROM dbo.bookings b
                WHERE b.space_id = @space_id
                  AND b.booking_id <> @booking_id
                  AND b.is_deleted = 0
                  AND b.status IN ('approved','checked_in','completed')
                  AND b.requested_start_time < @req_end
                  AND b.requested_end_time > @req_start
            )
            BEGIN
                SET @result_code = 51001;
                SET @message = N'BOOKING-OVERLAP: another confirmed booking overlaps this period on the space (BR1/NR6).';
                ROLLBACK TRANSACTION;
                RETURN 51001;
            END

            -- 5.2 BR4 (51002)
            IF EXISTS (
                SELECT 1
                FROM dbo.maintenance m
                WHERE m.space_id = @space_id
                  AND m.is_deleted = 0
                  AND m.status IN ('open','in_progress')
                  AND m.impact_level = 'out-of-service'
                  AND m.start_time < @req_end
                  AND (m.completion_time IS NULL OR m.completion_time > @req_start)
            )
            BEGIN
                SET @result_code = 51002;
                SET @message = N'MAINTENANCE-OOS: overlapping out-of-service maintenance exists on this space (BR4).';
                ROLLBACK TRANSACTION;
                RETURN 51002;
            END

            -- 5.3 BR2 manual override (51010)
            IF EXISTS (
                SELECT 1 FROM dbo.spaces
                WHERE space_id = @space_id
                  AND current_status IN ('temporarily_closed','retired')
            )
            BEGIN
                SET @result_code = 51010;
                SET @message = N'SPACE-CLOSED: the space is manually closed or retired (BR2).';
                ROLLBACK TRANSACTION;
                RETURN 51010;
            END

            -- 5.4 NR2: every overlapping active advisory must have an ack (51003)
            IF EXISTS (
                SELECT 1
                FROM dbo.maintenance m
                WHERE m.space_id = @space_id
                  AND m.is_deleted = 0
                  AND m.status IN ('open','in_progress')
                  AND m.impact_level = 'advisory'
                  AND m.start_time < @req_end
                  AND (m.completion_time IS NULL OR m.completion_time > @req_start)
                  AND NOT EXISTS (
                      SELECT 1 FROM dbo.booking_advisory_acknowledgement a
                      WHERE a.booking_id = @booking_id
                        AND a.maintenance_id = m.maintenance_id
                  )
            )
            BEGIN
                SET @result_code = 51003;
                SET @message = N'ACK-MISSING: advisory acknowledgements are incomplete (NR2).';
                ROLLBACK TRANSACTION;
                RETURN 51003;
            END
        END

        -- --------------------------------------------------------
        -- 6. Record the decision (BR7 trigger re-checks rejection reasons;
        --    trg_booking_approvals_check_space re-checks approved decisions;
        --    trg_booking_approvals_decision syncs bookings.status).
        -- --------------------------------------------------------
        INSERT INTO dbo.booking_approvals (booking_id, approver_id, decision_time, decision, rejection_reason, decision_note)
        VALUES (@booking_id, @approver_id, SYSDATETIME(), @decision, @rejection_reason, @decision_note);

        COMMIT TRANSACTION;

        SET @result_code = 0;
        SET @message = N'SUCCESS: decision recorded (approved or rejected).';
        RETURN 0;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        IF ERROR_NUMBER() = 1205
        BEGIN
            SET @result_code = 51006;
            SET @message = N'DEADLOCK: transaction aborted as deadlock victim (SQL 1205). Retry the request.';
            RETURN 51006;
        END
        ELSE
        BEGIN
            -- Unexpected error: roll back (done above) and rethrow; triggers
            -- rejected a write the procedure pre-check missed (defense-in-depth).
            THROW;
        END
    END CATCH
END
GO

-- ============================================================
-- 3. ENTRY POINT: usp_maintenance_set_impact_level (Task 11 §9.3 / §11.1)
--    Escalation/downgrade: fast-path read (51009/51012 early exits) -> applock
--    on the maintenance's space (closes K3) -> AUTHORITATIVE re-read:
--    active (51012) + level-change (51009) re-checked under the lock ->
--    UPDATE maintenance.impact_level -> COMMIT. NO booking DML (U3).
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.usp_maintenance_set_impact_level
    @maintenance_id   INT,
    @new_impact_level VARCHAR(50),
    @reason           NVARCHAR(MAX) = NULL,
    @result_code      INT = 0 OUTPUT,
    @message          NVARCHAR(500) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- ------------------------------------------------------------
    -- 1. Input validation (no locks required — caller contract)
    -- ------------------------------------------------------------
    IF @maintenance_id IS NULL OR @new_impact_level IS NULL
       OR @new_impact_level NOT IN ('advisory','out-of-service')
    BEGIN
        SET @result_code = 51011;
        SET @message = N'INVALID-INPUT: impact level must be advisory or out-of-service.';
        RETURN 51011;
    END

    DECLARE @lock_rc   INT;
    DECLARE @lock_resource NVARCHAR(255);
    DECLARE @space_id  INT;
    DECLARE @m_status  VARCHAR(50);
    DECLARE @cur_level VARCHAR(50);

    BEGIN TRY
        BEGIN TRANSACTION;

        -- --------------------------------------------------------
        -- 2. Fast-path read (Task 11 §9.3 step 2) — resolves space_id for
        --    the lock resource and exits early on not-found / not-active /
        --    no-change. EARLY EXIT ONLY, NOT authoritative (a concurrent
        --    change may commit before the lock is granted).
        -- --------------------------------------------------------
        SELECT @space_id = space_id,
               @m_status = status,
               @cur_level = impact_level
        FROM dbo.maintenance
        WHERE maintenance_id = @maintenance_id;

        IF @space_id IS NULL
        BEGIN
            SET @result_code = 51011;
            SET @message = N'INVALID-INPUT: maintenance record not found.';
            ROLLBACK TRANSACTION;
            RETURN 51011;
        END
        IF @m_status NOT IN ('open','in_progress')
        BEGIN
            SET @result_code = 51012;
            SET @message = N'MAINTENANCE-NOT-ACTIVE: impact level can only be changed on an open or in-progress maintenance record.';
            ROLLBACK TRANSACTION;
            RETURN 51012;
        END
        IF @cur_level = @new_impact_level
        BEGIN
            SET @result_code = 51009;
            SET @message = N'NO-CHANGE: the maintenance record already has this impact level.';
            ROLLBACK TRANSACTION;
            RETURN 51009;
        END

        -- --------------------------------------------------------
        -- 3. Acquire the SAME per-space critical section as the confirmation
        --    paths (Task 11 §7.1 / §9.3 step 3) — closes K3: escalation
        --    invalidates availability exactly where confirmation validates it.
        -- --------------------------------------------------------
        SET @lock_resource = N'space_booking:' + CONVERT(NVARCHAR(16), @space_id);
        EXEC @lock_rc = sys.sp_getapplock
            @Resource = @lock_resource,
            @LockMode = 'Exclusive',
            @LockOwner = 'Transaction',
            @LockTimeout = 5000;

        IF @lock_rc IN (-1, -2)
        BEGIN
            SET @result_code = 51005;
            SET @message = N'LOCK-TIMEOUT: could not acquire the space critical section within 5 s. Retry the request.';
            ROLLBACK TRANSACTION;
            RETURN 51005;
        END
        IF @lock_rc = -3
        BEGIN
            SET @result_code = 51006;
            SET @message = N'DEADLOCK: this session was chosen as the deadlock victim on the space critical section. Retry the request.';
            ROLLBACK TRANSACTION;
            RETURN 51006;
        END
        IF @lock_rc < 0
        BEGIN
            THROW 59006, 'sp_getapplock returned an unexpected negative result code.', 1;
        END

        -- --------------------------------------------------------
        -- 4. AUTHORITATIVE re-read under the lock (Task 11 §9.3 step 4) —
        --    mirrors the §9.2 double-check pattern: status must still be
        --    active and the level must still differ, else 51009/51012 +
        --    ROLLBACK. Makes the 51009 idempotency contract deterministic
        --    under concurrency (Task 13 scenario T5b).
        -- --------------------------------------------------------
        SELECT @space_id = space_id,
               @m_status = status,
               @cur_level = impact_level
        FROM dbo.maintenance
        WHERE maintenance_id = @maintenance_id;

        IF @space_id IS NULL
        BEGIN
            SET @result_code = 51011;
            SET @message = N'INVALID-INPUT: maintenance record not found.';
            ROLLBACK TRANSACTION;
            RETURN 51011;
        END
        IF @m_status NOT IN ('open','in_progress')
        BEGIN
            SET @result_code = 51012;
            SET @message = N'MAINTENANCE-NOT-ACTIVE: impact level can only be changed on an open or in-progress maintenance record.';
            ROLLBACK TRANSACTION;
            RETURN 51012;
        END
        IF @cur_level = @new_impact_level
        BEGIN
            SET @result_code = 51009;
            SET @message = N'NO-CHANGE: a concurrent change already set this impact level.';
            ROLLBACK TRANSACTION;
            RETURN 51009;
        END

        -- --------------------------------------------------------
        -- 5. Level change only (Task 11 §9.3 step 5). NO booking DML (U3):
        --    pending bookings are left untouched and become unapprovable at
        --    approval time (51002); approved bookings are identified by the
        --    Task 16 report #4. trg_maintenance_impact_history records the
        --    change (changed_by from SESSION_CONTEXT, fallback -1) and
        --    trg_maintenance_recompute_space_status refreshes the hint.
        -- --------------------------------------------------------
        UPDATE dbo.maintenance
        SET impact_level = @new_impact_level
        WHERE maintenance_id = @maintenance_id;

        COMMIT TRANSACTION;

        SET @result_code = 0;
        SET @message = N'SUCCESS: impact level changed.';
        RETURN 0;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        IF ERROR_NUMBER() = 1205
        BEGIN
            SET @result_code = 51006;
            SET @message = N'DEADLOCK: transaction aborted as deadlock victim (SQL 1205). Retry the request.';
            RETURN 51006;
        END
        ELSE
        BEGIN
            -- Unexpected error: roll back (done above) and rethrow; triggers
            -- rejected a write the procedure pre-check missed (defense-in-depth).
            THROW;
        END
    END CATCH
END
GO

-- ============================================================
-- 4. ENTRY POINT: usp_maintenance_report (Task 11 §9.4 / §11.1)
--    Maintenance-ticket creation — closes K5 (Task 08, added retro): a new
--    ticket created directly as out-of-service (or via the column DEFAULT,
--    which is 'out-of-service') raced booking confirmations through an
--    unguarded INSERT. This entry point takes the SAME per-space critical
--    section as the confirmation paths — but ONLY when the ticket starts at
--    out-of-service: advisory creation blocks nothing and needs no lock.
--    The lock is for serialization only: the booking side's post-lock BR4
--    re-check rejects any confirmation that lost the race (51002). This proc
--    NEVER rejects overlapping confirmed bookings — U3/NR4 keep them; report
--    #4 (Task 16) lists them as affected.
--    impact_level is always passed explicitly — the column DEFAULT
--    'out-of-service' (Task 09 A.3 legacy backfill) is never relied on here.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.usp_maintenance_report
    @space_id              INT,
    @reporter_id           INT,
    @problem_description   NVARCHAR(MAX),
    @start_time            DATETIME2,
    @impact_level          VARCHAR(50) = 'advisory',
    @maintenance_id        INT = NULL OUTPUT,
    @result_code           INT = 0 OUTPUT,
    @message               NVARCHAR(500) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    -- Task 11 §8.4: XACT_ABORT ON so any runtime error aborts the whole unit
    -- of work and the transaction-owned applock is released with it.
    SET XACT_ABORT ON;

    -- ------------------------------------------------------------
    -- 1. Input validation (no locks required — caller contract)
    -- ------------------------------------------------------------
    IF @space_id IS NULL OR @reporter_id IS NULL
       OR @problem_description IS NULL OR @start_time IS NULL
       OR @impact_level IS NULL
       OR @impact_level NOT IN ('advisory','out-of-service')
    BEGIN
        SET @result_code = 51011;
        SET @message = N'INVALID-INPUT: malformed ticket parameters (space, reporter, description, start time or impact level).';
        RETURN 51011;
    END

    DECLARE @lock_rc       INT;
    DECLARE @lock_resource NVARCHAR(255);
    DECLARE @new_id        INT;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- --------------------------------------------------------
        -- 2. Fast-path read (Task 11 §9.4 step 2) — space and reporter
        --    must exist and be valid. No overlap reads: creation never
        --    rejects overlapping confirmed bookings (U3/NR4).
        -- --------------------------------------------------------
        IF NOT EXISTS (SELECT 1 FROM dbo.spaces WHERE space_id = @space_id)
        BEGIN
            SET @result_code = 51011;
            SET @message = N'INVALID-INPUT: space not found.';
            ROLLBACK TRANSACTION;
            RETURN 51011;
        END
        IF NOT EXISTS (SELECT 1 FROM dbo.users WHERE user_id = @reporter_id AND account_status = 'active')
        BEGIN
            SET @result_code = 51011;
            SET @message = N'INVALID-INPUT: reporter not found or not active.';
            ROLLBACK TRANSACTION;
            RETURN 51011;
        END

        -- --------------------------------------------------------
        -- 3. Critical section (Task 11 §9.4 step 3) — ONLY when the ticket
        --    starts blocking. Advisory creation skips the lock entirely
        --    (advisory blocks nothing, mirroring the §9.3 downgrade logic).
        -- --------------------------------------------------------
        IF @impact_level = 'out-of-service'
        BEGIN
            SET @lock_resource = N'space_booking:' + CONVERT(NVARCHAR(16), @space_id);
            EXEC @lock_rc = sys.sp_getapplock
                @Resource = @lock_resource,
                @LockMode = 'Exclusive',
                @LockOwner = 'Transaction',
                @LockTimeout = 5000;

            IF @lock_rc IN (-1, -2)   -- -1 timeout, -2 cancelled -> 51005 LOCK-TIMEOUT (retryable)
            BEGIN
                SET @result_code = 51005;
                SET @message = N'LOCK-TIMEOUT: could not acquire the space critical section within 5 s. Retry the request.';
                ROLLBACK TRANSACTION;
                RETURN 51005;
            END
            IF @lock_rc = -3          -- -3 deadlock victim -> 51006 DEADLOCK (retryable)
            BEGIN
                SET @result_code = 51006;
                SET @message = N'DEADLOCK: this session was chosen as the deadlock victim on the space critical section. Retry the request.';
                ROLLBACK TRANSACTION;
                RETURN 51006;
            END
            IF @lock_rc < 0           -- any other negative return (e.g. -999) -> unexpected, rethrow via CATCH
            BEGIN
                THROW 59006, 'sp_getapplock returned an unexpected negative result code.', 1;
            END
        END

        -- --------------------------------------------------------
        -- 4. INSERT the ticket (Task 11 §9.4 step 4). impact_level is
        --    passed EXPLICITLY — the column DEFAULT 'out-of-service' is a
        --    legacy backfill device and must never be relied on here.
        --    trg_maintenance_recompute_space_status refreshes the
        --    current_status hint; trg_maintenance_impact_history is AFTER
        --    UPDATE only, so no history row is created on INSERT.
        -- --------------------------------------------------------
        INSERT INTO dbo.maintenance (space_id, reporter_id, problem_description, start_time, status, impact_level)
        VALUES (@space_id, @reporter_id, @problem_description, @start_time, 'open', @impact_level);
        SET @new_id = SCOPE_IDENTITY();

        COMMIT TRANSACTION;

        SET @maintenance_id = @new_id;
        SET @result_code = 0;
        SET @message = N'SUCCESS: maintenance ticket created.';
        RETURN 0;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        -- SQL 1205 raised by the engine (data-lock deadlock or applock victim
        -- surfaced as an error) maps to the Task 11 retryable 51006.
        IF ERROR_NUMBER() = 1205
        BEGIN
            SET @result_code = 51006;
            SET @message = N'DEADLOCK: transaction aborted as deadlock victim (SQL 1205). Retry the request.';
            RETURN 51006;
        END
        ELSE
        BEGIN
            -- Unexpected error: roll back (done above) and rethrow; triggers
            -- rejected a write the procedure pre-check missed (defense-in-depth).
            THROW;
        END
    END CATCH
END
GO

-- ============================================================
-- 5. NON-CONCURRENT SMOKE CHECKS
--    Safe on the scratch database: the entry points are called standalone
--    (each owns its transaction per Task 11 §9.1 — COMMIT on success,
--    ROLLBACK on failure) and every created smoke row is deleted explicitly,
--    so nothing persists. Task 13 concurrent-session scripts are NOT
--    created here (that is Task 13's deliverable).
-- ============================================================

-- S1: the four Task 11/12 entry points exist
SELECT 'S1-procedures' AS check_name,
       CASE WHEN OBJECT_ID(N'dbo.usp_booking_instant_submit', N'P') IS NOT NULL
             AND OBJECT_ID(N'dbo.usp_booking_approve', N'P') IS NOT NULL
             AND OBJECT_ID(N'dbo.usp_maintenance_set_impact_level', N'P') IS NOT NULL
             AND OBJECT_ID(N'dbo.usp_maintenance_report', N'P') IS NOT NULL
            THEN 'PASS' ELSE 'FAIL' END AS result,
       '4 entry points created' AS detail;
GO

-- S1b: parameter signatures (instant 9, approve 7, escalation 5, report 8
--      params; Task 11 §9 table: 6+3 / 5+2 / 3+2 / 5+3)
SELECT 'S1b-parameters' AS check_name,
       CASE WHEN (SELECT COUNT(*) FROM sys.parameters WHERE object_id = OBJECT_ID(N'dbo.usp_booking_instant_submit')) = 9
             AND (SELECT COUNT(*) FROM sys.parameters WHERE object_id = OBJECT_ID(N'dbo.usp_booking_approve')) = 7
             AND (SELECT COUNT(*) FROM sys.parameters WHERE object_id = OBJECT_ID(N'dbo.usp_maintenance_set_impact_level')) = 5
             AND (SELECT COUNT(*) FROM sys.parameters WHERE object_id = OBJECT_ID(N'dbo.usp_maintenance_report')) = 8
            THEN 'PASS' ELSE 'FAIL' END AS result,
       'parameter counts 9/7/5/8' AS detail;
GO

-- S2-S5: behavioral smoke checks (all rolled back)
IF NOT EXISTS (SELECT 1 FROM dbo.spaces)
   OR NOT EXISTS (SELECT 1 FROM dbo.users WHERE account_status = 'active' AND user_id <> -1)
BEGIN
    PRINT 'SKIP: smoke checks S2-S5 — no baseline spaces/users to test against.';
END
ELSE
BEGIN
    -- Far-future window to stay clear of baseline data; space is chosen so no
    -- confirmed booking and no active out-of-service maintenance overlaps it.
    DECLARE @win_start DATETIME2 = DATEADD(day, 400, SYSDATETIME());
    DECLARE @win_end   DATETIME2 = DATEADD(hour, 2, @win_start);

    DECLARE @smoke_space INT = (
        SELECT TOP 1 s.space_id
        FROM dbo.spaces s
        WHERE s.space_type IN ('classroom','computer_lab','project_lab','meeting_room')
          AND s.current_status NOT IN ('temporarily_closed','retired')
          AND s.capacity >= 10
          AND NOT EXISTS (
              SELECT 1 FROM dbo.maintenance m
              WHERE m.space_id = s.space_id
                AND m.is_deleted = 0
                AND m.status IN ('open','in_progress')
                AND m.impact_level = 'out-of-service'
                AND m.start_time < @win_end
                AND (m.completion_time IS NULL OR m.completion_time > @win_start)
          )
          AND NOT EXISTS (
              SELECT 1 FROM dbo.bookings b
              WHERE b.space_id = s.space_id
                AND b.is_deleted = 0
                AND b.status IN ('approved','checked_in','completed')
                AND b.requested_start_time < @win_end
                AND b.requested_end_time > @win_start
          )
        ORDER BY s.space_id
    );
    DECLARE @smoke_user  INT = (SELECT TOP 1 user_id FROM dbo.users WHERE account_status = 'active' AND user_id <> -1 ORDER BY user_id);
    DECLARE @smoke_staff INT = (SELECT TOP 1 user_id FROM dbo.users WHERE account_status = 'active' AND user_id <> -1 AND role IN ('facility_staff','facility_manager') ORDER BY user_id);

    IF @smoke_space IS NULL OR @smoke_user IS NULL OR @smoke_staff IS NULL
    BEGIN
        PRINT 'SKIP: smoke checks S2-S5 — no eligible smoke space/user/staff row found.';
    END
    ELSE
    BEGIN
        DECLARE @bid INT, @rc INT, @msg NVARCHAR(500), @mid INT, @bk_status VARCHAR(50);

        -- --------------------------------------------------------
        -- S2 + S3: instant success, then overlapping instant submit rejected
        -- with 51001 (BR1). Each entry point owns its transaction (Task 11
        -- §9.1: COMMIT on success, ROLLBACK on failure), so the smoke block
        -- calls them standalone — no outer transaction — and removes the
        -- created rows explicitly afterwards (nothing persists).
        -- --------------------------------------------------------
        BEGIN TRY
            EXEC dbo.usp_booking_instant_submit
                @space_id = @smoke_space, @requester_id = @smoke_user,
                @requested_start_time = @win_start, @requested_end_time = @win_end,
                @purpose = 'meeting', @expected_participants = 5,
                @booking_id = @bid OUTPUT, @result_code = @rc OUTPUT, @message = @msg OUTPUT;
            IF @rc = 0 AND @bid IS NOT NULL
                PRINT 'PASS: S2 instant submit success (rc=0, booking_id=' + CAST(@bid AS VARCHAR(20)) + ').';
            ELSE
                PRINT 'FAIL: S2 instant submit rc=' + CAST(@rc AS VARCHAR(20)) + ' msg=' + ISNULL(@msg, N'NULL');

            SELECT @bk_status = status FROM dbo.bookings WHERE booking_id = @bid;
            IF @bk_status = 'approved'
               AND EXISTS (SELECT 1 FROM dbo.booking_approvals WHERE booking_id = @bid AND approver_id = -1 AND decision = 'approved')
                PRINT 'PASS: S2 auto-approval via reserved approver -1; booking status approved.';
            ELSE
                PRINT 'FAIL: S2 auto-approval state missing (status=' + ISNULL(@bk_status, 'NULL') + ').';

            EXEC dbo.usp_booking_instant_submit
                @space_id = @smoke_space, @requester_id = @smoke_user,
                @requested_start_time = @win_start, @requested_end_time = @win_end,
                @purpose = 'meeting', @expected_participants = 5,
                @booking_id = @bid OUTPUT, @result_code = @rc OUTPUT, @message = @msg OUTPUT;
            IF @rc = 51001
                PRINT 'PASS: S3 overlapping instant submit rejected with 51001.';
            ELSE
                PRINT 'FAIL: S3 expected 51001, got rc=' + CAST(@rc AS VARCHAR(20)) + ' msg=' + ISNULL(@msg, N'NULL');

            DELETE FROM dbo.booking_approvals WHERE booking_id = @bid;
            DELETE FROM dbo.bookings WHERE booking_id = @bid;
            PRINT 'PASS: S2/S3 smoke rows removed (nothing persists).';
        END TRY
        BEGIN CATCH
            IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
            PRINT 'FAIL: S2/S3 aborted: ' + ERROR_MESSAGE();
        END CATCH;

        -- --------------------------------------------------------
        -- S4: staff approval success path — pending booking created inline,
        -- approved via usp_booking_approve, cleaned up.
        -- --------------------------------------------------------
        BEGIN TRY
            INSERT INTO dbo.bookings (space_id, requester_id, requested_start_time, requested_end_time, purpose, expected_participants)
            VALUES (@smoke_space, @smoke_user, @win_start, @win_end, 'meeting', 5);
            SET @bid = SCOPE_IDENTITY();

            EXEC dbo.usp_booking_approve
                @booking_id = @bid, @approver_id = @smoke_staff, @decision = 'approved',
                @rejection_reason = NULL, @decision_note = N'SMOKE staff approval',
                @result_code = @rc OUTPUT, @message = @msg OUTPUT;
            IF @rc = 0 AND EXISTS (SELECT 1 FROM dbo.bookings WHERE booking_id = @bid AND status = 'approved')
                PRINT 'PASS: S4 staff approval success (rc=0, status approved).';
            ELSE
                PRINT 'FAIL: S4 staff approval rc=' + CAST(@rc AS VARCHAR(20)) + ' msg=' + ISNULL(@msg, N'NULL');

            DELETE FROM dbo.booking_approvals WHERE booking_id = @bid;
            DELETE FROM dbo.bookings WHERE booking_id = @bid;
            PRINT 'PASS: S4 smoke rows removed (nothing persists).';
        END TRY
        BEGIN CATCH
            IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
            PRINT 'FAIL: S4 aborted: ' + ERROR_MESSAGE();
        END CATCH;

        -- --------------------------------------------------------
        -- S5: escalation no-op (51009, no history row) + real escalation
        -- success (history row recorded), cleaned up.
        -- --------------------------------------------------------
        BEGIN TRY
            INSERT INTO dbo.maintenance (space_id, reporter_id, problem_description, start_time, status, impact_level)
            VALUES (@smoke_space, @smoke_user, N'SMOKE: advisory ticket for escalation test', DATEADD(day, -1, SYSDATETIME()), 'open', 'advisory');
            SET @mid = SCOPE_IDENTITY();

            EXEC dbo.usp_maintenance_set_impact_level
                @maintenance_id = @mid, @new_impact_level = 'advisory', @reason = N'SMOKE no-op',
                @result_code = @rc OUTPUT, @message = @msg OUTPUT;
            IF @rc = 51009
                PRINT 'PASS: S5a unchanged level rejected with 51009 (no-op).';
            ELSE
                PRINT 'FAIL: S5a expected 51009, got rc=' + CAST(@rc AS VARCHAR(20)) + ' msg=' + ISNULL(@msg, N'NULL');
            IF NOT EXISTS (SELECT 1 FROM dbo.maintenance_impact_history WHERE maintenance_id = @mid)
                PRINT 'PASS: S5a no history row on no-op.';
            ELSE
                PRINT 'FAIL: S5a phantom history row on no-op.';

            EXEC dbo.usp_maintenance_set_impact_level
                @maintenance_id = @mid, @new_impact_level = 'out-of-service', @reason = N'SMOKE escalation',
                @result_code = @rc OUTPUT, @message = @msg OUTPUT;
            IF @rc = 0
                PRINT 'PASS: S5b escalation advisory -> out-of-service success (rc=0).';
            ELSE
                PRINT 'FAIL: S5b escalation rc=' + CAST(@rc AS VARCHAR(20)) + ' msg=' + ISNULL(@msg, N'NULL');
            IF EXISTS (SELECT 1 FROM dbo.maintenance_impact_history WHERE maintenance_id = @mid AND prior_level = 'advisory' AND new_level = 'out-of-service')
                PRINT 'PASS: S5b history row recorded by trg_maintenance_impact_history.';
            ELSE
                PRINT 'FAIL: S5b history row missing.';

            DELETE FROM dbo.maintenance_impact_history WHERE maintenance_id = @mid;
            DELETE FROM dbo.maintenance WHERE maintenance_id = @mid;
            PRINT 'PASS: S5 smoke rows removed (nothing persists).';
        END TRY
        BEGIN CATCH
            IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
            PRINT 'FAIL: S5 aborted: ' + ERROR_MESSAGE();
        END CATCH;

        -- --------------------------------------------------------
        -- S7: maintenance-ticket creation (K5 closure, Task 11 §9.4).
        --   S7a: out-of-service ticket created -> rc=0; a same-window instant
        --        submit on the same space is then blocked with 51002 (BR4);
        --   S7b: advisory ticket created -> rc=0; the same-window instant
        --        submit succeeds (rc=0) — advisory blocks nothing;
        --   S7c: out-of-service ticket created over an EXISTING confirmed
        --        booking -> still rc=0 (U3/NR4: booking kept, listed by
        --        report #4, Task 16).
        -- All created rows deleted afterwards (nothing persists).
        -- --------------------------------------------------------
        BEGIN TRY
            DECLARE @mid3 INT, @did INT, @did2 INT;

            EXEC dbo.usp_maintenance_report
                @space_id = @smoke_space, @reporter_id = @smoke_user,
                @problem_description = N'SMOKE: K5 out-of-service ticket',
                @start_time = @win_start, @impact_level = 'out-of-service',
                @maintenance_id = @mid3 OUTPUT, @result_code = @rc OUTPUT, @message = @msg OUTPUT;
            IF @rc = 0 AND @mid3 IS NOT NULL
                PRINT 'PASS: S7a out-of-service ticket created (rc=0, maintenance_id=' + CAST(@mid3 AS VARCHAR(20)) + ').';
            ELSE
                PRINT 'FAIL: S7a ticket creation rc=' + CAST(@rc AS VARCHAR(20)) + ' msg=' + ISNULL(@msg, N'NULL');

            EXEC dbo.usp_booking_instant_submit
                @space_id = @smoke_space, @requester_id = @smoke_user,
                @requested_start_time = @win_start, @requested_end_time = @win_end,
                @purpose = 'meeting', @expected_participants = 5,
                @booking_id = @did OUTPUT, @result_code = @rc OUTPUT, @message = @msg OUTPUT;
            IF @rc = 51002
                PRINT 'PASS: S7a same-window instant submit blocked with 51002 (BR4).';
            ELSE
                PRINT 'FAIL: S7a expected 51002, got rc=' + CAST(@rc AS VARCHAR(20)) + ' msg=' + ISNULL(@msg, N'NULL');

            DELETE FROM dbo.booking_approvals WHERE booking_id = @did;
            DELETE FROM dbo.bookings WHERE booking_id = @did;
            DELETE FROM dbo.maintenance WHERE maintenance_id = @mid3;
            PRINT 'PASS: S7a rows removed (nothing persists).';

            EXEC dbo.usp_maintenance_report
                @space_id = @smoke_space, @reporter_id = @smoke_user,
                @problem_description = N'SMOKE: K5 advisory ticket',
                @start_time = @win_start, @impact_level = 'advisory',
                @maintenance_id = @mid3 OUTPUT, @result_code = @rc OUTPUT, @message = @msg OUTPUT;
            IF @rc = 0 AND @mid3 IS NOT NULL
                PRINT 'PASS: S7b advisory ticket created (rc=0, maintenance_id=' + CAST(@mid3 AS VARCHAR(20)) + ').';
            ELSE
                PRINT 'FAIL: S7b ticket creation rc=' + CAST(@rc AS VARCHAR(20)) + ' msg=' + ISNULL(@msg, N'NULL');

            EXEC dbo.usp_booking_instant_submit
                @space_id = @smoke_space, @requester_id = @smoke_user,
                @requested_start_time = @win_start, @requested_end_time = @win_end,
                @purpose = 'meeting', @expected_participants = 5,
                @booking_id = @did OUTPUT, @result_code = @rc OUTPUT, @message = @msg OUTPUT;
            IF @rc = 0 AND @did IS NOT NULL
                PRINT 'PASS: S7b same-window instant submit succeeds (rc=0) — advisory blocks nothing.';
            ELSE
                PRINT 'FAIL: S7b expected 0, got rc=' + CAST(@rc AS VARCHAR(20)) + ' msg=' + ISNULL(@msg, N'NULL');

            DELETE FROM dbo.booking_approvals WHERE booking_id = @did;
            DELETE FROM dbo.bookings WHERE booking_id = @did;
            DELETE FROM dbo.maintenance WHERE maintenance_id = @mid3;
            PRINT 'PASS: S7b rows removed (nothing persists).';

            -- S7c: over an EXISTING confirmed booking (U3/NR4)
            INSERT INTO dbo.bookings (space_id, requester_id, requested_start_time, requested_end_time, purpose, expected_participants)
            VALUES (@smoke_space, @smoke_user, @win_start, @win_end, 'meeting', 5);
            SET @did2 = SCOPE_IDENTITY();
            EXEC dbo.usp_booking_approve
                @booking_id = @did2, @approver_id = @smoke_staff, @decision = 'approved',
                @rejection_reason = NULL, @decision_note = N'SMOKE prior booking',
                @result_code = @rc OUTPUT, @message = @msg OUTPUT;
            IF @rc <> 0
                PRINT 'FAIL: S7c prior approval rc=' + CAST(@rc AS VARCHAR(20)) + ' msg=' + ISNULL(@msg, N'NULL');

            EXEC dbo.usp_maintenance_report
                @space_id = @smoke_space, @reporter_id = @smoke_user,
                @problem_description = N'SMOKE: K5 ticket over confirmed booking',
                @start_time = @win_start, @impact_level = 'out-of-service',
                @maintenance_id = @mid3 OUTPUT, @result_code = @rc OUTPUT, @message = @msg OUTPUT;
            IF @rc = 0 AND @mid3 IS NOT NULL
                PRINT 'PASS: S7c out-of-service ticket over confirmed booking still created (rc=0) — U3/NR4 keeps the booking; report #4 lists it.';
            ELSE
                PRINT 'FAIL: S7c expected 0, got rc=' + CAST(@rc AS VARCHAR(20)) + ' msg=' + ISNULL(@msg, N'NULL');

            DELETE FROM dbo.booking_approvals WHERE booking_id = @did2;
            DELETE FROM dbo.bookings WHERE booking_id = @did2;
            DELETE FROM dbo.maintenance WHERE maintenance_id = @mid3;
            PRINT 'PASS: S7c rows removed (nothing persists).';
        END TRY
        BEGIN CATCH
            IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
            PRINT 'FAIL: S7 aborted: ' + ERROR_MESSAGE();
        END CATCH;
    END
END
GO

-- S6: invariant audit (Task 13 T8 shape) — after all smoke cleanups there
-- must be no overlapping confirmed bookings; a non-empty result here means
-- PRE-EXISTING data violates BR1/NR6 (baseline problem, not Task 12).
SELECT 'S6-invariant' AS check_name,
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'WARN' END AS result,
       'overlapping confirmed booking pairs (pre-existing data would warn)' AS detail
FROM (
    SELECT a.space_id
    FROM dbo.bookings a
    INNER JOIN dbo.bookings b
        ON b.space_id = a.space_id
       AND b.booking_id > a.booking_id
    WHERE a.is_deleted = 0 AND b.is_deleted = 0
      AND a.status IN ('approved','checked_in','completed')
      AND b.status IN ('approved','checked_in','completed')
      AND a.requested_start_time < b.requested_end_time
      AND a.requested_end_time > b.requested_start_time
) x;
GO

PRINT 'IMPLEMENTATION-OK: Task 12 script applied (procedures created/refreshed; smoke checks completed).';
GO
