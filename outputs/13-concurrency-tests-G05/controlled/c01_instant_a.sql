SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
-- ============================================================
-- T13 CONTROLLED c01 (K1) — instant submit vs instant submit
-- Task 12: usp_booking_instant_submit with per-space applock.
-- Two sessions race on the SAME window; exactly ONE succeeds with
-- rc=0/instant=1, the loser returns 51003. Which session wins is not
-- asserted (that would couple to arrival order); the SET is: one 0 +
-- one 51003, and the final audit shows zero overlapping confirmed
-- bookings (Q_BR1=0).
-- ============================================================
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @s1  INT = (SELECT space_id FROM dbo.spaces WHERE space_code = N'TEST-13-01-MR');
DECLARE @rq  INT = (SELECT user_id FROM dbo.users WHERE email = N'test13.requester@campus.edu');
DECLARE @w1  DATETIME2 = DATEADD(day, 600, SYSDATETIME());
DECLARE @w1_end DATETIME2 = DATEADD(hour, 2, @w1);
DECLARE @bk  INT, @ok  BIT, @rc  INT, @msg NVARCHAR(500);

-- Both sessions fire nearly simultaneously (runner launches pairs in
-- parallel; this script has no artificial delay for the race itself).
-- A loser that waits on the applock receives sp_getapplock return 1
-- (granted after wait) — Task 12 rev5 treats 0 and 1 both as success,
-- so the loser re-checks BR1 under the lock and returns 51003 cleanly.
BEGIN TRY
    EXEC dbo.usp_booking_instant_submit
        @space_id = @s1, @requester_id = @rq, @purpose = 'meeting',
        @expected_participants = 10,
        @requested_start_time = @w1, @requested_end_time = @w1_end,
        @booking_id = @bk OUTPUT, @instant_accepted = @ok OUTPUT,
        @result_code = @rc OUTPUT, @message = @msg OUTPUT;
END TRY
BEGIN CATCH
    PRINT 'FAIL c01-A: entry point threw (error ' + CAST(ERROR_NUMBER() AS VARCHAR(10))
        + ') — Task 12 applock-code defect; msg=' + ISNULL(ERROR_MESSAGE(),'null');
END CATCH

IF @rc = 0 AND @ok = 1
    PRINT 'PASS c01-A: instant approved (winner side).';
ELSE IF @rc = 51003
    PRINT 'PASS c01-A: conflict 51003 (loser side) as designed.';
ELSE
    PRINT 'FAIL c01-A: unexpected rc=' + ISNULL(CAST(@rc AS VARCHAR(5)),'null')
        + ' msg=' + ISNULL(@msg,'null');

-- Let the other session finish, then audit the pair outcome.
WAITFOR DELAY '00:00:04';
DECLARE @wins INT = (SELECT COUNT(*) FROM dbo.bookings
                     WHERE space_id = @s1 AND status = 'approved');
DECLARE @ovl INT = (SELECT COUNT(*)
    FROM dbo.bookings a
    INNER JOIN dbo.bookings b ON a.space_id = b.space_id AND a.booking_id < b.booking_id
    WHERE a.space_id = @s1 AND a.is_deleted = 0 AND b.is_deleted = 0
      AND a.status IN ('approved','checked_in','completed')
      AND b.status IN ('approved','checked_in','completed')
      AND a.requested_start_time < b.requested_end_time
      AND a.requested_end_time > b.requested_start_time);

IF @wins = 1
    PRINT 'PASS c01-A: exactly one booking confirmed on the window (race serialized).';
ELSE
    PRINT 'FAIL c01-A: expected exactly 1 confirmed booking, found ' + CAST(@wins AS VARCHAR(5));
IF @ovl = 0
    PRINT 'PASS c01-A: audit Q_BR1 = 0 (no overlapping confirmed bookings).';
ELSE
    PRINT 'FAIL c01-A: overlapping confirmed bookings remain (' + CAST(@ovl AS VARCHAR(5)) + ').';

-- Cleanup: remove this session's booking if it won.
IF @bk IS NOT NULL AND EXISTS (SELECT 1 FROM dbo.bookings WHERE booking_id = @bk)
    DELETE FROM dbo.bookings WHERE booking_id = @bk;
PRINT 'c01-A: cleanup done.';