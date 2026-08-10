SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
-- ============================================================
-- T13 BASELINE b10 session B (staff vs staff, no control)
-- Approves PB10b (overlaps PB10a) while A's approval of PB10a is
-- still uncommitted: the re-check sees PB10a as 'pending' -> passes.
-- ============================================================
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @s8    INT = (SELECT space_id FROM dbo.spaces WHERE space_code = N'TEST-13-08-MR');
DECLARE @st    INT = (SELECT user_id FROM dbo.users WHERE email = N'test13.staff@campus.edu');
DECLARE @pb10a INT, @pb10b INT;
SELECT TOP 1 @pb10a = booking_id FROM dbo.bookings WHERE space_id = @s8 AND status = 'pending' ORDER BY requested_start_time ASC;
SELECT TOP 1 @pb10b = booking_id FROM dbo.bookings WHERE space_id = @s8 AND status = 'pending' AND booking_id <> @pb10a ORDER BY requested_start_time ASC;

IF @pb10b IS NULL
    THROW 53010, N'Task 13 b10: PB10b fixture missing.', 1;

WAITFOR DELAY '00:00:02';   -- A's approval is in-flight now

INSERT INTO dbo.booking_approvals (booking_id, approver_id, decision_time, decision)
VALUES (@pb10b, @st, SYSDATETIME(), 'approved');
PRINT 'b10-B: PB10b approved (its re-check saw PB10a still pending).';

WAITFOR DELAY '00:00:06';   -- let A commit its approval too

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
    PRINT 'b10-B: 0 overlapping approved pairs recorded this run.';

PRINT 'b10-B: cleanup left to A (fixture restore).';