SET SHOWPLAN_XML ON;
GO

DECLARE @space_id   INT       = 205111;
DECLARE @slot_start DATETIME2 = '2021-09-06T11:00:00';
DECLARE @slot_end   DATETIME2 = '2021-09-06T12:00:00';

SELECT
    b.booking_id,
    b.space_id,
    s.space_code,
    s.space_name,
    b.requester_id,
    u.full_name AS requester_name,
    u.email AS requester_email,
    b.status,
    b.purpose,
    b.requested_start_time,
    b.requested_end_time
FROM dbo.bookings b
INNER JOIN dbo.spaces s
    ON s.space_id = b.space_id
INNER JOIN dbo.users u
    ON u.user_id = b.requester_id
WHERE b.space_id = @space_id
  AND b.is_deleted = 0
  AND b.status IN ('approved', 'checked_in', 'completed')
  AND @slot_end > @slot_start
  AND @slot_start < b.requested_end_time
  AND @slot_end > b.requested_start_time
ORDER BY b.requested_start_time ASC, b.booking_id ASC;
GO

SET SHOWPLAN_XML OFF;
GO
