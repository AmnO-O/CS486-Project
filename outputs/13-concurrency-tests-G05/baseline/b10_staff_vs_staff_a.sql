SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
-- ============================================================
-- T13 BASELINE b10 (T10 shape — staff vs staff, no control)
-- Two raw approvals of the two OVERLAPPING pending bookings on the
-- same space (PB10a & PB10b), raw SQL, autonomous race:
--   A and B each approve ONE pending (autocommit, no hold);
--   each approval's re-check runs inside the OTHER's uncommitted
--   window (or after its commit when the arrival collapses).
-- PASS families (both valid for this no-control twin, never a Task 12
-- business code):
--   1) both approvals commit while the other was still pending ->
--      overlapping confirmed bookings (Q_BR1 >= 1);
--   2) arrival collapses -> the second approval's raw trigger
--      backstops (raw engine error family) - no violation persists.
-- NOTE (why no held transaction): the approval INSERT flips
-- bookings.status via trg_booking_approvals_decision inside the
-- writer's transaction; a staged hold would block the second
-- session's re-check on the X-locked row and force the collapse.
-- Fixture lookup uses TOP-1 pending ordering (NOT time equality).
-- ============================================================
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @s8    INT = (SELECT space_id FROM dbo.spaces WHERE space_code = N'TEST-13-08-MR');
DECLARE @st    INT = (SELECT user_id FROM dbo.users WHERE email = N'test13.staff@campus.edu');
DECLARE @pb10a INT = (SELECT TOP 1 booking_id FROM dbo.bookings
                      WHERE space_id = @s8 AND status = 'pending'
                      ORDER BY requested_start_time ASC);
DECLARE @pb10b INT = (SELECT TOP 1 booking_id FROM dbo.bookings
                      WHERE space_id = @s8 AND status = 'pending' AND booking_id <> @pb10a
                      ORDER BY requested_start_time ASC);

IF @pb10a IS NULL OR @pb10b IS NULL
    THROW 53010, N'Task 13 b10: PB10a/PB10b fixture missing (run 00_setup.sql).', 1;

-- A approves PB10a immediately (autocommit); B fires ~2 s later.
BEGIN TRY
    INSERT INTO dbo.booking_approvals (booking_id, approver_id, decision_time, decision)
    VALUES (@pb10a, @st, SYSDATETIME(), 'approved');
    PRINT 'b10-A: approval of PB10a committed (decision trigger set status=approved).';
END TRY
BEGIN CATCH
    PRINT 'b10-A: approval of PB10a rejected by raw trigger (error '
        + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ' - backstop family, no business code).';
END CATCH

WAITFOR DELAY '00:00:06';   -- let B's approval land and commit

DECLARE @q INT = (SELECT COUNT(*)
    FROM dbo.bookings a
    INNER JOIN dbo.bookings b ON a.space_id = b.space_id AND a.booking_id < b.booking_id
    WHERE a.space_id = @s8 AND a.is_deleted = 0 AND b.is_deleted = 0
      AND a.status = 'approved' AND b.status = 'approved'
      AND a.requested_start_time < b.requested_end_time
      AND a.requested_end_time > b.requested_start_time);

IF @q > 0
    PRINT 'PASS b10-A: VIOLATION-OBSERVED (staff-vs-staff overlapping approvals, Q_BR1=' + CAST(@q AS VARCHAR(10)) + ').';
ELSE
    PRINT 'b10-A: 0 overlapping approved pairs recorded this run (second approval backstopped - collapsed race, no control).';

-- Restore fixture: A clears BOTH bookings' approval rows and reverts
-- statuses (idempotent; B also touches only its own row).
DELETE FROM dbo.booking_approvals WHERE booking_id IN (@pb10a, @pb10b);
UPDATE dbo.bookings SET status = 'pending' WHERE booking_id IN (@pb10a, @pb10b);
PRINT 'b10-A: fixture restored.';