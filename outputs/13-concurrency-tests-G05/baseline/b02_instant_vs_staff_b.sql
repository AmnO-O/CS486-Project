SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
-- ============================================================
-- T13 BASELINE b02 session B (K2 — no concurrency control)
-- Inserts TWO confirmed bookings overlapping the pending PB2a/PB2b
-- windows FIRST (deterministic submit-first order; A polls for these
-- rows before approving). The raw overlap trigger sees the pendings
-- as not-yet-approved, so both inserts commit.
-- ============================================================
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @s2 INT = (SELECT space_id FROM dbo.spaces WHERE space_code = N'TEST-13-02-MR');
DECLARE @rq INT = (SELECT user_id FROM dbo.users WHERE email = N'test13.requester@campus.edu');
DECLARE @w2a DATETIME2, @w2b DATETIME2;
SELECT TOP 1 @w2a = requested_start_time FROM dbo.bookings WHERE space_id = @s2 AND status = 'pending' ORDER BY requested_start_time ASC;
SELECT TOP 1 @w2b = requested_start_time FROM dbo.bookings WHERE space_id = @s2 AND status = 'pending' AND requested_start_time > @w2a ORDER BY requested_start_time ASC;
DECLARE @b1 INT, @b2 INT, @r1 INT = 0, @r2 INT = 0;

-- Insert #1: overlapping the PB2a window (A polls for this row).
BEGIN TRY
    INSERT INTO dbo.bookings
        (space_id, requester_id, requested_start_time, requested_end_time,
         purpose, expected_participants, status)
    VALUES
        (@s2, @rq, DATEADD(minute, 30, @w2a), DATEADD(hour, 1, DATEADD(minute, 30, @w2a)),
         'meeting', 10, 'approved');
    SET @b1 = SCOPE_IDENTITY();
    PRINT 'b02-B: inserted approved booking ' + CAST(@b1 AS VARCHAR(12)) + ' overlapping PB2a (no control).';
END TRY
BEGIN CATCH
    SET @r1 = ERROR_NUMBER();
    PRINT 'b02-B: PB2a-window insert rejected by raw trigger (error ' + CAST(@r1 AS VARCHAR(10))
        + ' — backstop family, no business code).';
END CATCH

-- Insert #2: overlapping the PB2b window (A polls next).
WAITFOR DELAY '00:00:02';
BEGIN TRY
    INSERT INTO dbo.bookings
        (space_id, requester_id, requested_start_time, requested_end_time,
         purpose, expected_participants, status)
    VALUES
        (@s2, @rq, DATEADD(minute, 30, @w2b), DATEADD(hour, 1, DATEADD(minute, 30, @w2b)),
         'meeting', 10, 'approved');
    SET @b2 = SCOPE_IDENTITY();
    PRINT 'b02-B: inserted approved booking ' + CAST(@b2 AS VARCHAR(12)) + ' overlapping PB2b (no control).';
END TRY
BEGIN CATCH
    SET @r2 = ERROR_NUMBER();
    PRINT 'b02-B: PB2b-window insert rejected by raw trigger (error ' + CAST(@r2 AS VARCHAR(10))
        + ' — backstop family, no business code).';
END CATCH

WAITFOR DELAY '00:00:04';   -- let A's approvals land before measuring
DECLARE @q INT = (SELECT COUNT(*)
    FROM dbo.bookings a
    INNER JOIN dbo.bookings b ON a.space_id = b.space_id AND a.booking_id < b.booking_id
    WHERE a.space_id = @s2 AND a.is_deleted = 0 AND b.is_deleted = 0
      AND a.status IN ('approved','checked_in','completed')
      AND b.status IN ('approved','checked_in','completed')
      AND a.requested_start_time < b.requested_end_time
      AND a.requested_end_time > b.requested_start_time);

IF @q > 0
    PRINT 'PASS b02-B: VIOLATION-OBSERVED (Q_BR1=' + CAST(@q AS VARCHAR(10)) + ').';
ELSE IF @r1 <> 0 AND @r2 <> 0
    PRINT 'b02-B: both inserts backstopped by raw triggers (no control).';
ELSE
    PRINT 'b02-B: no overlap persisted in this run (recorded).';

-- Cleanup: this session's rows.
IF @b1 IS NOT NULL AND EXISTS (SELECT 1 FROM dbo.bookings WHERE booking_id = @b1)
    DELETE FROM dbo.bookings WHERE booking_id = @b1;
IF @b2 IS NOT NULL AND EXISTS (SELECT 1 FROM dbo.bookings WHERE booking_id = @b2)
    DELETE FROM dbo.bookings WHERE booking_id = @b2;
PRINT 'b02-B: cleanup done.';