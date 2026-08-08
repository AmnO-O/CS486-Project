-- ============================================================
-- T13 CONTROLLED c09 session B (K5/T9)
-- Order-1: instant submit overlapping the order-1 OOS ticket -> 51002.
-- Order-2: instant submit on W5b BEFORE its ticket exists -> rc=0
-- (the K5 submit-wins branch).
-- ============================================================
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @s5 INT = (SELECT space_id FROM dbo.spaces WHERE space_code = N'TEST-13-05-MR');
DECLARE @rq INT = (SELECT user_id FROM dbo.users WHERE email = N'test13.requester@campus.edu');
DECLARE @w5 DATETIME2 = DATEADD(day, 680, SYSDATETIME());
DECLARE @bk INT, @ok BIT, @rc INT, @msg NVARCHAR(500);

-- Order-1: submit overlapping the order-1 ticket.
WAITFOR DELAY '00:00:02';
EXEC dbo.usp_booking_instant_submit
    @space_id = @s5, @requester_id = @rq, @purpose = 'meeting',
    @expected_participants = 5,
    @requested_start_time = DATEADD(minute, 30, @w5),
    @requested_end_time = DATEADD(hour, 1, DATEADD(minute, 30, @w5)),
    @booking_id = @bk OUTPUT, @instant_accepted = @ok OUTPUT,
    @result_code = @rc OUTPUT, @message = @msg OUTPUT;
IF @rc = 51002
    PRINT 'PASS c09-B: order-1 submit rc=51002 (BR4 against ticket).';
ELSE
    PRINT 'FAIL c09-B: expected 51002, got rc=' + ISNULL(CAST(@rc AS VARCHAR(5)),'null');

-- Order-2: submit wins on W5b (ticket not yet created there).
WAITFOR DELAY '00:00:01';
EXEC dbo.usp_booking_instant_submit
    @space_id = @s5, @requester_id = @rq, @purpose = 'meeting',
    @expected_participants = 10,
    @requested_start_time = DATEADD(hour, 2, @w5),
    @requested_end_time = DATEADD(hour, 3, @w5),
    @booking_id = @bk OUTPUT, @instant_accepted = @ok OUTPUT,
    @result_code = @rc OUTPUT, @message = @msg OUTPUT;
IF @rc = 0 AND @ok = 1
    PRINT 'PASS c09-B: order-2 submit rc=0/instant=1 (submit-wins branch).';
ELSE
    PRINT 'FAIL c09-B: expected 0/1, got rc=' + ISNULL(CAST(@rc AS VARCHAR(5)),'null')
        + ' instant=' + ISNULL(CAST(@ok AS VARCHAR(1)),'null');

-- Wait for A's order-2 ticket, then confirm the booking is untouched
-- and carries NO acknowledgement (report #4 scope note — the K5
-- submit-wins booking is not discoverable through the escalation
-- ack join).
WAITFOR DELAY '00:00:03';
DECLARE @ack_cnt INT = (SELECT COUNT(*) FROM dbo.booking_advisory_acknowledgement
                        WHERE booking_id = @bk);
IF @ack_cnt = 0
    PRINT 'PASS c09-B: submit-wins booking has zero ack rows (outside report #4 scope, per Task 11 §7.4).';
ELSE
    PRINT 'c09-B: note: ' + CAST(@ack_cnt AS VARCHAR(5)) + ' ack row(s) present.';

-- Cleanup: remove the confirmed booking (approvals cascade).
IF @bk IS NOT NULL AND EXISTS (SELECT 1 FROM dbo.bookings WHERE booking_id = @bk)
    DELETE FROM dbo.bookings WHERE booking_id = @bk;
PRINT 'c09-B: cleanup done.';