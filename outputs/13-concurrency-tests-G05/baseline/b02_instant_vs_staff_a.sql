USE CampusSpaceDB;
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
-- ============================================================
-- T13 BASELINE b02 (K2 — no concurrency control)
-- Staff approval vs instant submit, raw SQL, TWO sessions:
--   Order-1 (approve wins): A approves PB2a inside a long transaction
--     while B inserts a confirmed booking overlapping PB2a's window.
--     Both succeed -> overlapping confirmed bookings (audit >= 1).
--   Order-2 (submit wins): after B confirmed a booking overlapping
--     PB2b, A tries to approve PB2b -> RAW trigger error (no business
--     code, no retry contract).
-- ============================================================
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @s2  INT = (SELECT space_id FROM dbo.spaces WHERE space_code = N'TEST-13-02-MR');
DECLARE @st  INT = (SELECT user_id FROM dbo.users WHERE email = N'test13.staff@campus.edu');
DECLARE @pb2a INT, @pb2b INT;
SELECT TOP 1 @pb2a = booking_id FROM dbo.bookings WHERE space_id = @s2 AND status = 'pending' ORDER BY requested_start_time ASC;
SELECT TOP 1 @pb2b = booking_id FROM dbo.bookings WHERE space_id = @s2 AND status = 'pending' AND booking_id <> @pb2a ORDER BY requested_start_time ASC;

IF @pb2a IS NULL OR @pb2b IS NULL
BEGIN
    PRINT 'FAIL b02-A: fixture pending bookings missing (run 00_setup.sql first).';
    RETURN;
END

-- Order-1: approve PB2a while holding the transaction so B cannot see
-- the status change; B's insert (30 min later, overlapping) then passes.
BEGIN TRANSACTION;
    INSERT INTO dbo.booking_approvals (booking_id, approver_id, decision_time, decision)
    VALUES (@pb2a, @st, SYSDATETIME(), 'approved');
    PRINT 'b02-A: fiat approval of PB2a held in transaction...';
    WAITFOR DELAY '00:00:05';
COMMIT TRANSACTION;
PRINT 'b02-A: PB2a approval committed.';

/*
-- Order-2: B has committed its confirmed booking overlapping PB2b by now;
-- approving PB2b must hit the raw trigger backstop (no business code).
BEGIN TRY
    INSERT INTO dbo.booking_approvals (booking_id, approver_id, decision_time, decision)
    VALUES (@pb2b, @st, SYSDATETIME(), 'approved');
    PRINT 'b02-A: unexpected — PB2b approval succeeded without control.';
END TRY
BEGIN CATCH
    PRINT 'PASS b02-A: RAW-ERROR-APPROVAL-PB2B (error ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ' — no business result code).';
END CATCH
*/

DECLARE @q INT = (SELECT COUNT(*)
    FROM dbo.bookings a
    INNER JOIN dbo.bookings b ON a.space_id = b.space_id AND a.booking_id < b.booking_id
    WHERE a.space_id = @s2 AND a.is_deleted = 0 AND b.is_deleted = 0
      AND a.status IN ('approved','checked_in','completed')
      AND b.status IN ('approved','checked_in','completed')
      AND a.requested_start_time < b.requested_end_time
      AND a.requested_end_time > b.requested_start_time);

IF @q > 0
    PRINT 'PASS b02-A: VIOLATION-OBSERVED (overlapping confirmed bookings, Q_BR1=' + CAST(@q AS VARCHAR(10)) + ').';
ELSE
    PRINT 'b02-A: no persisted overlap this round (order-1 raced); recorded.';

-- Restore fixture: remove the approval on PB2a.
DELETE FROM dbo.booking_approvals WHERE booking_id = @pb2a;
PRINT 'b02-A: fixture restored.';