SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
-- ============================================================
-- T13 CONTROLLED c12 (T12) — soft-gate fallback vs instant overlap
-- Single session, deterministic:
--   1) fallback submit (purpose not allowed) -> rc=0, instant=0, pending;
--   2) instant submit (allowed purpose) on the SAME window -> rc=0,
--      instant=1 (pending rows are not confirmed, BR1 unaffected);
--   3) later staff approval of the PENDING one -> 51003 (BR1).
-- ============================================================
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @s7 INT = (SELECT space_id FROM dbo.spaces WHERE space_code = N'TEST-13-07-MR');
DECLARE @rq INT = (SELECT user_id FROM dbo.users WHERE email = N'test13.requester@campus.edu');
DECLARE @st INT = (SELECT user_id FROM dbo.users WHERE email = N'test13.staff@campus.edu');
DECLARE @w7 DATETIME2 = DATEADD(day, 720, SYSDATETIME());
DECLARE @w7_e1 DATETIME2 = DATEADD(hour, 2, @w7);
DECLARE @w7_s2 DATETIME2 = DATEADD(minute, 30, @w7);
DECLARE @w7_e2 DATETIME2 = DATEADD(hour, 1, @w7_s2);

DECLARE @pf INT, @okf BIT, @rcf INT, @msgf NVARCHAR(500);
DECLARE @pi INT, @oki BIT, @rci INT, @msgi NVARCHAR(500);
DECLARE @rc2 INT, @msg2 NVARCHAR(500);

-- 1) fallback
EXEC dbo.usp_booking_instant_submit
    @space_id = @s7, @requester_id = @rq, @purpose = 'lecture',
    @expected_participants = 10,
    @requested_start_time = @w7, @requested_end_time = @w7_e1,
    @booking_id = @pf OUTPUT, @instant_accepted = @okf OUTPUT,
    @result_code = @rcf OUTPUT, @message = @msgf OUTPUT;
IF @rcf = 0 AND @okf = 0
    PRINT 'PASS c12-1: fallback rc=0, instant=0 (pending).';
ELSE
    PRINT 'FAIL c12-1: expected 0/0, got rc=' + ISNULL(CAST(@rcf AS VARCHAR(5)),'null');

-- 2) instant on the same window
EXEC dbo.usp_booking_instant_submit
    @space_id = @s7, @requester_id = @rq, @purpose = 'meeting',
    @expected_participants = 10,
    @requested_start_time = @w7_s2,
    @requested_end_time = @w7_e2,
    @booking_id = @pi OUTPUT, @instant_accepted = @oki OUTPUT,
    @result_code = @rci OUTPUT, @message = @msgi OUTPUT;
IF @rci = 0 AND @oki = 1
    PRINT 'PASS c12-2: instant rc=0, instant=1 (pending does not block).';
ELSE
    PRINT 'FAIL c12-2: expected 0/1, got rc=' + ISNULL(CAST(@rci AS VARCHAR(5)),'null');

-- 3) approve the fallback -> overlap with the confirmed instant
EXEC dbo.usp_booking_approve
    @booking_id = @pf, @approver_id = @st, @decision = 'approved',
    @decision_note = N'c12 later', @result_code = @rc2 OUTPUT, @message = @msg2 OUTPUT;
IF @rc2 = 51003
    PRINT 'PASS c12-3: approve(fallback) rc=51003 (BR1).';
ELSE
    PRINT 'FAIL c12-3: expected 51003, got rc=' + ISNULL(CAST(@rc2 AS VARCHAR(5)),'null');

-- Cleanup both created bookings (approvals cascade).
IF @pf IS NOT NULL AND EXISTS (SELECT 1 FROM dbo.bookings WHERE booking_id = @pf)
    DELETE FROM dbo.bookings WHERE booking_id = @pf;
IF @pi IS NOT NULL AND EXISTS (SELECT 1 FROM dbo.bookings WHERE booking_id = @pi)
    DELETE FROM dbo.bookings WHERE booking_id = @pi;
PRINT 'c12: cleanup done.';