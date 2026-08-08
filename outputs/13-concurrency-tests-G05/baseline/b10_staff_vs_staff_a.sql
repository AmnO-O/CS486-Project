-- ============================================================
-- T13 BASELINE b10 (T10 shape — staff vs staff, no control)
-- Two raw approvals of two DIFFERENT pending bookings with OVERLAPPING
-- windows on the same space (PB10a & PB10b), raw SQL:
--   A approves PB10a inside a held transaction;
--   B also approves PB10b (its overlap re-check reads PB10a as still
--     pending -> passes) and commits;
--   A commits.
-- Expected: both pendings become approved -> overlapping confirmed
-- bookings (Q_BR1 >= 1) — the staff-vs-staff K1 shape without a
-- serialization gate.
-- ============================================================
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @s8    INT = (SELECT space_id FROM dbo.spaces WHERE space_code = N'TEST-13-08-MR');
DECLARE @st    INT = (SELECT user_id FROM dbo.users WHERE email = N'test13.staff@campus.edu');
DECLARE @w8    DATETIME2 = DATEADD(day, 740, SYSDATETIME());
DECLARE @w8b   DATETIME2 = DATEADD(minute, 30, @w8);
DECLARE @pb10a INT = (SELECT booking_id FROM dbo.bookings WHERE space_id = @s8 AND requested_start_time = @w8  AND status = 'pending');
DECLARE @pb10b INT = (SELECT booking_id FROM dbo.bookings WHERE space_id = @s8 AND requested_start_time = @w8b AND status = 'pending');

IF @pb10a IS NULL OR @pb10b IS NULL
    THROW 53010, N'Task 13 b10: PB10a/PB10b fixture missing (run 00_setup.sql).', 1;

-- A: approve PB10a, held open so B's re-check sees it still pending.
BEGIN TRANSACTION;
    INSERT INTO dbo.booking_approvals (booking_id, approver_id, decision_time, decision)
    VALUES (@pb10a, @st, SYSDATETIME(), 'approved');
    PRINT 'b10-A: approval of PB10a held uncommitted...';
    WAITFOR DELAY '00:00:05';
COMMIT TRANSACTION;

WAITFOR DELAY '00:00:03';   -- let B's approval run second
PRINT 'b10-A: after B, PB10a is approved.';

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
    PRINT 'b10-A: 0 overlapping approved pairs recorded this run.';

-- Restore fixture: remove approval rows, revert statuses to pending.
DELETE FROM dbo.booking_approvals WHERE booking_id IN (@pb10a, @pb10b);
UPDATE dbo.bookings SET status = 'pending' WHERE booking_id IN (@pb10a, @pb10b);
PRINT 'b10-A: fixture restored.';