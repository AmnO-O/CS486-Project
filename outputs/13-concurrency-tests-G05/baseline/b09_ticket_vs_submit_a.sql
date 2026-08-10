SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
-- ============================================================
-- T13 BASELINE b09 (K5 — no concurrency control)
-- out-of-service ticket creation vs a booking submit, raw SQL.
-- DETERMINISTIC order (poll-based, immune to spawn skew):
--   B inserts a CONFIRMED booking overlapping the would-be ticket
--     window first (+0 s; the BR4 trigger reads no OOS -> passes);
--   A polls until B's booking exists, then inserts the OOS ticket —
--     the raw maintenance INSERT has no overlap gate;
--   A commits -> the confirmed booking now overlaps an active
--     out-of-service ticket, silently (nothing re-checks).
-- Expected (PASS baseline): confirmed booking overlapping the OOS
-- ticket -> no mechanism caught it (Q_NR6 >= 1).
-- ============================================================
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @s5  INT = (SELECT space_id FROM dbo.spaces WHERE space_code = N'TEST-13-05-MR');
DECLARE @rq  INT = (SELECT user_id FROM dbo.users WHERE email = N'test13.requester@campus.edu');
DECLARE @w5  DATETIME2 = DATEADD(day, 680, SYSDATETIME());
DECLARE @tk  INT;

-- Poll for B's confirmed booking (window W5+30min) before inserting
-- the OOS ticket.
DECLARE @b_win DATETIME2 = DATEADD(minute, 30, @w5);
DECLARE @t INT = 0;
WHILE @t < 45 AND NOT EXISTS (SELECT 1 FROM dbo.bookings
                              WHERE space_id = @s5 AND requested_start_time = @b_win
                                AND status = 'approved' AND is_deleted = 0)
BEGIN
    WAITFOR DELAY '00:00:01';
    SET @t = @t + 1;
END
IF @t = 45
    PRINT 'WARN b09-A: poll timed out (B''s booking never landed).';
ELSE
    PRINT 'b09-A: B''s confirmed booking present (poll done).';

-- Insert the OOS ticket — the raw INSERT has no overlap gate; it
-- commits on top of the confirmed booking (nothing re-checks).
INSERT INTO dbo.maintenance
    (space_id, reporter_id, problem_description, start_time, status, impact_level)
VALUES
    (@s5, @rq, N'TEST-13 b09 OOS ticket', DATEADD(hour, -1, @w5), 'open', 'out-of-service');
SET @tk = SCOPE_IDENTITY();
PRINT 'b09-A: OOS ticket ' + CAST(@tk AS VARCHAR(12)) + ' committed after B.obtain:';

WAITFOR DELAY '00:00:02';
DECLARE @q INT = (SELECT COUNT(*)
    FROM dbo.bookings b
    INNER JOIN dbo.maintenance m ON m.space_id = b.space_id
    WHERE b.space_id = @s5 AND b.is_deleted = 0 AND m.is_deleted = 0
      AND b.status IN ('approved','checked_in','completed')
      AND m.status IN ('open','in_progress') AND m.impact_level = 'out-of-service'
      AND m.start_time < b.requested_end_time
      AND (m.completion_time IS NULL OR m.completion_time > b.requested_start_time));

IF @q > 0
    PRINT 'PASS b09-A: VIOLATION-OBSERVED (confirmed booking overlapping OOS ticket, Q=' + CAST(@q AS VARCHAR(10)) + ').';
ELSE
    PRINT 'b09-A: no violation persisted (collapsed race; raw backstop path).';

-- Cleanup: remove ticket + B handles its booking.
DELETE FROM dbo.maintenance WHERE maintenance_id = @tk;
PRINT 'b09-A: ticket removed.';