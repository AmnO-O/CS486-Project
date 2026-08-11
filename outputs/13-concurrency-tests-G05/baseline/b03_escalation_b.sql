USE CampusSpaceDB;
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
-- ============================================================
-- T13 BASELINE b03 session B (K3 — no concurrency control)
-- Inserts the confirmed booking overlapping M3 while A's escalation
-- is still uncommitted. The BR4 trigger reads M3 as advisory -> the
-- INSERT succeeds and commits.
-- ============================================================
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @s3 INT = (SELECT space_id FROM dbo.spaces WHERE space_code = N'TEST-13-03-MR');
DECLARE @rq INT = (SELECT user_id FROM dbo.users WHERE email = N'test13.requester@campus.edu');
DECLARE @w3 DATETIME2 = (SELECT start_time FROM dbo.maintenance WHERE space_id = @s3 AND problem_description = N'TEST-13 advisory M3');
DECLARE @b3 INT;

WAITFOR DELAY '00:00:01';
INSERT INTO dbo.bookings
    (space_id, requester_id, requested_start_time, requested_end_time,
     purpose, expected_participants, status)
VALUES
    (@s3, @rq, DATEADD(minute, 30, @w3), DATEADD(hour, 1, DATEADD(minute, 30, @w3)),
     'meeting', 10, 'approved');
SET @b3 = SCOPE_IDENTITY();
PRINT 'b03-B: confirmed booking ' + CAST(@b3 AS VARCHAR(12)) + ' committed while M3 was still advisory.';

WAITFOR DELAY '00:00:05';   -- let A commit its escalation first

DECLARE @prev VARCHAR(50) = (SELECT impact_level FROM dbo.maintenance WHERE maintenance_id =
    (SELECT TOP 1 maintenance_id FROM dbo.maintenance WHERE space_id = @s3 ORDER BY maintenance_id));
IF @prev = 'out-of-service'
    PRINT 'b03-B: M3 escalated while booking confirmed — Q audit next.';
-- measurement happens in A; here just report current overlap
DECLARE @q INT = (SELECT COUNT(*)
    FROM dbo.bookings b
    INNER JOIN dbo.maintenance m ON m.space_id = b.space_id
    WHERE b.space_id = @s3 AND b.is_deleted = 0 AND m.is_deleted = 0
      AND b.status IN ('approved','checked_in','completed')
      AND m.status IN ('open','in_progress') AND m.impact_level = 'out-of-service'
      AND m.start_time < b.requested_end_time
      AND (m.completion_time IS NULL OR m.completion_time > b.requested_start_time));
IF @q > 0
    PRINT 'PASS b03-B: Q_VIOLATION ≥ 1 (' + CAST(@q AS VARCHAR(10)) + ').';
ELSE
    PRINT 'b03-B: measured 0 (recording).';

-- Cleanup: remove own booking.
DELETE FROM dbo.bookings WHERE booking_id = @b3;
PRINT 'b03-B: cleanup done.';