SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
-- ============================================================
-- T13 BASELINE b03 session B (K3 — no concurrency control)
-- Inserts the confirmed booking overlapping M3 while M3 is still
-- advisory (deterministic submit-first; A polls for this row, then
-- escalates). The BR4 trigger reads M3 as advisory -> the INSERT
-- succeeds and commits.
--
-- NOTE (planFix R7/R10): this raw INSERT never touches
-- booking_approvals, so the 51004 approvals gate
-- (trg_booking_approvals_check_space) never fires on this path — there
-- is no latent 51004 for the ack trigger to fix. The only side effect
-- of the rev 6 insert trigger here is one inert ack row for (this
-- booking, M3) when M3 still reads 'advisory' at insert; it cascades
-- away with this row's deletion. b03 assertions are ack-independent
-- (verified: no ack queries anywhere in baseline/).
-- ============================================================
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @s3 INT = (SELECT space_id FROM dbo.spaces WHERE space_code = N'TEST-13-03-MR');
DECLARE @rq INT = (SELECT user_id FROM dbo.users WHERE email = N'test13.requester@campus.edu');
DECLARE @w3 DATETIME2 = (SELECT start_time FROM dbo.maintenance WHERE space_id = @s3 AND problem_description = N'TEST-13 advisory M3');
DECLARE @b3 INT, @r_err INT = 0;

BEGIN TRY
    INSERT INTO dbo.bookings
        (space_id, requester_id, requested_start_time, requested_end_time,
         purpose, expected_participants, status)
    VALUES
        (@s3, @rq, DATEADD(minute, 30, @w3), DATEADD(hour, 1, DATEADD(minute, 30, @w3)),
         'meeting', 10, 'approved');
    SET @b3 = SCOPE_IDENTITY();
    PRINT 'b03-B: confirmed booking ' + CAST(@b3 AS VARCHAR(12)) + ' committed while M3 was still advisory.';
END TRY
BEGIN CATCH
    SET @r_err = ERROR_NUMBER();
    PRINT 'b03-B: insert rejected by raw BR4 trigger (error ' + CAST(@r_err AS VARCHAR(10))
        + ' — backstop family, no business code).';
END CATCH

WAITFOR DELAY '00:00:06';   -- let A escalate and commit first

DECLARE @q INT = (SELECT COUNT(*)
    FROM dbo.bookings b
    INNER JOIN dbo.maintenance m ON m.space_id = b.space_id
    WHERE b.space_id = @s3 AND b.is_deleted = 0 AND m.is_deleted = 0
      AND b.status IN ('approved','checked_in','completed')
      AND m.status IN ('open','in_progress') AND m.impact_level = 'out-of-service'
      AND m.start_time < b.requested_end_time
      AND (m.completion_time IS NULL OR m.completion_time > b.requested_start_time));
IF @q > 0
    PRINT 'PASS b03-B: Q_VIOLATION >= 1 (' + CAST(@q AS VARCHAR(10)) + ').';
ELSE IF @r_err <> 0
    PRINT 'b03-B: insert backstopped by raw trigger (no control).';
ELSE
    PRINT 'b03-B: measured 0 (recording).';

-- Cleanup: remove own booking.
IF @b3 IS NOT NULL AND EXISTS (SELECT 1 FROM dbo.bookings WHERE booking_id = @b3)
    DELETE FROM dbo.bookings WHERE booking_id = @b3;
PRINT 'b03-B: cleanup done.';