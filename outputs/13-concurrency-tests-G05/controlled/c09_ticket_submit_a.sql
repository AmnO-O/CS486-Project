-- ============================================================
-- T13 CONTROLLED c09 (K5/T9) — ticket creation vs instant submit
-- Task 12: usp_maintenance_report vs usp_booking_instant_submit.
-- TWO ORDERS (deterministic):
--   Order-1 (ticket first): A reports OOS on S5 -> rc=0; B's instant
--     submit overlapping -> 51002 (BR4).
--   Order-2 (submit first): B's instant on W5b succeeds (rc=0);
--     A's later OOS ticket on the same window still rc=0 (the booking
--     is NOT cancelled; it is simply out of report #4's scope — the
--     K5 submit-wins branch, Task 11 §7.4 scope note).
-- ============================================================
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @s5 INT = (SELECT space_id FROM dbo.spaces WHERE space_code = N'TEST-13-05-MR');
DECLARE @rq INT = (SELECT user_id FROM dbo.users WHERE email = N'test13.requester@campus.edu');
DECLARE @w5 DATETIME2 = DATEADD(day, 680, SYSDATETIME());

DECLARE @tk INT, @rc INT, @msg NVARCHAR(500);

-- Order-1: OOS ticket FIRST on W5.
EXEC dbo.usp_maintenance_report
    @space_id = @s5, @reporter_id = @rq,
    @problem_description = N'c09 order-1 OOS ticket',
    @start_time = DATEADD(hour, -1, @w5), @impact_level = 'out-of-service',
    @maintenance_id = @tk OUTPUT, @result_code = @rc OUTPUT, @message = @msg OUTPUT;
IF @rc = 0 AND @tk IS NOT NULL
    PRINT 'PASS c09-A: OOS ticket rc=0 (ticket ' + CAST(@tk AS VARCHAR(12)) + ').';
ELSE
    PRINT 'FAIL c09-A: expected rc=0, got rc=' + ISNULL(CAST(@rc AS VARCHAR(5)),'null');

-- Order-2: ticket on W5b (submit-first window) AFTER B's booking
-- confirmed there; creating the ticket stays rc=0 and the booking
-- is left confirmed (submit-wins semantics; affected-set note).
WAITFOR DELAY '00:00:05';   -- B's order-1 submit + order-2 booking finish inside
EXEC dbo.usp_maintenance_report
    @space_id = @s5, @reporter_id = @rq,
    @problem_description = N'c09 order-2 OOS ticket',
    @start_time = DATEADD(hour, 4, @w5), @impact_level = 'out-of-service',
    @maintenance_id = @tk OUTPUT, @result_code = @rc OUTPUT, @message = @msg OUTPUT;
IF @rc = 0
    PRINT 'PASS c09-A: order-2 ticket rc=0 (ticket coexists with the confirmed booking).';
ELSE
    PRINT 'FAIL c09-A: expected rc=0, got rc=' + ISNULL(CAST(@rc AS VARCHAR(5)),'null');

-- Cleanup: remove both tickets (booking handled in B).
DELETE FROM dbo.maintenance WHERE space_id = @s5 AND problem_description LIKE N'c09 %';
PRINT 'c09-A: cleanup done.';