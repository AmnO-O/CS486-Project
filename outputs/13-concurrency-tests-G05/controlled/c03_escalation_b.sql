USE CampusSpaceDB;
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
-- ============================================================
-- T13 CONTROLLED c03 session B (K3/DD1/T4)
-- Order-1: instant submit inside the (already escalated) M3 window
--          -> 51002 (BR4).
-- T4 asserts: PB3 still 'pending' (escalation never touched it) and
--          any later approval attempt -> 51002 (BR4 behind the wire).
-- ============================================================
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @s3  INT = (SELECT space_id FROM dbo.spaces WHERE space_code = N'TEST-13-03-MR');
DECLARE @rq  INT = (SELECT user_id FROM dbo.users WHERE email = N'test13.requester@campus.edu');
DECLARE @st  INT = (SELECT user_id FROM dbo.users WHERE email = N'test13.staff@campus.edu');
DECLARE @w3  DATETIME2;
DECLARE @pb3 INT;
SELECT TOP 1 @pb3 = booking_id, @w3 = requested_start_time FROM dbo.bookings WHERE space_id = @s3 AND status = 'pending';
DECLARE @w3_start DATETIME2 = DATEADD(minute, 30, @w3);
DECLARE @w3_end   DATETIME2 = DATEADD(hour, 1, @w3_start);

IF @pb3 IS NULL
    THROW 53031, N'Task 13 c03: PB3 missing.', 1;

DECLARE @bk INT, @ok BIT, @rc INT, @msg NVARCHAR(500);
WAITFOR DELAY '00:00:02';

-- Submit overlapping M3 -> escalation already committed -> BR4 blocks.
EXEC dbo.usp_booking_instant_submit
    @space_id = @s3, @requester_id = @rq, @purpose = 'meeting',
    @expected_participants = 5,
    @requested_start_time = @w3_start,
    @requested_end_time = @w3_end,
    @booking_id = @bk OUTPUT, @instant_accepted = @ok OUTPUT,
    @result_code = @rc OUTPUT, @message = @msg OUTPUT;
IF @rc = 51002
    PRINT 'PASS c03-B: instant submit rc=51002 (BR4: OOS overlap).';
ELSE
    PRINT 'FAIL c03-B: expected 51002, got rc=' + ISNULL(CAST(@rc AS VARCHAR(5)),'null');

-- T4: PB3 untouched (still pending — escalation does no booking DML).
DECLARE @st3 VARCHAR(50) = (SELECT status FROM dbo.bookings WHERE booking_id = @pb3);
IF @st3 = 'pending'
    PRINT 'PASS c03-B: PB3 still pending (escalation performs no booking DML, DD1).';
ELSE
    PRINT 'FAIL c03-B: PB3 status = ' + ISNULL(@st3,'null') + ' (should be pending).';

-- T4 tail: approval attempt -> 51002 (BR4 on the approval path).
EXEC dbo.usp_booking_approve
    @booking_id = @pb3, @approver_id = @st, @decision = 'approved',
    @decision_note = N'c03 T4 check', @result_code = @rc OUTPUT, @message = @msg OUTPUT;
IF @rc = 51002
    PRINT 'PASS c03-B: approve(PB3) rc=51002 (BR4 on the W2 path).';
ELSE
    PRINT 'FAIL c03-B: expected approve 51002, got rc=' + ISNULL(CAST(@rc AS VARCHAR(5)),'null');

PRINT 'c03-B: done (fixture left as-is: PB3 pending, M3 advisory-restored in A).';