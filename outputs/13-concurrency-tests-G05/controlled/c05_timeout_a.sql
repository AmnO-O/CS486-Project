USE CampusSpaceDB;
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
-- ============================================================
-- T13 CONTROLLED c05 (T5/T7) — app lock timeout + retry
-- Task 12: usp_maintenance_report with sp_getapplock 5 s timeout.
-- Session A takes the raw applock on the space and holds it 20 s
-- (simulating a long legitimate transaction); session B's ticket
-- attempt yields 51005 (lock timeout) and the retry after release
-- succeeds (rc=0).
-- ============================================================
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @s4 INT = (SELECT space_id FROM dbo.spaces WHERE space_code = N'TEST-13-04-MR');
DECLARE @res NVARCHAR(255) = N'space_booking:' + CONVERT(NVARCHAR(12), @s4);
DECLARE @lock_rc INT;

BEGIN TRANSACTION;
    EXEC @lock_rc = sys.sp_getapplock
        @Resource = @res,
        @LockMode = 'Exclusive', @LockOwner = 'Transaction', @LockTimeout = 5000;
    IF @lock_rc <> 0   -- hold only if we own it
        ROLLBACK TRANSACTION;
    ELSE BEGIN
        PRINT 'c05-A: holding app lock on space_booking:... for 8 s.';
        WAITFOR DELAY '00:00:08';
        COMMIT TRANSACTION;
    END
PRINT 'c05-A: lock released.';