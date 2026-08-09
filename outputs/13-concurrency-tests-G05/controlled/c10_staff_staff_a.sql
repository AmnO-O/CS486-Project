SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
-- ============================================================
-- T13 CONTROLLED c10 (T10) — staff vs staff approvals
-- Task 12: usp_booking_approve on two overlapping pendings (PB10a,
-- PB10b) on the same space. The shared per-space applock serializes:
-- first approval rc=0, the other rc=51003 (BR1).
-- ============================================================
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @s8    INT = (SELECT space_id FROM dbo.spaces WHERE space_code = N'TEST-13-08-MR');
DECLARE @st    INT = (SELECT user_id FROM dbo.users WHERE email = N'test13.staff@campus.edu');
DECLARE @w8    DATETIME2 = DATEADD(day, 740, SYSDATETIME());
DECLARE @w8b   DATETIME2 = DATEADD(minute, 30, @w8);
DECLARE @pb10a INT = (SELECT booking_id FROM dbo.bookings WHERE space_id = @s8 AND requested_start_time = @w8  AND status = 'pending');
DECLARE @pb10b INT = (SELECT booking_id FROM dbo.bookings WHERE space_id = @s8 AND requested_start_time = @w8b AND status = 'pending');

IF @pb10a IS NULL OR @pb10b IS NULL
    THROW 53040, N'Task 13 c10: PB10a/PB10b fixture missing.', 1;

DECLARE @rc INT, @msg NVARCHAR(500);

-- First approval (session A acts first; B at ~+2 s).
EXEC dbo.usp_booking_approve
    @booking_id = @pb10a, @approver_id = @st, @decision = 'approved',
    @decision_note = N'c10 first', @result_code = @rc OUTPUT, @message = @msg OUTPUT;
IF @rc = 0
    PRINT 'PASS c10-A: approve(PB10a) rc=0 (first wins).';
ELSE
    PRINT 'FAIL c10-A: expected rc=0, got rc=' + ISNULL(CAST(@rc AS VARCHAR(5)),'null');

WAITFOR DELAY '00:00:06';   -- B attempts PB10b -> must 51003

-- Restore fixture.
DELETE FROM dbo.booking_approvals WHERE booking_id IN (@pb10a, @pb10b);
UPDATE dbo.bookings SET status = 'pending' WHERE booking_id IN (@pb10a, @pb10b);
PRINT 'c10-A: fixture restored.';