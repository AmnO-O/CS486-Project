SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
-- ============================================================
-- T13 CONTROLLED c05 session B (T5/T7) — app lock timeout + retry
-- Against session A holding the space app lock 20 s:
--   1st usp_maintenance_report attempt -> 51005 (5 s timeout).
--   Then wait past A's release and RETRY -> rc=0 (T7).
-- ============================================================
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @s4  INT = (SELECT space_id FROM dbo.spaces WHERE space_code = N'TEST-13-04-MR');
DECLARE @rq  INT = (SELECT user_id FROM dbo.users WHERE email = N'test13.requester@campus.edu');
DECLARE @w4  DATETIME2 = DATEADD(day, 660, SYSDATETIME());
DECLARE @w4_st1 DATETIME2 = DATEADD(hour, 1, @w4);
DECLARE @w4_st2 DATETIME2 = DATEADD(hour, 2, @w4);
DECLARE @tk  INT, @rc  INT, @msg NVARCHAR(500);

WAITFOR DELAY '00:00:01';    -- A owns the lock by now

-- First attempt: must time out with the retryable 51005.
WAITFOR DELAY '00:00:02';
EXEC dbo.usp_maintenance_report
    @space_id = @s4, @reporter_id = @rq,
    @problem_description = N'c05 OOS ticket',
    @start_time = @w4_st1, @impact_level = 'out-of-service',
    @maintenance_id = @tk OUTPUT, @result_code = @rc OUTPUT, @message = @msg OUTPUT;

IF @rc = 51005
    PRINT 'PASS c05-B: first report rc=51005 (app lock timeout, retryable).';
ELSE
    PRINT 'FAIL c05-B: expected 51005, got rc=' + ISNULL(CAST(@rc AS VARCHAR(5)),'null');

WAITFOR DELAY '00:00:22';   -- A releases at ~20 s; lock free again

-- Retry (T7): should succeed.
EXEC dbo.usp_maintenance_report
    @space_id = @s4, @reporter_id = @rq,
    @problem_description = N'c05 retry OOS ticket',
    @start_time = @w4_st2, @impact_level = 'out-of-service',
    @maintenance_id = @tk OUTPUT, @result_code = @rc OUTPUT, @message = @msg OUTPUT;

IF @rc = 0 AND @tk IS NOT NULL
    PRINT 'PASS c05-B: retry rc=0, ticket ' + CAST(@tk AS VARCHAR(12)) + ' created (T7).';
ELSE
    PRINT 'FAIL c05-B: retry: expected rc=0, got rc=' + ISNULL(CAST(@rc AS VARCHAR(5)),'null');

-- Cleanup: remove the ticket created in this session.
IF @tk IS NOT NULL AND EXISTS (SELECT 1 FROM dbo.maintenance WHERE maintenance_id = @tk)
    DELETE FROM dbo.maintenance WHERE maintenance_id = @tk;
PRINT 'c05-B: cleanup done.';