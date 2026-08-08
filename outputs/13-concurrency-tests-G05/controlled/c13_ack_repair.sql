-- ============================================================
-- T13 CONTROLLED c13 (T13) — advisory ack repair inside W2
-- Single session: PB13 (pending) overlaps an active advisory M9 whose
-- ack rows were NEVER inserted. Approving PB13 through Task 12's
-- usp_booking_approve must:
--   1) return rc=0 (not 51004) — W2 repairs the missing ack set
--      inside the critical section (acknowledged_by = requester);
--   2) leave the ack rows present for (PB13, M9).
-- ============================================================
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @s9  INT = (SELECT space_id FROM dbo.spaces WHERE space_code = N'TEST-13-09-MR');
DECLARE @st  INT = (SELECT user_id FROM dbo.users WHERE email = N'test13.staff@campus.edu');
DECLARE @w9  DATETIME2 = DATEADD(day, 760, SYSDATETIME());
DECLARE @pb13 INT = (SELECT booking_id FROM dbo.bookings WHERE space_id = @s9 AND requested_start_time = @w9 AND status = 'pending');
DECLARE @m9  INT = (SELECT maintenance_id FROM dbo.maintenance
                    WHERE space_id = @s9 AND problem_description = N'TEST-13 advisory M9');

IF @pb13 IS NULL OR @m9 IS NULL
    THROW 53050, N'Task 13 c13: PB13/M9 fixture missing.', 1;

-- Sanity: no ack rows exist yet (the fixture deliberately omitted them).
DECLARE @before INT = (SELECT COUNT(*) FROM dbo.booking_advisory_acknowledgement
                       WHERE booking_id = @pb13 AND maintenance_id = @m9);
IF @before > 0
    PRINT 'c13: note: ack rows already present (' + CAST(@before AS VARCHAR(5)) + ') — still assert approve+repair.';

DECLARE @rc INT, @msg NVARCHAR(500);
EXEC dbo.usp_booking_approve
    @booking_id = @pb13, @approver_id = @st, @decision = 'approved',
    @decision_note = N'c13 ack repair', @result_code = @rc OUTPUT, @message = @msg OUTPUT;

IF @rc = 0
    PRINT 'PASS c13: approve rc=0 (W2 repaired the missing acks, no 51004).';
ELSE
    PRINT 'FAIL c13: expected rc=0, got rc=' + ISNULL(CAST(@rc AS VARCHAR(5)),'null')
        + ' msg=' + ISNULL(@msg,'null');

-- Post-state: acks now exist, attributed to the requester.
DECLARE @rq INT = (SELECT requester_id FROM dbo.bookings WHERE booking_id = @pb13);
DECLARE @after INT = (SELECT COUNT(*) FROM dbo.booking_advisory_acknowledgement
                      WHERE booking_id = @pb13 AND maintenance_id = @m9);
DECLARE @by_rq INT = (SELECT COUNT(*) FROM dbo.booking_advisory_acknowledgement
                      WHERE booking_id = @pb13 AND maintenance_id = @m9 AND acknowledged_by = @rq);
IF @after >= 1 AND @by_rq = @after
    PRINT 'PASS c13: ack row(s) exist for (PB13, M9), acknowledged_by = requester (' + CAST(@after AS VARCHAR(5)) + ' row(s)).';
ELSE
    PRINT 'FAIL c13: acks=' + CAST(@after AS VARCHAR(5)) + ' by_requester=' + CAST(@by_rq AS VARCHAR(5));

-- Cleanup: booking delete cascades approvals+acks; maintenance stays.
DELETE FROM dbo.bookings WHERE booking_id = @pb13;
PRINT 'c13: cleanup done.';