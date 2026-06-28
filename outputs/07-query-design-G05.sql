-- ============================================================
-- CS486 Group G05 — Campus Space Management System
-- Task 07: Query Design
-- Target: SQL Server 2019+ (T-SQL)
-- Schema: dbo (CS486_G05 database)
-- Dependencies: outputs/05-db-definition-G05.sql, outputs/06-sample-data-G05.sql
-- ============================================================

-- ============================================================
-- Query 1: Pending approvals for today
-- --student-name: Nguyen Huu Phuoc
-- --target-users: facility_staff
-- --business-question: What bookings are waiting for my
--    approval today?
-- ============================================================
-- Business question:
--   Which pending booking requests fall within today or the
--   next 24 hours and need immediate attention?
--
-- Target user(s):
--   Facility Staff
--
-- Why useful:
--   Facility staff need to review and approve/reject bookings
--   in a timely manner. This query shows the most urgent
--   requests first so that no requester is left waiting.
-- ============================================================

DECLARE @staff_id INT = 5;

SELECT
    b.booking_id,
    s.space_code,
    s.space_name,
    u.full_name   AS requester,
    u.email       AS requester_email,
    b.requested_start_time,
    b.requested_end_time,
    b.purpose,
    b.expected_participants,
    b.created_at  AS submitted_at
FROM [dbo].[bookings] b
INNER JOIN [dbo].[spaces] s ON b.space_id = s.space_id
INNER JOIN [dbo].[users] u ON b.requester_id = u.user_id
WHERE b.status = 'pending'
  AND b.is_deleted = 0
  AND b.requested_start_time <= DATEADD(DAY, 1, GETDATE())
ORDER BY b.requested_start_time;
GO

-- ============================================================
-- Query 2: Real-time occupancy snapshot
-- --student-name: Nguyen Huu Phuoc
-- --target-users: facility_staff
-- --business-question: Which spaces are currently occupied and
--    by whom?
-- ============================================================
-- Business question:
--   What is happening right now — which spaces are checked in
--   or approved, who booked them, and when do they end?
--
-- Target user(s):
--   Facility Staff
--
-- Why useful:
--   Provides a live dashboard for facility staff to monitor
--   current occupancy, plan walkthroughs, and respond to
--   issues or emergencies in real time.
-- ============================================================

DECLARE @now DATETIME2 = GETDATE();

SELECT
    b.booking_id,
    s.space_code,
    s.space_name,
    s.building,
    s.room_number,
    u.full_name   AS requester,
    b.purpose,
    b.expected_participants,
    b.requested_start_time,
    b.requested_end_time,
    b.status,
    b.actual_start_time
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
-- Query 3: Active maintenance tickets
-- --student-name: Nguyen Huu Phuoc
-- --target-users: facility_staff
-- --business-question: What maintenance issues are open or
--    in progress across all spaces?
-- ============================================================
-- Business question:
--   Which spaces are affected by unresolved maintenance,
--   what is the problem, who is assigned, and how long has
--   it been open?
--
-- Target user(s):
--   Facility Staff
--
-- Why useful:
--   Gives a single view of all active maintenance across
--   campus so staff can prioritize repairs and track
--   assignment progress.
-- ============================================================

SELECT
    m.maintenance_id,
    s.space_code,
    s.space_name,
    s.building,
    s.room_number,
    m.problem_description,
    m.status,
    m.start_time,
    u_reporter.full_name      AS reporter,
    u_assigned.full_name      AS assigned_staff,
    DATEDIFF(DAY, m.start_time, GETDATE()) AS days_open
FROM [dbo].[maintenances] m
INNER JOIN [dbo].[spaces] s ON m.space_id = s.space_id
INNER JOIN [dbo].[users] u_reporter ON m.reporter_id = u_reporter.user_id
LEFT JOIN [dbo].[users] u_assigned ON m.assigned_staff_id = u_assigned.user_id
WHERE m.is_deleted = 0
  AND m.status IN ('open', 'in_progress')
ORDER BY m.status, m.start_time;
GO

-- ============================================================
-- Query 4: Eligible check-in bookings
-- --student-name: Nguyen Huu Phuoc
-- --target-users: facility_staff
-- --business-question: Which approved bookings have passed
--    their start time but have not checked in yet?
-- ============================================================
-- Business question:
--   Which approved bookings have a start time in the past
--   but no actual check-in recorded yet?
--
-- Target user(s):
--   Facility Staff
--
-- Why useful:
--   Enables staff to proactively identify no-shows or
--   perform check-in for late arrivals, reducing idle
--   space time and improving utilization.
-- ============================================================

SELECT
    b.booking_id,
    s.space_code,
    s.space_name,
    u.full_name   AS requester,
    u.email       AS requester_email,
    b.requested_start_time,
    b.requested_end_time,
    b.purpose,
    b.expected_participants
FROM [dbo].[bookings] b
INNER JOIN [dbo].[spaces] s ON b.space_id = s.space_id
INNER JOIN [dbo].[users] u ON b.requester_id = u.user_id
WHERE b.status = 'approved'
  AND b.is_deleted = 0
  AND b.requested_start_time <= GETDATE()
  AND b.actual_start_time IS NULL
ORDER BY b.requested_start_time;
GO

-- ============================================================
-- Query 5: Session completion report for today
-- --student-name: Nguyen Huu Phuoc
-- --target-users: facility_staff
-- --business-question: What sessions ended today and what
--    was the final condition of each space?
-- ============================================================
-- Business question:
--   Which sessions were completed today, what were the actual
--   end times, and what final condition was noted for each
--   space?
--
-- Target user(s):
--   Facility Staff
--
-- Why useful:
--   Enables staff to review end-of-day space conditions,
--   flag damage or cleaning needs, and verify all sessions
--   were properly closed out before the next day.
-- ============================================================

DECLARE @report_date DATE = '2026-07-01';

SELECT
    b.booking_id,
    s.space_code,
    s.space_name,
    u.full_name           AS requester,
    b.actual_start_time,
    b.actual_end_time,
    b.initial_condition,
    b.final_condition,
    b.usage_notes,
    u_staff.full_name     AS checked_in_by_staff
FROM [dbo].[bookings] b
INNER JOIN [dbo].[spaces] s ON b.space_id = s.space_id
INNER JOIN [dbo].[users] u ON b.requester_id = u.user_id
LEFT JOIN [dbo].[users] u_staff ON b.checked_in_by = u_staff.user_id
WHERE b.status = 'completed'
  AND b.is_deleted = 0
  AND CAST(b.actual_end_time AS DATE) = @report_date
ORDER BY b.actual_end_time;
GO

-- ============================================================
-- Query 6: Rejection audit trail for a specific requester
-- --student-name: Pham Huu Nam
-- --target-users: facility_manager
-- --business-question: Professor submitted consecutive booking
--    requests that were all rejected. Need complete audit
--    trail including refusal reasons, timestamps, and staff
--    who processed them.
-- ============================================================
-- Business question:
--   When a requester has multiple consecutive bookings rejected,
--   what is the complete audit trail — rejection reasons,
--   decision timestamps, and which staff member processed
--   each rejection?
--
-- Target user(s):
--   Facility Manager
--
-- Why useful:
--   Enables the Facility Manager to investigate potential bias,
--   systemic resource shortages, or miscommunication by
--   reviewing the full rejection history for a specific
--   requester, ordered chronologically, with all decision
--   metadata.
-- ============================================================

DECLARE @requester_name NVARCHAR(255) = N'Prof. Robert Chen';

SELECT
    b.booking_id,
    u_req.full_name            AS requester_name,
    u_req.email                AS requester_email,
    s.space_code,
    s.space_name,
    s.building,
    b.requested_start_time,
    b.requested_end_time,
    b.purpose,
    b.expected_participants,
    b.status,
    b.rejection_reason,
    b.decision_time,
    b.decision_note,
    u_app.full_name            AS approver_name,
    u_app.user_id              AS approver_id,
    b.created_at               AS submitted_at,
    b.updated_at               AS last_updated
FROM [dbo].[bookings] b
INNER JOIN [dbo].[users] u_req ON b.requester_id = u_req.user_id
INNER JOIN [dbo].[spaces] s ON b.space_id = s.space_id
LEFT JOIN [dbo].[users] u_app ON b.approver_id = u_app.user_id
WHERE b.status = 'rejected'
  AND b.is_deleted = 0
  AND u_req.full_name = @requester_name
ORDER BY b.requested_start_time;
GO

-- ============================================================
-- Query 7: Maintenance risk profile — spaces with resolved
-- issues and their upcoming bookings
-- ============================================================
-- --student-name: Pham Huu Nam
-- --target-users: facility_manager
-- --business-question: Which spaces have encountered resolved
--    maintenance issues within the past six months, and what
--    are their upcoming approved bookings for the next seven
--    days?
-- ============================================================
-- Business question:
--   Which spaces have encountered resolved maintenance issues
--   within the past six months, and what are their upcoming
--   approved bookings for the next seven days? The facility
--   manager needs this comprehensive risk profile to identify
--   rooms with a history of failure and leverage their
--   available gap times (or empty slots) for preventive
--   maintenance before new schedules are disrupted.
--
-- Target user(s):
--   Facility Manager
--
-- Why useful:
--   Enables the Facility Manager to proactively identify
--   spaces with recent resolved-maintenance history that have
--   upcoming bookings, assess risk exposure, and schedule
--   preventive maintenance during gap windows to avoid
--   disruption.
-- ============================================================

DECLARE @lookback_months INT = 6;
DECLARE @lookahead_days  INT = 7;

WITH resolved_maintenance AS (
    SELECT
        m.space_id,
        COUNT(*)          AS resolved_incidents,
        MAX(m.completion_time) AS last_resolved,
        STRING_AGG(m.problem_description, '; ')
            WITHIN GROUP (ORDER BY m.completion_time DESC) AS recent_issues
    FROM [dbo].[maintenances] m
    WHERE m.is_deleted = 0
      AND m.status = 'resolved'
      AND m.completion_time >= DATEADD(MONTH, -@lookback_months, GETDATE())
    GROUP BY m.space_id
),
upcoming_bookings AS (
    SELECT
        b.space_id,
        COUNT(*)           AS upcoming_booking_count,
        MIN(b.requested_start_time) AS earliest_booking_start,
        MAX(b.requested_end_time)   AS latest_booking_end
    FROM [dbo].[bookings] b
    WHERE b.is_deleted = 0
      AND b.status IN ('approved', 'checked_in')
      AND b.requested_start_time >= GETDATE()
      AND b.requested_start_time < DATEADD(DAY, @lookahead_days, GETDATE())
    GROUP BY b.space_id
)
SELECT
    s.space_code,
    s.space_name,
    s.building,
    s.room_number,
    s.space_type,
    s.capacity,
    s.current_status,
    rm.resolved_incidents,
    rm.last_resolved,
    rm.recent_issues,
    COALESCE(ub.upcoming_booking_count, 0) AS upcoming_booking_count,
    ub.earliest_booking_start,
    ub.latest_booking_end,
    CASE
        WHEN ub.upcoming_booking_count IS NULL
            THEN N'No upcoming bookings — available for preventive maintenance'
        WHEN ub.upcoming_booking_count > 0
            THEN N'Has ' + CAST(ub.upcoming_booking_count AS NVARCHAR(10))
                 + N' upcoming booking(s) — check gap windows'
        ELSE N'No data'
    END AS risk_recommendation
FROM [dbo].[spaces] s
INNER JOIN resolved_maintenance rm ON s.space_id = rm.space_id
LEFT JOIN upcoming_bookings ub ON s.space_id = ub.space_id
ORDER BY
    rm.last_resolved DESC,
    ub.earliest_booking_start;
GO

-- ============================================================
-- Query 8: Department no-show rate analysis for this semester
-- ============================================================
-- --student-name: Pham Huu Nam
-- --target-users: facility_manager
-- --business-question: During high-demand weeks, certain
--    departments have a habit of booking multiple spaces "just
--    in case" but failing to check in, creating artificial
--    room shortages. Identify departments with the highest
--    No-Show rates this semester.
-- ============================================================
-- Business question:
--   During high-demand weeks, certain departments have a habit
--   of booking multiple spaces "just in case" but failing to
--   check in, creating artificial room shortages. The Facility
--   Manager needs a report identifying departments with the
--   highest No-Show rates this semester to enforce strict
--   reservation penalties.
--
-- Target user(s):
--   Facility Manager
--
-- Why useful:
--   Quantifies no-show behaviour by department so the Facility
--   Manager can target enforcement actions, adjust approval
--   policies, or implement penalty rules for repeat offenders,
--   freeing artificially held space for legitimate demand.
-- ============================================================

DECLARE @semester_start     DATE = '2026-01-01';
DECLARE @min_total_bookings INT = 2;

WITH department_bookings AS (
    SELECT
        d.department_id,
        d.name                                  AS department_name,
        COUNT(*)                                AS total_confirmed_bookings,
        SUM(CASE WHEN b.status = 'no_show' THEN 1 ELSE 0 END) AS no_show_count
    FROM [dbo].[bookings] b
    INNER JOIN [dbo].[users] u ON b.requester_id = u.user_id
    INNER JOIN [dbo].[departments] d ON u.department_id = d.department_id
    WHERE b.is_deleted = 0
      AND b.status IN ('approved', 'checked_in', 'completed', 'no_show')
      AND b.requested_start_time >= @semester_start
    GROUP BY d.department_id, d.name
)
SELECT
    department_name,
    total_confirmed_bookings,
    no_show_count,
    ROUND(CAST(no_show_count AS FLOAT) / NULLIF(total_confirmed_bookings, 0) * 100, 2) AS no_show_rate_pct,
    CASE
        WHEN CAST(no_show_count AS FLOAT) / NULLIF(total_confirmed_bookings, 0) >= 0.50
            THEN N'Critical — review approval policy'
        WHEN CAST(no_show_count AS FLOAT) / NULLIF(total_confirmed_bookings, 0) >= 0.25
            THEN N'Warning — monitor closely'
        ELSE N'Normal'
    END AS risk_level
FROM department_bookings
WHERE total_confirmed_bookings >= @min_total_bookings
ORDER BY no_show_rate_pct DESC, total_confirmed_bookings DESC;
GO

-- ============================================================
-- Query 9: Cumulative usage hours per requester this month
-- ============================================================
-- --student-name: Pham Huu Nam
-- --target-users: facility_manager
-- --business-question: When multiple students submit competing
--    booking requests for the same room and time slot, how
--    many cumulative hours has each requester actually used
--    university shared spaces during the current month?
-- ============================================================
-- Business question:
--   When multiple students submit competing booking requests
--   for the same meeting room and time slot, how many
--   cumulative hours has each requester actually used
--   university shared spaces during the current month? The
--   Facility Manager needs this information to support fair
--   allocation by prioritizing users who have received less
--   access to shared facilities.
--
-- Target user(s):
--   Facility Manager
--
-- Why useful:
--   Quantifies actual space usage per requester for the
--   current month, enabling the Facility Manager to make
--   data-driven fair-allocation decisions when resolving
--   competing booking requests — prioritising users who
--   have used shared facilities the least.
-- ============================================================

DECLARE @month_start DATE = DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1);
DECLARE @month_end   DATE = DATEADD(DAY, -1, DATEADD(MONTH, 1, @month_start));

SELECT
    u.user_id,
    u.full_name               AS requester_name,
    u.email                   AS requester_email,
    d.name                    AS department_name,
    u.role,
    COUNT(b.booking_id)       AS sessions_attended,
    SUM(
        DATEDIFF(MINUTE,
            COALESCE(b.actual_start_time, b.requested_start_time),
            COALESCE(b.actual_end_time,   b.requested_end_time)
        )
    )                         AS total_minutes_used,
    ROUND(
        SUM(
            DATEDIFF(MINUTE,
                COALESCE(b.actual_start_time, b.requested_start_time),
                COALESCE(b.actual_end_time,   b.requested_end_time)
            )
        ) / 60.0, 2
    )                         AS total_hours_used
FROM [dbo].[users] u
INNER JOIN [dbo].[departments] d ON u.department_id = d.department_id
LEFT JOIN [dbo].[bookings] b ON u.user_id = b.requester_id
    AND b.is_deleted = 0
    AND b.status IN ('completed', 'checked_in')
    AND b.requested_start_time >= @month_start
    AND b.requested_start_time <= @month_end
GROUP BY u.user_id, u.full_name, u.email, d.name, u.role
ORDER BY total_minutes_used ASC, u.full_name;
GO

-- ============================================================
-- Query 10: Room-type demand & approval analysis (past semester)
-- ============================================================
-- --student-name: Pham Huu Nam
-- --target-users: facility_manager
-- --business-question: Which room type was most frequently
--    requested last semester, including its successful approval
--    rate and the number of unique users attracted?
-- ============================================================
-- Business question:
--   Provide a summary of the past semester regarding which room
--   type (classroom, laboratory, meeting_room) was most
--   frequently requested, including its successful approval
--   rate and the number of unique users attracted, in order to
--   evaluate potential expansion or consolidation.
--
-- Target user(s):
--   Facility Manager
--
-- Why useful:
--   Helps the Facility Manager make data-driven decisions about
--   space portfolio planning — which room types are over- or
--   under-demanded, which have high friction (low approval), and
--   how many unique users each type serves, informing expansion
--   or consolidation strategies.
-- ============================================================

DECLARE @semester_start DATE = '2026-01-01';
DECLARE @semester_end   DATE = '2026-06-30';

SELECT
    s.space_type,
    COUNT(*)                                    AS total_requests,
    COUNT(DISTINCT b.requester_id)              AS unique_requester_count,
    SUM(CASE WHEN b.status IN ('approved','checked_in','completed','no_show') THEN 1 ELSE 0 END)
                                                AS approved_sessions,
    SUM(CASE WHEN b.status = 'rejected' THEN 1 ELSE 0 END)
                                                AS rejected_count,
    CASE
        WHEN COUNT(CASE WHEN b.status IN ('approved','checked_in','completed','no_show','rejected') THEN 1 END) > 0
        THEN ROUND(
                CAST(
                    SUM(CASE WHEN b.status IN ('approved','checked_in','completed','no_show') THEN 1 ELSE 0 END) AS FLOAT
                )
                / NULLIF(
                    SUM(CASE WHEN b.status IN ('approved','checked_in','completed','no_show','rejected') THEN 1 ELSE 0 END),
                    0
                ) * 100,
                1
             )
        ELSE NULL
    END                                         AS approval_rate_pct,
    MIN(s.capacity)                             AS min_capacity,
    MAX(s.capacity)                             AS max_capacity
FROM [dbo].[bookings] b
INNER JOIN [dbo].[spaces] s ON b.space_id = s.space_id
WHERE b.is_deleted = 0
  AND b.requested_start_time >= @semester_start
  AND b.requested_start_time <= @semester_end
GROUP BY s.space_type
ORDER BY total_requests DESC;
GO

-- ============================================================
-- Query 11: Available classrooms / computer labs with Projector
--            and Whiteboard
-- ============================================================
-- --student-name: Cao Quang Hung
-- --target-user: student
-- --business-question: Which Classrooms or Computer laboratories
--    in a specific building are currently Available for the next
--    X hours and contain both a Projector and a Whiteboard?
-- ============================================================
-- Business question:
--   Which Classrooms or Computer laboratories in a specific
--   building are currently Available for the next X hours and
--   contain both a Projector and a Whiteboard?
--
-- Target user(s):
--   Student
--
-- Why useful:
--   Students and lecturers can quickly find teaching or study
--   spaces equipped with both a Projector (for presentations)
--   and a Whiteboard (for brainstorming) that are free to book
--   within their desired time window, helping them prepare
--   effectively for classes or group work.
-- ============================================================

DECLARE @building    NVARCHAR(100) = N'Building B';
DECLARE @hours_ahead INT            = 4;
DECLARE @window_end  DATETIME2      = DATEADD(HOUR, @hours_ahead, GETDATE());

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
WHERE s.space_type IN ('classroom', 'computer_lab')
  AND s.building = @building
  AND s.current_status = 'available'
  AND NOT EXISTS (
      SELECT 1
      FROM [dbo].[bookings] b
      WHERE b.space_id = s.space_id
        AND b.is_deleted = 0
        AND b.status IN ('approved', 'checked_in', 'completed')
        AND b.requested_start_time < @window_end
        AND b.requested_end_time > GETDATE()
  )
  AND EXISTS (
      SELECT 1
      FROM [dbo].[space_facilities] sf
      INNER JOIN [dbo].[facilities] f ON sf.facility_id = f.facility_id
      WHERE sf.space_id = s.space_id
        AND f.name = N'Projector'
  )
  AND EXISTS (
      SELECT 1
      FROM [dbo].[space_facilities] sf
      INNER JOIN [dbo].[facilities] f ON sf.facility_id = f.facility_id
      WHERE sf.space_id = s.space_id
        AND f.name = N'Whiteboard'
  )
ORDER BY s.space_code;
GO

-- ============================================================
-- Query 12: Seminar / Student Activity events on a given date
--            with capacity >= 20
-- ============================================================
-- --student-name: Cao Quang Hung
-- --target-user: student
-- --business-question: Which "Seminar" or "Student Activity"
--    events are happening on a given date in spaces with
--    capacity of 20 or more people, and who is organizing them?
-- ============================================================
-- Business question:
--   Which "Seminar" or "Student Activity" events are happening
--   on a given date in spaces with a capacity of 20 or more
--   people, and who is organizing them?
--
-- Target user(s):
--   Student
--
-- Why useful:
--   Students frequently look for open academic events or
--   large student activities to attend on campus. Instead
--   of checking physical bulletin boards, this query allows
--   a student to dynamically discover events happening on a
--   specific date, pinpoint the exact building and room
--   number, and see the organizer's name and department in
--   case they need to reach out for an itinerary.
-- ============================================================

DECLARE @event_date    DATE = '2026-06-22';
DECLARE @min_capacity  INT  = 20;

SELECT
    b.booking_id,
    b.purpose,
    b.requested_start_time,
    b.requested_end_time,
    s.space_name,
    s.space_type,
    s.building,
    s.floor,
    s.room_number,
    s.capacity,
    u.full_name           AS organizer_name,
    u.email               AS organizer_email,
    d.name                AS organizer_department
FROM [dbo].[bookings] b
INNER JOIN [dbo].[spaces] s ON b.space_id = s.space_id
INNER JOIN [dbo].[users] u ON b.requester_id = u.user_id
INNER JOIN [dbo].[departments] d ON u.department_id = d.department_id
WHERE b.purpose IN ('seminar', 'student_activity')
  AND CAST(b.requested_start_time AS DATE) = @event_date
  AND s.capacity >= @min_capacity
  AND b.is_deleted = 0
  AND b.status IN ('checked_in', 'completed', 'approved')
ORDER BY b.requested_start_time;
GO

-- ============================================================
-- Query 13: Alternative spaces when usual room is blocked
-- ============================================================
-- --student-name: Cao Quang Hung
-- --target-user: student
-- --business-question: If my usual requested space is "Under
--    Maintenance" or "Temporarily Closed", what are the top 3
--    alternative spaces on the same floor with an equal or
--    greater capacity?
-- ============================================================
-- Business question:
--   If my usual requested space (the one I book most
--   frequently) is currently "Under Maintenance" or
--   "Temporarily Closed", what are the top 3 alternative
--   spaces on the same floor with an equal or greater
--   capacity?
--
-- Target user(s):
--   Student
--
-- Why useful:
--   Students often develop a routine around a "go-to" study
--   room or lab. When they arrive and find it closed for
--   maintenance or renovation, they waste time wandering
--   floor-by-floor looking for backup space. This query learns
--   which room the student uses most from their booking
--   history, checks if it is unavailable, and proactively
--   recommends up to 3 alternatives on the same floor with at
--   least as many seats — ranked by capacity. This turns a
--   frustrating walk-in discovery into a one-click
--   recommendation.
-- ============================================================

DECLARE @student_email    NVARCHAR(255) = N't06.student1@university.edu';
DECLARE @blocked_statuses VARCHAR(100)  = 'under_maintenance, temporarily_closed';

WITH
student_user AS (
    SELECT [user_id]
    FROM [dbo].[users]
    WHERE [email] = @student_email
),
usual_space AS (
    SELECT TOP 1
        s.[space_id],
        s.[space_code],
        s.[space_name],
        s.[space_type],
        s.[building],
        s.[floor],
        s.[room_number],
        s.[capacity],
        s.[current_status],
        COUNT(*) AS [times_booked]
    FROM [dbo].[bookings] b
    INNER JOIN [dbo].[spaces] s ON b.[space_id] = s.[space_id]
    WHERE b.[requester_id] = (SELECT [user_id] FROM [student_user])
      AND b.[is_deleted] = 0
    GROUP BY
        s.[space_id], s.[space_code], s.[space_name], s.[space_type],
        s.[building], s.[floor], s.[room_number], s.[capacity], s.[current_status]
    ORDER BY COUNT(*) DESC
),
alternatives AS (
    SELECT TOP 3
        s.[space_code],
        s.[space_name],
        s.[space_type],
        s.[building],
        s.[floor],
        s.[room_number],
        s.[capacity],
        ROW_NUMBER() OVER (ORDER BY s.[capacity]) AS [alt_rank]
    FROM [dbo].[spaces] s
    WHERE s.[building] = (SELECT [building] FROM [usual_space])
      AND s.[floor] = (SELECT [floor] FROM [usual_space])
      AND s.[space_id] <> (SELECT [space_id] FROM [usual_space])
      AND s.[capacity] >= (SELECT [capacity] FROM [usual_space])
      AND s.[current_status] = 'available'
    ORDER BY s.[capacity]
)
-- Branch 1: No booking history
SELECT
    NULL                      AS [space_code],
    N'No booking history found for this student.' AS [space_name],
    NULL                      AS [building],
    NULL                      AS [floor],
    NULL                      AS [room_number],
    NULL                      AS [capacity],
    NULL                      AS [current_status],
    NULL                      AS [times_booked],
    N'Verify the student email and try again.' AS [recommendation],
    NULL                      AS [alt_rank],
    NULL                      AS [alt_reason]
WHERE (SELECT COUNT(*) FROM [usual_space]) = 0

UNION ALL

-- Branch 2: Usual space is available (not blocked)
SELECT
    us.[space_code],
    us.[space_name],
    us.[building],
    us.[floor],
    us.[room_number],
    us.[capacity],
    us.[current_status],
    us.[times_booked],
    N'Your usual space — available' AS [recommendation],
    NULL                      AS [alt_rank],
    NULL                      AS [alt_reason]
FROM [usual_space] us
WHERE us.[current_status] NOT IN (
    SELECT [value] FROM STRING_SPLIT(@blocked_statuses, ',')
)
  AND (SELECT COUNT(*) FROM [usual_space]) > 0

UNION ALL

-- Branch 3: Usual space is blocked → show alternatives
SELECT
    a.[space_code],
    a.[space_name],
    a.[building],
    a.[floor],
    a.[room_number],
    a.[capacity],
    N'available'              AS [current_status],
    NULL                      AS [times_booked],
    N'Alternative #' + CAST(a.[alt_rank] AS NVARCHAR(10))
                              AS [recommendation],
    a.[alt_rank],
    N'Capacity ' + CAST(a.[capacity] AS NVARCHAR(10))
    + N' ≥ ' + CAST((SELECT us2.[capacity] FROM [usual_space] us2) AS NVARCHAR(10))
    + N' (your usual room)'   AS [alt_reason]
FROM [alternatives] a
WHERE EXISTS (
    SELECT 1 FROM [usual_space] us
    WHERE us.[current_status] IN (
        SELECT [value] FROM STRING_SPLIT(@blocked_statuses, ',')
    )
)
  AND (SELECT COUNT(*) FROM [alternatives]) > 0

UNION ALL

-- Branch 4: Usual space is blocked but no alternatives found
SELECT
    us.[space_code],
    us.[space_name],
    us.[building],
    us.[floor],
    us.[room_number],
    us.[capacity],
    us.[current_status],
    us.[times_booked],
    N'Your usual space is UNAVAILABLE — no alternatives on this floor with >= capacity'
                              AS [recommendation],
    NULL                      AS [alt_rank],
    NULL                      AS [alt_reason]
FROM [usual_space] us
WHERE us.[current_status] IN (
    SELECT [value] FROM STRING_SPLIT(@blocked_statuses, ',')
)
  AND (SELECT COUNT(*) FROM [alternatives]) = 0
  AND (SELECT COUNT(*) FROM [usual_space]) > 0
ORDER BY [alt_rank];
GO

-- ============================================================
-- Query 14: Lab availability by day of week
-- ============================================================
-- --student-name: Cao Quang Hung
-- --target-user: student
-- --business-question: Based on booking history from the past
--    year, which days of the week have the most available
--    project and computer laboratories?
-- ============================================================
-- Business question:
--   Based on booking history from the past year, which days
--   of the week have the most available project and computer
--   laboratories?
--
-- Target user(s):
--   Student
--
-- Why useful:
--   A student looking for a lab to work in can quickly see
--   which days of the week have the most free lab spaces,
--   helping them plan their visit on a high-availability day.
-- ============================================================

DECLARE @space_types   VARCHAR(255) = 'computer_lab,project_lab';
DECLARE @lookback_year INT          = 1;

WITH lab_spaces AS (
    SELECT [space_id]
    FROM [dbo].[spaces]
    WHERE [space_type] IN (
        SELECT [value] FROM STRING_SPLIT(@space_types, ',')
    )
),
total_labs AS (
    SELECT COUNT(*) AS [cnt] FROM [lab_spaces]
),
booked_days AS (
    SELECT DISTINCT
        (DATEPART(WEEKDAY, b.[requested_start_time]) + @@DATEFIRST + 6) % 7 + 1
            AS [dow_num],
        b.[space_id]
    FROM [dbo].[bookings] b
    WHERE b.[space_id] IN (SELECT [space_id] FROM [lab_spaces])
      AND b.[is_deleted] = 0
      AND b.[status] IN ('approved', 'checked_in', 'completed')
      AND b.[requested_start_time] >= DATEADD(YEAR, -@lookback_year, GETDATE())
      AND b.[requested_start_time] < GETDATE()
)
SELECT
    d.[day_name]                              AS [day_of_week],
    t.[cnt] - COUNT(DISTINCT bd.[space_id])   AS [available_labs],
    t.[cnt]                                   AS [total_labs],
    CASE
        WHEN COUNT(DISTINCT bd.[space_id]) = 0 THEN N'All labs available'
        ELSE N'Reduced availability'
    END                                       AS [status]
FROM (VALUES
    (1, N'Monday'), (2, N'Tuesday'), (3, N'Wednesday'),
    (4, N'Thursday'), (5, N'Friday'), (6, N'Saturday'),
    (7, N'Sunday')
) AS d([dow_num], [day_name])
CROSS JOIN [total_labs] t
LEFT JOIN [booked_days] bd ON bd.[dow_num] = d.[dow_num]
GROUP BY d.[dow_num], d.[day_name], t.[cnt]
ORDER BY d.[dow_num];
GO

-- ============================================================
-- Query 15: Department admin — upcoming approved bookings
--            by department members
-- ============================================================
-- --student-name: Cao Quang Hung
-- --target-user: department_administrator
-- --business-question: What are the upcoming approved bookings
--    made by users in my department for the next two weeks?
-- ============================================================
-- Business question:
--   What are the upcoming approved bookings made by users in
--   my department for the next two weeks?
--
-- Target user(s):
--   Department Administrator
--
-- Why useful:
--   Department Administrators can monitor all approved upcoming
--   bookings made by members of their department — seeing who
--   booked which space, for what purpose, and when. This helps
--   them plan around department events, identify scheduling
--   conflicts, and ensure fair resource allocation within the
--   department.
-- ============================================================

DECLARE @admin_email    NVARCHAR(255) = N't06.deptadmin1@university.edu';
DECLARE @lookahead_days INT           = 14;

WITH admin_dept AS (
    SELECT [department_id]
    FROM [dbo].[users]
    WHERE [email] = @admin_email
      AND [role] = 'department_admin'
)
SELECT
    b.[booking_id],
    u.[full_name]            AS [requester_name],
    u.[email]                AS [requester_email],
    u.[role]                 AS [requester_role],
    s.[space_code],
    s.[space_name],
    s.[space_type],
    s.[building],
    s.[floor],
    s.[room_number],
    s.[capacity],
    b.[purpose],
    b.[requested_start_time],
    b.[requested_end_time],
    b.[expected_participants],
    DATEDIFF(DAY, GETDATE(), b.[requested_start_time])
                             AS [days_until_start]
FROM [dbo].[bookings] b
INNER JOIN [dbo].[spaces] s ON b.[space_id] = s.[space_id]
INNER JOIN [dbo].[users] u ON b.[requester_id] = u.[user_id]
WHERE u.[department_id] = (SELECT [department_id] FROM [admin_dept])
  AND b.[is_deleted] = 0
  AND b.[status] = 'approved'
  AND b.[requested_start_time] >= GETDATE()
  AND b.[requested_start_time] < DATEADD(DAY, @lookahead_days, GETDATE())
ORDER BY b.[requested_start_time];
GO
