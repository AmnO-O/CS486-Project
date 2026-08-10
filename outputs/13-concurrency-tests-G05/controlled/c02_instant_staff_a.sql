SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
-- ============================================================
-- T13 CONTROLLED c02 (K2) — instant submit vs staff approval
-- Task 12: usp_booking_instant_submit vs usp_booking_approve,
-- both orders, deterministic sequencing. FIXED SCHEDULE with >= 12 s
-- margins between critical events (process-spawn skew observed up to
-- ~6 s; margins absorb it so the asserted codes never depend on
-- arrival order):
--   B submit W2A @+36 s  -> 51003 (A approved PB2a @+12 s first);
--   B submit W2B @+40 s  -> rc=0, instant=1 (submit-wins order);
--   A approve PB2b @+60 s -> 51003 (BR1 vs B's confirmed W2B booking).
-- ============================================================
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @s2   INT = (SELECT space_id FROM dbo.spaces WHERE space_code = N'TEST-13-02-MR');
DECLARE @st   INT = (SELECT user_id FROM dbo.users WHERE email = N'test13.staff@campus.edu');

DECLARE @pb2a INT, @pb2b INT;
SELECT TOP 1 @pb2a = booking_id FROM dbo.bookings WHERE space_id = @s2 AND status = 'pending' ORDER BY requested_start_time ASC;
SELECT TOP 1 @pb2b = booking_id FROM dbo.bookings WHERE space_id = @s2 AND status = 'pending' AND booking_id <> @pb2a ORDER BY requested_start_time ASC;

IF @pb2a IS NULL OR @pb2b IS NULL
    THROW 53020, N'Task 13 c02: PB2a/PB2b fixture missing (run 00_setup.sql).', 1;

DECLARE @rc INT, @msg NVARCHAR(500);

-- Order-1: approve PB2a first; B is submitting at ~+36 s (12 s margin).
WAITFOR DELAY '00:00:12';
EXEC dbo.usp_booking_approve
    @booking_id = @pb2a, @approver_id = @st, @decision = 'approved',
    @rejection_reason = NULL, @decision_note = N'T13 c02 order-1',
    @result_code = @rc OUTPUT, @message = @msg OUTPUT;
IF @rc = 0
    PRINT 'PASS c02-A: approve(PB2a) rc=0 (order-1 approve wins).';
ELSE
    PRINT 'FAIL c02-A: expected rc=0, got rc=' + ISNULL(CAST(@rc AS VARCHAR(5)),'null');

-- Wait for B: W2A submit (expect 51003 at +36 s) and W2B submit (expect
-- 0 at +40 s), both with margins against the +60 s approval below.
WAITFOR DELAY '00:00:48';

-- Order-2: B confirmed an instant covering W2B -> this approval must fail BR1.
EXEC dbo.usp_booking_approve
    @booking_id = @pb2b, @approver_id = @st, @decision = 'approved',
    @decision_note = N'T13 c02 order-2',
    @result_code = @rc OUTPUT, @message = @msg OUTPUT;
IF @rc = 51003
    PRINT 'PASS c02-A: approve(PB2b) rc=51003 (conflict with confirmed instant).';
ELSE
    PRINT 'FAIL c02-A: expected 51003, got rc=' + ISNULL(CAST(@rc AS VARCHAR(5)),'null')
        + ' msg=' + ISNULL(@msg,'null');

-- Cleanup: restore fixture (approval rows and created instant bookings removed, bookings back to pending).
DELETE FROM dbo.booking_approvals WHERE booking_id IN (@pb2a, @pb2b);
DELETE FROM dbo.bookings WHERE space_id = @s2 AND status = 'approved';
UPDATE dbo.bookings SET status = 'pending' WHERE booking_id IN (@pb2a, @pb2b);
PRINT 'c02-A: fixture restored.';