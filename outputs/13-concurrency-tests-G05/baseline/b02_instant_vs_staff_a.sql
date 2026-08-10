SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
-- ============================================================
-- T13 BASELINE b02 (K2 — no concurrency control)
-- Staff approval vs instant submit, raw SQL, TWO sessions.
-- DETERMINISTIC order (poll-based, immune to session-spawn skew):
--   B inserts a CONFIRMED booking overlapping PB2a's window first
--     (+0 s; the overlap trigger sees PB2a still PENDING -> passes);
--   A polls until B's booking exists, then approves PB2a — the raw
--     approval INSERT has NO BR1 overlap gate (check_space covers
--     BR2/BR4/NR2 only), so it succeeds ON TOP of B's confirmed
--     booking;
--   order-2: B inserts a second confirmed booking overlapping PB2b;
--     A polls for it and approves PB2b the same way.
-- Expected: overlapping confirmed bookings persist (Q_BR1 >= 1) with
-- NO mechanism catching the staff approval — the missing critical
-- section, demonstrated.
-- ============================================================
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @s2  INT = (SELECT space_id FROM dbo.spaces WHERE space_code = N'TEST-13-02-MR');
DECLARE @st  INT = (SELECT user_id FROM dbo.users WHERE email = N'test13.staff@campus.edu');
DECLARE @pb2a INT, @pb2b INT, @pb2a_start DATETIME2, @pb2b_start DATETIME2;
SELECT TOP 1 @pb2a = booking_id, @pb2a_start = requested_start_time FROM dbo.bookings WHERE space_id = @s2 AND status = 'pending' ORDER BY requested_start_time ASC;
SELECT TOP 1 @pb2b = booking_id, @pb2b_start = requested_start_time FROM dbo.bookings WHERE space_id = @s2 AND status = 'pending' AND booking_id <> @pb2a ORDER BY requested_start_time ASC;

IF @pb2a IS NULL OR @pb2b IS NULL
BEGIN
    PRINT 'FAIL b02-A: fixture pending bookings missing (run 00_setup.sql first).';
    RETURN;
END

-- Poll for B's confirmed booking overlapping PB2a (window W2a+30min).
DECLARE @b1_win DATETIME2 = DATEADD(minute, 30, @pb2a_start);
DECLARE @t INT = 0;
WHILE @t < 45 AND NOT EXISTS (SELECT 1 FROM dbo.bookings
                              WHERE space_id = @s2 AND requested_start_time = @b1_win
                                AND status = 'approved' AND is_deleted = 0)
BEGIN
    WAITFOR DELAY '00:00:01';
    SET @t = @t + 1;
END
IF @t = 45
    PRINT 'WARN b02-A: poll #1 timed out (B''s insert never landed).';
ELSE
    PRINT 'b02-A: B''s confirmed booking present (poll #1 done).';

-- Order-1: approve PB2a ON TOP of the confirmed booking — the raw
-- approval INSERT has no BR1 gate, so it succeeds (no control).
BEGIN TRY
    INSERT INTO dbo.booking_approvals (booking_id, approver_id, decision_time, decision)
    VALUES (@pb2a, @st, SYSDATETIME(), 'approved');
    PRINT 'b02-A: fiat approval of PB2a succeeded over the confirmed booking (no BR1 gate — no control).';
END TRY
BEGIN CATCH
    PRINT 'b02-A: PB2a approval rejected by raw trigger (error ' + CAST(ERROR_NUMBER() AS VARCHAR(10))
        + ' — backstop family).';
END CATCH

-- Poll for B's second confirmed booking overlapping PB2b (W2b+30min).
DECLARE @b2_win DATETIME2 = DATEADD(minute, 30, @pb2b_start);
SET @t = 0;
WHILE @t < 45 AND NOT EXISTS (SELECT 1 FROM dbo.bookings
                              WHERE space_id = @s2 AND requested_start_time = @b2_win
                                AND status = 'approved' AND is_deleted = 0)
BEGIN
    WAITFOR DELAY '00:00:01';
    SET @t = @t + 1;
END
IF @t = 45
    PRINT 'WARN b02-A: poll #2 timed out (B''s insert #2 never landed).';
ELSE
    PRINT 'b02-A: B''s confirmed booking #2 present (poll #2 done).';

-- Order-2: approve PB2b the same way (un-gated -> succeeds).
BEGIN TRY
    INSERT INTO dbo.booking_approvals (booking_id, approver_id, decision_time, decision)
    VALUES (@pb2b, @st, SYSDATETIME(), 'approved');
    PRINT 'b02-A: fiat approval of PB2b succeeded (no BR1 gate — no control).';
END TRY
BEGIN CATCH
    PRINT 'b02-A: PB2b approval rejected by raw trigger (error ' + CAST(ERROR_NUMBER() AS VARCHAR(10))
        + ' — backstop family).';
END CATCH

WAITFOR DELAY '00:00:02';
DECLARE @q INT = (SELECT COUNT(*)
    FROM dbo.bookings a
    INNER JOIN dbo.bookings b ON a.space_id = b.space_id AND a.booking_id < b.booking_id
    WHERE a.space_id = @s2 AND a.is_deleted = 0 AND b.is_deleted = 0
      AND a.status IN ('approved','checked_in','completed')
      AND b.status IN ('approved','checked_in','completed')
      AND a.requested_start_time < b.requested_end_time
      AND a.requested_end_time > b.requested_start_time);

IF @q > 0
    PRINT 'PASS b02-A: VIOLATION-OBSERVED (overlapping confirmed bookings, Q_BR1=' + CAST(@q AS VARCHAR(10)) + ').';
ELSE
    PRINT 'b02-A: no persisted overlap this round (recorded).';

-- Restore fixture (FULL: both pendings + both race windows + any
-- approval rows the race created) so c02 can reuse PB2a/PB2b later.
DELETE FROM dbo.booking_approvals WHERE booking_id IN (@pb2a, @pb2b);
DELETE FROM dbo.bookings
    WHERE space_id = @s2 AND requested_start_time IN (@b1_win, @b2_win);
UPDATE dbo.bookings SET status = 'pending' WHERE booking_id IN (@pb2a, @pb2b);
PRINT 'b02-A: fixture restored (both pendings).';