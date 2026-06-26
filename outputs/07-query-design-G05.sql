-- ============================================================
-- CS486 Group G05 — Campus Space Management System
-- Task 07: Query Design
-- Target: SQL Server 2019+ (T-SQL)
-- Schema: dbo (CS486_G05 database)
-- Dependencies: outputs/05-db-definition-G05.sql, outputs/06-sample-data-G05.sql
-- ============================================================

-- ============================================================
-- Query 1: Available spaces for a given time slot
-- ============================================================
-- Business question:
--   Which spaces are available for booking during a specific
--   time window with at least a given capacity?
--
-- Target user(s):
--   Lecturer, Teaching Assistant, Student, Facility Staff
--
-- Why useful:
--   Enables requesters and staff to quickly find suitable rooms
--   without manually cross-checking calendars, maintenance
--   schedules, and capacity limits.
-- ============================================================

DECLARE @slot_start    DATETIME2 = '2026-07-01 08:00:00';
DECLARE @slot_end      DATETIME2 = '2026-07-01 12:00:00';
DECLARE @min_capacity  INT       = 30;

SELECT
    s.space_code,
    s.space_name,
    s.space_type,
    s.building,
    s.floor,
    s.room_number,
    s.capacity,
    s.usage_policy
FROM [dbo].[spaces] s
WHERE s.current_status = 'available'
  AND s.capacity >= @min_capacity
  AND NOT EXISTS (
      SELECT 1
      FROM [dbo].[bookings] b
      WHERE b.space_id = s.space_id
        AND b.is_deleted = 0
        AND b.status IN ('approved', 'checked_in', 'completed')
        AND b.requested_start_time < @slot_end
        AND b.requested_end_time > @slot_start
  )
  AND NOT EXISTS (
      SELECT 1
      FROM [dbo].[maintenances] m
      WHERE m.space_id = s.space_id
        AND m.is_deleted = 0
        AND m.status IN ('open', 'in_progress')
        AND m.start_time < @slot_end
        AND (m.completion_time IS NULL OR m.completion_time > @slot_start)
  )
ORDER BY s.capacity DESC, s.space_code;
GO

-- ============================================================
-- Query 2: Currently active bookings (real-time snapshot)
-- ============================================================
-- Business question:
--   What bookings are happening right now across all spaces?
--
-- Target user(s):
--   Facility Manager, Facility Staff
--
-- Why useful:
--   Provides a live dashboard of space occupancy so facility
--   staff can monitor usage, plan walkthroughs, and respond
--   to issues in real time.
-- ============================================================

DECLARE @now DATETIME2 = GETDATE();

SELECT
    b.booking_id,
    s.space_code,
    s.space_name,
    s.building,
    s.room_number,
    u.full_name   AS requester,
    u.email       AS requester_email,
    b.purpose,
    b.expected_participants,
    b.requested_start_time,
    b.requested_end_time,
    b.status
FROM [dbo].[bookings] b
INNER JOIN [dbo].[spaces] s ON b.space_id = s.space_id
INNER JOIN [dbo].[users] u ON b.requester_id = u.user_id
WHERE b.is_deleted = 0
  AND b.status IN ('approved', 'checked_in')
  AND b.requested_start_time <= @now
  AND b.requested_end_time > @now
ORDER BY b.requested_start_time;
GO

-- ============================================================
-- Query 3: Active maintenance tickets with space details
-- ============================================================
-- Business question:
--   What are the unresolved maintenance issues, which spaces
--   are affected, and who is handling them?
--
-- Target user(s):
--   Facility Manager, Facility Staff
--
-- Why useful:
--   Gives a single view of all open/in-progress maintenance
--   across the campus, enabling workload prioritization and
--   resource allocation for the facility team.
-- ============================================================

DECLARE @building NVARCHAR(100) = NULL;  -- NULL = all buildings

SELECT
    m.maintenance_id,
    s.space_code,
    s.space_name,
    s.building,
    s.room_number,
    m.problem_description,
    m.status,
    m.start_time,
    u_reporter.full_name   AS reporter,
    u_staff.full_name      AS assigned_staff,
    DATEDIFF(DAY, m.start_time, GETDATE()) AS days_since_reported
FROM [dbo].[maintenances] m
INNER JOIN [dbo].[spaces] s ON m.space_id = s.space_id
INNER JOIN [dbo].[users] u_reporter ON m.reporter_id = u_reporter.user_id
LEFT JOIN [dbo].[users] u_staff ON m.assigned_staff_id = u_staff.user_id
WHERE m.is_deleted = 0
  AND m.status IN ('open', 'in_progress')
  AND (@building IS NULL OR s.building = @building)
ORDER BY m.status, m.start_time;
GO

-- ============================================================
-- Query 4: Space utilization analytics
-- ============================================================
-- Business question:
--   Which spaces had the highest usage (total booked hours and
--   average occupancy rate) over a given period?
--
-- Target user(s):
--   Facility Manager, Department Administrator
--
-- Why useful:
--   Identifies overused and underused spaces to guide capacity
--   planning, scheduling policy, and renovation decisions.
-- ============================================================

DECLARE @start_date DATE = '2026-06-01';
DECLARE @end_date   DATE = '2026-07-31';

SELECT
    s.space_code,
    s.space_name,
    s.space_type,
    s.building,
    s.capacity,
    COUNT(b.booking_id)                                                      AS total_bookings,
    ISNULL(SUM(DATEDIFF(HOUR, b.requested_start_time, b.requested_end_time)), 0) AS total_hours_booked,
    ISNULL(AVG(b.expected_participants * 1.0), 0)                           AS avg_expected_participants,
    CASE
        WHEN s.capacity > 0
        THEN CAST(ROUND(100.0 * AVG(CAST(b.expected_participants AS FLOAT)) / s.capacity, 1) AS DECIMAL(5,1))
        ELSE 0
    END                                                                     AS avg_utilization_pct
FROM [dbo].[spaces] s
LEFT JOIN [dbo].[bookings] b
    ON s.space_id = b.space_id
    AND b.is_deleted = 0
    AND b.status IN ('approved', 'checked_in', 'completed')
    AND b.requested_start_time >= @start_date
    AND b.requested_end_time <= DATEADD(DAY, 1, @end_date)
GROUP BY s.space_id, s.space_code, s.space_name, s.space_type, s.building, s.capacity
ORDER BY total_hours_booked DESC, s.space_code;
GO

-- ============================================================
-- Query 5: Rejection audit trail
-- ============================================================
-- Business question:
--   Show all booking rejections with the decision metadata —
--   who rejected, when, why, and what the booking was for.
--
-- Target user(s):
--   Facility Manager, Department Administrator
--
-- Why useful:
--   Provides an audit trail for rejected requests, ensuring
--   accountability and enabling review of rejection patterns
--   or unfair denials.
-- ============================================================

DECLARE @start_date DATE = '2026-01-01';
DECLARE @end_date   DATE = '2026-12-31';

SELECT
    b.booking_id,
    s.space_code,
    s.space_name,
    u_requester.full_name     AS requester,
    u_requester.email         AS requester_email,
    b.requested_start_time,
    b.requested_end_time,
    b.purpose,
    u_approver.full_name      AS rejected_by,
    b.decision_time,
    b.rejection_reason,
    b.decision_note
FROM [dbo].[bookings] b
INNER JOIN [dbo].[spaces] s ON b.space_id = s.space_id
INNER JOIN [dbo].[users] u_requester ON b.requester_id = u_requester.user_id
LEFT JOIN [dbo].[users] u_approver ON b.approver_id = u_approver.user_id
WHERE b.status = 'rejected'
  AND b.is_deleted = 0
  AND b.decision_time >= @start_date
  AND b.decision_time < DATEADD(DAY, 1, @end_date)
ORDER BY b.decision_time DESC;
GO

-- ============================================================
-- Query 6: No-show analysis by user
-- ============================================================
-- Business question:
--   Which users have the highest number of no-show bookings,
--   broken down by department and role?
--
-- Target user(s):
--   Facility Manager
--
-- Why useful:
--   Identifies users who repeatedly fail to show up, enabling
--   targeted policy enforcement, warning notifications, or
--   restrictions to improve space utilization.
-- ============================================================

DECLARE @start_date DATE = '2026-01-01';
DECLARE @end_date   DATE = '2026-12-31';

SELECT
    u.user_id,
    u.full_name,
    u.email,
    u.role,
    d.name        AS department,
    COUNT(b.booking_id) AS no_show_count
FROM [dbo].[users] u
INNER JOIN [dbo].[departments] d ON u.department_id = d.department_id
LEFT JOIN [dbo].[bookings] b
    ON u.user_id = b.requester_id
    AND b.status = 'no_show'
    AND b.is_deleted = 0
    AND b.requested_start_time >= @start_date
    AND b.requested_end_time < DATEADD(DAY, 1, @end_date)
GROUP BY u.user_id, u.full_name, u.email, u.role, d.name
HAVING COUNT(b.booking_id) > 0
ORDER BY no_show_count DESC, u.full_name;
GO

-- ============================================================
-- Query 7: Space facility inventory
-- ============================================================
-- Business question:
--   What is the complete facility inventory for each space in
--   a given building or of a given space type?
--
-- Target user(s):
--   Facility Staff, Facility Manager
--
-- Why useful:
--   Helps requesters choose a space based on available equipment
--   (e.g. "find a classroom with a projector") and helps staff
--   audit equipment distribution across campus.
-- ============================================================

DECLARE @building   NVARCHAR(100) = NULL;  -- NULL = all buildings
DECLARE @space_type VARCHAR(50)   = NULL;  -- NULL = all types

SELECT
    s.space_code,
    s.space_name,
    s.space_type,
    s.building,
    s.floor,
    s.room_number,
    s.capacity,
    s.current_status,
    STRING_AGG(
        CASE
            WHEN sf.quantity IS NOT NULL
            THEN f.name + N' (x' + CAST(sf.quantity AS NVARCHAR(10)) + N')'
            ELSE f.name
        END,
        N', '
    ) WITHIN GROUP (ORDER BY f.name) AS facilities
FROM [dbo].[spaces] s
LEFT JOIN [dbo].[space_facilities] sf ON s.space_id = sf.space_id
LEFT JOIN [dbo].[facilities] f ON sf.facility_id = f.facility_id
WHERE (@building IS NULL OR s.building = @building)
  AND (@space_type IS NULL OR s.space_type = @space_type)
GROUP BY s.space_id, s.space_code, s.space_name, s.space_type,
         s.building, s.floor, s.room_number, s.capacity, s.current_status
ORDER BY s.building, s.floor, s.space_code;
GO
