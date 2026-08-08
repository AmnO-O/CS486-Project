-- ============================================================
-- CS486 G05 — Campus Space Management System
-- Task 13: Concurrency Tests — audit_invariant.sql (suite-wide)
-- Target: SQL Server 2019+ (T-SQL); run via sqlcmd -d <db> -i audit_invariant.sql
--
-- Suite-wide invariant audit over the TEST-13 fixture world:
--   Q_BR1  overlapping CONFIRMED booking pairs per space         -> expect 0
--   Q_NR6  confirmed bookings overlapping ACTIVE out-of-service
--          maintenance per space                                 -> expect 0
-- A non-zero row count in either query = suite FAIL. Every
-- scenario script also embeds the space-scoped form of these
-- queries as its own trailing audit; this file is the final word
-- after ALL scenarios have cleaned up.
-- ============================================================
SET NOCOUNT ON;

DECLARE @br1  INT;
DECLARE @nr6  INT;

-- Q_BR1: overlapping confirmed (approved/checked_in/completed) bookings
SELECT @br1 = COUNT(*)
FROM dbo.bookings a
INNER JOIN dbo.bookings b ON a.space_id = b.space_id AND a.booking_id < b.booking_id
INNER JOIN dbo.spaces s ON s.space_id = a.space_id
WHERE s.space_code LIKE N'TEST-13-%'
  AND a.is_deleted = 0 AND b.is_deleted = 0
  AND a.status IN ('approved','checked_in','completed')
  AND b.status IN ('approved','checked_in','completed')
  AND a.requested_start_time < b.requested_end_time
  AND a.requested_end_time > b.requested_start_time;

-- Q_NR6: confirmed bookings overlapping active out-of-service maintenance
SELECT @nr6 = COUNT(*)
FROM dbo.bookings b
INNER JOIN dbo.maintenance m ON m.space_id = b.space_id
INNER JOIN dbo.spaces s ON s.space_id = b.space_id
WHERE s.space_code LIKE N'TEST-13-%'
  AND b.is_deleted = 0 AND m.is_deleted = 0
  AND b.status IN ('approved','checked_in','completed')
  AND m.status IN ('open','in_progress')
  AND m.impact_level = 'out-of-service'
  AND m.start_time < b.requested_end_time
  AND (m.completion_time IS NULL OR m.completion_time > b.requested_start_time);

IF @br1 = 0 AND @nr6 = 0
    PRINT 'PASS suite-audit: zero overlapping confirmed pairs AND zero confirmed-vs-OOS overlaps on TEST-13 spaces.';
ELSE
BEGIN
    PRINT 'FAIL suite-audit: br1_overlapping_pairs=' + CAST(@br1 AS VARCHAR(10))
        + ' nr6_confirmed_vs_oos=' + CAST(@nr6 AS VARCHAR(10));
    THROW 53990, N'Task 13 suite audit failed.', 1;
END