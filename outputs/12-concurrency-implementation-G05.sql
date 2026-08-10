SET QUOTED_IDENTIFIER ON;
GO
SET ANSI_NULLS ON;
GO

-- ============================================================
-- CS486 G05 — Campus Space Management System
-- Task 12: Phase 2 Concurrency Implementation (entry points)
-- Target: SQL Server 2019+ (T-SQL)
--
-- REVISION 3 (2026-08-08): aligned with Task 09 v2.6 / Task 10 rev5 / Task 11 v3.4 —
--   the v2.5 per-space duration cap (spaces.max_hours) was REMOVED upstream, so the
--   instant soft gate is now check 1 ONLY (purpose membership in
--   space_type_allowed_purpose); there is no duration gate anywhere (W1 step 2/4,
--   preflight 0.2, comments). No other contract change.
--
-- REVISION 4 (2026-08-10): W1 step 8's ack INSERT is REMOVED — Task 10 rev6 adds
--   trigger trg_bookings_insert_advisory_acknowledgements (AFTER INSERT on bookings,
--   unconditional, status-agnostic), which is now the SINGLE owner of insert-time
--   acknowledgement materialization (planFix R3). W1 steps renumbered (auto-approval
--   is now step 8, COMMIT step 9); W2 NR2 repair (DD6) is UNCHANGED; error codes and
--   the lock contract are unchanged. Smoke set extended with S0/S1b/S4b to prove the
--   trigger materializes acks on both auto-approved and pending (fallback) inserts.
--   (Review pass 2026-08-10: preflight 0.2b upstream pointer updated to rev6; W1
--   step 7 comment restores the 8c pair-validation note. No logic change.)
--
-- Upstream files implemented:
--   - outputs/10-schema-migration-G05.sql   (approved 2026-08-10, rev6 — Phase 2 schema,
--     Task 09 v2.6: no max_hours column, junction space_type_allowed_purpose seeded;
--     rev6 adds trg_bookings_insert_advisory_acknowledgements — W1 relies on it, R3)
--   - outputs/11-concurrency-design-G05.md  (approved 2026-08-08, v3.3/v3.4 — the
--     implementation contract: workflows W1..W4, Section 6.3 result codes,
--     Section 9 Task 12 handoff)
--   - docs/design-decisions.md              (Task 11 revision v3.4: 4 entry points;
--     K5 closed via usp_maintenance_report; Task 09 v2.6 decision 2026-08-08)
--   - docs/tech-stack.md                    (SQL Server 2019+, T-SQL naming conventions)
--
-- SELECTED STRATEGY (Task 11 Section 5.2 / Section 6):
--   transaction-owned sys.sp_getapplock on ONE fixed resource per space:
--       Resource    = N'space_booking:<space_id>'
--       LockMode    = 'Exclusive'
--       LockOwner   = 'Transaction'  (released automatically at COMMIT/ROLLBACK)
--       LockTimeout = 5000           (5 seconds)
--   shared by all four write entry points, so every pair of writers on the
--   same space serializes (K1, K2, K3, K5 closed; K4 by construction).
--
-- NO-SCHEMA-CHANGE PROMISE:
--   This script creates or alters ONLY stored procedures (4 entry points,
--   CREATE OR ALTER = idempotent re-run). It does not create, alter or drop
--   any table, column, key, index, or trigger. The existing triggers and the
--   filtered unique index keep their role as defense-in-depth only (Task 11
--   Section 4.4).
--
-- TASK 11 §11 RECOMMENDED HARDENING (DENY table writes + GRANT EXECUTE only,
-- ownership chaining) is NOT scripted here: no application-role principal is
-- defined in this project's schema, so the DENY/GRANT statement cannot be
-- written against a real name. It remains an operations note for deployment.
--
-- RESULT-CODE CONTRACT (Task 11 Section 6.3 — implemented exactly):
--     0     success
--   51001   request context invalid (row not found / not in expected state / bad input)
--   51002   BR4: overlapping active out-of-service maintenance blocks
--   51003   BR1: overlapping confirmed booking exists
--   51004   NR2: advisory acknowledgement(s) missing
--   51005   applock timeout (-1)  -> retryable
--   51006   applock cancelled (-2) -> retryable
--   51007   deadlock victim (-3 / server 1205) -> restart unit
--   51008   BR2: space is retired or temporarily_closed
--   51009   BR3: expected participants exceed space capacity
--   -999    applock bad parameter — programmer error: THROWN, never returned
--   unexpected errors: ROLLBACK + re-THROW (the §6.3 table is exhaustive — there
--   is deliberately NO unexpected-error code; trigger/constraint failures on
--   corrupted data surface as raw errors, per §7.1 step 10 semantics).
--
-- SESSION CONTEXT (Task 11 Section 6.4):
--   maintenance impact changes attribute changed_by via SESSION_CONTEXT
--   (N'current_user_id'), set and cleared by the APPLICATION layer at unit
--   boundaries (pooled-connection risk). The entry points do not set or clear
--   it themselves; the smoke section at the bottom sets/clears the context to
--   prove the impact-history attribution path works end-to-end.
-- ============================================================

-- ============================================================
-- 0. PREFLIGHT CHECKS (THROW numbers >= 50000, distinct from the
--    business result codes 51001..51009)
-- ============================================================

-- 0.1 All Phase 1 baseline + Phase 2 migrated tables exist
IF OBJECT_ID(N'dbo.bookings', N'U') IS NULL
   OR OBJECT_ID(N'dbo.booking_approvals', N'U') IS NULL
   OR OBJECT_ID(N'dbo.booking_sessions', N'U') IS NULL
   OR OBJECT_ID(N'dbo.maintenance', N'U') IS NULL
   OR OBJECT_ID(N'dbo.spaces', N'U') IS NULL
   OR OBJECT_ID(N'dbo.users', N'U') IS NULL
   OR OBJECT_ID(N'dbo.maintenance_impact_history', N'U') IS NULL
   OR OBJECT_ID(N'dbo.booking_advisory_acknowledgement', N'U') IS NULL
   OR OBJECT_ID(N'dbo.space_type_allowed_purpose', N'U') IS NULL
BEGIN
    THROW 52010, N'Task 12 preflight: required Phase 2 table missing. Run outputs/10-schema-migration-G05.sql first.', 1;
END
GO

-- 0.2 Required Phase 2 columns exist (Task 09 v2.6: NO max_hours — the v2.5
--     duration cap was removed; the only data-driven instant gate is the junction)
IF COL_LENGTH(N'dbo.maintenance', N'impact_level') IS NULL
   OR COL_LENGTH(N'dbo.maintenance', N'completion_time') IS NULL
   OR COL_LENGTH(N'dbo.bookings', N'status') IS NULL
   OR COL_LENGTH(N'dbo.spaces', N'current_status') IS NULL
BEGIN
    THROW 52011, 'Task 12 preflight: required column missing (impact_level / completion_time / bookings.status / spaces.current_status).', 1;
END
GO

-- 0.2b v2.6 assumption check: the duration-cap column must NOT exist. If
--      spaces.max_hours is present, the database was migrated with the v2.5
--      migration, not Task 10 rev5/rev6 — the soft-gate contract would differ.
IF COL_LENGTH(N'dbo.spaces', N'max_hours') IS NOT NULL
BEGIN
    THROW 52015, 'Task 12 preflight: spaces.max_hours exists — this is the v2.5 schema. Re-run outputs/10-schema-migration-G05.sql rev6 (approved 2026-08-10; Task 09 v2.6 has no duration cap).', 1;
END
GO

-- 0.3 Triggers kept/added by Task 10 are present. Note: since rev4 removed W1
--      step 8's ack INSERT, trg_bookings_insert_advisory_acknowledgements is NOT
--      merely defense-in-depth anymore — it is the ONLY insert-time ack owner
--      (planFix R3); its absence would silently break the NR2 insert-time layer.
IF OBJECT_ID(N'dbo.trg_bookings_prevent_overlap', N'TR') IS NULL
   OR OBJECT_ID(N'dbo.trg_bookings_check_maintenance', N'TR') IS NULL
   OR OBJECT_ID(N'dbo.trg_bookings_check_capacity', N'TR') IS NULL
   OR OBJECT_ID(N'dbo.trg_booking_approvals_check_space', N'TR') IS NULL
   OR OBJECT_ID(N'dbo.trg_booking_approvals_check_role', N'TR') IS NULL
   OR OBJECT_ID(N'dbo.trg_booking_approvals_decision', N'TR') IS NULL
   OR OBJECT_ID(N'dbo.trg_booking_approvals_rejection', N'TR') IS NULL
   OR OBJECT_ID(N'dbo.trg_maintenance_impact_history', N'TR') IS NULL
   OR OBJECT_ID(N'dbo.trg_maintenance_recompute_space_status', N'TR') IS NULL
   OR OBJECT_ID(N'dbo.trg_booking_advisory_ack_validate', N'TR') IS NULL
   OR OBJECT_ID(N'dbo.trg_bookings_insert_advisory_acknowledgements', N'TR') IS NULL
BEGIN
    THROW 52012, 'Task 12 preflight: required trigger missing (defense-in-depth set or trg_bookings_insert_advisory_acknowledgements — Task 10 rev6 migration required).', 1;
END
GO

-- 0.4 Indexes the overlap re-checks rely on
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'uq_bookings_active_overlap')
   OR NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'idx_bookings_time_range')
   OR NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'idx_maintenance_space_id')
BEGIN
    THROW 52013, 'Task 12 preflight: required index missing (uq_bookings_active_overlap / idx_bookings_time_range / idx_maintenance_space_id).', 1;
END
GO

-- 0.5 Reserved system user (Task 10 seed) exists
IF NOT EXISTS (SELECT 1 FROM dbo.users WHERE user_id = -1 AND role = 'facility_manager' AND account_status = 'active')
BEGIN
    THROW 52014, 'Task 12 preflight: reserved system user -1 missing.', 1;
END
GO

PRINT 'T12-PREFLIGHT-OK';
GO

-- ============================================================
-- 1. ENTRY POINT: dbo.usp_booking_instant_submit (Task 11 W1)
--    Instant booking submission with optional auto-approval.
--    Soft gate (Task 09 v2.6 check 1 ONLY — purpose membership in
--    space_type_allowed_purpose; NO duration gate) only demotes to
--    pending (@instant_accepted = 0, not an error); hard gates
--    (BR2/BR3/BR1/BR4/requester active) return deterministic codes.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.usp_booking_instant_submit
    @space_id              INT,
    @requester_id          INT,
    @purpose               VARCHAR(50),
    @expected_participants INT,
    @requested_start_time  DATETIME2,
    @requested_end_time    DATETIME2,
    @booking_id            INT             = NULL OUTPUT,
    @instant_accepted      BIT             = 0   OUTPUT,
    @result_code           INT             = 0   OUTPUT,
    @message               NVARCHAR(500)   = N'' OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @booking_id = NULL;
    SET @instant_accepted = 0;
    SET @result_code = 0;
    SET @message = N'';

    DECLARE @lock_rc INT = -999;
    DECLARE @lock_resource NVARCHAR(128);
    DECLARE @space_type VARCHAR(50);
    DECLARE @capacity INT;
    DECLARE @space_closed BIT = 0;
    DECLARE @requester_active BIT = 0;
    DECLARE @purpose_allowed BIT = 0;

    BEGIN TRY
        -- W1 step 1: input validation (lock-free, deterministic 51001)
        IF @space_id IS NULL OR @requester_id IS NULL OR @purpose IS NULL
           OR @requested_start_time IS NULL OR @requested_end_time IS NULL
        BEGIN
            SET @result_code = 51001;
            SET @message = N'Missing required input.';
            RETURN;
        END
        IF @requested_end_time <= @requested_start_time
        BEGIN
            SET @result_code = 51001;
            SET @message = N'Requested end time must be after start time.';
            RETURN;
        END
        IF @expected_participants IS NULL OR @expected_participants <= 0
        BEGIN
            SET @result_code = 51001;
            SET @message = N'Expected participants must be positive.';
            RETURN;
        END

        -- W1 step 2: fast-path soft hint (Task 09 v2.6 check 1 — purpose
        -- membership ONLY; the v2.5 duration-cap gate was removed upstream, so
        -- there is no duration check here).
        -- Advisory only; the authoritative decision is recomputed later under the lock.
        SELECT @space_type = s.space_type,
               @capacity   = s.capacity,
               @space_closed = CASE WHEN s.current_status IN ('retired','temporarily_closed') THEN 1 ELSE 0 END
        FROM dbo.spaces s
        WHERE s.space_id = @space_id;

        IF @space_type IS NULL
        BEGIN
            SET @result_code = 51001;
            SET @message = N'Space not found.';
            RETURN;
        END

        SELECT @requester_active = CASE WHEN account_status = 'active' THEN 1 ELSE 0 END
        FROM dbo.users
        WHERE user_id = @requester_id;
        IF @requester_active IS NULL
        BEGIN
            SET @result_code = 51001;
            SET @message = N'Requester not found.';
            RETURN;
        END

        -- No duration gate exists in Task 09 v2.6 (v2.5 max_hours cap removed upstream).

        -- W1 step 3: transaction + per-space application lock (serialization point)
        SET @lock_resource = N'space_booking:' + CONVERT(NVARCHAR(12), @space_id);
        BEGIN TRANSACTION;

        EXEC @lock_rc = sys.sp_getapplock
            @Resource    = @lock_resource,
            @LockMode    = 'Exclusive',
            @LockOwner   = 'Transaction',   -- released at COMMIT/ROLLBACK
            @LockTimeout = 5000;            -- 5 s

        IF @lock_rc = -1   -- timeout
        BEGIN
            ROLLBACK TRANSACTION;
            SET @result_code = 51005;
            SET @message = N'App lock timeout (51005).';
            RETURN;
        END
        IF @lock_rc = -2   -- cancelled
        BEGIN
            ROLLBACK TRANSACTION;
            SET @result_code = 51006;
            SET @message = N'App lock cancelled (51006).';
            RETURN;
        END
        IF @lock_rc = -3   -- deadlock victim
        BEGIN
            ROLLBACK TRANSACTION;
            SET @result_code = 51007;
            SET @message = N'Deadlock victim (51007) — restart unit.';
            RETURN;
        END
        IF @lock_rc NOT IN (0, 1)   -- 0 granted sync, 1 granted after wait; else (e.g. -999) programmer error
        BEGIN
            ROLLBACK TRANSACTION;
            THROW 52999, N'usp_booking_instant_submit: invalid sp_getapplock return.', 1;
        END

        -- W1 step 4: post-lock authoritative re-checks (BR2/BR3/requester,
        -- and re-run of the soft gate on the fresh read)
        SELECT @space_type  = s.space_type,
               @capacity    = s.capacity,
               @space_closed = CASE WHEN s.current_status IN ('retired','temporarily_closed') THEN 1 ELSE 0 END
        FROM dbo.spaces s
        WHERE s.space_id = @space_id;

        IF @space_type IS NULL
        BEGIN
            ROLLBACK TRANSACTION;
            SET @result_code = 51001;
            SET @message = N'Space vanished (authoritative read).';
            RETURN;
        END
        IF @space_closed = 1
        BEGIN
            ROLLBACK TRANSACTION;
            SET @result_code = 51008;
            SET @message = N'Space is retired or temporarily closed (BR2).';
            RETURN;
        END
        IF @expected_participants > @capacity
        BEGIN
            ROLLBACK TRANSACTION;
            SET @result_code = 51009;
            SET @message = N'Expected participants exceed space capacity (BR3).';
            RETURN;
        END

        SELECT @requester_active = CASE WHEN account_status = 'active' THEN 1 ELSE 0 END
        FROM dbo.users
        WHERE user_id = @requester_id;
        IF @requester_active IS NULL OR @requester_active = 0
        BEGIN
            ROLLBACK TRANSACTION;
            SET @result_code = 51001;
            SET @message = N'Requester account is not active.';
            RETURN;
        END

        -- soft gate recomputed from the authoritative row (Task 09 v2.6 check 1
        -- only — purpose membership; no duration gate exists)
        SET @purpose_allowed = CASE WHEN EXISTS (
                SELECT 1 FROM dbo.space_type_allowed_purpose p
                WHERE p.space_type = @space_type AND p.purpose = @purpose
            ) THEN 1 ELSE 0 END;
        SET @instant_accepted = @purpose_allowed;

        -- W1 step 5: BR1 re-check (confirmed bookings, interval overlap)
        IF EXISTS (
            SELECT 1 FROM dbo.bookings b
            WHERE b.space_id = @space_id
              AND b.is_deleted = 0
              AND b.status IN ('approved','checked_in','completed')
              AND b.requested_start_time < @requested_end_time
              AND b.requested_end_time > @requested_start_time
        )
        BEGIN
            ROLLBACK TRANSACTION;
            SET @result_code = 51003;
            SET @message = N'Overlapping confirmed booking (BR1).';
            RETURN;
        END

        -- W1 step 6: BR4 re-check (active out-of-service maintenance, overlap)
        IF EXISTS (
            SELECT 1 FROM dbo.maintenance m
            WHERE m.space_id = @space_id
              AND m.is_deleted = 0
              AND m.status IN ('open','in_progress')
              AND m.impact_level = 'out-of-service'
              AND m.start_time < @requested_end_time
              AND (m.completion_time IS NULL OR m.completion_time > @requested_start_time)
        )
        BEGIN
            ROLLBACK TRANSACTION;
            SET @result_code = 51002;
            SET @message = N'Overlapping out-of-service maintenance (BR4).';
            RETURN;
        END

        -- W1 step 7: insert the booking row (status EXPLICIT 'pending' — N6).
        -- Acknowledgement rows for overlapping active advisories are materialized
        -- by trigger trg_bookings_insert_advisory_acknowledgements in the SAME
        -- transaction (planFix R3 — the schema trigger is the single insert-time
        -- owner; the ack INSERT formerly done here was removed in rev4).
        -- trg_booking_advisory_ack_validate (8c) confirms each materialized pair.
        INSERT INTO dbo.bookings
            (space_id, requester_id, requested_start_time, requested_end_time, purpose,
             expected_participants, status)
        VALUES
            (@space_id, @requester_id, @requested_start_time, @requested_end_time, @purpose,
             @expected_participants, 'pending');

        SET @booking_id = SCOPE_IDENTITY();

        -- W1 step 8: auto-approval iff the instant test passed (hard AND soft gates).
        -- Otherwise the booking stays pending (design: NOT an error — DD5).
        IF @instant_accepted = 1
        BEGIN
            INSERT INTO dbo.booking_approvals
                (booking_id, approver_id, decision_time, decision, rejection_reason, decision_note)
            VALUES
                (@booking_id, -1, SYSDATETIME(), 'approved', NULL, N'Instant auto-approval (system user -1).');
        END

        -- W1 step 9: COMMIT releases the app lock automatically
        COMMIT TRANSACTION;

        SET @result_code = 0;
        SET @message = N'Booking created (id=' + CONVERT(NVARCHAR(12), @booking_id)
                     + N'), instant=' + CASE WHEN @instant_accepted = 1 THEN 'true' ELSE 'false' END + N'.';
        RETURN;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        IF ERROR_NUMBER() = 1205
        BEGIN
            SET @result_code = 51007;
            SET @message = N'Deadlock victim (51007) — restart unit.';
        END
        ELSE
        BEGIN
            THROW;   -- re-throw: §6.3 is exhaustive (0/51001..51009) — no code for
                     -- unexpected errors; raw trigger/constraint errors surface
        END
    END CATCH
END
GO

-- ============================================================
-- 2. ENTRY POINT: dbo.usp_booking_approve (Task 11 W2)
--    Staff approval / rejection of a pending booking.
--    For 'approved', the procedure re-checks BR2/BR3/BR1/BR4 and REPAIRS
--    missing acknowledgement rows (DD6) before writing the approval row.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.usp_booking_approve
    @booking_id       INT,
    @approver_id      INT,
    @decision         VARCHAR(50),
    @rejection_reason NVARCHAR(MAX) = NULL,
    @decision_note    NVARCHAR(MAX) = NULL,
    @result_code      INT           = 0   OUTPUT,
    @message          NVARCHAR(500) = N'' OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @result_code = 0;
    SET @message = N'';

    DECLARE @lock_rc INT = -999;
    DECLARE @lock_resource NVARCHAR(128);
    DECLARE @space_id INT;
    DECLARE @requester_id INT;
    DECLARE @booking_status VARCHAR(50);
    DECLARE @space_closed BIT = 0;
    DECLARE @capacity INT;
    DECLARE @participants INT;
    DECLARE @req_start DATETIME2;
    DECLARE @req_end DATETIME2;

    BEGIN TRY
        -- W2 step 1: fast-path input validation + spatial lookup
        IF @booking_id IS NULL OR @approver_id IS NULL OR @decision IS NULL
        BEGIN
            SET @result_code = 51001;
            SET @message = N'Missing required input.';
            RETURN;
        END
        IF @decision NOT IN ('approved','rejected')
        BEGIN
            SET @result_code = 51001;
            SET @message = N'Decision must be approved or rejected.';
            RETURN;
        END

        SELECT @space_id = b.space_id, @requester_id = b.requester_id,
               @booking_status = b.status
        FROM dbo.bookings b
        WHERE b.booking_id = @booking_id;
        IF @space_id IS NULL
        BEGIN
            SET @result_code = 51001;
            SET @message = N'Booking not found.';
            RETURN;
        END

        -- W2 step 2: acquire the SAME per-space app lock as the other entry points
        SET @lock_resource = N'space_booking:' + CONVERT(NVARCHAR(12), @space_id);
        BEGIN TRANSACTION;

        EXEC @lock_rc = sys.sp_getapplock
            @Resource    = @lock_resource,
            @LockMode    = 'Exclusive',
            @LockOwner   = 'Transaction',
            @LockTimeout = 5000;

        IF @lock_rc = -1
        BEGIN
            ROLLBACK TRANSACTION;
            SET @result_code = 51005;
            SET @message = N'App lock timeout (51005).';
            RETURN;
        END
        IF @lock_rc = -2
        BEGIN
            ROLLBACK TRANSACTION;
            SET @result_code = 51006;
            SET @message = N'App lock cancelled (51006).';
            RETURN;
        END
        IF @lock_rc = -3
        BEGIN
            ROLLBACK TRANSACTION;
            SET @result_code = 51007;
            SET @message = N'Deadlock victim (51007) — restart unit.';
            RETURN;
        END
        IF @lock_rc NOT IN (0, 1)   -- 0 granted sync, 1 granted after wait; else (e.g. -999) programmer error
        BEGIN
            ROLLBACK TRANSACTION;
            THROW 52999, N'usp_booking_approve: invalid sp_getapplock return.', 1;
        END

        -- W2 step 3: re-read the booking under the lock — must still be pending
        SELECT @space_id = b.space_id, @requester_id = b.requester_id,
               @booking_status = b.status,
               @participants   = b.expected_participants,
               @req_start      = b.requested_start_time,
               @req_end        = b.requested_end_time
        FROM dbo.bookings b
        WHERE b.booking_id = @booking_id;
        IF @space_id IS NULL OR @booking_status <> 'pending'
        BEGIN
            ROLLBACK TRANSACTION;
            SET @result_code = 51001;
            SET @message = N'Booking is not pending anymore (already decided).';
            RETURN;
        END

        IF @decision = 'approved'
        BEGIN
            -- W2 step 4a: BR2 manual overrides (authoritative post-lock read)
            IF NOT EXISTS (SELECT 1 FROM dbo.spaces WHERE space_id = @space_id)
            BEGIN
                ROLLBACK TRANSACTION;
                SET @result_code = 51001;
                SET @message = N'Space not found (authoritative re-read).';
                RETURN;
            END

            SELECT @space_closed = CASE WHEN current_status IN ('retired','temporarily_closed') THEN 1 ELSE 0 END,
                   @capacity     = capacity
            FROM dbo.spaces
            WHERE space_id = @space_id;

            IF @space_closed = 1
            BEGIN
                ROLLBACK TRANSACTION;
                SET @result_code = 51008;
                SET @message = N'Space is closed or retired (BR2).';
                RETURN;
            END
            IF @participants > @capacity
            BEGIN
                ROLLBACK TRANSACTION;
                SET @result_code = 51009;
                SET @message = N'Capacity exceeded (BR3).';
                RETURN;
            END

            -- W2 step 4b: BR1 overlap (confirmed bookings, excluding this one)
            IF EXISTS (
                SELECT 1 FROM dbo.bookings b
                WHERE b.space_id = @space_id
                  AND b.booking_id <> @booking_id
                  AND b.is_deleted = 0
                  AND b.status IN ('approved','checked_in','completed')
                  AND b.requested_start_time < @req_end
                  AND b.requested_end_time > @req_start
            )
            BEGIN
                ROLLBACK TRANSACTION;
                SET @result_code = 51003;
                SET @message = N'Overlapping confirmed booking (BR1).';
                RETURN;
            END

            -- W2 step 4c: BR4 out-of-service overlap
            IF EXISTS (
                SELECT 1 FROM dbo.maintenance m
                WHERE m.space_id = @space_id
                  AND m.is_deleted = 0
                  AND m.status IN ('open','in_progress')
                  AND m.impact_level = 'out-of-service'
                  AND m.start_time < @req_end
                  AND (m.completion_time IS NULL OR m.completion_time > @req_start)
            )
            BEGIN
                ROLLBACK TRANSACTION;
                SET @result_code = 51002;
                SET @message = N'Overlapping out-of-service maintenance (BR4).';
                RETURN;
            END

            -- W2 step 5: NR2 repair (DD6) — insert any missing acknowledgement
            -- rows for overlapping active advisories (acknowledged_by = requester,
            -- now) so the completeness trigger can never block an approvable booking.
            INSERT INTO dbo.booking_advisory_acknowledgement
                (booking_id, maintenance_id, acknowledged_at, acknowledged_by)
            SELECT @booking_id, m.maintenance_id, SYSDATETIME(), @requester_id
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
              );

            -- W2 step 5b: NR2 completeness gate (51004 if still missing)
            IF EXISTS (
                SELECT 1 FROM dbo.maintenance m
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
                ROLLBACK TRANSACTION;
                SET @result_code = 51004;
                SET @message = N'Advisory acknowledgement(s) missing after repair (NR2).';
                RETURN;
            END
        END
        ELSE -- decision = 'rejected'
        BEGIN
            -- BR7: rejection requires a reason
            IF @rejection_reason IS NULL OR LTRIM(RTRIM(@rejection_reason)) = N''
            BEGIN
                ROLLBACK TRANSACTION;
                SET @result_code = 51001;
                SET @message = N'Rejection reason required (BR7).';
                RETURN;
            END
        END

        -- W2 step 6: write the approval row (decision and times explicit)
        INSERT INTO dbo.booking_approvals
            (booking_id, approver_id, decision_time, decision, rejection_reason, decision_note)
        VALUES
            (@booking_id, @approver_id, SYSDATETIME(), @decision, @rejection_reason, @decision_note);

        COMMIT TRANSACTION;

        SET @result_code = 0;
        SET @message = N'Booking ' + CONVERT(NVARCHAR(12), @booking_id) + N' marked ' + @decision + N'.';
        RETURN;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        IF ERROR_NUMBER() = 1205
        BEGIN
            SET @result_code = 51007;
            SET @message = N'Deadlock victim (51007) — restart unit.';
        END
        ELSE
        BEGIN
            THROW;   -- re-throw: §6.3 is exhaustive (0/51001..51009) — no code for
                     -- unexpected errors; raw trigger/constraint errors surface
        END
    END CATCH
END
GO

-- ============================================================
-- 3. ENTRY POINT: dbo.usp_maintenance_set_impact_level (Task 11 W3)
--    Escalation / downgrade of an ACTIVE maintenance record.
--    No booking DML here (DD1): approved bookings overlapping an escalated
--    maintenance are handled by BR4 at approval time; the operations path
--    uses the same per-space lock so the CHECK-ACT window vs W2/W4 is
--    serialized. No-op calls (same level) return 0 WITHOUT a lock or write.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.usp_maintenance_set_impact_level
    @maintenance_id   INT,
    @new_impact_level VARCHAR(50),
    @reason           NVARCHAR(MAX) = NULL,
    @result_code      INT           = 0   OUTPUT,
    @message          NVARCHAR(500) = N'' OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @result_code = 0;
    SET @message = N'';

    DECLARE @lock_rc INT = -999;
    DECLARE @lock_resource NVARCHAR(128);
    DECLARE @space_id INT;
    DECLARE @cur_level VARCHAR(50);
    DECLARE @cur_status VARCHAR(50);

    BEGIN TRY
        IF @maintenance_id IS NULL OR @new_impact_level IS NULL
        BEGIN
            SET @result_code = 51001;
            SET @message = N'Missing required input.';
            RETURN;
        END
        IF @new_impact_level NOT IN ('advisory','out-of-service')
        BEGIN
            SET @result_code = 51001;
            SET @message = N'Invalid impact level (must be advisory or out-of-service).';
            RETURN;
        END

        -- fast-path hint read (authoritative re-read happens under the lock)
        SELECT @space_id = m.space_id, @cur_status = m.status, @cur_level = m.impact_level
        FROM dbo.maintenance m
        WHERE m.maintenance_id = @maintenance_id;

        IF @space_id IS NULL
        BEGIN
            SET @result_code = 51001;
            SET @message = N'Maintenance not found.';
            RETURN;
        END

        -- W3 step 1: same level -> no-op success (no lock, no write)
        IF @cur_level = @new_impact_level
        BEGIN
            SET @result_code = 0;
            SET @message = N'Level unchanged (no-op).';
            RETURN;
        END

        -- W3 step 2: lock this maintenance's SPACE (serializes with in-flight
        -- bookings/confirmations on that space — the K3 wire)
        SET @lock_resource = N'space_booking:' + CONVERT(NVARCHAR(12), @space_id);
        BEGIN TRANSACTION;

        EXEC @lock_rc = sys.sp_getapplock
            @Resource    = @lock_resource,
            @LockMode    = 'Exclusive',
            @LockOwner   = 'Transaction',
            @LockTimeout = 5000;

        IF @lock_rc = -1
        BEGIN
            ROLLBACK TRANSACTION;
            SET @result_code = 51005;
            SET @message = N'App lock timeout (51005).';
            RETURN;
        END
        IF @lock_rc = -2
        BEGIN
            ROLLBACK TRANSACTION;
            SET @result_code = 51006;
            SET @message = N'App lock cancelled (51006).';
            RETURN;
        END
        IF @lock_rc = -3
        BEGIN
            ROLLBACK TRANSACTION;
            SET @result_code = 51007;
            SET @message = N'Deadlock victim (51007) — restart unit.';
            RETURN;
        END
        IF @lock_rc NOT IN (0, 1)   -- 0 granted sync, 1 granted after wait; else (e.g. -999) programmer error
        BEGIN
            ROLLBACK TRANSACTION;
            THROW 52999, N'usp_maintenance_set_impact_level: invalid sp_getapplock return.', 1;
        END

        -- W3 step 3: authoritative re-read — still actionable
        SELECT @space_id = m.space_id, @cur_status = m.status, @cur_level = m.impact_level
        FROM dbo.maintenance m
        WHERE m.maintenance_id = @maintenance_id;

        IF @space_id IS NULL OR @cur_status NOT IN ('open','in_progress')
        BEGIN
            ROLLBACK TRANSACTION;
            SET @result_code = 51001;
            SET @message = N'Maintenance no longer actionable.';
            RETURN;
        END
        IF @cur_level = @new_impact_level
        BEGIN
            COMMIT TRANSACTION; -- concurrent no-op (level already matching)
            SET @result_code = 0;
            SET @message = N'Level already matching (concurrent no-op).';
            RETURN;
        END

        -- W3 step 4: UPDATE fires the impact-history trigger (NR3) and the
        -- recompute trigger. changed_by comes from SESSION_CONTEXT(N'current_user_id');
        -- per design §6.4/§9 the APPLICATION sets/clears it at unit boundaries (this
        -- procedure's signature has no user parameter, so §7.3 step 4's "Set" is the
        -- caller's duty); the trigger falls back to reserved user -1 when unset.
        UPDATE dbo.maintenance
        SET impact_level = @new_impact_level
        WHERE maintenance_id = @maintenance_id;

        COMMIT TRANSACTION;
        SET @result_code = 0;
        SET @message = N'Impact level updated to ' + @new_impact_level + N'.';
        RETURN;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        IF ERROR_NUMBER() = 1205
        BEGIN
            SET @result_code = 51007;
            SET @message = N'Deadlock victim (51007) — restart unit.';
        END
        ELSE
        BEGIN
            THROW;   -- re-throw: §6.3 is exhaustive (0/51001..51009) — no code for
                     -- unexpected errors; raw trigger/constraint errors surface
        END
    END CATCH
END
GO

-- ============================================================
-- 4. ENTRY POINT: dbo.usp_maintenance_report (Task 11 W4; K5 closure)
--    Maintenance ticket creation. Acquires the same per-space lock ONLY
--    when the ticket starts at 'out-of-service' (blocking level), so an
--    in-flight booking cannot be overwritten by a blocking ticket.
--    Advisory tickets need no lock (they block nothing).
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.usp_maintenance_report
    @space_id              INT,
    @reporter_id           INT,
    @problem_description   NVARCHAR(MAX),
    @start_time            DATETIME2,
    @impact_level          VARCHAR(50) = 'advisory',
    @maintenance_id        INT         = NULL OUTPUT,
    @result_code           INT         = 0   OUTPUT,
    @message               NVARCHAR(500) = N'' OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @maintenance_id = NULL;
    SET @result_code = 0;
    SET @message = N'';

    DECLARE @lock_rc INT = -999;
    DECLARE @lock_resource NVARCHAR(128);
    DECLARE @ok BIT = 0;

    BEGIN TRY
        -- W4 step 1: validation without a lock
        IF @space_id IS NULL OR @reporter_id IS NULL OR @start_time IS NULL
           OR @problem_description IS NULL OR LTRIM(RTRIM(@problem_description)) = N''
        BEGIN
            SET @result_code = 51001;
            SET @message = N'Missing required ticket fields.';
            RETURN;
        END
        IF @impact_level NOT IN ('advisory','out-of-service')
        BEGIN
            SET @result_code = 51001;
            SET @message = N'Invalid impact level (must be advisory or out-of-service).';
            RETURN;
        END

        SELECT @ok = 1 FROM dbo.spaces WHERE space_id = @space_id;
        IF @ok = 0
        BEGIN
            SET @result_code = 51001;
            SET @message = N'Space not found.';
            RETURN;
        END

        SELECT @ok = CASE WHEN account_status = 'active' THEN 1 ELSE 0 END
        FROM dbo.users
        WHERE user_id = @reporter_id;
        IF @ok = 0
        BEGIN
            SET @result_code = 51001;
            SET @message = N'Reporter is not an active user.';
            RETURN;
        END

        -- W4 step 2: lock ONLY for blocking (out-of-service) tickets
        IF @impact_level = 'out-of-service'
        BEGIN
            SET @lock_resource = N'space_booking:' + CONVERT(NVARCHAR(12), @space_id);
            BEGIN TRANSACTION;

            EXEC @lock_rc = sys.sp_getapplock
                @Resource    = @lock_resource,
                @LockMode    = 'Exclusive',
                @LockOwner   = 'Transaction',
                @LockTimeout = 5000;

            IF @lock_rc = -1
            BEGIN
                ROLLBACK TRANSACTION;
                SET @result_code = 51005;
                SET @message = N'App lock timeout (51005).';
                RETURN;
            END
            IF @lock_rc = -2
            BEGIN
                ROLLBACK TRANSACTION;
                SET @result_code = 51006;
                SET @message = N'App lock cancelled (51006).';
                RETURN;
            END
            IF @lock_rc = -3
            BEGIN
                ROLLBACK TRANSACTION;
                SET @result_code = 51007;
                SET @message = N'Deadlock victim (51007) — restart unit.';
                RETURN;
            END
            IF @lock_rc NOT IN (0, 1)   -- 0 granted sync, 1 granted after wait; else (e.g. -999) programmer error
            BEGIN
                ROLLBACK TRANSACTION;
                THROW 52999, N'usp_maintenance_report: invalid sp_getapplock return.', 1;
            END

            -- W4 step 3: re-read the space inside the critical section
            SELECT @ok = 1 FROM dbo.spaces WHERE space_id = @space_id;
            IF @ok = 0
            BEGIN
                ROLLBACK TRANSACTION;
                SET @result_code = 51001;
                SET @message = N'Space vanished before insert.';
                RETURN;
            END
        END

        -- W4 step 4: INSERT — impact_level and status always passed explicitly (N6)
        INSERT INTO dbo.maintenance
            (space_id, reporter_id, problem_description, start_time, status, impact_level)
        VALUES
            (@space_id, @reporter_id, @problem_description, @start_time, 'open', @impact_level);

        SET @maintenance_id = SCOPE_IDENTITY();

        -- W4 step 5: COMMIT only on the locked path; the advisory path commits
        -- via the auto-commit INSERT above.
        IF @impact_level = 'out-of-service'
            COMMIT TRANSACTION;

        SET @result_code = 0;
        SET @message = N'Ticket id=' + CONVERT(NVARCHAR(12), @maintenance_id) + N' created (impact=' + @impact_level + N').';
        RETURN;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        IF ERROR_NUMBER() = 1205
        BEGIN
            SET @result_code = 51007;
            SET @message = N'Deadlock victim (51007) — restart unit.';
        END
        ELSE
        BEGIN
            THROW;   -- re-throw: §6.3 is exhaustive (0/51001..51009) — no code for
                     -- unexpected errors; raw trigger/constraint errors surface
        END
    END CATCH
END
GO

PRINT 'T12-PROCEDURES-CREATED';
GO

-- ============================================================
-- 5. NON-CONCURRENT SMOKE CHECKS (scratch-DB safe)
--    Entry points are called STANDALONE only (N3: they own a transaction
--    and would dismiss an outer one). Created rows are explicitly deleted
--    afterwards and the overlap invariant is re-verified. No Task 13
--    two-session scripts here.
-- ============================================================
PRINT 'SMOKE: verify entry points exist (name + parameter count)';
SELECT p.name AS procedure_name, COUNT(pr.object_id) AS parameter_count
FROM sys.procedures p
LEFT JOIN sys.parameters pr ON pr.object_id = p.object_id
WHERE p.name IN ('usp_booking_instant_submit','usp_booking_approve',
                 'usp_maintenance_set_impact_level','usp_maintenance_report')
GROUP BY p.name
ORDER BY p.name;
GO

DECLARE @smk_space INT = (SELECT TOP 1 s.space_id
        FROM dbo.spaces s
        INNER JOIN dbo.space_type_allowed_purpose p ON p.space_type = s.space_type
        WHERE s.capacity >= 20
          AND s.current_status NOT IN ('retired','temporarily_closed')
        ORDER BY s.space_id);
DECLARE @smk_requester INT = (SELECT TOP 1 user_id FROM dbo.users
        WHERE account_status = 'active' AND user_id <> -1 ORDER BY user_id);
DECLARE @smk_staff INT = (SELECT TOP 1 user_id FROM dbo.users
        WHERE role IN ('facility_staff','facility_manager')
          AND account_status = 'active' AND user_id <> -1 ORDER BY user_id);

IF @smk_space IS NULL OR @smk_requester IS NULL OR @smk_staff IS NULL
BEGIN
    PRINT 'SMOKE-SKIP: no usable space / user in this database (smoke tests skipped).';
END
ELSE
BEGIN
    SET NOCOUNT ON;

    DECLARE @win_start  DATETIME2 = DATEADD(day,  400, SYSDATETIME());  -- far future, away from sample rows
    DECLARE @win_end    DATETIME2 = DATEADD(hour, 2, @win_start);
    DECLARE @oos_start  DATETIME2 = DATEADD(day,  380, SYSDATETIME());  -- S3 OOS window
    DECLARE @oos_end    DATETIME2 = DATEADD(hour, 2, @oos_start);
    DECLARE @win2_start DATETIME2 = DATEADD(day,  340, SYSDATETIME());  -- S4/S6 window
    DECLARE @win2_end   DATETIME2 = DATEADD(hour, 2, @win2_start);
    -- EXEC parameter lists accept only literals/variables (no function calls):
    DECLARE @win_plus30  DATETIME2 = DATEADD(minute, 30, @win_start);
    DECLARE @win_plus60  DATETIME2 = DATEADD(hour,   1, @win_start);
    DECLARE @smk_purpose VARCHAR(50) = (SELECT TOP 1 p.purpose FROM dbo.space_type_allowed_purpose p
                                        JOIN dbo.spaces s ON s.space_type = p.space_type
                                        WHERE s.space_id = @smk_space ORDER BY p.purpose);

    DECLARE @b1 INT, @ia1 BIT, @rc1 INT, @msg1 NVARCHAR(500);
    DECLARE @b2 INT, @ia2 BIT, @rc2 INT, @msg2 NVARCHAR(500);
    DECLARE @b3 INT, @ia3 BIT, @rc3b INT, @msg3b NVARCHAR(500);
    DECLARE @m0 INT, @rc0 INT, @msg0 NVARCHAR(500);   -- S0 advisory seed (trigger ack source)
    DECLARE @m3 INT, @rc3 INT, @msg3 NVARCHAR(500);
    DECLARE @b4 INT, @ia4 BIT, @rc4 INT, @msg4 NVARCHAR(500);
    DECLARE @m6 INT, @rc6 INT, @msg6 NVARCHAR(500);
    DECLARE @hist INT, @hist2 INT;
    DECLARE @acks INT;                                 -- ack-presence assertion (R3/R4)

    -- S0: seed an ADVISORY ticket overlapping the S1 window (day +400) so the
    -- insert-time trigger has a real advisory to materialize acks for (R3/R4).
    EXEC dbo.usp_maintenance_report @space_id = @smk_space, @reporter_id = @smk_requester,
        @problem_description = N'S0 advisory seed (trigger ack source)',
        @start_time = @win_start, @impact_level = 'advisory',
        @maintenance_id = @m0 OUTPUT, @result_code = @rc0 OUTPUT, @message = @msg0 OUTPUT;
    IF @rc0 = 0 AND @m0 IS NOT NULL
        PRINT 'PASS S0: advisory seed ticket created (rc=0).';
    ELSE
        PRINT 'FAIL S0: expected rc=0 — got rc=' + ISNULL(CAST(@rc0 AS VARCHAR(5)),'null');

    -- S1: instant submit success (all gates pass) -> rc=0, instant=1
    EXEC dbo.usp_booking_instant_submit
        @space_id = @smk_space,
        @requester_id = @smk_requester,
        @purpose = @smk_purpose,
        @expected_participants = 10,
        @requested_start_time = @win_start,
        @requested_end_time = @win_end,
        @booking_id = @b1 OUTPUT,
        @instant_accepted = @ia1 OUTPUT,
        @result_code = @rc1 OUTPUT,
        @message = @msg1 OUTPUT;

    IF @rc1 = 0 AND @ia1 = 1 AND @b1 IS NOT NULL
        PRINT 'PASS S1: instant submit auto-approved (rc=0, instant=1).';
    ELSE
        PRINT 'FAIL S1: expected rc=0 instant=1 — got rc=' + ISNULL(CAST(@rc1 AS VARCHAR(5)),'null')
            + ' instant=' + ISNULL(CAST(@ia1 AS VARCHAR(1)),'null') + '.';

    -- S1b: acks materialized by the trigger (R3/R4) — count must equal the number
    -- of overlapping active advisories at insert time, all attributed to requester;
    -- a UQ (booking_id, maintenance_id) double-insert would have rolled back S1.
    SET @acks = (SELECT COUNT(*) FROM dbo.booking_advisory_acknowledgement
                 WHERE booking_id = @b1);
    IF @acks >= 1
       AND @acks = (SELECT COUNT(*) FROM dbo.maintenance m
            WHERE m.space_id = @smk_space AND m.is_deleted = 0
              AND m.status IN ('open','in_progress') AND m.impact_level = 'advisory'
              AND m.start_time < @win_end
              AND (m.completion_time IS NULL OR m.completion_time > @win_start))
       AND NOT EXISTS (SELECT 1 FROM dbo.booking_advisory_acknowledgement
                       WHERE booking_id = @b1 AND acknowledged_by <> @smk_requester)
        PRINT 'PASS S1b: trigger materialized ' + CAST(@acks AS VARCHAR(5))
            + ' ack row(s) at insert (attributed to requester).';
    ELSE
        PRINT 'FAIL S1b: ack count=' + CAST(@acks AS VARCHAR(5)) + ' — trigger contract (R3/R4) broken.';

    -- S2: overlapping instant submit -> BR1 (51003)
    EXEC dbo.usp_booking_instant_submit
        @space_id = @smk_space,
        @requester_id = @smk_requester,
        @purpose = @smk_purpose,
        @expected_participants = 5,
        @requested_start_time = @win_plus30,
        @requested_end_time = @win_plus60,
        @booking_id = @b2 OUTPUT,
        @instant_accepted = @ia2 OUTPUT,
        @result_code = @rc2 OUTPUT,
        @message = @msg2 OUTPUT;
    IF @rc2 = 51003
        PRINT 'PASS S2: overlap rejected (code 51003, BR1).';
    ELSE
        PRINT 'FAIL S2: expected 51003 — got rc=' + ISNULL(CAST(@rc2 AS VARCHAR(5)),'null');

    -- S3a: out-of-service ticket (W4, K5 closure) on the day-380 window.
    EXEC dbo.usp_maintenance_report
        @space_id = @smk_space,
        @reporter_id = @smk_requester,
        @problem_description = N'S3 smoke OOS ticket',
        @start_time = @oos_start,
        @impact_level = 'out-of-service',
        @maintenance_id = @m3 OUTPUT,
        @result_code = @rc3 OUTPUT,
        @message = @msg3 OUTPUT;
    IF @rc3 = 0 AND @m3 IS NOT NULL
        PRINT 'PASS S3a: ticket created (W4, rc=0).';
    ELSE
        PRINT 'FAIL S3a: expected rc=0 — got rc=' + ISNULL(CAST(@rc3 AS VARCHAR(5)),'null');

    -- S3b: instant submit overlapping the OOS ticket -> BR4 (51002).
    --       (no confirmed booking overlaps day 380, so BR1 stays out of the way)
    EXEC dbo.usp_booking_instant_submit
        @space_id = @smk_space,
        @requester_id = @smk_requester,
        @purpose = @smk_purpose,
        @expected_participants = 5,
        @requested_start_time = @oos_start,
        @requested_end_time = @oos_end,
        @booking_id = @b3 OUTPUT,
        @instant_accepted = @ia3 OUTPUT,
        @result_code = @rc3b OUTPUT,
        @message = @msg3b OUTPUT;
    IF @rc3b = 51002
        PRINT 'PASS S3b: booking against OOS ticket rejected (code 51002, BR4).';
    ELSE
        PRINT 'FAIL S3b: expected 51002 — got rc=' + ISNULL(CAST(@rc3b AS VARCHAR(5)),'null');

    -- S4: pending fallback when the purpose is NOT allowed for this space type
    -- (soft gate 1). Candidates restricted to the CK_bookings_purpose domain so
    -- the INSERT itself stays CHECK-valid; eligibility comes from the junction.
    DECLARE @purpose_not_allowed VARCHAR(50) = (SELECT TOP 1 v.v
        FROM (VALUES ('administrative_event'),('student_activity'),('meeting'),('workshop'),
                     ('seminar'),('examination'),('lecture')) v(v)
        WHERE NOT EXISTS (SELECT 1 FROM dbo.space_type_allowed_purpose p
                 WHERE p.space_type = (SELECT space_type FROM dbo.spaces WHERE space_id = @smk_space)
                   AND p.purpose = v.v)
        ORDER BY v.v);

    IF @purpose_not_allowed IS NULL
        PRINT 'SKIP S4: every candidate purpose is allowed for the smoke space.';
    ELSE
    BEGIN
        EXEC dbo.usp_booking_instant_submit
            @space_id = @smk_space,
            @requester_id = @smk_requester,
            @purpose = @purpose_not_allowed,
            @expected_participants = 3,
            @requested_start_time = @win2_start,
            @requested_end_time = @win2_end,
            @booking_id = @b4 OUTPUT,
            @instant_accepted = @ia4 OUTPUT,
            @result_code = @rc4 OUTPUT,
            @message = @msg4 OUTPUT;
        IF @rc4 = 0 AND @ia4 = 0 AND @b4 IS NOT NULL
            PRINT 'PASS S4: purpose not eligible -> pending fallback (rc=0, instant=0).';
        ELSE
            PRINT 'FAIL S4: expected pending fallback — rc=' + ISNULL(CAST(@rc4 AS VARCHAR(5)),'null')
                + ' msg=' + ISNULL(@msg4,'null');

        -- S4b: trigger still ran for the PENDING insert (R1: status-agnostic) —
        -- ack count must match the active-advisory predicate (0 on this clean window).
        SET @acks = (SELECT COUNT(*) FROM dbo.booking_advisory_acknowledgement
                     WHERE booking_id = @b4);
        IF @acks = (SELECT COUNT(*) FROM dbo.maintenance m
                WHERE m.space_id = @smk_space AND m.is_deleted = 0
                  AND m.status IN ('open','in_progress') AND m.impact_level = 'advisory'
                  AND m.start_time < @win2_end
                  AND (m.completion_time IS NULL OR m.completion_time > @win2_start))
            PRINT 'PASS S4b: pending fallback ack count matches predicate ('
                + CAST(@acks AS VARCHAR(5)) + ').';
        ELSE
            PRINT 'FAIL S4b: ack count=' + CAST(@acks AS VARCHAR(5)) + ' for pending booking.';

        -- S5: staff approve the pending booking (W2 success path)
        DECLARE @rc5b INT, @msg5b NVARCHAR(500);
        EXEC dbo.usp_booking_approve @booking_id = @b4, @approver_id = @smk_staff,
            @decision = 'approved', @rejection_reason = NULL, @decision_note = N'SMOKE',
            @result_code = @rc5b OUTPUT, @message = @msg5b OUTPUT;
        IF @rc5b = 0
            PRINT 'PASS S5: staff approval succeeded (rc=0).';
        ELSE
            PRINT 'FAIL S5: expected rc=0 — got rc=' + ISNULL(CAST(@rc5b AS VARCHAR(5)),'null');

        -- S5b: rejection without a reason -> 51001 (BR7)
        DECLARE @rc5c INT, @msg5c NVARCHAR(500);
        EXEC dbo.usp_booking_approve @booking_id = @b4, @approver_id = @smk_staff,
            @decision = 'rejected', @rejection_reason = NULL,
            @result_code = @rc5c OUTPUT, @message = @msg5c OUTPUT;
        IF @rc5c = 51001
            PRINT 'PASS S5b: rejection without reason refuses (51001, BR7).';
        ELSE
            PRINT 'FAIL S5b: expected 51001 — got rc=' + ISNULL(CAST(@rc5c AS VARCHAR(5)),'null');
    END

    -- S6: escalation/downgrade (W3) + SESSION_CONTEXT attribution
    EXEC dbo.usp_maintenance_report @space_id = @smk_space, @reporter_id = @smk_requester,
        @problem_description = N'S6 advisory ticket', @start_time = @win2_start,
        @impact_level = 'advisory',
        @maintenance_id = @m6 OUTPUT, @result_code = @rc6 OUTPUT, @message = @msg6 OUTPUT;
    IF @rc6 = 0 AND @m6 IS NOT NULL
        PRINT 'PASS S6a: advisory ticket created (no-lock path).';
    ELSE
        PRINT 'FAIL S6a: expected rc=0 — got rc=' + ISNULL(CAST(@rc6 AS VARCHAR(5)),'null');

    EXEC sys.sp_set_session_context N'current_user_id', @smk_staff;
    DECLARE @rc6b INT, @msg6b NVARCHAR(500);
    EXEC dbo.usp_maintenance_set_impact_level @maintenance_id = @m6,
        @new_impact_level = 'out-of-service', @reason = N'SMOKE escalate',
        @result_code = @rc6b OUTPUT, @message = @msg6b OUTPUT;
    SET @hist = (SELECT COUNT(*) FROM dbo.maintenance_impact_history
                 WHERE maintenance_id = @m6 AND new_level = 'out-of-service'
                   AND changed_by = @smk_staff);
    IF @rc6b = 0 AND @hist >= 1
        PRINT 'PASS S6b: escalation recorded with SESSION_CONTEXT attribution (NR3).';
    ELSE
        PRINT 'FAIL S6b: rc=' + ISNULL(CAST(@rc6b AS VARCHAR(5)),'null') + ' hist=' + ISNULL(CAST(@hist AS VARCHAR(5)),'null');

    -- no-op re-escalation: same level -> success (rc=0) without a new history row
    DECLARE @rc6c INT, @msg6c NVARCHAR(500);
    EXEC dbo.usp_maintenance_set_impact_level @maintenance_id = @m6,
        @new_impact_level = 'out-of-service',
        @result_code = @rc6c OUTPUT, @message = @msg6c OUTPUT;
    SET @hist2 = (SELECT COUNT(*) FROM dbo.maintenance_impact_history
                  WHERE maintenance_id = @m6 AND new_level = 'out-of-service');
    IF @rc6c = 0 AND @hist2 = @hist
        PRINT 'PASS S6c: no-op same-level returns 0 and writes no new history row.';
    ELSE
        PRINT 'FAIL S6c: rc=' + ISNULL(CAST(@rc6c AS VARCHAR(5)),'null') + ' hist2=' + ISNULL(CAST(@hist2 AS VARCHAR(5)),'null');

    -- downgrade back to advisory (locked path, second transition)
    DECLARE @rc6d INT, @msg6d NVARCHAR(500);
    EXEC dbo.usp_maintenance_set_impact_level @maintenance_id = @m6,
        @new_impact_level = 'advisory',
        @result_code = @rc6d OUTPUT, @message = @msg6d OUTPUT;
    IF @rc6d = 0
        PRINT 'PASS S6d: downgrade back to advisory succeeded (rc=0).';
    ELSE
        PRINT 'FAIL S6d: expected rc=0 — got rc=' + ISNULL(CAST(@rc6d AS VARCHAR(5)),'null');

    EXEC sys.sp_set_session_context N'current_user_id', NULL;

    -- cleanup: remove all smoke-created rows (cascades: approvals, sessions, acks, history)
    IF @b1 IS NOT NULL DELETE FROM dbo.bookings WHERE booking_id = @b1;
    IF @b4 IS NOT NULL DELETE FROM dbo.bookings WHERE booking_id = @b4;
    IF @m3 IS NOT NULL DELETE FROM dbo.maintenance WHERE maintenance_id = @m3;
    IF @m6 IS NOT NULL DELETE FROM dbo.maintenance WHERE maintenance_id = @m6;
    IF @m0 IS NOT NULL DELETE FROM dbo.maintenance WHERE maintenance_id = @m0;

    -- final invariant audit: no overlapping confirmed bookings on the smoke space
    DECLARE @ovl INT = (SELECT COUNT(*)
        FROM dbo.bookings a
        INNER JOIN dbo.bookings b ON a.space_id = b.space_id AND a.booking_id < b.booking_id
        WHERE a.space_id = @smk_space
          AND a.is_deleted = 0 AND b.is_deleted = 0
          AND a.status IN ('approved','checked_in','completed')
          AND b.status IN ('approved','checked_in','completed')
          AND a.requested_start_time < b.requested_end_time
          AND a.requested_end_time > b.requested_start_time);
    IF @ovl = 0
        PRINT 'PASS invariant: zero overlapping confirmed bookings on the smoke space.';
    ELSE
        PRINT 'FAIL invariant: ' + CAST(@ovl AS VARCHAR(10)) + ' overlapping pair(s) remain.';

    PRINT 'SMOKE-OK: all non-concurrent Task 12 smoke checks finished.';
END
GO
