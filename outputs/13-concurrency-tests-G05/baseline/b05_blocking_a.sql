-- ============================================================
-- T13 BASELINE b05 (lock-contract — no concurrency control)
-- There is NO application lock in the raw world, so there is NO
-- timeout, NO 51005, NO retry contract. Session A holds a row lock
-- on maintenance M3; session B waits on the same row with NO
-- timeout semantics and completes only when A commits.
-- Expected (PASS): B waited >= 5 s with no business code emitted
-- (contrast: controlled c05 returns 51005 after 5 s and B retries).
-- ============================================================
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @s3 INT = (SELECT space_id FROM dbo.spaces WHERE space_code = N'TEST-13-03-MR');
DECLARE @m3 INT = (SELECT maintenance_id FROM dbo.maintenance
                   WHERE space_id = @s3 AND problem_description = N'TEST-13 advisory M3');
IF @m3 IS NULL
    THROW 53008, N'Task 13 b05: M3 not found.', 1;

BEGIN TRANSACTION;
    -- touch the same row B needs -> exclusive row lock held ~18 s
    UPDATE dbo.maintenance
    SET status = 'open'           -- no-op value: lock only, state unchanged
    WHERE maintenance_id = @m3;
    PRINT 'b05-A: holding row lock on M3 (no app lock, no timeout contract).';
    WAITFOR DELAY '00:00:18';
COMMIT TRANSACTION;
PRINT 'b05-A: released after 18 s.';