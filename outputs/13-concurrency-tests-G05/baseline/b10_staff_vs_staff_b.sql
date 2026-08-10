SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
-- ============================================================
-- T13 BASELINE b10 session B (staff vs staff, no control)
-- Approves PB10b (overlaps PB10a) as the second writer of the
-- autonomous race: A's approval (of PB10a) fires ~0-2 s earlier.
-- If B's re-check still sees PB10a pending (A's approval uncommitted)
-- both commits -> overlapping confirmed bookings; if A committed
-- first, the raw trigger backstops B - that raw-engine-error family
-- is the baseline's PASS too. TRY/CATCH keeps the runner clean.
-- ============================================================
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @s8    INT = (SELECT space_id FROM dbo.spaces WHERE space_code = N'TEST-13-08-MR');
DECLARE @st    INT = (SELECT user_id FROM dbo.users WHERE email = N'test13.staff@campus.edu');
DECLARE @pb10b INT = (SELECT TOP 1 booking_id FROM dbo.bookings
                      WHERE space_id = @s8 AND status = 'pending'
                      ORDER BY requested_start_time DESC);

IF @pb10b IS NULL
    THROW 53010, N'Task 13 b10: PB10b fixture missing.', 1;

WAITFOR DELAY '00:00:02';   -- A's approval is in-flight/committed by now

BEGIN TRY
    INSERT INTO dbo.booking_approvals (booking_id, approver_id, decision_time, decision)
    VALUES (@pb10b, @st, SYSDATETIME(), 'approved');
    PRINT 'b10-B: PB10b approval committed (re-check saw PB10a still pending - no control).';
END TRY
BEGIN CATCH
    PRINT 'PASS b10-B: RAW-ERROR family - overlapping approve rejected by trigger (error '
        + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ') with no Task 12 business code.';
END CATCH

WAITFOR DELAY '00:00:06';   -- let A's approval commit too

DECLARE @q INT = (SELECT COUNT(*)
    FROM dbo.bookings a
    INNER JOIN dbo.bookings b ON a.space_id = b.space_id AND a.booking_id < b.booking_id
    WHERE a.space_id = @s8 AND a.is_deleted = 0 AND b.is_deleted = 0
      AND a.status = 'approved' AND b.status = 'approved'
      AND a.requested_start_time < b.requested_end_time
      AND a.requested_end_time > b.requested_start_time);

IF @q > 0
    PRINT 'PASS b10-B: VIOLATION-OBSERVED (Q_BR1=' + CAST(@q AS VARCHAR(10)) + ').';
ELSE
    PRINT 'b10-B: no overlapping approved pair persisted (collapsed race; backstop path).';

PRINT 'b10-B: cleanup left to A (fixture restore).';