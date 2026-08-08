-- ============================================================
-- CS486 G05 — Campus Space Management System
-- Task 13: Concurrency Tests — 99_cleanup.sql (fixture teardown)
-- Target: SQL Server 2019+ (T-SQL); run via sqlcmd -d <db> -i 99_cleanup.sql
--
-- Removes EVERY TEST-13 row (fixture + anything the scenario scripts
-- created on TEST-13 spaces/users). Cascade-safe order:
--   acks/history (children of maintenance+bookings) -> bookings
--   -> maintenance -> spaces -> users -> department.
-- Re-runnable; ends by verifying the fixture is fully gone.
-- ============================================================
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @rq INT = (SELECT user_id FROM dbo.users WHERE email = N'test13.requester@campus.edu');
DECLARE @st INT = (SELECT user_id FROM dbo.users WHERE email = N'test13.staff@campus.edu');

-- 1. Advisory acknowledgements + impact history (children, deleted first
--    for safety even though the FK chains cascade)
DELETE a
FROM dbo.booking_advisory_acknowledgement a
INNER JOIN dbo.maintenance m ON m.maintenance_id = a.maintenance_id
WHERE m.problem_description LIKE N'TEST-13 %';

DELETE a
FROM dbo.booking_advisory_acknowledgement a
INNER JOIN dbo.bookings b ON b.booking_id = a.booking_id
INNER JOIN dbo.spaces s ON s.space_id = b.space_id
WHERE s.space_code LIKE N'TEST-13-%';

DELETE h
FROM dbo.maintenance_impact_history h
INNER JOIN dbo.maintenance m ON m.maintenance_id = h.maintenance_id
WHERE m.problem_description LIKE N'TEST-13 %';

-- 2. Bookings on TEST-13 spaces (cascades: booking_approvals,
--    booking_sessions, acks)
DELETE b
FROM dbo.bookings b
INNER JOIN dbo.spaces s ON s.space_id = b.space_id
WHERE s.space_code LIKE N'TEST-13-%';

-- 3. Maintenance on TEST-13 spaces (cascades: history, acks)
DELETE m
FROM dbo.maintenance m
INNER JOIN dbo.spaces s ON s.space_id = m.space_id
WHERE s.space_code LIKE N'TEST-13-%';

-- 4. Spaces, then users, then the department
DELETE FROM dbo.spaces WHERE space_code LIKE N'TEST-13-%';
DELETE FROM dbo.users WHERE user_id IN (@rq, @st);
DELETE FROM dbo.departments WHERE name = N'TEST-13-Dept';

-- 5. Verification: nothing left
DECLARE @left INT = (
    SELECT
        (SELECT COUNT(*) FROM dbo.spaces WHERE space_code LIKE N'TEST-13-%')
      + (SELECT COUNT(*) FROM dbo.users WHERE email LIKE N'test13.%@campus.edu')
      + (SELECT COUNT(*) FROM dbo.departments WHERE name = N'TEST-13-Dept')
      + (SELECT COUNT(*) FROM dbo.bookings b INNER JOIN dbo.spaces s ON s.space_id = b.space_id
         WHERE s.space_code LIKE N'TEST-13-%')
);

IF @left = 0
    PRINT 'T13-CLEANUP-OK: all TEST-13 rows removed.';
ELSE
BEGIN
    PRINT 'T13-CLEANUP-FAIL: ' + CAST(@left AS VARCHAR(10)) + ' TEST-13 row(s) remain.';
    THROW 53099, N'Task 13 cleanup verification failed.', 1;
END
