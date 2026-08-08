-- ============================================================
-- T13 BASELINE b02 session B (K2 — no concurrency control)
-- Inserts TWO confirmed bookings overlapping the pending PB2a/PB2b
-- windows while A's transaction is still open: the raw overlap
-- trigger sees only committed rows, so both inserts succeed.
-- ============================================================
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @s2 INT = (SELECT space_id FROM dbo.spaces WHERE space_code = N'TEST-13-02-MR');
DECLARE @rq INT = (SELECT user_id FROM dbo.users WHERE email = N'test13.requester@campus.edu');
DECLARE @w2a DATETIME2 = DATEADD(day, 620, SYSDATETIME());
DECLARE @w2b DATETIME2 = DATEADD(day, 621, SYSDATETIME());
DECLARE @b1 INT, @b2 INT;

-- overlapping with the pending's window (A hasn't committed its
-- approval yet — the 'approved' INSERT sees only pending data).
WAITFOR DELAY '00:00:02';
INSERT INTO dbo.bookings
    (space_id, requester_id, requested_start_time, requested_end_time,
     purpose, expected_participants, status)
VALUES
    (@s2, @rq, DATEADD(minute, 30, @w2a), DATEADD(hour, 1, DATEADD(minute, 30, @w2a)),
     'meeting', 10, 'approved');
SET @b1 = SCOPE_IDENTITY();
PRINT 'b02-B: inserted approved booking ' + CAST(@b1 AS VARCHAR(12)) + ' overlapping PB2a.';

-- Second order window: overlap PB2b (approval attempt falling a trigger).
WAITFOR DELAY '00:00:01';
INSERT INTO dbo.bookings
    (space_id, requester_id, requested_start_time, requested_end_time,
     purpose, expected_participants, status)
VALUES
    (@s2, @rq, DATEADD(minute, 30, @w2b), DATEADD(hour, 1, DATEADD(minute, 30, @w2b)),
     'meeting', 10, 'approved');
SET @b2 = SCOPE_IDENTITY();
PRINT 'b02-B: inserted confirmed booking ' + CAST(@b2 AS VARCHAR(12)) + ' overlapping PB2b.';

WAITFOR DELAY '00:00:04';   -- let A fail/commit before measuring
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
ELSE
    PRINT 'b02-B: no overlap persisted in this run; B inserts committed (recorded).';

-- Cleanup: this session's rows.
DELETE FROM dbo.bookings WHERE booking_id IN (@b1, @b2);
PRINT 'b02-B: cleanup done.';