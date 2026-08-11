USE CampusSpaceDB;
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
-- ============================================================
-- T13 CONTROLLED c09 session B (K5/T9)
-- Order-1: instant submit overlapping A's order-1 ticket (created at
--          ~+0 s, start W5-1h, NULL completion) -> 51002 (BR4).
-- Order-2: A deletes T1 at ~+6 s; on the now-clean window B confirms
--          first (~+8 s) -> rc=0/instant=1 (submit-wins). A's T2
--          (~+10 s) then lands over the confirmed booking: rc=0
--          (ticket creation does no booking DML), and the booking
--          carries zero ack rows (acks are written only on the
--          submit/approve paths, never by report #4).
-- ============================================================
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @s5 INT = (SELECT space_id FROM dbo.spaces WHERE space_code = N'TEST-13-05-MR');
DECLARE @rq INT = (SELECT user_id FROM dbo.users WHERE email = N'test13.requester@campus.edu');
DECLARE @w5 DATETIME2 = DATEADD(day, 680, SYSDATETIME());
DECLARE @w5_s1 DATETIME2 = DATEADD(minute, 30, @w5);
DECLARE @w5_e1 DATETIME2 = DATEADD(hour, 1, @w5_s1);
DECLARE @w5_s2 DATETIME2 = DATEADD(hour, 2, @w5);
DECLARE @w5_e2 DATETIME2 = DATEADD(hour, 3, @w5);
DECLARE @bk INT, @ok BIT, @rc INT, @msg NVARCHAR(500);

-- Order-1: overlapping A's T1 window.
WAITFOR DELAY '00:00:02';
EXEC dbo.usp_booking_instant_submit
    @space_id = @s5, @requester_id = @rq, @purpose = 'meeting',
    @expected_participants = 5,
    @requested_start_time = @w5_s1,
    @requested_end_time = @w5_e1,
    @booking_id = @bk OUTPUT, @instant_accepted = @ok OUTPUT,
    @result_code = @rc OUTPUT, @message = @msg OUTPUT;
IF @rc = 51002
    PRINT 'PASS c09-B: order-1 submit rc=51002 (BR4 against ticket).';
ELSE
    PRINT 'FAIL c09-B: expected 51002, got rc=' + ISNULL(CAST(@rc AS VARCHAR(5)),'null');

-- Order-2: A deletes T1 at ~+6 s, T2 arrives only at ~+10 s.
WAITFOR DELAY '00:00:06';
EXEC dbo.usp_booking_instant_submit
    @space_id = @s5, @requester_id = @rq, @purpose = 'meeting',
    @expected_participants = 10,
    @requested_start_time = @w5_s2,
    @requested_end_time = @w5_e2,
    @booking_id = @bk OUTPUT, @instant_accepted = @ok OUTPUT,
    @result_code = @rc OUTPUT, @message = @msg OUTPUT;
IF @rc = 0 AND @ok = 1
    PRINT 'PASS c09-B: order-2 submit rc=0/instant=1 (submit-wins branch).';
ELSE
    PRINT 'FAIL c09-B: expected 0/1, got rc=' + ISNULL(CAST(@rc AS VARCHAR(5)),'null')
        + ' instant=' + ISNULL(CAST(@ok AS VARCHAR(1)),'null');

-- A's T2 created at ~+10 s; then verify no booking DML and zero acks.
WAITFOR DELAY '00:00:05';
DECLARE @st VARCHAR(50) = (SELECT status FROM dbo.bookings WHERE booking_id = @bk);
DECLARE @ack_cnt INT = (SELECT COUNT(*) FROM dbo.booking_advisory_acknowledgement
                        WHERE booking_id = @bk);
IF @st = 'approved'
    PRINT 'PASS c09-B: booking still approved (ticket creation did no DML).';
ELSE
    PRINT 'FAIL c09-B: booking status = ' + ISNULL(@st,'null');
IF @ack_cnt = 0
    PRINT 'PASS c09-B: zero ack rows on the submit-wins booking.';
ELSE
    PRINT 'FAIL c09-B: ' + CAST(@ack_cnt AS VARCHAR(5)) + ' ack row(s) present.';

-- Cleanup: remove the confirmed booking (approvals cascade).
IF @bk IS NOT NULL AND EXISTS (SELECT 1 FROM dbo.bookings WHERE booking_id = @bk)
    DELETE FROM dbo.bookings WHERE booking_id = @bk;
PRINT 'c09-B: cleanup done.';