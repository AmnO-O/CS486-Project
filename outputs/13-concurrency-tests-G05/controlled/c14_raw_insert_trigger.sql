SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
-- ============================================================
-- T13 CONTROLLED c14 (planFix §4.4 — NEW non-optional test case)
-- Insert-time ack trigger on the RAW-DML path.
--
-- The schema trigger trg_bookings_insert_advisory_acknowledgements
-- (Task 10 rev 6) is the trigger's stated primary purpose (planFix R5):
-- guaranteed acks for booking rows written OUTSIDE the Task 12
-- procedures (ad-hoc DBA fixes, app bugs, future insert paths).
--
-- This single-session test proves:
--   1) a raw INSERT INTO dbo.bookings overlapping an active advisory
--      materializes ack rows IMMEDIATELY — count == number of
--      overlapping active advisories (same predicate the trigger uses;
--      R6 complement of trg_booking_advisory_ack_validate);
--   2) all acks attributed to the requester (acknowledged_by);
--   3) the composite UQ (booking_id, maintenance_id) is never
--      double-inserted (a duplicate insert would rollback the raw
--      INSERT and @bk14 would be lost);
--   4) the raw booking stays 'pending' (no auto-approval side effect).
--
-- Self-cleaning: deletes its own booking (cascades acks) and ticket.
-- Uses S7 at day +800 — beyond every other scenario window (max +760).
-- ============================================================
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @s7 INT = (SELECT space_id FROM dbo.spaces WHERE space_code = N'TEST-13-07-MR');
DECLARE @rq INT = (SELECT user_id FROM dbo.users WHERE email = N'test13.requester@campus.edu');
DECLARE @wc14 DATETIME2 = DATEADD(day, 800, SYSDATETIME());
DECLARE @st14_adv DATETIME2 = DATEADD(hour, -1, @wc14);

IF @s7 IS NULL OR @rq IS NULL
    THROW 53051, N'Task 13 c14: S7/RQ fixture missing.', 1;

-- 1) Seed an advisory ticket TC14 on S7 starting 1 h before the raw
--    insert window (advisory path of usp_maintenance_report — no lock).
DECLARE @m14 INT, @rc INT, @msg NVARCHAR(500);
EXEC dbo.usp_maintenance_report
    @space_id = @s7, @reporter_id = @rq,
    @problem_description = N'TEST-13 advisory TC14',
    @start_time = @st14_adv, @impact_level = 'advisory',
    @maintenance_id = @m14 OUTPUT, @result_code = @rc OUTPUT, @message = @msg OUTPUT;
IF @rc = 0 AND @m14 IS NOT NULL
    PRINT 'PASS c14-1: advisory TC14 seeded (rc=0).';
ELSE
    PRINT 'FAIL c14-1: expected rc=0, got rc=' + ISNULL(CAST(@rc AS VARCHAR(5)),'null')
        + ' msg=' + ISNULL(@msg,'null');

-- 2) RAW INSERT (bypasses the procedures — the trigger's territory).
--    Window [wc14, wc14+2h] overlaps TC14 (start = wc14-1h, completion NULL).
DECLARE @st14 DATETIME2 = @wc14;
DECLARE @en14 DATETIME2 = DATEADD(hour, 2, @wc14);
DECLARE @bk14 INT;
INSERT INTO dbo.bookings
    (space_id, requester_id, requested_start_time, requested_end_time,
     purpose, expected_participants, status)
VALUES
    (@s7, @rq, @st14, @en14, 'meeting', 10, 'pending');
SET @bk14 = SCOPE_IDENTITY();
PRINT 'c14-2: raw pending booking ' + CAST(@bk14 AS VARCHAR(12)) + ' inserted.';

-- 3) Acks materialized by the trigger, immediately:
--    expected = overlapping active advisories (dynamic predicate count).
DECLARE @expected INT = (SELECT COUNT(*)
    FROM dbo.maintenance m
    WHERE m.space_id = @s7 AND m.is_deleted = 0
      AND m.status IN ('open','in_progress') AND m.impact_level = 'advisory'
      AND m.start_time < @en14
      AND (m.completion_time IS NULL OR m.completion_time > @st14));
DECLARE @actual INT = (SELECT COUNT(*) FROM dbo.booking_advisory_acknowledgement
                       WHERE booking_id = @bk14);
DECLARE @by_rq INT = (SELECT COUNT(*) FROM dbo.booking_advisory_acknowledgement
                      WHERE booking_id = @bk14 AND acknowledged_by = @rq);
IF @expected >= 1 AND @actual = @expected AND @by_rq = @actual
    PRINT 'PASS c14-3: trigger materialized ' + CAST(@actual AS VARCHAR(5))
        + ' ack row(s) at raw insert (expected ' + CAST(@expected AS VARCHAR(5))
        + ', all attributed to requester).';
ELSE
    PRINT 'FAIL c14-3: expected=' + CAST(@expected AS VARCHAR(5))
        + ' actual=' + CAST(@actual AS VARCHAR(5))
        + ' by_requester=' + CAST(@by_rq AS VARCHAR(5));

-- 4) UQ correctness: a second insert of the same (booking, maintenance)
--    pair would violate UQ_booking_advisory_ack_booking_maintenance and
--    rollback the raw INSERT — reaching this line proves no double-insert.
IF @bk14 IS NOT NULL
    PRINT 'PASS c14-4: raw insert committed — composite UQ never double-inserted.';
ELSE
    PRINT 'FAIL c14-4: booking id missing (insert rolled back?).';

-- 5) Status stayed 'pending' (raw insert wrote it; no approval followed).
DECLARE @st VARCHAR(50) = (SELECT status FROM dbo.bookings WHERE booking_id = @bk14);
IF @st = 'pending'
    PRINT 'PASS c14-5: status stays pending (no approval row written).';
ELSE
    PRINT 'FAIL c14-5: status = ' + ISNULL(@st,'null');

-- Cleanup: booking delete cascades acks; maintenance delete cascades
-- history + any remaining acks (FK ON DELETE CASCADE on both sides).
IF @bk14 IS NOT NULL DELETE FROM dbo.bookings WHERE booking_id = @bk14;
IF @m14 IS NOT NULL DELETE FROM dbo.maintenance WHERE maintenance_id = @m14;
PRINT 'c14: cleanup done.';