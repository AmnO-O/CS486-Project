-- ============================================================
-- T13 BASELINE b09 (K5 — no concurrency control)
-- out-of-service ticket creation vs a booking submit, raw SQL:
--   A inserts the OOS ticket inside a held transaction (in-flight);
--   B inserts a CONFIRMED booking overlapping the ticket window.
--   B's BR4 trigger reads committed maintenance only -> sees no OOS
--   -> passes; B commits; then A commits.
-- Expected (PASS baseline): confirmed booking overlapping the OOS
-- worry-line -> no mechanism caught it (Q_OVERLAP >= 1).
-- ============================================================
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @s5  INT = (SELECT space_id FROM dbo.spaces WHERE space_code = N'TEST-13-05-MR');
DECLARE @rq  INT = (SELECT user_id FROM dbo.users WHERE email = N'test13.requester@campus.edu');
DECLARE @w5  DATETIME2 = DATEADD(day, 680, SYSDATETIME());
DECLARE @tk  INT;

BEGIN TRANSACTION;
    INSERT INTO dbo.maintenance
        (space_id, reporter_id, problem_description, start_time, status, impact_level)
    VALUES
        (@s5, @rq, N'TEST-13 b09 OOS ticket', DATEADD(hour, -1, @w5), 'open', 'out-of-service');
    SET @tk = SCOPE_IDENTITY();
    PRINT 'b09-A: OOS ticket ' + CAST(@tk AS VARCHAR(12)) + ' held uncommitted...';
    WAITFOR DELAY '00:00:05';
COMMIT TRANSACTION;
PRINT 'b09-A: OOS ticket committed after B.obtain:';

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
    PRINT 'b09-A: 0 violations recorded this run.';

-- Cleanup: remove ticket + B handles its booking.
DELETE FROM dbo.maintenance WHERE maintenance_id = @tk;
PRINT 'b09-A: ticket removed.';