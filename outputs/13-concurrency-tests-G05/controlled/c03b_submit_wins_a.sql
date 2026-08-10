SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
-- ============================================================
-- T13 CONTROLLED c03b (T3b — K3 submit-wins order)
-- Task 12: usp_booking_instant_submit then usp_maintenance_set_impact_level.
-- Deterministic sequence (fixed schedule, >= 12 s margins between
-- critical events to absorb ~6 s process-spawn skew):
--   B: instant submit #1 @+2 s on M3's space (still advisory) -> rc=0,
--      instant=1;
--   A: escalates M3 @+15 s -> rc=0 (escalation performs no booking DML —
--      DD1: the confirmed booking is left in place);
--   B: submit #2 @+22 s on a later window (M3 still escalated) -> 51002
--      (BR4 now active);
--   A: restores M3 to advisory @+45 s (after B's #2 landed).
-- ============================================================
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @s3  INT = (SELECT space_id FROM dbo.spaces WHERE space_code = N'TEST-13-03-MR');
DECLARE @m3  INT = (SELECT maintenance_id FROM dbo.maintenance
                    WHERE space_id = @s3 AND problem_description = N'TEST-13 advisory M3');
IF @m3 IS NULL
    THROW 53032, N'Task 13 c03b: M3 missing.', 1;

DECLARE @rc INT, @msg NVARCHAR(500);

-- B confirms its booking at ~+2 s while M3 is advisory; wait for it
-- (margin: B @2+6s=8s < escalation @15-6s=9s worst case).
WAITFOR DELAY '00:00:15';
DECLARE @st INT = (SELECT TOP 1 user_id FROM dbo.users WHERE email=N'test13.staff@campus.edu');
EXEC sys.sp_set_session_context N'current_user_id', @st;
EXEC dbo.usp_maintenance_set_impact_level
    @maintenance_id = @m3, @new_impact_level = 'out-of-service',
    @reason = N'c03b submit-wins', @result_code = @rc OUTPUT, @message = @msg OUTPUT;
EXEC sys.sp_set_session_context N'current_user_id', NULL;

IF @rc = 0
    PRINT 'PASS c03b-A: escalation rc=0 after the booking was confirmed (DD1: no booking DML).';
ELSE
    PRINT 'FAIL c03b-A: expected rc=0, got rc=' + ISNULL(CAST(@rc AS VARCHAR(5)),'null');

-- Hold the escalated state until B's submit #2 (~+22 s) has observed
-- BR4, then restore the fixture for later scenarios.
WAITFOR DELAY '00:00:30';
UPDATE dbo.maintenance SET impact_level = 'advisory' WHERE maintenance_id = @m3;
PRINT 'c03b-A: M3 restored to advisory.';