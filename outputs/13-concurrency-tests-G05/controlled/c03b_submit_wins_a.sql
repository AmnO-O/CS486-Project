USE CampusSpaceDB;
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
-- ============================================================
-- T13 CONTROLLED c03b (T3b — K3 submit-wins order)
-- Task 12: usp_booking_instant_submit then usp_maintenance_set_impact_level.
-- Deterministic sequence:
--   B: instant submit overlapping M3 (still advisory) -> rc=0, instant=1;
--   A: then escalates M3 -> rc=0 (escalation performs no booking DML —
--      DD1: the confirmed booking is left in place);
--   B: any later submit overlapping M3 -> 51002 (BR4 now active).
-- ============================================================
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @s3  INT = (SELECT space_id FROM dbo.spaces WHERE space_code = N'TEST-13-03-MR');
DECLARE @m3  INT = (SELECT maintenance_id FROM dbo.maintenance
                    WHERE space_id = @s3 AND problem_description = N'TEST-13 advisory M3');
IF @m3 IS NULL
    THROW 53032, N'Task 13 c03b: M3 missing.', 1;

DECLARE @rc INT, @msg NVARCHAR(500);

-- B confirms its booking at ~+2 s while M3 is advisory; wait for it.
WAITFOR DELAY '00:00:04';
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

-- Hold the escalated state long enough for B's submit #2 (~+6 s) to
-- observe BR4, then restore the fixture for later scenarios.
WAITFOR DELAY '00:00:10';
-- UPDATE dbo.maintenance SET impact_level = 'advisory' WHERE maintenance_id = @m3;
-- PRINT 'c03b-A: M3 restored to advisory.';