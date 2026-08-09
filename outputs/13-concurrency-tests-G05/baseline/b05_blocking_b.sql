SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
-- ============================================================
-- T13 BASELINE b05 session B (no timeout/retry contract)
-- Waits on the row A holds. No applock -> no 51005; the UPDATE
-- blocks silently until A commits, then completes (~18 s later).
-- Eighteen seconds vs the 5-second timeout in the controlled run.
-- ============================================================
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @s3 INT = (SELECT space_id FROM dbo.spaces WHERE space_code = N'TEST-13-03-MR');
DECLARE @m3 INT = (SELECT maintenance_id FROM dbo.maintenance
                   WHERE space_id = @s3 AND problem_description = N'TEST-13 advisory M3');
IF @m3 IS NULL
    THROW 53008, N'Task 13 b05: M3 not found.', 1;

DECLARE @t0 DATETIME2 = SYSDATETIME();
WAITFOR DELAY '00:00:02';   -- ensure A owns the lock first

-- This blocks until A's COMMIT — no timeout parameter exists to bound it.
UPDATE dbo.maintenance
SET impact_level = 'advisory'   -- no-op value: lock only, state unchanged
WHERE maintenance_id = @m3;

DECLARE @elapsed_ms INT = DATEDIFF(second, @t0, SYSDATETIME());
IF @elapsed_ms >= 5
    PRINT 'PASS b05-B: uncontrolled blocking observed (B waited ' + CAST(@elapsed_ms AS VARCHAR(6))
        + ' s for A; no business code, no retry contract).';
ELSE
    PRINT 'FAIL b05-B: expected a long silent wait, got ' + CAST(@elapsed_ms AS VARCHAR(6)) + 's.';
PRINT 'b05-B: done.';