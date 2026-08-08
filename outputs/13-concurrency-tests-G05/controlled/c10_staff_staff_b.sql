-- ============================================================
-- T13 CONTROLLED c10 session B (T10) — second approval attempt
-- ============================================================
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @s8    INT = (SELECT space_id FROM dbo.spaces WHERE space_code = N'TEST-13-08-MR');
DECLARE @st    INT = (SELECT user_id FROM dbo.users WHERE email = N'test13.staff@campus.edu');
DECLARE @w8    DATETIME2 = DATEADD(day, 740, SYSDATETIME());
DECLARE @w8b   DATETIME2 = DATEADD(minute, 30, @w8);
DECLARE @pb10b INT = (SELECT booking_id FROM dbo.bookings WHERE space_id = @s8 AND requested_start_time = @w8b AND status = 'pending');

IF @pb10b IS NULL
    THROW 53041, N'Task 13 c10: PB10b missing.', 1;

DECLARE @rc INT, @msg NVARCHAR(500);
WAITFOR DELAY '00:00:02';

EXEC dbo.usp_booking_approve
    @booking_id = @pb10b, @approver_id = @st, @decision = 'approved',
    @decision_note = N'c10 second', @result_code = @rc OUTPUT, @message = @msg OUTPUT;
IF @rc = 51003
    PRINT 'PASS c10-B: approve(PB10b) rc=51003 (overlap with the first approval).';
ELSE
    PRINT 'FAIL c10-B: expected 51003, got rc=' + ISNULL(CAST(@rc AS VARCHAR(5)),'null')
        + ' msg=' + ISNULL(@msg,'null');

PRINT 'c10-B: done (fixture restored in A).';