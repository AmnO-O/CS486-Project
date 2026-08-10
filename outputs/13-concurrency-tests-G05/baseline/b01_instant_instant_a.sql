SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
-- ============================================================
-- T13 BASELINE b01 (K1 — no concurrency control)
-- Two raw INSERTs of CONFIRMED bookings on the same space,
-- overlapping windows, running in TWO sessions (A and B).
-- No app lock, no entry point, no re-check: the defense triggers
-- check committed data only (READ COMMITTED), so once each session
-- holds its own uncommitted row, the other session's check passes.
--
-- PASS families (both valid for this no-control twin, never a Task 12
-- business code):
--   1) BOTH commit -> overlapping confirmed bookings (Q_BR1 >= 1);
--   2) arrival collapses -> B's raw INSERT is rejected by the Phase-1
--      trigger backstop (raw engine error family).
-- A's 12 s hold window absorbs ~6 s process-spawn skew between the
-- two sessions, maximizing the real concurrent window.
-- ============================================================
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @s1  INT = (SELECT space_id FROM dbo.spaces WHERE space_code = N'TEST-13-01-MR');
DECLARE @rq  INT = (SELECT user_id FROM dbo.users WHERE email = N'test13.requester@campus.edu');
DECLARE @w1  DATETIME2 = DATEADD(day, 600, SYSDATETIME());
DECLARE @b_a INT;

-- Session A: open a transaction, insert its confirmed booking, hold it
-- open long enough that session B's overlap check (which sees only
-- committed rows) cannot see this row.
BEGIN TRANSACTION;
    INSERT INTO dbo.bookings
        (space_id, requester_id, requested_start_time, requested_end_time,
         purpose, expected_participants, status)
    VALUES
        (@s1, @rq, @w1, DATEADD(hour, 2, @w1), 'meeting', 10, 'approved');
    SET @b_a = SCOPE_IDENTITY();

    PRINT 'b01-A: holding confirmed booking ' + CAST(@b_a AS VARCHAR(12)) + ' uncommitted at W1.';
    WAITFOR DELAY '00:00:12';   -- window where B's check reads no committed overlap
COMMIT TRANSACTION;
PRINT 'b01-A: committed booking ' + CAST(@b_a AS VARCHAR(12)) + '.';

WAITFOR DELAY '00:00:06';   -- let B's insert attempt land inside the window

DECLARE @q INT = (SELECT COUNT(*)
    FROM dbo.bookings a
    INNER JOIN dbo.bookings b ON a.space_id = b.space_id AND a.booking_id < b.booking_id
    WHERE a.space_id = @s1 AND a.is_deleted = 0 AND b.is_deleted = 0
      AND a.status IN ('approved','checked_in','completed')
      AND b.status IN ('approved','checked_in','completed')
      AND a.requested_start_time < b.requested_end_time
      AND a.requested_end_time > b.requested_start_time);

-- Family 1: the violation persisted. Family 2: B's row is absent
-- (its insert was rejected by the raw trigger backstop).
DECLARE @b_rows INT = (SELECT COUNT(*) FROM dbo.bookings
                       WHERE space_id = @s1
                         AND requested_start_time = DATEADD(minute, 30, @w1));

IF @q > 0
    PRINT 'PASS b01-A: VIOLATION-OBSERVED (overlapping confirmed bookings, Q_BR1=' + CAST(@q AS VARCHAR(10)) + ').';
ELSE IF @b_rows = 0
    PRINT 'PASS b01-A: collapsed race — B was backstopped by the raw trigger (no control, no Task 12 code).';
ELSE
    PRINT 'FAIL b01-A: expected overlapping-confirmed violation, found Q_BR1=0.';

-- Cleanup: A's own race row (B cleans its own by booking_id).
DELETE FROM dbo.bookings WHERE requested_start_time = @w1 AND space_id = @s1;
DELETE FROM dbo.bookings WHERE requested_start_time = DATEADD(minute, 30, @w1) AND space_id = @s1;
PRINT 'b01-A: cleanup done.';