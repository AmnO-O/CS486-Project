SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
-- ============================================================
-- T13 CONTROLLED c03 (K3/DD1/T4) — escalation vs in-flight submit
-- Task 12: usp_maintenance_set_impact_level / usp_booking_instant_submit.
-- Order-1 (escalate wins): A escalates M3 to out-of-service (rc=0);
-- B's instant submit overlapping M3 is then blocked -> 51002.
-- T4: the pending PB3 stays untouched (escalation performs NO booking
-- DML); a later approval of PB3 is blocked 51002 (BR4).
-- ============================================================
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @s3  INT = (SELECT space_id FROM dbo.spaces WHERE space_code = N'TEST-13-03-MR');
DECLARE @m3  INT = (SELECT maintenance_id FROM dbo.maintenance
                    WHERE space_id = @s3 AND problem_description = N'TEST-13 advisory M3');
IF @m3 IS NULL
    THROW 53030, N'Task 13 c03: M3 missing.', 1;

DECLARE @rc INT, @msg NVARCHAR(500);

DECLARE @st INT = (SELECT TOP 1 user_id FROM dbo.users WHERE email=N'test13.staff@campus.edu');
EXEC sys.sp_set_session_context N'current_user_id', @st;
EXEC dbo.usp_maintenance_set_impact_level
    @maintenance_id = @m3, @new_impact_level = 'out-of-service',
    @reason = N'c03 escalate-wins', @result_code = @rc OUTPUT, @message = @msg OUTPUT;
EXEC sys.sp_set_session_context N'current_user_id', NULL;

IF @rc = 0
    PRINT 'PASS c03-A: escalation rc=0 (M3 -> out-of-service).';
ELSE
    PRINT 'FAIL c03-A: expected rc=0, got rc=' + ISNULL(CAST(@rc AS VARCHAR(5)),'null');

WAITFOR DELAY '00:00:04';   -- B submits during the escalated window

-- Order-1 done; verify T4 later inside B. Restore fixture.
UPDATE dbo.maintenance SET impact_level = 'advisory' WHERE maintenance_id = @m3;
PRINT 'c03: M3 restored to advisory (fixture next in c03-B).';