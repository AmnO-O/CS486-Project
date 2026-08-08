SET SHOWPLAN_XML ON;
GO

DECLARE @semester_start DATETIME2 = '2024-09-01T00:00:00';
DECLARE @semester_end   DATETIME2 = '2025-02-01T00:00:00';

WITH semester_bookings AS (
    SELECT
        b.booking_id,
        b.space_id,
        CASE
            WHEN b.requested_start_time < @semester_start THEN @semester_start
            ELSE b.requested_start_time
        END AS effective_start_time,
        CASE
            WHEN b.requested_end_time > @semester_end THEN @semester_end
            ELSE b.requested_end_time
        END AS effective_end_time
    FROM dbo.bookings b
    WHERE b.is_deleted = 0
      AND b.status IN ('approved', 'checked_in', 'completed')
      AND @semester_end > @semester_start
      AND b.requested_start_time < @semester_end
      AND b.requested_end_time > @semester_start
)
SELECT
    s.space_id,
    s.space_code,
    s.space_name,
    s.space_type,
    s.building,
    s.floor,
    s.room_number,
    s.capacity,
    COUNT(sb.booking_id) AS confirmed_booking_count,
    COALESCE(
        ROUND(SUM(DATEDIFF_BIG(SECOND, sb.effective_start_time, sb.effective_end_time) / 3600.0), 2),
        0.00
    ) AS total_hours_in_semester,
    COALESCE(
        ROUND(
            SUM(DATEDIFF_BIG(SECOND, sb.effective_start_time, sb.effective_end_time) / 3600.0)
            / NULLIF(COUNT(sb.booking_id), 0),
            2
        ),
        0.00
    ) AS average_hours_per_booking
FROM dbo.spaces s
LEFT JOIN semester_bookings sb
    ON sb.space_id = s.space_id
GROUP BY
    s.space_id,
    s.space_code,
    s.space_name,
    s.space_type,
    s.building,
    s.floor,
    s.room_number,
    s.capacity
ORDER BY total_hours_in_semester DESC, s.space_code ASC;
GO

SET SHOWPLAN_XML OFF;
GO
