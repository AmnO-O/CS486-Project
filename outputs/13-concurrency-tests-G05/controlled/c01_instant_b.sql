SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
-- ============================================================
-- T13 CONTROLLED c01 session B (K1) — mirror of c01-A
-- Same race, same assertion set: outcome {0, 51003} either way is
-- PASS for this side; the pair-level assertions live in each side's
-- trailing audit (exactly one winner + zero overlap).
-- ============================================================
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @s1 INT = (SELECT space_id FROM dbo.spaces WHERE space_code = N'TEST-13-01-MR');
DECLARE @rq INT = (SELECT user_id FROM dbo.users WHERE email = N'test13.requester@campus.edu');
DECLARE @w1 DATETIME2 = DATEADD(day, 600, SYSDATETIME());
DECLARE @w1_start DATETIME2 = DATEADD(minute, 30, @w1);
DECLARE @w1_end DATETIME2 = DATEADD(hour, 1, DATEADD(minute, 30, @w1));
DECLARE @bk INT, @ok BIT, @rc INT, @msg NVARCHAR(500);

EXEC dbo.usp_booking_instant_submit
    @space_id = @s1, @requester_id = @rq, @purpose = 'meeting',
    @expected_participants = 10,
    @requested_start_time = @w1_start,
    @requested_end_time = @w1_end,
    @booking_id = @bk OUTPUT, @instant_accepted = @ok OUTPUT,
    @result_code = @rc OUTPUT, @message = @msg OUTPUT;

IF @rc = 0 AND @ok = 1
    PRINT 'PASS c01-B: instant approved (winner side).';
ELSE IF @rc = 51003
    PRINT 'PASS c01-B: conflict 51003 (loser side) as designed.';
ELSE
    PRINT 'FAIL c01-B: unexpected rc=' + ISNULL(CAST(@rc AS VARCHAR(5)),'null')
        + ' msg=' + ISNULL(@msg,'null');

WAITFOR DELAY '00:00:04';
DECLARE @wins INT = (SELECT COUNT(*) FROM dbo.bookings WHERE space_id = @s1 AND status = 'approved');
DECLARE @ovl INT = (SELECT COUNT(*)
    FROM dbo.bookings a
    INNER JOIN dbo.bookings b ON a.space_id = b.space_id AND a.booking_id < b.booking_id
    WHERE a.space_id = @s1 AND a.is_deleted = 0 AND b.is_deleted = 0
      AND a.status IN ('approved','checked_in','completed')
      AND b.status IN ('approved','checked_in','completed')
      AND a.requested_start_time < b.requested_end_time
      AND a.requested_end_time > b.requested_start_time);

IF @wins = 1
    PRINT 'PASS c01-B: exactly one booking confirmed on the window (race serialized).';
ELSE
    PRINT 'FAIL c01-B: expected exactly 1 confirmed booking, found ' + CAST(@wins AS VARCHAR(5));
IF @ovl = 0
    PRINT 'PASS c01-B: audit Q_BR1 = 0.';
ELSE
    PRINT 'FAIL c01-B: overlapping confirmed bookings remain (' + CAST(@ovl AS VARCHAR(5)) + ').';

WAITFOR DELAY '00:00:03';
IF @bk IS NOT NULL AND EXISTS (SELECT 1 FROM dbo.bookings WHERE booking_id = @bk)
    DELETE FROM dbo.bookings WHERE booking_id = @bk;
PRINT 'c01-B: cleanup done.';