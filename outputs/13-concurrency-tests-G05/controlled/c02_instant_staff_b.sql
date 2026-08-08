-- ============================================================
-- T13 CONTROLLED c02 session B (K2)
-- Order-1: instant submit overlapping W2A after A approved PB2a -> 51003.
-- Order-2: instant submit overlapping W2B (before any approval) -> 0.
-- ============================================================
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @s2  INT = (SELECT space_id FROM dbo.spaces WHERE space_code = N'TEST-13-02-MR');
DECLARE @rq  INT = (SELECT user_id FROM dbo.users WHERE email = N'test13.requester@campus.edu');
DECLARE @w2a DATETIME2 = DATEADD(day, 620, SYSDATETIME());
DECLARE @w2b DATETIME2 = DATEADD(day, 621, SYSDATETIME());
DECLARE @bk INT, @ok BIT, @rc INT, @msg NVARCHAR(500);

-- Order-1: A approved PB2a at ~+1 s; submit W2A overlapping it.
WAITFOR DELAY '00:00:02';
EXEC dbo.usp_booking_instant_submit
    @space_id = @s2, @requester_id = @rq, @purpose = 'meeting',
    @expected_participants = 5,
    @requested_start_time = DATEADD(minute, 30, @w2a),
    @requested_end_time = DATEADD(hour, 1, DATEADD(minute, 30, @w2a)),
    @booking_id = @bk OUTPUT, @instant_accepted = @ok OUTPUT,
    @result_code = @rc OUTPUT, @message = @msg OUTPUT;
IF @rc = 51003
    PRINT 'PASS c02-B: W2A instant submit rc=51003 (approved booking exists).';
ELSE
    PRINT 'FAIL c02-B: expected 51003 for W2A submit, got rc=' + ISNULL(CAST(@rc AS VARCHAR(5)),'null');

-- Order-2: no approval exists on W2B yet -> instant succeeds.
WAITFOR DELAY '00:00:01';
EXEC dbo.usp_booking_instant_submit
    @space_id = @s2, @requester_id = @rq, @purpose = 'meeting',
    @expected_participants = 10,
    @requested_start_time = DATEADD(minute, 30, @w2b),
    @requested_end_time = DATEADD(hour, 1, DATEADD(minute, 30, @w2b)),
    @booking_id = @bk OUTPUT, @instant_accepted = @ok OUTPUT,
    @result_code = @rc OUTPUT, @message = @msg OUTPUT;
IF @rc = 0 AND @ok = 1
    PRINT 'PASS c02-B: W2B instant submit rc=0, instant=1 (order-2 submit wins).';
ELSE
    PRINT 'FAIL c02-B: expected 0/1 for W2B, got rc=' + ISNULL(CAST(@rc AS VARCHAR(5)),'null');

-- Cleanup: the confirmed instant booking stays until fixture restore in
-- c02-A / 99_cleanup (A's second approval depends on its existence).