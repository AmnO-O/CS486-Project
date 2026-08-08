-- ============================================================
-- CS486 G05 - Campus Space Management System
-- Task 16: Analytical Queries (Phase 2)
-- Target: SQL Server 2019+ (T-SQL)
--
-- Prerequisites: Tasks 05 and 10 schema, plus Task 14 data.
-- U4 convention: Semester 1 [September 1, February 1), Semester 2
-- [February 1, July 1), summer excluded. Confirmed statuses are
-- approved, checked_in, and completed.
-- ============================================================

-- ============================================================
-- Task 16 Query Q1: Booking Conflict Check
-- ============================================================
-- task16-query-id: Q1
-- target-users: application layer, facility_staff
-- business-question: Which confirmed bookings conflict with a proposed slot?
-- why-useful: Read hint before submission or approval. Task 12 locked write
--   procedures remain the concurrency-safe authority for BR1/NR6.
-- ============================================================

-- Caller contract: @slot_end must be strictly greater than @slot_start.
DECLARE @space_id   INT       = 205010;
DECLARE @slot_start DATETIME2 = '2024-09-16T10:00:00';
DECLARE @slot_end   DATETIME2 = '2024-09-16T12:00:00';

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

-- ============================================================
-- Task 16 Query Q2: Available Space Finder
-- ============================================================
-- task16-query-id: Q2
-- target-users: student, lecturer, teaching_assistant, facility_staff, facility_manager
-- business-question: Which spaces meet the requested capacity and every required
--   facility, with no confirmed-booking or out-of-service-maintenance conflict?
-- why-useful: Supports Phase 2 Report #3. Advisory maintenance does not block a
--   result; availability is derived directly from time-overlap predicates.
--   The @required_facilities table variable must contain all requested facilities;
--   relational division returns only spaces that have every one.
-- ============================================================

DECLARE @slot_start       DATETIME2 = '2024-09-16T10:00:00';
DECLARE @slot_end         DATETIME2 = '2024-09-16T12:00:00';
DECLARE @minimum_capacity INT       = 20;

-- Add one row for every required facility. Seed with at least two to reflect
-- a realistic multi-facility search (e.g. a lecture room needing a projector
-- AND a whiteboard). Leave the table empty to require none.
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

-- ============================================================
-- Task 16 Query Q3: Total Approved Booking Hours per Space
-- ============================================================
-- task16-query-id: Q3
-- target-users: facility_manager
-- business-question: How many confirmed booking hours did each space have in a semester?
-- why-useful: Supports Phase 2 Report #1. Durations are clipped to the
--   half-open semester window under U4.
-- ============================================================

-- Example: Semester 1 AY2024-2025 = [2024-09-01, 2025-02-01).
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

-- ============================================================
-- Task 16 Query Q5: Confirmed Bookings Affected by Escalation
-- ============================================================
-- task16-query-id: Q5
-- target-users: facility_manager
-- business-question: Which already-confirmed bookings were affected when advisory
--   maintenance was escalated to out-of-service?
-- why-useful: Supports Phase 2 Report #4 and NR4 with requester details and a
--   follow-up action. This query is read-only and does not mutate bookings.
-- ============================================================

WITH escalation_events AS (
    SELECT
        mih.history_id,
        mih.maintenance_id,
        mih.changed_at AS escalation_time,
        mih.changed_by,
        mih.prior_level,
        mih.new_level,
        mih.reason AS escalation_reason,
        m.space_id,
        m.problem_description,
        m.status AS maintenance_status,
        m.start_time AS maintenance_start_time,
        m.completion_time AS maintenance_end_time
    FROM dbo.maintenance_impact_history mih
    INNER JOIN dbo.maintenance m
        ON m.maintenance_id = mih.maintenance_id
    WHERE mih.prior_level = 'advisory'
      AND mih.new_level = 'out-of-service'
      AND m.is_deleted = 0
)
SELECT
    ee.history_id,
    ee.escalation_time,
    escalator.full_name AS escalated_by,
    ee.prior_level,
    ee.new_level,
    ee.escalation_reason,
    ee.maintenance_id,
    ee.problem_description,
    ee.maintenance_status,
    ee.maintenance_start_time,
    ee.maintenance_end_time,
    s.space_id,
    s.space_code,
    s.space_name,
    s.space_type,
    s.building,
    s.floor,
    s.room_number,
    b.booking_id,
    b.requested_start_time,
    b.requested_end_time,
    b.purpose,
    b.expected_participants,
    b.status AS booking_status,
    requester.user_id AS requester_id,
    requester.full_name AS requester_name,
    requester.email AS requester_email,
    requester.phone_number AS requester_phone,
    baa.acknowledged_at,
    acknowledger.full_name AS acknowledged_by,
    ROUND(
        DATEDIFF_BIG(
            SECOND,
            CASE
                WHEN b.requested_start_time < ee.maintenance_start_time
                    THEN ee.maintenance_start_time
                ELSE b.requested_start_time
            END,
            CASE
                WHEN b.requested_end_time > COALESCE(ee.maintenance_end_time, b.requested_end_time)
                    THEN COALESCE(ee.maintenance_end_time, b.requested_end_time)
                ELSE b.requested_end_time
            END
        ) / 3600.0,
        2
    ) AS overlap_hours,
    CASE
        WHEN b.status = 'approved'
            THEN N'Contact requester: booking remains approved after escalation'
        WHEN b.status = 'checked_in'
            THEN N'Contact requester: session checked in after escalation'
        ELSE N'Contact requester: completed booking affected by escalation'
    END AS recommended_action
FROM escalation_events ee
INNER JOIN dbo.booking_approvals ba
    ON ba.decision = 'approved'
   AND ba.decision_time <= ee.escalation_time
INNER JOIN dbo.bookings b
    ON b.booking_id = ba.booking_id
   AND b.space_id = ee.space_id
   AND b.is_deleted = 0
   AND b.status IN ('approved', 'checked_in', 'completed')
   AND b.requested_start_time < COALESCE(ee.maintenance_end_time, CONVERT(DATETIME2, '9999-12-31T23:59:59'))
   AND b.requested_end_time > ee.maintenance_start_time
INNER JOIN dbo.booking_advisory_acknowledgement baa
    ON baa.booking_id = b.booking_id
   AND baa.maintenance_id = ee.maintenance_id
INNER JOIN dbo.spaces s
    ON s.space_id = ee.space_id
INNER JOIN dbo.users requester
    ON requester.user_id = b.requester_id
INNER JOIN dbo.users escalator
    ON escalator.user_id = ee.changed_by
INNER JOIN dbo.users acknowledger
    ON acknowledger.user_id = baa.acknowledged_by
ORDER BY ee.escalation_time DESC, b.requested_start_time ASC, b.booking_id ASC;
GO