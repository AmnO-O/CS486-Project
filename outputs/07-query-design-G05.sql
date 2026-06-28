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
-- Query 6: Rejected booking audit trail for a professor
-- --student-name: Pham Huu Nam
-- --target-users: facility_manager
-- --business-question: Professor submitted consecutive booking
--    requests that were all rejected. Need complete audit trail
--    including refusal reasons, timestamps, and staff who
--    processed them.
-- ============================================================
-- Business question:
--   A professor submitted consecutive booking requests that
--   were all rejected. What is the complete audit trail —
--   including refusal reasons, decision timestamps, and the
--   staff members who processed each rejection?
--
-- Target user(s):
--   Facility Manager
--
-- Why useful:
--   Facility managers need to investigate potential bias,
--   miscommunication, or procedural issues in booking
--   decisions. This query surfaces a full chronological audit
--   trail of rejections for a specific user, enabling
--   transparent review and process improvement.
-- ============================================================

-- Filter by user_id (surrogate key) — full_name is shown for
-- readability only; the filter uses user_id for precision.
DECLARE @requester_id INT = 2;   -- Prof. Robert Chen (lecturer)

SELECT
    b.booking_id,
    s.space_code,
    s.space_name,
    b.requested_start_time,
    b.requested_end_time,
    b.purpose,
    b.status,
    b.rejection_reason,
    b.decision_time,
    b.decision_note,
    approver.full_name     AS processed_by,
    approver.role          AS processor_role
FROM [dbo].[bookings] b
INNER JOIN [dbo].[spaces] s ON b.space_id = s.space_id
INNER JOIN [dbo].[users] approver ON b.approver_id = approver.user_id
WHERE b.requester_id = @requester_id
  AND b.status = 'rejected'
  AND b.is_deleted = 0
ORDER BY b.decision_time DESC;
-- Note: returns zero rows if no rejections exist for the
-- specified user. Logic is correct; seed data includes
-- exactly one rejected booking (booking 8) for lecturer 2.
GO

-- ============================================================
-- Query 7: Risk profile — spaces with recent resolved
-- maintenance and their upcoming bookings
-- --student-name: Pham Huu Nam
-- --target-users: facility_manager
-- --business-question: Which spaces have encountered resolved
--    maintenance issues within the past six months, and what
--    are their upcoming approved bookings for the next seven
--    days? Facility manager needs a comprehensive risk profile
--    to identify rooms with a history of failure and leverage
--    gap times for preventive maintenance.
-- ============================================================
-- Business question:
--   Which spaces had resolved maintenance issues in the last
--   six months, and what approved bookings are coming up for
--   them in the next seven days? Where are the gaps between
--   bookings that could be used for preventive maintenance?
--
-- Target user(s):
--   Facility Manager
--
-- Why useful:
--   Provides a consolidated risk profile so facility managers
--   can proactively schedule preventive maintenance during
--   time gaps, reducing the chance of emergency breakdowns
--   that disrupt teaching and events.
-- ============================================================

DECLARE @risk_months     INT = 6;   -- look back for resolved maintenance
DECLARE @lookahead_days  INT = 7;   -- look forward for upcoming bookings
DECLARE @now             DATETIME2 = GETDATE();

WITH risk_spaces AS (
    -- Spaces with resolved maintenance in the risk window
    SELECT DISTINCT
        m.space_id,
        s.space_code,
        s.space_name,
        s.building,
        s.current_status
    FROM [dbo].[maintenances] m
    INNER JOIN [dbo].[spaces] s ON m.space_id = s.space_id
    WHERE m.status = 'resolved'
      AND m.is_deleted = 0
      AND m.completion_time >= DATEADD(MONTH, -@risk_months, @now)
),
recent_maintenance AS (
    -- Latest resolved maintenance detail per risk space
    SELECT
        rs.space_id,
        m.problem_description,
        m.completion_time,
        m.result_note,
        ROW_NUMBER() OVER (
            PARTITION BY m.space_id ORDER BY m.completion_time DESC
        ) AS rn
    FROM risk_spaces rs
    INNER JOIN [dbo].[maintenances] m ON rs.space_id = m.space_id
    WHERE m.status = 'resolved'
      AND m.is_deleted = 0
      AND m.completion_time >= DATEADD(MONTH, -@risk_months, @now)
),
upcoming_bookings AS (
    -- Approved bookings in the look-ahead window for risk spaces
    SELECT
        rs.space_id,
        b.booking_id,
        b.requested_start_time,
        b.requested_end_time,
        b.purpose,
        b.expected_participants
    FROM risk_spaces rs
    INNER JOIN [dbo].[bookings] b ON rs.space_id = b.space_id
    WHERE b.status = 'approved'
      AND b.is_deleted = 0
      AND b.requested_start_time >= @now
      AND b.requested_end_time <= DATEADD(DAY, @lookahead_days, @now)
)
SELECT
    rs.space_code,
    rs.space_name,
    rs.building,
    rs.current_status,
    rm.problem_description  AS most_recent_issue,
    rm.completion_time      AS issue_resolved_at,
    rm.result_note          AS resolution_summary,
    ub.requested_start_time AS next_booking_start,
    ub.requested_end_time   AS next_booking_end,
    ub.purpose              AS booking_purpose
FROM risk_spaces rs
LEFT JOIN recent_maintenance rm ON rs.space_id = rm.space_id AND rm.rn = 1
LEFT JOIN upcoming_bookings ub ON rs.space_id = ub.space_id
ORDER BY rs.space_code, ub.requested_start_time;
-- Note: may return zero rows if no resolved maintenance exists
-- in the risk window or no approved bookings exist in the
-- look-ahead window. Seed data includes resolved maintenance on
-- space 6 (computer lab, completed 2026-06-06), which is within
-- 6 months of current date (2026-06-28). No approved bookings
-- for space 6 fall within the next 7 days (pending booking 5
-- is on 2026-07-05 — outside 7-day window from 2026-06-28).
GO

-- ============================================================
-- Query 8: Department no-show rate analysis for the semester
-- --student-name: Pham Huu Nam
-- --target-users: facility_manager
-- --business-question: During high-demand weeks, certain
--    departments habitually book multiple spaces "just in case"
--    but fail to check in, creating artificial room shortages.
--    Facility Manager needs a report identifying departments
--    with the highest No-Show rates this semester to enforce
--    strict reservation penalties.
-- ============================================================
-- Business question:
--   Which departments have the highest no-show rate this
--   semester? How many bookings were checked in/completed vs.
--   marked as no-show, broken down by department?
--
-- Target user(s):
--   Facility Manager
--
-- Why useful:
--   Reveals departments that systematically over-reserve spaces
--   without using them, causing artificial shortages. Enables
--   data-driven policy enforcement such as caps or penalties
--   on departments with above-threshold no-show rates.
-- ============================================================

DECLARE @semester_start DATETIME2 = '2026-06-01 00:00:00'; -- semester start
DECLARE @semester_end   DATETIME2 = '2026-08-31 23:59:59'; -- semester end
DECLARE @threshold_pct  DECIMAL(5,2) = 0;   -- minimum no-show % to appear

WITH booking_stats AS (
    SELECT
        d.department_id,
        d.name AS department_name,
        COUNT(*) AS total_past_bookings,
        SUM(CASE WHEN b.status = 'no_show' THEN 1 ELSE 0 END) AS no_show_count,
        SUM(CASE WHEN b.status IN ('completed', 'checked_in') THEN 1 ELSE 0 END) AS attended_count
    FROM [dbo].[bookings] b
    INNER JOIN [dbo].[users] u ON b.requester_id = u.user_id
    INNER JOIN [dbo].[departments] d ON u.department_id = d.department_id
    WHERE b.is_deleted = 0
      AND b.requested_start_time >= @semester_start
      AND b.requested_start_time < @semester_end
      AND b.status IN ('completed', 'checked_in', 'no_show')
    GROUP BY d.department_id, d.name
)
SELECT
    department_name,
    total_past_bookings,
    no_show_count,
    attended_count,
    CASE
        WHEN total_past_bookings > 0
        THEN CAST(100.0 * no_show_count / total_past_bookings AS DECIMAL(5,1))
        ELSE 0
    END AS no_show_rate_pct
FROM booking_stats
WHERE total_past_bookings > 0
  AND CAST(100.0 * no_show_count / total_past_bookings AS DECIMAL(5,1)) >= @threshold_pct
ORDER BY no_show_rate_pct DESC, total_past_bookings DESC;
-- Note: returns zero rows if no past bookings exist in the
-- semester window. Seed data includes one no-show (booking 4,
-- student1, CS dept) and one completed (booking 3, student1,
-- CS dept), giving CS dept a 50% no-show rate.
GO

-- ============================================================
-- Query 9: Competitor usage analysis for fair allocation
-- --student-name: Pham Huu Nam
-- --target-users: facility_manager
-- --business-question: When multiple students submit competing
--    booking requests for the same meeting room and time slot,
--    how many cumulative hours has each requester actually used
--    university shared spaces during the current month? The
--    department administrator needs this information to support
--    fair allocation by prioritizing users who have received
--    less access to shared facilities.
-- ============================================================
-- Business question:
--   When multiple students submit competing booking requests
--   for the same meeting room and time slot, how many cumulative
--   hours has each requester actually used university shared
--   spaces during the current month? The department administrator
--   needs this information to support fair allocation by
--   prioritizing users who have received less access to shared
--   facilities.
--
-- Target user(s):
--   Facility Manager
--
-- Why useful:
--   Enables data-driven fair allocation of contested meeting
--   rooms by surfacing cumulative usage per requester. Users
--   who have consumed fewer shared-space hours can be
--   prioritised, preventing a minority from monopolising
--   limited facilities.
-- ============================================================

DECLARE @target_space_id INT        = 9;   -- T06-SW-001 (Student Workspace)
DECLARE @slot_start     DATETIME2   = '2026-07-12 10:00:00';
DECLARE @slot_end       DATETIME2   = '2026-07-12 12:00:00';

WITH competing_requesters AS (
    SELECT DISTINCT b.requester_id
    FROM [dbo].[bookings] b
    WHERE b.space_id = @target_space_id
      AND b.is_deleted = 0
      AND b.status IN ('pending', 'approved')
      AND b.requested_start_time < @slot_end
      AND b.requested_end_time > @slot_start
),
monthly_usage AS (
    SELECT
        b.requester_id,
        SUM(
            CASE
                WHEN b.status = 'completed'
                    THEN DATEDIFF(MINUTE, b.actual_start_time, b.actual_end_time)
                WHEN b.status = 'checked_in' AND b.actual_end_time IS NOT NULL
                    THEN DATEDIFF(MINUTE, b.actual_start_time, b.actual_end_time)
                WHEN b.status = 'checked_in' AND b.actual_end_time IS NULL
                    THEN DATEDIFF(MINUTE, b.actual_start_time, GETDATE())
                ELSE 0
            END
        ) / 60.0 AS cumulative_hours
    FROM [dbo].[bookings] b
    WHERE b.requester_id IN (SELECT requester_id FROM competing_requesters)
      AND b.is_deleted = 0
      AND b.status IN ('completed', 'checked_in')
      AND b.actual_start_time >= DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1)
      AND b.actual_start_time < DATEADD(MONTH, 1, DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1))
    GROUP BY b.requester_id
)
SELECT
    u.user_id,
    u.full_name,
    u.email,
    d.name                              AS department,
    u.role,
    COALESCE(mu.cumulative_hours, 0)    AS cumulative_hours_this_month
FROM competing_requesters cr
INNER JOIN [dbo].[users] u ON cr.requester_id = u.user_id
INNER JOIN [dbo].[departments] d ON u.department_id = d.department_id
LEFT JOIN monthly_usage mu ON cr.requester_id = mu.requester_id
ORDER BY
    CASE WHEN mu.cumulative_hours IS NULL THEN 1 ELSE 0 END,
    mu.cumulative_hours ASC;
-- Note: returns zero rows if no pending/approved bookings overlap
-- the specified space and time slot. Seed data includes a cancelled
-- booking (booking 11) on space 9 (2026-07-12 10:00-12:00), but
-- 'cancelled' status is excluded from competing_requesters. Logic
-- is correct for real-world use when multiple students submit
-- overlapping pending/approved requests.
GO

-- ============================================================
-- Query 10: Room-type utilization summary for the semester
-- --student-name: Pham Huu Nam
-- --target-users: facility_manager
-- --business-question: Provide a summary of the past semester
--    regarding which room type (classroom, laboratory,
--    meeting_room) was most frequently requested, including its
--    successful approval rate and the number of unique users
--    attracted, in order to evaluate potential expansion or
--    consolidation.
-- ============================================================
-- Business question:
--   Which space type had the highest request volume last
--   semester, what was its approval rate, and how many unique
--   users requested each type? This guides decisions on
--   expanding high-demand types or consolidating underused
--   ones.
--
-- Target user(s):
--   Facility Manager
--
-- Why useful:
--   Strategic planning requires data on actual demand by space
--   category. Approval rate signals whether supply meets demand;
--   unique user count reveals breadth of reliance. Together
--   they justify capital investments or space reallocation.
-- ============================================================

DECLARE @semester_start DATETIME2 = '2026-06-01 00:00:00';
DECLARE @semester_end   DATETIME2 = '2026-08-31 23:59:59';

SELECT
    s.space_type,
    COUNT(*)                          AS total_requests,
    SUM(CASE WHEN b.status IN ('approved','checked_in','completed')
             THEN 1 ELSE 0 END)       AS successful_count,
    ROUND(
        100.0 * SUM(CASE WHEN b.status IN ('approved','checked_in','completed')
                         THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0),
        1
    )                                 AS approval_rate_pct,
    COUNT(DISTINCT b.requester_id)    AS unique_users
FROM [dbo].[bookings] b
INNER JOIN [dbo].[spaces] s ON b.space_id = s.space_id
WHERE b.is_deleted = 0
  AND b.requested_start_time >= @semester_start
  AND b.requested_start_time < @semester_end
  AND b.status != 'cancelled'
GROUP BY s.space_type
ORDER BY total_requests DESC, approval_rate_pct DESC;
-- Note: returns zero rows if no bookings exist in the semester
-- window. Seed data covers multiple space types across various
-- bookings (auditorium, classroom, computer_lab, project_lab,
-- student_workspace) within the Jun–Aug 2026 window.
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

-- ============================================================
-- Query 16: Available computer/project lab for tutorial session
-- ============================================================
-- --student-name: Tran Dinh Quoc Thang
-- --target-users: teaching_assistant
-- --business-question: Which computer_lab or project_lab spaces
--    are available for a tutorial/project session in a requested
--    time slot with enough Computer workstations?
-- ============================================================
-- Business question:
--   Which computer_lab or project_lab spaces are available in a
--   given time slot, have enough Computer workstations for
--   expected participants, exclude unavailable spaces and
--   conflicting confirmed bookings, and optionally include a
--   Projector for presentations?
--
-- Target user(s):
--   Teaching Assistant
--
-- Why useful:
--   Teaching Assistants need to reserve labs that can actually
--   support a tutorial or project session. This query checks
--   capacity, workstation count, optional projector availability,
--   live space status, confirmed booking conflicts, and unresolved
--   maintenance conflicts in one reusable availability search.
-- ============================================================

DECLARE @slot_start             DATETIME2    = '2026-07-05 13:00:00';
DECLARE @slot_end               DATETIME2    = '2026-07-05 15:00:00';
DECLARE @expected_participants  INT          = 20;
DECLARE @minimum_computers      INT          = 20;
DECLARE @require_projector      BIT          = 1;
DECLARE @space_type_computer    VARCHAR(50)  = 'computer_lab';
DECLARE @space_type_project     VARCHAR(50)  = 'project_lab';
DECLARE @space_status_available VARCHAR(50)  = 'available';
DECLARE @status_approved        VARCHAR(50)  = 'approved';
DECLARE @status_checked_in      VARCHAR(50)  = 'checked_in';
DECLARE @status_completed       VARCHAR(50)  = 'completed';
DECLARE @maint_open             VARCHAR(50)  = 'open';
DECLARE @maint_in_progress      VARCHAR(50)  = 'in_progress';
DECLARE @facility_computer      NVARCHAR(255) = N'Computer';
DECLARE @facility_projector     NVARCHAR(255) = N'Projector';

WITH equipment_summary AS (
    SELECT
        sf.[space_id],
        SUM(CASE WHEN f.[name] = @facility_computer
                 THEN COALESCE(sf.[quantity], 1) ELSE 0 END) AS [computer_count],
        MAX(CASE WHEN f.[name] = @facility_projector
                 THEN 1 ELSE 0 END) AS [has_projector]
    FROM [dbo].[space_facilities] sf
    INNER JOIN [dbo].[facilities] f
        ON sf.[facility_id] = f.[facility_id]
    GROUP BY sf.[space_id]
)
SELECT
    s.[space_code],
    s.[space_name],
    s.[space_type],
    s.[building],
    s.[floor],
    s.[room_number],
    s.[capacity],
    es.[computer_count],
    CASE WHEN es.[has_projector] = 1 THEN N'Yes' ELSE N'No' END AS [projector_available]
FROM [dbo].[spaces] s
INNER JOIN equipment_summary es
    ON s.[space_id] = es.[space_id]
WHERE s.[space_type] IN (@space_type_computer, @space_type_project)
  AND s.[current_status] = @space_status_available
  AND s.[capacity] >= @expected_participants
  AND es.[computer_count] >= @minimum_computers
  AND (@require_projector = 0 OR es.[has_projector] = 1)
  AND NOT EXISTS (
      SELECT 1
      FROM [dbo].[bookings] b
      WHERE b.[space_id] = s.[space_id]
        AND b.[is_deleted] = 0
        AND b.[status] IN (@status_approved, @status_checked_in, @status_completed)
        AND @slot_start < b.[requested_end_time]
        AND @slot_end > b.[requested_start_time]
  )
  AND NOT EXISTS (
      SELECT 1
      FROM [dbo].[maintenances] m
      WHERE m.[space_id] = s.[space_id]
        AND m.[is_deleted] = 0
        AND m.[status] IN (@maint_open, @maint_in_progress)
        AND m.[start_time] < @slot_end
        AND (m.[completion_time] IS NULL OR m.[completion_time] > @slot_start)
  )
ORDER BY s.[building], s.[floor], s.[room_number], s.[space_code];
-- Note: defaults match T06-LAB-001: computer_lab, available,
-- capacity 30, 20 computers, projector, and no confirmed booking
-- or unresolved maintenance conflict during the requested slot.
GO

-- ============================================================
-- Query 17: Lecturer's personal booking timeline for a semester
-- ============================================================
-- --student-name: Tran Dinh Quoc Thang
-- --target-users: lecturer
-- --business-question: Show my own booking timeline within a
--    semester date range, including all statuses and details.
-- ============================================================
-- Business question:
--   A lecturer wants to see their own complete booking timeline
--   within a given semester, covering all statuses (pending,
--   approved, checked_in, completed, rejected, cancelled). The
--   result includes room details, purpose, requested time,
--   decision note, rejection reason, and approver name.
--
-- Target user(s):
--   Lecturer
--
-- Why useful:
--   A lecturer can review every request in chronological order,
--   including the approval outcome and session details. This is
--   useful for planning classes, checking rejected requests, and
--   confirming whether approved sessions still need action.
-- ============================================================

DECLARE @lecturer_email NVARCHAR(255) = N't06.lecturer1@university.edu';
-- Note: email is unique by UQ_users_email, so it is safe for lookup.
DECLARE @semester_start DATETIME2 = '2026-06-01 00:00:00';
DECLARE @semester_end   DATETIME2 = '2026-08-31 23:59:59';

WITH lecturer_account AS (
    SELECT u.[user_id], u.[full_name], u.[email]
    FROM [dbo].[users] u
    WHERE u.[email] = @lecturer_email
)
SELECT
    b.[booking_id],
    la.[full_name]                   AS [lecturer_name],
    s.[space_code],
    s.[space_name],
    s.[space_type],
    s.[building],
    s.[floor],
    s.[room_number],
    b.[purpose],
    b.[requested_start_time],
    b.[requested_end_time],
    DATEDIFF(MINUTE, b.[requested_start_time], b.[requested_end_time])
                                       AS [scheduled_minutes],
    b.[expected_participants],
    b.[status],
    approver.[full_name]             AS [approver_name],
    b.[decision_time],
    b.[decision_note],
    b.[rejection_reason],
    b.[actual_start_time],
    b.[actual_end_time]
FROM lecturer_account la
INNER JOIN [dbo].[bookings] b
    ON la.[user_id] = b.[requester_id]
INNER JOIN [dbo].[spaces] s
    ON b.[space_id] = s.[space_id]
LEFT JOIN [dbo].[users] approver
    ON b.[approver_id] = approver.[user_id]
WHERE b.[is_deleted] = 0
  AND b.[requested_start_time] >= @semester_start
  AND b.[requested_start_time] < @semester_end
ORDER BY b.[requested_start_time], b.[booking_id];
-- Note: seed data includes Prof. Robert Chen with one rejected
-- computer_lab request and two approved auditorium requests in
-- the June-August 2026 semester window.
GO

-- ============================================================
-- Query 18: TA's completed lab session history for a semester
-- ============================================================
-- --student-name: Tran Dinh Quoc Thang
-- --target-users: teaching_assistant
-- --business-question: Show my own completed computer_lab or
--    project_lab sessions within a semester date range.
-- ============================================================
-- Business question:
--   A Teaching Assistant wants to review their completed lab
--   sessions (computer_lab or project_lab) within a given
--   semester, including actual start/end time, actual duration,
--   expected participants, space condition notes (initial and
--   final), usage notes, and room details.
--
-- Target user(s):
--   Teaching Assistant
--
-- Why useful:
--   Teaching Assistants can produce a focused record of past lab
--   sessions for teaching reports or issue follow-up. The result
--   includes the actual session duration, check-in staff, room
--   condition notes, usage notes, and available facility summary.
-- ============================================================

DECLARE @ta_email             NVARCHAR(255) = N't06.ta1@university.edu';
-- Note: email is unique by UQ_users_email, so it is safe for lookup.
DECLARE @semester_start       DATETIME2 = '2026-06-01 00:00:00';
DECLARE @semester_end         DATETIME2 = '2026-08-31 23:59:59';
DECLARE @status_completed     VARCHAR(50) = 'completed';
DECLARE @space_type_computer  VARCHAR(50) = 'computer_lab';
DECLARE @space_type_project   VARCHAR(50) = 'project_lab';

WITH ta_account AS (
    SELECT u.[user_id], u.[full_name], u.[email]
    FROM [dbo].[users] u
    WHERE u.[email] = @ta_email
)
SELECT
    b.[booking_id],
    ta.[full_name] AS [teaching_assistant],
    s.[space_code],
    s.[space_name],
    s.[space_type],
    s.[building],
    s.[floor],
    s.[room_number],
    b.[purpose],
    b.[expected_participants],
    b.[actual_start_time],
    b.[actual_end_time],
    DATEDIFF(MINUTE, b.[actual_start_time], b.[actual_end_time])
        AS [actual_duration_minutes],
    checked_by.[full_name] AS [checked_in_by_staff],
    b.[initial_condition],
    b.[final_condition],
    b.[usage_notes],
    facilities.[facility_list]
FROM ta_account ta
INNER JOIN [dbo].[bookings] b
    ON ta.[user_id] = b.[requester_id]
INNER JOIN [dbo].[spaces] s
    ON b.[space_id] = s.[space_id]
LEFT JOIN [dbo].[users] checked_by
    ON b.[checked_in_by] = checked_by.[user_id]
OUTER APPLY (
    SELECT STRING_AGG(
               CONCAT(f.[name], N' x', COALESCE(CONVERT(NVARCHAR(20), sf.[quantity]), N'1')),
               N', '
           ) AS [facility_list]
    FROM [dbo].[space_facilities] sf
    INNER JOIN [dbo].[facilities] f
        ON sf.[facility_id] = f.[facility_id]
    WHERE sf.[space_id] = s.[space_id]
) facilities
WHERE b.[is_deleted] = 0
  AND b.[status] = @status_completed
  AND s.[space_type] IN (@space_type_computer, @space_type_project)
  AND b.[actual_start_time] >= @semester_start
  AND b.[actual_end_time] < @semester_end
ORDER BY b.[actual_end_time] DESC, b.[booking_id] DESC;
-- Note: returns zero rows if the TA has no completed lab sessions
-- in the selected semester. Current seed data has a future pending
-- TA lab request, so the query logic is valid even when the default
-- result set is empty.
GO

-- ============================================================
-- Query 19: Booking approval lead-time analysis by purpose,
--            space type, and decision status
-- ============================================================
-- --student-name: Tran Dinh Quoc Thang
-- --target-users: lecturer
-- --business-question: Analyze my booking approval lead time
--    by purpose, space type, and final decision status.
-- ============================================================
-- Business question:
--   A lecturer wants to analyze how long their booking
--   approvals/rejections take, broken down by purpose, space
--   type, and final decision status. Lead time is calculated
--   from created_at (submission) to decision_time.
--
-- Target user(s):
--   Lecturer
--
-- Why useful:
--   Lead-time analysis helps lecturers understand how early they
--   should submit requests and whether some purposes or spaces
--   receive slower decisions. The warning count also exposes seed
--   rows whose generated audit timestamp is later than the stored
--   decision timestamp.
-- ============================================================

DECLARE @lecturer_email  NVARCHAR(255) = N't06.lecturer1@university.edu';
-- Note: email is unique by UQ_users_email, so it is safe for lookup.
DECLARE @semester_start  DATETIME2 = '2026-06-01 00:00:00';
DECLARE @semester_end    DATETIME2 = '2026-08-31 23:59:59';
DECLARE @status_approved VARCHAR(50) = 'approved';
DECLARE @status_rejected VARCHAR(50) = 'rejected';

WITH lecturer_account AS (
    SELECT u.[user_id]
    FROM [dbo].[users] u
    WHERE u.[email] = @lecturer_email
),
decided_bookings AS (
    SELECT
        s.[space_type],
        b.[purpose],
        b.[status],
        DATEDIFF(MINUTE, b.[created_at], b.[decision_time]) AS [lead_minutes],
        CASE WHEN b.[decision_time] < b.[created_at] THEN 1 ELSE 0 END
            AS [decision_before_created_flag]
    FROM lecturer_account la
    INNER JOIN [dbo].[bookings] b
        ON la.[user_id] = b.[requester_id]
    INNER JOIN [dbo].[spaces] s
        ON b.[space_id] = s.[space_id]
    WHERE b.[is_deleted] = 0
      AND b.[status] IN (@status_approved, @status_rejected)
      AND b.[decision_time] IS NOT NULL
      AND b.[requested_start_time] >= @semester_start
      AND b.[requested_start_time] < @semester_end
)
SELECT
    db.[space_type],
    db.[purpose],
    db.[status] AS [decision_status],
    COUNT(*) AS [booking_count],
    CAST(MIN(db.[lead_minutes]) / 60.0 AS DECIMAL(10,2))
        AS [min_lead_time_hours],
    CAST(AVG(CAST(db.[lead_minutes] AS DECIMAL(10,2))) / 60.0 AS DECIMAL(10,2))
        AS [avg_lead_time_hours],
    CAST(MAX(db.[lead_minutes]) / 60.0 AS DECIMAL(10,2))
        AS [max_lead_time_hours],
    SUM(db.[decision_before_created_flag])
        AS [timestamp_warning_count]
FROM decided_bookings db
GROUP BY db.[space_type], db.[purpose], db.[status]
ORDER BY db.[space_type], db.[purpose], db.[status];
-- Note: seed data uses GETDATE() for created_at while decision_time
-- is fixed in June/July 2026, so timestamp_warning_count can be
-- nonzero in the sample database. In live data, created_at should
-- represent the actual submission timestamp.
GO

-- ============================================================
-- Query 20: Pre-session readiness check - upcoming lab bookings
--            with space or maintenance issues
-- ============================================================
-- --student-name: Tran Dinh Quoc Thang
-- --target-users: teaching_assistant
-- --business-question: Which of my approved upcoming
--    computer_lab/project_lab bookings starting within X days
--    have a space that is not available or has unresolved
--    maintenance?
-- ============================================================
-- Business question:
--   A Teaching Assistant wants a proactive alert showing which
--   of their approved upcoming lab bookings (starting within
--   X days) might be disrupted because the space is not
--   currently available or has overlapping unresolved
--   maintenance.
--
-- Target user(s):
--   Teaching Assistant
--
-- Why useful:
--   This query acts as an early warning list for lab sessions
--   that may need a backup room or facility-staff follow-up. It
--   checks the current space status and unresolved maintenance
--   that overlaps the approved booking window.
-- ============================================================

DECLARE @ta_email             NVARCHAR(255) = N't06.ta1@university.edu';
-- Note: email is unique by UQ_users_email, so it is safe for lookup.
DECLARE @as_of                DATETIME2 = GETDATE();
DECLARE @lookahead_days       INT = 30;
DECLARE @status_approved      VARCHAR(50) = 'approved';
DECLARE @space_status_ready   VARCHAR(50) = 'available';
DECLARE @space_type_computer  VARCHAR(50) = 'computer_lab';
DECLARE @space_type_project   VARCHAR(50) = 'project_lab';
DECLARE @maint_open           VARCHAR(50) = 'open';
DECLARE @maint_in_progress    VARCHAR(50) = 'in_progress';

WITH ta_account AS (
    SELECT u.[user_id]
    FROM [dbo].[users] u
    WHERE u.[email] = @ta_email
),
upcoming_lab_bookings AS (
    SELECT
        b.[booking_id],
        b.[space_id],
        b.[purpose],
        b.[requested_start_time],
        b.[requested_end_time],
        b.[expected_participants]
    FROM ta_account ta
    INNER JOIN [dbo].[bookings] b
        ON ta.[user_id] = b.[requester_id]
    WHERE b.[is_deleted] = 0
      AND b.[status] = @status_approved
      AND b.[requested_start_time] >= @as_of
      AND b.[requested_start_time] < DATEADD(DAY, @lookahead_days, @as_of)
)
SELECT
    ulb.[booking_id],
    s.[space_code],
    s.[space_name],
    s.[space_type],
    s.[building],
    s.[floor],
    s.[room_number],
    ulb.[purpose],
    ulb.[requested_start_time],
    ulb.[requested_end_time],
    ulb.[expected_participants],
    s.[current_status] AS [space_status],
    CASE
        WHEN s.[current_status] <> @space_status_ready
            THEN N'Space status is ' + s.[current_status]
        WHEN active_maintenance.[maintenance_id] IS NOT NULL
            THEN N'Overlapping unresolved maintenance'
        ELSE N'Ready'
    END AS [readiness_flag],
    active_maintenance.[problem_description] AS [maintenance_issue],
    active_maintenance.[status]              AS [maintenance_status],
    active_maintenance.[start_time]          AS [maintenance_start_time]
FROM upcoming_lab_bookings ulb
INNER JOIN [dbo].[spaces] s
    ON ulb.[space_id] = s.[space_id]
OUTER APPLY (
    SELECT TOP 1
        m.[maintenance_id],
        m.[problem_description],
        m.[status],
        m.[start_time]
    FROM [dbo].[maintenances] m
    WHERE m.[space_id] = ulb.[space_id]
      AND m.[is_deleted] = 0
      AND m.[status] IN (@maint_open, @maint_in_progress)
      AND m.[start_time] < ulb.[requested_end_time]
      AND (m.[completion_time] IS NULL OR m.[completion_time] > ulb.[requested_start_time])
    ORDER BY m.[start_time]
) active_maintenance
WHERE s.[space_type] IN (@space_type_computer, @space_type_project)
  AND (
      s.[current_status] <> @space_status_ready
      OR active_maintenance.[maintenance_id] IS NOT NULL
  )
ORDER BY ulb.[requested_start_time], s.[space_code];
-- Note: returns zero rows when the TA has no approved upcoming
-- lab bookings with readiness problems. Current seed data gives
-- the TA a pending lab request, not an approved one, so the empty
-- default result is expected.
GO
