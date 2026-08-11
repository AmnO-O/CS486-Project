USE CampusSpaceDB;
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
-- ============================================================
-- T13 CONTROLLED c11 (T11) — soft-gate fallback (single session)
-- Task 12: usp_booking_instant_submit with a purpose NOT in
-- space_type_allowed_purpose for this space type ('lecture' is not
-- allowed for meeting_room): result 0, @instant_accepted = 0, the
-- booking stays 'pending', and NO auto-approval row is created.
-- (v2.6: this is the only soft gate — no duration cap exists.)
-- ============================================================
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @s6 INT = (SELECT space_id FROM dbo.spaces WHERE space_code = N'TEST-13-06-MR');
DECLARE @rq INT = (SELECT user_id FROM dbo.users WHERE email = N'test13.requester@campus.edu');
DECLARE @w6 DATETIME2 = DATEADD(day, 700, SYSDATETIME());
DECLARE @w6_end DATETIME2 = DATEADD(hour, 2, @w6);
DECLARE @bk INT, @ok BIT, @rc INT, @msg NVARCHAR(500);

EXEC dbo.usp_booking_instant_submit
    @space_id = @s6, @requester_id = @rq, @purpose = 'lecture',   -- not allowed for meeting_room
    @expected_participants = 10,
    @requested_start_time = @w6, @requested_end_time = @w6_end,
    @booking_id = @bk OUTPUT, @instant_accepted = @ok OUTPUT,
    @result_code = @rc OUTPUT, @message = @msg OUTPUT;

IF @rc = 0 AND @ok = 0
    PRINT 'PASS c11: rc=0, @instant_accepted=0 (soft gate -> fallback).';
ELSE
    PRINT 'FAIL c11: expected rc=0 instant=0, got rc=' + ISNULL(CAST(@rc AS VARCHAR(5)),'null')
        + ' instant=' + ISNULL(CAST(@ok AS VARCHAR(1)),'null');

DECLARE @st VARCHAR(50) = (SELECT status FROM dbo.bookings WHERE booking_id = @bk);
DECLARE @ap INT = (SELECT COUNT(*) FROM dbo.booking_approvals WHERE booking_id = @bk);
IF @st = 'pending' AND @ap = 0
    PRINT 'PASS c11: booking stays pending with NO auto-approval row.';
ELSE
    PRINT 'FAIL c11: status=' + ISNULL(@st,'null') + ' approvals=' + CAST(@ap AS VARCHAR(5));

-- IF @bk IS NOT NULL AND EXISTS (SELECT 1 FROM dbo.bookings WHERE booking_id = @bk)
--     DELETE FROM dbo.bookings WHERE booking_id = @bk;
-- PRINT 'c11: cleanup done.';