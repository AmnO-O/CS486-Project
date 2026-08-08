-- ============================================================
-- T13 CONTROLLED c09 (K5/T9) — ticket creation vs instant submit
-- Task 12: usp_maintenance_report vs usp_booking_instant_submit.
-- TWO DETERMINISTIC ORDERS (completion_time stays NULL, so an OOS
-- ticket covers every later window; each order is therefore isolated):
--
--   Order-1 (ticket wins): A reports OOS on S5 -> rc=0; B's instant
--     submit inside T1's window -> 51002 (BR4). A then closes T1
--     (fixture recycle) so order-2 runs on clean state.
--
--   Order-2 (submit wins): B's instant submit confirms FIRST (rc=0,
--     instant=1) on T2's future window; only then A creates T2 over
--     that window -> T2 creation rc=0 (ticket creation performs NO
--     booking DML — DD1-style: the confirmed booking is untouched and
--     stays confirmed, and NO ack row exists for it — the report #4
--     escalation-scoped ack join is what matters, not ticket creation).
-- ============================================================
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @s5 INT = (SELECT space_id FROM dbo.spaces WHERE space_code = N'TEST-13-05-MR');
DECLARE @rq INT = (SELECT user_id FROM dbo.users WHERE email = N'test13.requester@campus.edu');
DECLARE @w5 DATETIME2 = DATEADD(day, 680, SYSDATETIME())   -- W5 = +680 days
                  , @w5b DATETIME2 = DATEADD(hour, 2, @w5); -- order-2 window

DECLARE @tk INT, @rc INT, @msg NVARCHAR(500);

-- Order-1: OOS ticket on S1 at W1-1h, covering W1..W5+2h (NULL completion).
EXEC dbo.usp_maintenance_report
    @space_id = @s5, @reporter_id = @rq,
    @problem_description = N'c09 order-1 OOS ticket',
    @start_time = DATEADD(hour, -1, @w5), @impact_level = 'out-of-service',
    @maintenance_id = @tk OUTPUT, @result_code = @rc OUTPUT, @message = @msg OUTPUT;
IF @rc = 0 AND @tk IS NOT NULL
    PRINT 'PASS c09-A: order-1 ticket rc=0 (maintenance_id=' + CAST(@tk AS VARCHAR(12)) + ').';
ELSE
    PRINT 'FAIL c09-A: expected rc=0, got rc=' + ISNULL(CAST(@rc AS VARCHAR(5)),'null');

-- Cleanup T1 -> frees every future window (NULL completion).
WAITFOR DELAY '00:00:06';
DELETE FROM dbo.maintenance WHERE maintenance_id = @tk;
PRINT 'c09-A: order-1 ticket deleted (fixture for order-2 clean).';

-- Order-2: B confirms its booking at ~+8 s (W5b window); only then
-- create a ticket over that same window (rc must stay 0; the confirmed
-- booking is untouched — ticket creation does NO booking DML).
WAITFOR DELAY '00:00:04';
EXEC dbo.usp_maintenance_report
    @space_id = @s5, @reporter_id = @rq,
    @problem_description = N'c09 order-2 OOS ticket',
    @start_time = @w5b, @impact_level = 'out-of-service',
    @maintenance_id = @tk OUTPUT, @result_code = @rc OUTPUT, @message = @msg OUTPUT;
IF @rc = 0
    PRINT 'PASS c09-A: order-2 ticket rc=0 (ticket creation does no booking DML).';
ELSE
    PRINT 'FAIL c09-A: expected rc=0, got rc=' + ISNULL(CAST(@rc AS VARCHAR(5)),'null');

-- Wait for B's submit-then-verify phase, then close the fixture.
WAITFOR DELAY '00:00:11';
IF @tk IS NOT NULL AND EXISTS (SELECT 1 FROM dbo.maintenance WHERE maintenance_id = @tk)
    DELETE FROM dbo.maintenance WHERE maintenance_id = @tk;
PRINT 'c09-A: cleanup done.';