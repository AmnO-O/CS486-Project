USE CampusSpaceDB;
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
-- ============================================================
-- T13 BASELINE b01 session B (K1 — no concurrency control)
-- Inserts a CONFIRMED booking overlapping A's still-uncommitted row.
-- The overlap trigger reads committed rows only and therefore passes;
-- B commits. Both sessions end with overlapping confirmed bookings.
-- ============================================================
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @s1 INT = (SELECT space_id FROM dbo.spaces WHERE space_code = N'TEST-13-01-MR');
DECLARE @rq INT = (SELECT user_id FROM dbo.users WHERE email = N'test13.requester@campus.edu');
DECLARE @w1 DATETIME2 = DATEADD(day, 600, SYSDATETIME());
DECLARE @b_b INT;

-- Give session A time to begin its transaction, then insert an
-- overlapping (chestré start_time = W1+30min, 1h) confirmed booking.
WAITFOR DELAY '00:00:02';

INSERT INTO dbo.bookings
    (space_id, requester_id, requested_start_time, requested_end_time,
     purpose, expected_participants, status)
VALUES
    (@s1, @rq, DATEADD(minute, 30, @w1), DATEADD(hour, 1, DATEADD(minute, 30, @w1)),
     'meeting', 10, 'approved');
SET @b_b = SCOPE_IDENTITY();
PRINT 'b01-B: committed overlapping confirmed booking ' + CAST(@b_b AS VARCHAR(12)) + '.';

-- Wait until A has committed as well, then measure the corrupted state.
WAITFOR DELAY '00:00:05';
DECLARE @q INT = (SELECT COUNT(*)
    FROM dbo.bookings a
    INNER JOIN dbo.bookings b ON a.space_id = b.space_id AND a.booking_id < b.booking_id
    WHERE a.space_id = @s1 AND a.is_deleted = 0 AND b.is_deleted = 0
      AND a.status IN ('approved','checked_in','completed')
      AND b.status IN ('approved','checked_in','completed')
      AND a.requested_start_time < b.requested_end_time
      AND a.requested_end_time > b.requested_start_time);

IF @q = 0
    PRINT 'FAIL b01-B: expected overlap violation, found none (Q_BR1=0).';
ELSE
    PRINT 'PASS b01-B: VIOLATION-OBSERVED (overlapping confirmed bookings, Q_BR1=' + CAST(@q AS VARCHAR(10)) + ').';

-- Cleanup left to session A (which deletes both overlapping bookings by window).
-- PRINT 'b01-B: cleanup left to session A.';