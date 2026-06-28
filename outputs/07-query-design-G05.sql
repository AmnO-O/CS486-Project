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