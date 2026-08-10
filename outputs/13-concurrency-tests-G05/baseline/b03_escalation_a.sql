SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
-- ============================================================
-- T13 BASELINE b03 (K3 — no concurrency control)
-- Escalation (advisory -> out-of-service) vs an in-flight booking:
-- both writers raw SQL, no app lock.
-- DETERMINISTIC order (poll-based, immune to spawn skew):
--   B inserts a CONFIRMED booking overlapping M3's window first
--     (+0 s; BR4 trigger reads M3 still 'advisory' -> passes);
--   A polls until B's booking exists, then escalates M3 to
--     out-of-service — the escalation UPDATE has NO overlap gate;
--   A commits -> a CONFIRMED booking now overlaps an ACTIVE
--     out-of-service maintenance, silently (nothing re-checks).
-- Expected: Q_NR6 >= 1 (confirmed vs active-OOS overlap).
-- ============================================================
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @s3  INT = (SELECT space_id FROM dbo.spaces WHERE space_code = N'TEST-13-03-MR');
DECLARE @m3  INT = (SELECT maintenance_id FROM dbo.maintenance
                    WHERE space_id = @s3 AND problem_description = N'TEST-13 advisory M3');

IF @m3 IS NULL
BEGIN
    PRINT 'FAIL b03-A: fixture maintenance M3 missing (run 00_setup.sql).';
    THROW 53007, N'Task 13 b03: M3 not found.', 1;
END

DECLARE @w3 DATETIME2 = (SELECT start_time FROM dbo.maintenance WHERE maintenance_id = @m3);

-- Poll for B's confirmed booking (window W3+30min) before escalating.
DECLARE @b_win DATETIME2 = DATEADD(minute, 30, @w3);
DECLARE @t INT = 0;
WHILE @t < 45 AND NOT EXISTS (SELECT 1 FROM dbo.bookings
                              WHERE space_id = @s3 AND requested_start_time = @b_win
                                AND status = 'approved' AND is_deleted = 0)
BEGIN
    WAITFOR DELAY '00:00:01';
    SET @t = @t + 1;
END
IF @t = 45
    PRINT 'WARN b03-A: poll timed out (B''s booking never landed).';
ELSE
    PRINT 'b03-A: B''s confirmed booking present (poll done).';

-- Escalate — the raw UPDATE has no overlap gate; it commits on top of
-- the confirmed booking (nothing re-checks).
UPDATE dbo.maintenance
SET impact_level = 'out-of-service'
WHERE maintenance_id = @m3;
PRINT 'b03-A: M3 escalated (out-of-service) after B committed its booking.';

WAITFOR DELAY '00:00:02';
DECLARE @q INT = (SELECT COUNT(*)
    FROM dbo.bookings b
    INNER JOIN dbo.maintenance m ON m.space_id = b.space_id
    WHERE b.space_id = @s3 AND b.is_deleted = 0 AND m.is_deleted = 0
      AND b.status IN ('approved','checked_in','completed')
      AND m.status IN ('open','in_progress') AND m.impact_level = 'out-of-service'
      AND m.start_time < b.requested_end_time
      AND (m.completion_time IS NULL OR m.completion_time > b.requested_start_time));

IF @q > 0
    PRINT 'PASS b03-A: VIOLATION-OBSERVED (confirmed booking overlapping active OOS maintenance, Q_NR6=' + CAST(@q AS VARCHAR(10)) + ').';
ELSE
    PRINT 'b03-A: no persist overlap recorded this round.';

-- Cleanup: restore M3 to advisory (fixture state used by c03).
UPDATE dbo.maintenance SET impact_level = 'advisory' WHERE maintenance_id = @m3;
PRINT 'b03-A: M3 restored to advisory.';