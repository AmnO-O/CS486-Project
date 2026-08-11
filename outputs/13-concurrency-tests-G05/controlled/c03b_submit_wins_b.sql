USE CampusSpaceDB;
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
-- ============================================================
-- T13 CONTROLLED c03b session B (T3b — K3 submit-wins order)
-- B confirms while M3 is advisory; then, after A escalates, any
-- further submit on M3's window is blocked with 51002.
-- ============================================================
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @s3 INT = (SELECT space_id FROM dbo.spaces WHERE space_code = N'TEST-13-03-MR');
DECLARE @rq INT = (SELECT user_id FROM dbo.users WHERE email = N'test13.requester@campus.edu');
DECLARE @w3 DATETIME2 = DATEADD(day, 640, SYSDATETIME());
DECLARE @w3_s1 DATETIME2 = DATEADD(hour, 4, @w3);
DECLARE @w3_e1 DATETIME2 = DATEADD(hour, 5, @w3);
DECLARE @w3_s2 DATETIME2 = DATEADD(hour, 6, @w3);
DECLARE @w3_e2 DATETIME2 = DATEADD(hour, 7, @w3);
DECLARE @b1 INT, @o1 BIT, @r1 INT, @m1 NVARCHAR(500);
DECLARE @b2 INT, @o2 BIT, @r2 INT, @m2 NVARCHAR(500);

-- Submit #1 while M3 is still advisory (A escalates at ~+4 s).
WAITFOR DELAY '00:00:02';
EXEC dbo.usp_booking_instant_submit
    @space_id = @s3, @requester_id = @rq, @purpose = 'meeting',
    @expected_participants = 5,
    @requested_start_time = @w3_s1,
    @requested_end_time = @w3_e1,
    @booking_id = @b1 OUTPUT, @instant_accepted = @o1 OUTPUT,
    @result_code = @r1 OUTPUT, @message = @m1 OUTPUT;
IF @r1 = 0 AND @o1 = 1
    PRINT 'PASS c03b-B: submit #1 rc=0, instant=1 (M3 advisory).';
ELSE
    PRINT 'FAIL c03b-B: expected 0/1, got rc=' + ISNULL(CAST(@r1 AS VARCHAR(5)),'null');

WAITFOR DELAY '00:00:03';   -- A escalates at ~+4 s, holds OOS until +14 s

-- Submit #2 on a DIFFERENT window (M3 has no completion: overlaps all
-- later times; #1's window is taken by the confirmed booking, so BR1
-- would fire there) -> BR4 active -> 51002.
EXEC dbo.usp_booking_instant_submit
    @space_id = @s3, @requester_id = @rq, @purpose = 'meeting',
    @expected_participants = 10,
    @requested_start_time = @w3_s2,
    @requested_end_time = @w3_e2,
    @booking_id = @b2 OUTPUT, @instant_accepted = @o2 OUTPUT,
    @result_code = @r2 OUTPUT, @message = @m2 OUTPUT;
IF @r2 = 51002
    PRINT 'PASS c03b-B: submit #2 rc=51002 (escalated now blocks; submit-wins order proven).';
ELSE
    PRINT 'FAIL c03b-B: expected 51002, got rc=' + ISNULL(CAST(@r2 AS VARCHAR(5)),'null');

-- Cleanup: remove the confirmed booking of order-1.
-- IF @b1 IS NOT NULL AND EXISTS (SELECT 1 FROM dbo.bookings WHERE booking_id = @b1)
--     DELETE FROM dbo.bookings WHERE booking_id = @b1;
-- PRINT 'c03b-B: cleanup done.';