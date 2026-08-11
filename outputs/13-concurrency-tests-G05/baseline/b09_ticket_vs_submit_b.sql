SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
-- ============================================================
-- T13 BASELINE b09 session B (K5 — no concurrency control)
-- Inserts the confirmed booking overlapping the OOS ticket while the
-- ticket is uncommitted. BR4 trigger sees no OOS -> insert passes.
-- ============================================================
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @s5 INT = (SELECT space_id FROM dbo.spaces WHERE space_code = N'TEST-13-05-MR');
DECLARE @rq INT = (SELECT user_id FROM dbo.users WHERE email = N'test13.requester@campus.edu');
DECLARE @w5 DATETIME2 = DATEADD(day, 680, SYSDATETIME());
DECLARE @b5 INT;

WAITFOR DELAY '00:00:01';
INSERT INTO dbo.bookings
    (space_id, requester_id, requested_start_time, requested_end_time,
     purpose, expected_participants, status)
VALUES
    (@s5, @rq, DATEADD(minute, 30, @w5), DATEADD(hour, 1, DATEADD(minute, 30, @w5)),
     'meeting', 10, 'approved');
SET @b5 = SCOPE_IDENTITY();
PRINT 'b09-B: confirmed booking ' + CAST(@b5 AS VARCHAR(12)) + ' committed.';

WAITFOR DELAY '00:00:05';
DECLARE @q INT = (SELECT COUNT(*)
    FROM bookings b
    INNER JOIN dbo.maintenance m ON m.space_id = b.space_id
    WHERE b.space_id = @s5 AND b.is_deleted = 0 AND m.is_deleted = 0
      AND b.status IN ('approved','checked_in','completed')
      AND m.status IN ('open','in_progress') AND m.impact_level = 'out-of-service'
      AND m.start_time < b.requested_end_time
      AND (m.completion_time IS NULL OR m.completion_time > b.requested_start_time));
IF @q > 0
    PRINT 'PASS b09-B: VIOLATION-OBSERVED (Q=' + CAST(@q AS VARCHAR(10)) + ').';
ELSE
    PRINT 'b09-B: 0 violations at time of read.';

DELETE FROM dbo.bookings WHERE booking_id = @b5;
PRINT 'b09-B: cleanup done.';