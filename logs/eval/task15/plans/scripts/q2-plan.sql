SET SHOWPLAN_XML ON;
GO

DECLARE @slot_start       DATETIME2 = '2024-09-16T10:00:00';
DECLARE @slot_end         DATETIME2 = '2024-09-16T12:00:00';
DECLARE @minimum_capacity INT       = 20;

DECLARE @required_facilities TABLE (
    facility_name NVARCHAR(255) NOT NULL PRIMARY KEY
);
INSERT INTO @required_facilities (facility_name) VALUES (N'T14 Projector');
INSERT INTO @required_facilities (facility_name) VALUES (N'T14 Whiteboard');

WITH booking_conflicts AS (
    SELECT DISTINCT b.space_id
    FROM dbo.bookings b
    WHERE b.is_deleted = 0
      AND b.status IN ('approved', 'checked_in', 'completed')
      AND @slot_start < b.requested_end_time
      AND @slot_end > b.requested_start_time
),
maintenance_conflicts AS (
    SELECT DISTINCT m.space_id
    FROM dbo.maintenance m
    WHERE m.is_deleted = 0
      AND m.status IN ('open', 'in_progress')
      AND m.impact_level = 'out-of-service'
      AND m.start_time < @slot_end
      AND (m.completion_time IS NULL OR m.completion_time > @slot_start)
),
spaces_with_all_required_facilities AS (
    SELECT s2.space_id
    FROM dbo.spaces s2
    WHERE NOT EXISTS (
        SELECT 1
        FROM @required_facilities rf
        WHERE NOT EXISTS (
            SELECT 1
            FROM dbo.space_facilities sf2
            INNER JOIN dbo.facilities f2
                ON f2.facility_id = sf2.facility_id
            WHERE sf2.space_id = s2.space_id
              AND f2.name = rf.facility_name
        )
    )
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
    s.current_status AS status_hint,
    @slot_start AS requested_start_time,
    @slot_end AS requested_end_time,
    STRING_AGG(
        CONCAT(f.name, N' x', COALESCE(CONVERT(NVARCHAR(20), sf.quantity), N'1')),
        N', '
    ) WITHIN GROUP (ORDER BY f.name) AS facility_summary,
    N'Available' AS availability_status
FROM dbo.spaces s
LEFT JOIN dbo.space_facilities sf
    ON sf.space_id = s.space_id
LEFT JOIN dbo.facilities f
    ON f.facility_id = sf.facility_id
LEFT JOIN booking_conflicts bc
    ON bc.space_id = s.space_id
LEFT JOIN maintenance_conflicts mc
    ON mc.space_id = s.space_id
WHERE @slot_end > @slot_start
  AND s.capacity >= @minimum_capacity
  AND s.current_status NOT IN ('retired', 'temporarily_closed')
  AND bc.space_id IS NULL
  AND mc.space_id IS NULL
  AND EXISTS (
      SELECT 1
      FROM spaces_with_all_required_facilities sr
      WHERE sr.space_id = s.space_id
  )
GROUP BY
    s.space_id,
    s.space_code,
    s.space_name,
    s.space_type,
    s.building,
    s.floor,
    s.room_number,
    s.capacity,
    s.current_status
ORDER BY s.capacity ASC, s.space_code ASC;
GO

SET SHOWPLAN_XML OFF;
GO
