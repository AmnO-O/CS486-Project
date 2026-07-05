-- ============================================================
-- CS486 Group G05 — Campus Space Management System
-- Task 07: Query Design (Run 02)
-- Target: SQL Server 2019+ (T-SQL)
-- Schema version: 10-table (facilities carries space_id directly,
--   facility_categories lookup, incidents table)
-- ============================================================

-- ============================================================
-- Query 1: Find Available Classrooms / Computer Labs in a Time Window
-- ============================================================
-- Business question:
--   Which available classrooms or computer labs in a given
--   building have enough capacity for my class during a
--   specific time slot?
--
-- Target user(s):
--   Lecturer
--
-- Why useful:
--   Enables lecturers to quickly locate suitable rooms that are
--   free of booking conflicts, maintenance, and capacity
--   issues without cross-referencing multiple sources.
-- ============================================================

DECLARE @building             NVARCHAR(100) = N'Beta Building';
DECLARE @min_capacity         INT           = 40;
DECLARE @slot_start           DATETIME2     = '2026-07-10 09:00:00';
DECLARE @slot_end             DATETIME2     = '2026-07-10 11:00:00';
DECLARE @type_classroom       VARCHAR(50)   = 'classroom';
DECLARE @type_computer_lab    VARCHAR(50)   = 'computer_lab';
DECLARE @space_available      VARCHAR(50)   = 'available';

SELECT
    s.space_code,
    s.space_name,
    s.space_type,
    s.building,
    s.floor,
    s.room_number,
    s.capacity,
    s.current_status
FROM spaces s
WHERE s.building = @building
  AND s.space_type IN (@type_classroom, @type_computer_lab)
  AND s.capacity >= @min_capacity
  AND s.current_status = @space_available
  AND NOT EXISTS (
      SELECT 1
      FROM bookings b
      WHERE b.space_id = s.space_id
        AND b.is_deleted = 0
        AND b.status IN ('approved', 'checked_in', 'completed')
        AND b.requested_start_time < @slot_end
        AND b.requested_end_time > @slot_start
  )
  AND NOT EXISTS (
      SELECT 1
      FROM maintenance m
      WHERE m.space_id = s.space_id
        AND m.is_deleted = 0
        AND m.status IN ('open', 'in_progress')
        AND m.start_time < @slot_end
        AND (m.completion_time IS NULL OR m.completion_time > @slot_start)
  )
  AND NOT EXISTS (
      SELECT 1
      FROM incidents inc
      WHERE inc.space_id = s.space_id
        AND inc.status IN ('reported', 'investigating')
  )
ORDER BY s.capacity ASC, s.space_code;
GO

-- ============================================================
-- Query 2: Available Spaces Right Now for Immediate Booking
-- ============================================================
-- Business question:
--   Which spaces are available right now with no active
--   booking or unresolved maintenance, suitable for a
--   walk-in short-term use?
--
-- Target user(s):
--   Student, Lecturer
--
-- Why useful:
--   Lets users quickly see which rooms are free at this
--   moment for spontaneous study sessions, meetings, or
--   make-up classes without submitting a future-dated
--   booking request.
-- ============================================================

DECLARE @now             DATETIME2 = GETDATE();
DECLARE @lookahead_hours INT       = 2;
DECLARE @window_end      DATETIME2 = DATEADD(HOUR, @lookahead_hours, @now);
DECLARE @space_available VARCHAR(50) = 'available';

SELECT
    s.space_code,
    s.space_name,
    s.space_type,
    s.building,
    s.floor,
    s.room_number,
    s.capacity,
    s.current_status
FROM spaces s
WHERE s.current_status = @space_available
  AND NOT EXISTS (
      SELECT 1
      FROM bookings b
      WHERE b.space_id = s.space_id
        AND b.is_deleted = 0
        AND b.status IN ('approved', 'checked_in')
        AND b.requested_start_time < @window_end
        AND b.requested_end_time > @now
  )
  AND NOT EXISTS (
      SELECT 1
      FROM maintenance m
      WHERE m.space_id = s.space_id
        AND m.is_deleted = 0
        AND m.status IN ('open', 'in_progress')
        AND m.start_time < @window_end
        AND (m.completion_time IS NULL OR m.completion_time > @now)
  )
  AND NOT EXISTS (
      SELECT 1
      FROM incidents inc
      WHERE inc.space_id = s.space_id
        AND inc.status IN ('reported', 'investigating')
  )
ORDER BY s.building, s.floor, s.capacity DESC;
GO

-- ============================================================
-- Query 3: Labs with Minimum Workstations and Projector
-- ============================================================
-- Business question:
--   Which computer labs have at least 25 active computers
--   and at least one active projector, for a tutorial
--   session?
--
-- Target user(s):
--   Teaching Assistant, Lecturer
--
-- Why useful:
--   Enables teaching assistants to verify lab readiness
--   (enough workstations + projector) before submitting a
--   booking request, avoiding last-minute equipment
--   shortages.
-- ============================================================

DECLARE @min_workstations     INT         = 25;
DECLARE @min_projectors       INT         = 1;
DECLARE @type_computer_lab    VARCHAR(50) = 'computer_lab';
DECLARE @type_project_lab     VARCHAR(50) = 'project_lab';
DECLARE @category_computer    VARCHAR(50) = 'computer';
DECLARE @category_projector   VARCHAR(50) = 'projector';
DECLARE @facility_active      VARCHAR(20) = 'active';
DECLARE @space_available      VARCHAR(50) = 'available';

WITH lab_equipment AS (
    SELECT
        s.space_id,
        s.space_code,
        s.space_name,
        s.building,
        s.floor,
        s.room_number,
        s.capacity,
        COUNT(CASE WHEN fc.category_name = @category_computer THEN 1 END) AS workstation_count,
        COUNT(CASE WHEN fc.category_name = @category_projector THEN 1 END) AS projector_count
    FROM spaces s
    LEFT JOIN facilities f ON f.space_id = s.space_id AND f.status = @facility_active
    LEFT JOIN facility_categories fc ON fc.category_id = f.category_id
    WHERE s.space_type IN (@type_computer_lab, @type_project_lab)
      AND s.current_status = @space_available
    GROUP BY s.space_id, s.space_code, s.space_name, s.building, s.floor, s.room_number, s.capacity
)
SELECT
    le.space_code,
    le.space_name,
    le.space_type,
    le.building,
    le.floor,
    le.room_number,
    le.capacity,
    le.workstation_count,
    le.projector_count
FROM lab_equipment le
WHERE le.workstation_count >= @min_workstations
  AND le.projector_count >= @min_projectors
ORDER BY le.capacity ASC, le.space_code;
GO

-- ============================================================
-- Query 4: Upcoming Booking Schedule for a Building Today
-- ============================================================
-- Business question:
--   What is the full booking schedule for a specific
--   building today, including all non-deleted bookings
--   that overlap with the current day?
--
-- Target user(s):
--   Facility Staff, Student
--
-- Why useful:
--   Provides a complete timetable of room usage in a
--   building for the current day, helping users find
--   gaps in the schedule and coordinate their activities.
-- ============================================================

DECLARE @target_building  NVARCHAR(100) = N'Beta Building';
DECLARE @today_start      DATETIME2 = DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), DAY(GETDATE()));
DECLARE @today_end        DATETIME2 = DATEADD(DAY, 1, @today_start);
DECLARE @status_pending   VARCHAR(50) = 'pending';
DECLARE @status_approved  VARCHAR(50) = 'approved';
DECLARE @status_checked   VARCHAR(50) = 'checked_in';
DECLARE @status_completed VARCHAR(50) = 'completed';

SELECT
    s.space_code,
    s.space_name,
    s.space_type,
    s.floor,
    s.room_number,
    s.capacity,
    b.booking_id,
    requester.full_name    AS requester_name,
    requester.email        AS requester_email,
    b.purpose,
    b.expected_participants,
    b.requested_start_time,
    b.requested_end_time,
    b.status               AS booking_status,
    DATEDIFF(MINUTE, b.requested_start_time, b.requested_end_time) AS duration_minutes
FROM spaces s
INNER JOIN bookings b ON b.space_id = s.space_id
INNER JOIN users requester ON requester.user_id = b.requester_id
WHERE s.building = @target_building
  AND b.is_deleted = 0
  AND b.requested_start_time < @today_end
  AND b.requested_end_time > @today_start
  AND b.status IN (@status_pending, @status_approved, @status_checked, @status_completed)
ORDER BY s.floor, s.room_number, b.requested_start_time;
GO

-- ============================================================
-- Query 5: List Equipment in a Specific Space
-- ============================================================
-- Business question:
--   What equipment is currently installed in a specific
--   space, including category name, facility code, and
--   operational status?
--
-- Target user(s):
--   Facility Staff, Lecturer
--
-- Why useful:
--   Gives a complete equipment inventory for a room at a
--   glance, helping staff verify that required devices
--   (projector, whiteboard, computers) are present and
--   functional before approving a booking.
-- ============================================================

DECLARE @space_code NVARCHAR(50) = N'T06-LAB-201';

SELECT
    fc.category_name                                  AS equipment_type,
    CONCAT(fc.prefix, '_', f.facility_id)             AS facility_code,
    f.status
FROM facilities f
INNER JOIN facility_categories fc ON fc.category_id = f.category_id
INNER JOIN spaces s ON s.space_id = f.space_id
WHERE s.space_code = @space_code
ORDER BY fc.category_name, f.facility_id;
GO

-- ============================================================
-- Query 6: Count Devices by Category in a Building
-- ============================================================
-- Business question:
--   How many devices of each facility category are
--   installed across all spaces in a given building?
--
-- Target user(s):
--   Facility Manager
--
-- Why useful:
--   Provides a building-level equipment census so the
--   facility manager can plan maintenance schedules,
--   budget for replacements, and identify buildings
--   that are under-equipped relative to their usage.
-- ============================================================

DECLARE @building NVARCHAR(100) = N'Alpha Building';

SELECT
    fc.category_name,
    COUNT(f.facility_id) AS total_devices,
    COUNT(CASE WHEN f.status = 'active' THEN 1 END)   AS active_count,
    COUNT(CASE WHEN f.status = 'inactive' THEN 1 END) AS inactive_count,
    COUNT(CASE WHEN f.status = 'retired' THEN 1 END)  AS retired_count,
    COUNT(CASE WHEN f.status = 'lost' THEN 1 END)     AS lost_count
FROM facilities f
INNER JOIN facility_categories fc ON fc.category_id = f.category_id
INNER JOIN spaces s ON s.space_id = f.space_id
WHERE s.building = @building
  AND f.space_id IS NOT NULL
GROUP BY fc.category_name
ORDER BY fc.category_name;
GO

-- ============================================================
-- Query 7: Find Devices Currently in Storage (Unassigned)
-- ============================================================
-- Business question:
--   Which devices are currently in storage (not assigned
--   to any space) and available for deployment?
--
-- Target user(s):
--   Facility Staff
--
-- Why useful:
--   Lets staff quickly identify spare inventory that can
--   be deployed to replace broken or missing equipment
--   in active spaces without purchasing new units.
-- ============================================================

DECLARE @facility_active VARCHAR(20) = 'active';

SELECT
    CONCAT(fc.prefix, '_', f.facility_id) AS facility_code,
    fc.category_name,
    f.status
FROM facilities f
INNER JOIN facility_categories fc ON fc.category_id = f.category_id
WHERE f.space_id IS NULL
  AND f.status = @facility_active
ORDER BY fc.category_name, f.facility_id;
GO

-- ============================================================
-- Query 8: Facility Status Distribution Report
-- ============================================================
-- Business question:
--   What is the overall health of our equipment inventory
--   — how many devices are active, inactive, retired, or
--   lost, broken down by category?
--
-- Target user(s):
--   Facility Manager
--
-- Why useful:
--   Provides a high-level equipment lifecycle snapshot,
--   enabling the facility manager to identify categories
--   with high retirement or loss rates and plan
--   replacement budgets accordingly.
-- ============================================================

SELECT
    fc.category_name,
    COUNT(*)                                              AS total,
    SUM(CASE WHEN f.status = 'active' THEN 1 ELSE 0 END)   AS active,
    SUM(CASE WHEN f.status = 'inactive' THEN 1 ELSE 0 END) AS inactive,
    SUM(CASE WHEN f.status = 'retired' THEN 1 ELSE 0 END)  AS retired,
    SUM(CASE WHEN f.status = 'lost' THEN 1 ELSE 0 END)     AS lost
FROM facilities f
INNER JOIN facility_categories fc ON fc.category_id = f.category_id
GROUP BY fc.category_name
ORDER BY fc.category_name;
GO

-- ============================================================
-- Query 9: Active Maintenance Tickets Right Now
-- ============================================================
-- Business question:
--   What maintenance tickets are currently open or in
--   progress, including how long each has been waiting?
--
-- Target user(s):
--   Facility Staff
--
-- Why useful:
--   Provides a real-time view of all unresolved
--   maintenance issues so staff can prioritise urgent
--   tickets, follow up on stalled repairs, and inform
--   affected users about space availability.
-- ============================================================

DECLARE @status_open        VARCHAR(50) = 'open';
DECLARE @status_in_progress VARCHAR(50) = 'in_progress';
DECLARE @now                DATETIME2   = GETDATE();

SELECT
    m.maintenance_id,
    s.space_code,
    s.space_name,
    s.building,
    s.floor,
    s.room_number,
    s.space_type,
    m.problem_description,
    m.status,
    reporter.full_name       AS reporter_name,
    assignee.full_name       AS assigned_to,
    CONCAT(fc.category_name, N' ', fc.prefix, '_', m.facility_id) AS target_device,
    m.start_time,
    DATEDIFF(DAY, m.start_time, @now) AS days_since_reported
FROM maintenance m
INNER JOIN spaces s ON s.space_id = m.space_id
INNER JOIN users reporter ON reporter.user_id = m.reporter_id
LEFT JOIN users assignee ON assignee.user_id = m.assigned_staff_id
LEFT JOIN facilities f ON f.facility_id = m.facility_id
LEFT JOIN facility_categories fc ON fc.category_id = f.category_id
WHERE m.status IN (@status_open, @status_in_progress)
  AND m.is_deleted = 0
ORDER BY
    CASE m.status WHEN 'open' THEN 1 ELSE 2 END,
    m.start_time ASC;
GO

-- ============================================================
-- Query 10: Space-Level vs Device-Level Maintenance Comparison
-- ============================================================
-- Business question:
--   How much of our maintenance activity is targeted at
--   specific devices versus the space as a whole?
--
-- Target user(s):
--   Facility Manager
--
-- Why useful:
--   Helps the facility manager understand whether
--   maintenance resources are spent on general space
--   issues (cleaning, furniture) or device-specific
--   repairs (projector, computer), informing budget
--   and staffing decisions.
-- ============================================================

DECLARE @status_resolved VARCHAR(50) = 'resolved';
DECLARE @status_open     VARCHAR(50) = 'open';
DECLARE @status_progress VARCHAR(50) = 'in_progress';

SELECT
    CASE WHEN m.facility_id IS NOT NULL THEN N'device-level' ELSE N'space-level' END AS maintenance_scope,
    COUNT(*)                                                                           AS total_tickets,
    SUM(CASE WHEN m.status = @status_resolved THEN 1 ELSE 0 END)                       AS resolved_count,
    SUM(CASE WHEN m.status IN (@status_open, @status_progress) THEN 1 ELSE 0 END)      AS active_count,
    ROUND(AVG(CASE WHEN m.status = @status_resolved THEN
        CAST(DATEDIFF(HOUR, m.start_time, m.completion_time) AS DECIMAL(10, 2))
    ELSE NULL END), 2)                                                                 AS avg_resolution_hours
FROM maintenance m
WHERE m.is_deleted = 0
GROUP BY CASE WHEN m.facility_id IS NOT NULL THEN N'device-level' ELSE N'space-level' END
ORDER BY maintenance_scope;
GO

-- ============================================================
-- Query 11: Maintenance Resolution — Auto-Resolved Incidents
-- ============================================================
-- Business question:
--   Which incidents were automatically resolved through
--   maintenance completion, and what maintenance work
--   addressed them?
--
-- Target user(s):
--   Facility Manager
--
-- Why useful:
--   Traces the incident-to-maintenance resolution chain
--   for audit and reporting, proving that the BR21
--   auto-resolution trigger is working and providing
--   a complete incident lifecycle record.
-- ============================================================

DECLARE @now DATETIME2 = GETDATE();

SELECT
    inc.incident_id,
    inc.incident_type,
    inc.severity,
    LEFT(inc.description, 200)            AS incident_summary,
    inc.resolved_at,
    m.maintenance_id                      AS resolving_maintenance_id,
    m.problem_description                 AS maintenance_description,
    m.result_note                         AS maintenance_result,
    s.space_code,
    s.space_name
FROM incidents inc
INNER JOIN spaces s ON s.space_id = inc.space_id
INNER JOIN maintenance m
    ON m.space_id = inc.space_id
    AND m.status = 'resolved'
    AND inc.resolved_at = m.completion_time
WHERE inc.status = 'resolved'
  AND inc.resolution_notes IS NULL
ORDER BY inc.resolved_at DESC, inc.incident_id;
GO

-- ============================================================
-- Query 12: Maintenance Workload by Staff Member
-- ============================================================
-- Business question:
--   How many active and resolved maintenance tickets
--   does each facility staff member currently handle?
--
-- Target user(s):
--   Facility Manager
--
-- Why useful:
--   Enables the facility manager to balance workloads
--   across staff, identify overburdened team members,
--   and re-assign open tickets when someone is on leave.
-- ============================================================

DECLARE @status_open        VARCHAR(50) = 'open';
DECLARE @status_in_progress VARCHAR(50) = 'in_progress';
DECLARE @status_resolved    VARCHAR(50) = 'resolved';

SELECT
    staff.user_id,
    staff.full_name                       AS staff_name,
    staff.email                           AS staff_email,
    COUNT(*)                              AS total_assigned,
    SUM(CASE WHEN m.status IN (@status_open, @status_in_progress) THEN 1 ELSE 0 END) AS active_count,
    SUM(CASE WHEN m.status = @status_resolved THEN 1 ELSE 0 END)                      AS resolved_count
FROM maintenance m
INNER JOIN users staff ON staff.user_id = m.assigned_staff_id
WHERE m.is_deleted = 0
  AND m.assigned_staff_id IS NOT NULL
GROUP BY staff.user_id, staff.full_name, staff.email
ORDER BY active_count DESC, total_assigned DESC;
GO

-- ============================================================
-- Query 13: Unresolved Incidents Prioritized by Severity
-- ============================================================
-- Business question:
--   Which incidents are currently reported or under
--   investigation, ordered by severity and how long
--   they have been open?
--
-- Target user(s):
--   Facility Staff
--
-- Why useful:
--   Gives facility staff a prioritised queue of
--   unresolved incidents — critical theft or safety
--   hazards appear first — enabling rapid response
--   and informed dispatching.
-- ============================================================

DECLARE @status_reported       VARCHAR(30) = 'reported';
DECLARE @status_investigating  VARCHAR(30) = 'investigating';
DECLARE @now                   DATETIME2   = GETDATE();

SELECT
    inc.incident_id,
    inc.incident_type,
    inc.severity,
    inc.description,
    inc.status,
    s.space_code,
    s.space_name,
    s.building,
    s.floor,
    s.room_number,
    reporter.full_name       AS reported_by_name,
    assignee.full_name       AS assigned_to_name,
    inc.created_at,
    DATEDIFF(HOUR, inc.created_at, @now) AS hours_since_reported,
    CASE WHEN inc.facility_id IS NOT NULL
        THEN CONCAT(fc.category_name, N' ', fc.prefix, '_', inc.facility_id)
        ELSE NULL
    END AS involved_device
FROM incidents inc
INNER JOIN spaces s ON s.space_id = inc.space_id
INNER JOIN users reporter ON reporter.user_id = inc.reported_by
LEFT JOIN users assignee ON assignee.user_id = inc.assigned_to
LEFT JOIN facilities f ON f.facility_id = inc.facility_id
LEFT JOIN facility_categories fc ON fc.category_id = f.category_id
WHERE inc.status IN (@status_reported, @status_investigating)
ORDER BY
    CASE inc.severity
        WHEN 'critical' THEN 1
        WHEN 'high' THEN 2
        WHEN 'medium' THEN 3
        WHEN 'low' THEN 4
    END,
    inc.created_at ASC;
GO

-- ============================================================
-- Query 14: Incident Statistics by Type and Severity
-- ============================================================
-- Business question:
--   What is the breakdown of incidents by type and
--   severity, and what is the average resolution time
--   for each combination?
--
-- Target user(s):
--   Facility Manager
--
-- Why useful:
--   Reveals patterns in incident types (e.g. frequent
--   safety hazards, slow-to-resolve vandalism cases),
--   enabling the facility manager to implement targeted
--   prevention measures and improve response times.
-- ============================================================

DECLARE @semester_start DATETIME2 = '2026-01-01 00:00:00';

SELECT
    inc.incident_type,
    inc.severity,
    COUNT(*)                                                         AS total_count,
    SUM(CASE WHEN inc.status IN ('resolved', 'closed') THEN 1 ELSE 0 END) AS resolved_count,
    ROUND(AVG(CASE WHEN inc.resolved_at IS NOT NULL
        THEN CAST(DATEDIFF(HOUR, inc.created_at, inc.resolved_at) AS DECIMAL(10, 2))
        ELSE NULL END), 2)                                            AS avg_resolution_hours,
    MIN(CASE WHEN inc.resolved_at IS NOT NULL
        THEN DATEDIFF(HOUR, inc.created_at, inc.resolved_at)
        ELSE NULL END)                                                AS min_resolution_hours,
    MAX(CASE WHEN inc.resolved_at IS NOT NULL
        THEN DATEDIFF(HOUR, inc.created_at, inc.resolved_at)
        ELSE NULL END)                                                AS max_resolution_hours
FROM incidents inc
WHERE inc.created_at >= @semester_start
GROUP BY inc.incident_type, inc.severity
ORDER BY avg_resolution_hours DESC, inc.severity, inc.incident_type;
GO

-- ============================================================
-- Query 15: Spaces Blocked by Unresolved Incidents
-- ============================================================
-- Business question:
--   Which spaces have unresolved incidents that are
--   blocking new bookings, and how many incidents
--   remain open per space?
--
-- Target user(s):
--   Facility Staff, Facility Manager
--
-- Why useful:
--   Lets staff identify spaces that are unavailable
--   due to active incidents (theft, vandalism, safety
--   hazards) so they can prioritise resolution and
--   inform users whose bookings are affected.
-- ============================================================

SELECT
    s.space_code,
    s.space_name,
    s.building,
    s.floor,
    s.room_number,
    s.space_type,
    s.current_status,
    COUNT(inc.incident_id) AS unresolved_incident_count,
    STRING_AGG(
        CONCAT(inc.incident_type, N' (', inc.severity, N'): ', LEFT(inc.description, 100)),
        N'; '
    ) AS incident_summary
FROM spaces s
INNER JOIN incidents inc ON inc.space_id = s.space_id
    AND inc.status IN ('reported', 'investigating')
GROUP BY
    s.space_code,
    s.space_name,
    s.building,
    s.floor,
    s.room_number,
    s.space_type,
    s.current_status
ORDER BY unresolved_incident_count DESC, s.building, s.room_number;
GO

-- ============================================================
-- Query 16: Incidents Associated with a Specific Facility
-- ============================================================
-- Business question:
--   What incidents have been reported involving a
--   specific device, including its resolution status
--   and any linked maintenance work?
--
-- Target user(s):
--   Facility Staff
--
-- Why useful:
--   Provides a complete incident history for a
--   particular device, helping staff track recurrent
--   issues with specific equipment and decide
--   whether to repair or replace it.
-- ============================================================

DECLARE @facility_code_pattern NVARCHAR(50) = N'pro_5';

SELECT
    inc.incident_id,
    inc.incident_type,
    inc.severity,
    LEFT(inc.description, 200)      AS description,
    inc.status                      AS incident_status,
    inc.created_at                  AS incident_reported_at,
    inc.resolved_at                 AS incident_resolved_at,
    m.maintenance_id                AS related_maintenance_id,
    m.status                        AS maintenance_status,
    m.problem_description           AS maintenance_problem
FROM incidents inc
INNER JOIN facilities f ON f.facility_id = inc.facility_id
INNER JOIN facility_categories fc ON fc.category_id = f.category_id
LEFT JOIN maintenance m
    ON m.facility_id = inc.facility_id
    AND m.is_deleted = 0
WHERE CONCAT(fc.prefix, '_', f.facility_id) = @facility_code_pattern
ORDER BY inc.created_at DESC;
GO

-- ============================================================
-- Query 17: Booking Utilization by Space Type Over Past 30 Days
-- ============================================================
-- Business question:
--   How many hours have been used per space type in the
--   last 30 days, and what is the utilization rate
--   relative to available capacity?
--
-- Target user(s):
--   Facility Manager
--
-- Why useful:
--   Enables the facility manager to identify over- and
--   under-utilised space types, supporting data-driven
--   decisions about space reallocation, consolidation,
--   or expansion.
-- ============================================================

DECLARE @past_days       INT       = 30;
DECLARE @window_start    DATETIME2 = DATEADD(DAY, -@past_days, GETDATE());
DECLARE @window_end      DATETIME2 = GETDATE();
DECLARE @status_completed VARCHAR(50) = 'completed';

WITH space_capacity AS (
    SELECT
        space_type,
        COUNT(*)              AS total_spaces,
        SUM(capacity)         AS total_capacity
    FROM spaces
    WHERE current_status NOT IN ('retired')
    GROUP BY space_type
),
usage_hours AS (
    SELECT
        s.space_type,
        ROUND(SUM(DATEDIFF(SECOND, bs.actual_start_time, bs.actual_end_time)) / 3600.0, 2) AS total_used_hours
    FROM bookings b
    INNER JOIN spaces s ON s.space_id = b.space_id
    INNER JOIN booking_sessions bs ON bs.booking_id = b.booking_id
    WHERE b.status = @status_completed
      AND b.is_deleted = 0
      AND bs.actual_end_time IS NOT NULL
      AND bs.actual_start_time >= @window_start
      AND bs.actual_start_time < @window_end
    GROUP BY s.space_type
)
SELECT
    sc.space_type,
    sc.total_spaces,
    sc.total_capacity,
    COALESCE(uh.total_used_hours, 0) AS total_used_hours,
    CASE WHEN sc.total_capacity > 0
        THEN ROUND(COALESCE(uh.total_used_hours, 0) / (sc.total_capacity * @past_days * 10.0) * 100, 2)
        ELSE 0
    END AS utilization_rate_pct
FROM space_capacity sc
LEFT JOIN usage_hours uh ON uh.space_type = sc.space_type
ORDER BY utilization_rate_pct DESC;
GO

-- ============================================================
-- Query 18: No-Show Rate by Department
-- ============================================================
-- Business question:
--   Which departments have the highest no-show rates
--   for approved bookings, indicating over-reservation
--   without follow-through?
--
-- Target user(s):
--   Facility Manager
--
-- Why useful:
--   Highlights departments that book spaces but
--   frequently fail to show up, enabling the facility
--   manager to enforce penalties, require deposits,
--   or limit concurrent bookings for repeat offenders.
-- ============================================================

DECLARE @semester_start DATETIME2 = '2026-01-01 00:00:00';
DECLARE @semester_end   DATETIME2 = '2027-01-01 00:00:00';
DECLARE @status_no_show VARCHAR(50) = 'no_show';
DECLARE @status_approved VARCHAR(50) = 'approved';
DECLARE @status_checked  VARCHAR(50) = 'checked_in';
DECLARE @status_completed VARCHAR(50) = 'completed';

WITH confirmed_bookings AS (
    SELECT
        b.booking_id,
        b.requester_id,
        b.status
    FROM bookings b
    WHERE b.is_deleted = 0
      AND b.status IN (@status_approved, @status_checked, @status_completed, @status_no_show)
      AND b.requested_start_time >= @semester_start
      AND b.requested_start_time < @semester_end
)
SELECT
    d.name                                  AS department_name,
    COUNT(cb.booking_id)                    AS total_confirmed_bookings,
    SUM(CASE WHEN cb.status = @status_no_show THEN 1 ELSE 0 END) AS no_show_count,
    ROUND(
        100.0 * SUM(CASE WHEN cb.status = @status_no_show THEN 1 ELSE 0 END)
        / NULLIF(COUNT(cb.booking_id), 0), 2
    )                                       AS no_show_rate_pct
FROM confirmed_bookings cb
INNER JOIN users u ON u.user_id = cb.requester_id
INNER JOIN departments d ON d.department_id = u.department_id
GROUP BY d.department_id, d.name
HAVING COUNT(cb.booking_id) >= 1
ORDER BY no_show_rate_pct DESC, total_confirmed_bookings DESC;
GO

-- ============================================================
-- Query 19: Department Booking Purpose Breakdown
-- ============================================================
-- Business question:
--   What booking purposes does my department use most
--   frequently, and how many of those resulted in
--   completed sessions?
--
-- Target user(s):
--   Department Administrator
--
-- Why useful:
--   Enables department administrators to understand
--   their department's space usage patterns — whether
--   rooms are used for lectures, workshops, meetings,
--   or student activities — and to advocate for
--   appropriate space allocations.
-- ============================================================

DECLARE @target_department_name NVARCHAR(255) = N'School of Computer Science';
DECLARE @semester_start         DATETIME2     = '2026-01-01 00:00:00';
DECLARE @semester_end           DATETIME2     = '2027-01-01 00:00:00';
DECLARE @status_completed       VARCHAR(50)   = 'completed';

SELECT
    b.purpose,
    COUNT(*)                                                        AS total_requests,
    SUM(CASE WHEN b.status = @status_completed THEN 1 ELSE 0 END)    AS completed_count,
    ROUND(
        100.0 * SUM(CASE WHEN b.status = @status_completed THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0), 2
    )                                                               AS completion_rate_pct,
    COUNT(DISTINCT b.requester_id)                                   AS unique_users
FROM bookings b
INNER JOIN users u ON u.user_id = b.requester_id
INNER JOIN departments d ON d.department_id = u.department_id
WHERE d.name = @target_department_name
  AND b.is_deleted = 0
  AND b.requested_start_time >= @semester_start
  AND b.requested_start_time < @semester_end
GROUP BY b.purpose
ORDER BY total_requests DESC;
GO

-- ============================================================
-- Query 20: Approval / Rejection Statistics by Purpose and Space Type
-- ============================================================
-- Business question:
--   For each combination of booking purpose and space
--   type, what is the approval rate, rejection rate,
--   and average decision time?
--
-- Target user(s):
--   Facility Manager
--
-- Why useful:
--   Reveals whether certain purposes (e.g. student
--   activities) or space types (e.g. auditoriums) face
--   higher rejection rates or slower decisions, enabling
--   the facility manager to review policies and improve
--   service levels.
-- ============================================================

DECLARE @semester_start DATETIME2     = '2026-01-01 00:00:00';
DECLARE @semester_end   DATETIME2     = '2027-01-01 00:00:00';
DECLARE @decision_approved VARCHAR(50) = 'approved';
DECLARE @decision_rejected VARCHAR(50) = 'rejected';

SELECT
    b.purpose,
    s.space_type,
    COUNT(*)                                                          AS total_decided,
    SUM(CASE WHEN ba.decision = @decision_approved THEN 1 ELSE 0 END)  AS approved_count,
    SUM(CASE WHEN ba.decision = @decision_rejected THEN 1 ELSE 0 END)  AS rejected_count,
    ROUND(
        100.0 * SUM(CASE WHEN ba.decision = @decision_approved THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0), 2
    )                                                                 AS approval_rate_pct,
    ROUND(
        AVG(CAST(DATEDIFF(MINUTE, b.created_at, ba.decision_time) AS DECIMAL(10, 2))), 2
    )                                                                 AS avg_decision_minutes
FROM booking_approvals ba
INNER JOIN bookings b ON b.booking_id = ba.booking_id
INNER JOIN spaces s ON s.space_id = b.space_id
WHERE b.is_deleted = 0
  AND ba.decision IN (@decision_approved, @decision_rejected)
  AND b.requested_start_time >= @semester_start
  AND b.requested_start_time < @semester_end
GROUP BY b.purpose, s.space_type
ORDER BY total_decided DESC, approval_rate_pct DESC;
GO
